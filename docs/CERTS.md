# Vault TLS Certificate Workflow

These steps create a dedicated certificate authority (CA) plus per-node server certificates for the Vault cluster. All artifacts live under the local `certs/` directory so Ansible can upload them automatically.

## 1. Customize targets (optional)
Edit `scripts/generate-vault-certs.sh` if you need to change:

- `TARGETS` – hostname/IP pairs. Defaults match `s-vault-01`..`03`.
- `CLUSTER_DOMAIN` – second DNS entry the cert gets (defaults to `devanshu.dev` for Devanshu's Cloud DNS zone).
- `LB_HOSTNAME` – optional extra SAN, defaults to `vault.devanshu.dev` so the per-node certs also cover the internal load balancer name.
- `CERT_DAYS` – validity window (3650 days by default).

## 2. Generate CA and node certificates
Run the helper from the repo root:

```bash
bash scripts/generate-vault-certs.sh
```

The script creates:

- `certs/vault-root-ca.crt` / `vault-root-ca.key`
  - `certs/<node>.crt` / `certs/<node>.key` for each host (SANs include `s-vault-0X` and `s-vault-0X.devanshu.dev`)
- matching `.csr` and `.ext` files for troubleshooting

Re-run anytime; existing files are backed up with a `.bak` suffix before regeneration.

## 3. Use the certificates with Ansible
The `vault` role (when `vault_copy_tls_files=true`, which is the default) copies these files to every VM automatically:

- CA → `/etc/vault.d/tls/ca.crt`
- Server cert → `/etc/vault.d/tls/prod-vault.crt`
- Server key → `/etc/vault.d/tls/prod-vault.key`

Ensure `group_vars/vault.yml` points to the desired remote paths. If you prefer different filenames or DNS suffixes, change the vars or pass overrides via `-e`/environment variables before running the script.

## 4. Validating

```bash
openssl x509 -in certs/s-vault-01.crt -text -noout | grep -n "Subject Alternative Name" -A2
openssl verify -CAfile certs/vault-root-ca.crt certs/s-vault-01.crt
```

After deployment, confirm Vault is listening with TLS enabled:

```bash
curl -s https://s-vault-01.devanshu.dev:8200/v1/sys/health --cacert certs/vault-root-ca.crt
```

Keep the CA key secret (`certs/vault-root-ca.key`) and consider storing production certificates in a secrets manager instead of git.
