# Vault Raft Snapshot Restore Guide (Full Cluster Restore)

This document provides a clear and safe procedure for performing a **full restore** of a HashiCorp Vault HA cluster that uses **Integrated Storage (Raft)**. This operation restores Vault to the exact state captured in the snapshot.

> ⚠️ **WARNING — This operation overwrites ALL Vault data.**
> After restore, Vault will contain *only* the data that existed at the time of the snapshot.
> Anything created later (secrets, roles, policies, identities, tokens, leases) will be lost.

Use this guide only if you intend to fully revert your Vault cluster to an earlier state.

---

# 1. Requirements

* A valid Raft snapshot file (e.g., `vault-backup.snap`)
* Access to all Vault nodes
* Access to the leader node for the restore command
* Vault is using **Raft storage** (`storage "raft" { ... }`)

---

# 2. Identify the Vault Leader

You may identify the leader prior to restore using:

```bash
export VAULT_ADDR="https://vault-01.devanshu.dev:8200"
vault operator raft list-peers
```

The leader is the node with:

```
"leader": true
```

You will run the **restore command on this node**.

---

# 3. Stop Vault on ALL Nodes

Run on **each node** (vault-01, vault-02, vault-03):

```bash
sudo systemctl stop vault
```

Ensure that *all* Vault nodes are stopped before proceeding.

---

# 4. Clear Raft Storage Directory on the Leader Node

Vault requires a clean raft directory before restoring a snapshot.

> ⚠️ **THIS WILL ERASE ALL CURRENT VAULT DATA.**

Locate your Vault raft storage path. Common paths:

* `/opt/vault/data`
* `/vault/data`
* `/var/lib/vault/data`

Example:

```bash
sudo rm -rf /opt/vault/data/*
```

Replace the directory with the one configured in your Vault server config.

---

# 5. Restore the Snapshot

On the **leader node**, run:

```bash
export VAULT_ADDR="https://vault-01.devanshu.dev:8200"
vault operator raft snapshot restore vault-backup.snap
```

If the file is in another directory, include the path:

```bash
vault operator raft snapshot restore /home/ubuntu/backup/vault-backup.snap
```

Expected output should confirm restoration succeeded.

---

# 6. Start Vault on All Nodes

After the snapshot is restored on the leader, start Vault everywhere:

Run on each node:

```bash
sudo systemctl start vault
```

All nodes will automatically join the cluster and sync state from the restored leader.

Verify:

```bash
VAULT_ADDR="https://vault-01.devanshu.dev:8200" vault status
```

---

# 7. Verify Restore Success

Test secret retrieval:

```bash
vault kv get stage/your-secret
```

Check mounts:

```bash
vault secrets list
```

Validate auth methods:

```bash
vault auth list
```

Check identity entities and aliases if needed:

```bash
vault list identity/entity/name
```

---

# 8. Post-Restore Notes

### ✔ The following **ARE restored**:

* All KV secrets
* Transit & PKI data
* Auth backends + configuration (OIDC, AppRole, AWS, etc.)
* Policies
* Identity entities, groups, aliases
* Token & lease metadata
* Secret engine mounts

### ❌ The following **ARE NOT restored**:

* Vault server config (`vault.hcl`)
* TLS certificates
* OS files, system configs
* Audit logs

Ensure these exist separately as part of server configuration management.

---

# 9. Restore Checklist

Use this quick checklist before performing a restore:

* [ ] Snapshot file verified (`vault operator raft snapshot inspect`)
* [ ] Maintenance window confirmed
* [ ] All applications prepared for downtime
* [ ] All Vault nodes confirmed stopped
* [ ] Raft directory backed up (optional)
* [ ] Snapshot restore tested on a temporary node (recommended)

---

# 10. Optional: Validate Snapshot File

Before restoring, inspect snapshot:

```bash
vault operator raft snapshot inspect vault-backup.snap
```

This will show:

* Term
* Index
* Cluster servers
* Snapshot version

---
