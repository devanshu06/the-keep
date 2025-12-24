# HashiCorp Vault – Google SSO (OIDC) Configuration Guide

This document provides a complete, step-by-step guide for enabling **Google OAuth (OIDC) SSO** in a HashiCorp Vault HA cluster. It includes:

* Google Cloud OAuth setup
* Vault OIDC configuration
* Role creation (readonly, readwrite, admin)
* Policy creation
* Identity entity & alias mapping
* Testing and troubleshooting

This guide reflects the final working configuration achieved in the conversation.

---

## 1. Prerequisites

### Vault Setup

* Vault HA cluster with nodes:

  * `vault-01.devanshu.dev`
  * `vault-02.devanshu.dev`
  * `vault-03.devanshu.dev`
* Load balancer exposed at:

  * `https://vault.devanshu.dev`
* KV v2 secret engines mounted at:

  * `stage/`
  * `prod/`
* Use the public Vault URL for CLI/UI:

```bash
export VAULT_ADDR="https://vault.devanshu.dev"
```

### Domain

* Google Workspace domain: **devanshu.dev**

### Required Users

* `user@devanshu.dev` → **readwrite**
* `admin@devanshu.dev` → **admin**
* All other devanshu.dev users → **readonly**

---

## 2. Create Google OAuth Credentials

### Step 1 — Create OAuth Client

1. Go to **Google Cloud Console** → *APIs & Services → Credentials*.
2. Click **Create Credentials → OAuth Client ID**.
3. Choose **Web Application**.
4. Add the following Authorized Redirect URI:

```
https://vault.devanshu.dev/ui/vault/auth/oidc/oidc/callback
```

5. Save and copy:

   * **Client ID**
   * **Client Secret**

### Step 2 — Scopes (OAuth Consent Screen)

Make sure these scopes are added:

* `openid`
* `email`
* `profile`

### Step 3 — User Type

Set OAuth consent screen **User Type = Internal**.

---

## 3. Export Vault Variables

```bash
export VAULT_ADDR="https://vault.devanshu.dev"
export CLIENT_ID="<google-client-id>"
export CLIENT_SECRET="<google-client-secret>"
export REDIRECT_URI="https://vault.devanshu.dev/ui/vault/auth/oidc/oidc/callback"
```

(Standard POSIX shell syntax is used for all examples below.)

---

## 4. Enable + Configure the OIDC Auth Method

```bash
vault auth enable oidc

vault write auth/oidc/config \
  oidc_discovery_url="https://accounts.google.com" \
  oidc_client_id="$CLIENT_ID" \
  oidc_client_secret="$CLIENT_SECRET" \
  default_role="readonly"
```

---

## 5. Create Vault Policies

### 5.1 readonly.hcl

```hcl
path "stage/data/*" {
  capabilities = ["read", "list"]
}

path "stage/metadata/*" {
  capabilities = ["read", "list"]
}

path "prod/data/*" {
  capabilities = ["read", "list"]
}

path "prod/metadata/*" {
  capabilities = ["read", "list"]
}
```

### 5.2 readwrite.hcl

```hcl
path "stage/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "stage/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "prod/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "prod/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

### 5.3 admin.hcl

```hcl
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
```

### Apply policies:

```bash
vault policy write readonly readonly.hcl
vault policy write readwrite readwrite.hcl
vault policy write admin admin.hcl
```

---

## 6. Create OIDC Roles (Using JSON Files)

Vault + fish shell requires full JSON bodies.

### 6.1 readonly-role.json

```json
{
  "bound_audiences": "<google-client-id>",
  "allowed_redirect_uris": [
    "https://vault.devanshu.dev/ui/vault/auth/oidc/oidc/callback"
  ],
  "user_claim": "email",
  "oidc_scopes": ["openid", "email", "profile"],
  "token_policies": ["readonly"],
  "bound_claims": {
    "hd": ["devanshu.dev"]
  }
}
```

Apply:

```bash
vault write auth/oidc/role/readonly @readonly-role.json
```

---

### 6.2 readwrite-role.json

```json
{
  "bound_audiences": "<google-client-id>",
  "allowed_redirect_uris": [
    "https://vault.devanshu.dev/ui/vault/auth/oidc/oidc/callback"
  ],
  "user_claim": "email",
  "oidc_scopes": ["openid", "email", "profile"],
  "token_policies": ["readwrite"],
  "bound_claims": {
    "email": ["user@devanshu.dev"],
    "hd": ["devanshu.dev"]
  }
}
```

Apply:

```bash
vault write auth/oidc/role/readwrite @readwrite-role.json
```

---

### 6.3 admin-role.json

```json
{
  "bound_audiences": "<google-client-id>",
  "allowed_redirect_uris": [
    "https://vault.devanshu.dev/ui/vault/auth/oidc/oidc/callback"
  ],
  "user_claim": "email",
  "oidc_scopes": ["openid", "email", "profile"],
  "token_policies": ["admin"],
  "bound_claims": {
    "email": ["admin@devanshu.dev"],
    "hd": ["devanshu.dev"]
  }
}
```

Apply:

```bash
vault write auth/oidc/role/admin @admin-role.json
```

---

## 7. Configure Identity Entities (User-Specific Permissions)

This ensures:

* `user@devanshu.dev` gets **readwrite**
* `admin@devanshu.dev` gets **admin**
* All other devanshu.dev users get **readonly**

### Step 1 — Get OIDC mount accessor

```bash
OIDC_ACCESSOR=$(vault auth list -format=json | jq -r '."oidc/".accessor')/".accessor')
```

### Step 2 — Create identity entities

#### Admin Entity

```bash
DEV_ID=$(vault write -format=json identity/entity name="admin" policies="admin" | jq -r .data.id)

vault write identity/entity-alias \
  name="admin@devanshu.dev" \
  canonical_id="$DEV_ID" \
  mount_accessor="$OIDC_ACCESSOR"="$DEV_ID" \
  mount_accessor="$OIDC_ACCESSOR"
```

#### Readwrite Entity

```bash
USER_ID=$(vault write -format=json identity/entity name="user" policies="readwrite" | jq -r .data.id)

vault write identity/entity-alias \
  name="user@devanshu.dev" \
  canonical_id="$USER_ID" \
  mount_accessor="$OIDC_ACCESSOR"="$OIDC_ACCESSOR"
```

---

## 8. Login Testing

### UI Login

Navigate to:

```
https://vault.devanshu.dev/ui
```

Choose **OIDC** → Authenticate using Google.

### CLI Login

```bash
vault login -method=oidc
```

### Validate Permissions

```bash
vault kv get stage/booking-service
vault kv put stage/test key=value   # only readwrite and admin
vault kv list stage/
```

---

## 9. Troubleshooting

### Error: "claim email not found"

Fix:

* Ensure `oidc_scopes` includes `email`
* Google app must be **Internal**
* Email scope must be approved on OAuth consent screen

### Access denied for KV

Fix:

* Verify policies use correct KV v2 paths:

  * `stage/data/*`
  * `stage/metadata/*`

### "Must specify at least one config path" error

Cause:

* Running `vault server` incorrectly
  Fix:
* Use `vault debug` instead of re-running Vault server.

---

## 10. Summary

This setup enables:

* Google Workspace SSO using OIDC
* Domain-restricted login (`devanshu.dev`)
* Role-based access:

  * **readonly** → all users
  * **readwrite** → `user@devanshu.dev`
  * **admin** → `admin@devanshu.dev`
* Clean KV v2 permissions
* Identity entity overrides for precise RBAC

---

