# Ansible Operations Guide

Use this document as a quick reference for running the Vault HA automation and understanding the code layout.

## Project Layout
- `ansible.cfg` – global Ansible defaults: inventory path, SSH options, YAML output for readability.
- `inventory/hosts.ini` – declares the three Vault nodes and ties each host to its VM-specific user and private key.
- `group_vars/vault.yml` – cluster-wide overrides such as TLS file locations, cluster name, advertised address, and (optionally) auto-unseal config.
- `site.yml` – entry point play, includes the `vault` role for every host in the `vault` group.
- `roles/vault/` – all automation logic:
  - `defaults/` – tunable variables with safe defaults.
  - `tasks/` – installation, configuration, and service management steps.
  - `templates/` – Jinja2 templates for `vault.hcl`, systemd unit, and environment file.
  - `handlers/` – restart logic triggered when config changes.

## Common Commands
- Dry run against all nodes (good for syntax and connectivity; package-install tasks are skipped automatically):
  ```bash
  ansible-playbook site.yml --check
  ```
- Full deployment with verbose output:
  ```bash
  ansible-playbook site.yml -vv
  ```
- Limit execution to a single node while testing:
  ```bash
  ansible-playbook site.yml -l s-vault-01
  ```
- Override variables at runtime (example version bump):
  ```bash
  ansible-playbook site.yml -e vault_version=1.17.3
  ```
- Use an alternate inventory (e.g., staging):
  ```bash
  ansible-playbook -i inventory/stage.ini site.yml
  ```
- Only run handlers (e.g., to reload configs after manual edits):
  ```bash
  ansible-playbook site.yml --tags handlers
  ```
- Syntax validation without connecting to hosts:
  ```bash
  ansible-playbook site.yml --syntax-check
  ```

## Ad-hoc Checks
- Ping every Vault node to confirm SSH access and Python availability:
  ```bash
  ansible vault -m ping
  ```
- Gather facts for a single host (useful for debugging variables):
  ```bash
  ansible s-vault-02 -m setup
  ```
- Run a one-off shell command on all nodes:
  ```bash
  ansible vault -m shell -a "systemctl status vault --no-pager"
  ```

## Tips
- Keep TLS material synchronized with the paths declared in `group_vars/vault.yml` or pass overrides with `-e`.
- Generate/refresh local TLS assets via `bash scripts/generate-vault-certs.sh` (artifacts land in `certs/` and are uploaded automatically when `vault_copy_tls_files=true`).
- When using your private Cloud DNS zone (`devanshu.dev`), add `s-vault-0X.devanshu.dev` and `vault.devanshu.dev` A records pointing to the VM IPs/LB so certificates and advertised addresses resolve internally.
- Always provide the desired Vault package version (e.g., `-e vault_version=1.21.0-1`); run `apt-cache madison vault` on a node to inspect available versions.
- When testing new GCP KMS keys, set `vault_use_auto_unseal=true` and supply the full `vault_gcp_kms` dictionary (include a `region` such as `me-central2`; `location` can be used as a fallback).
- After any change under `roles/vault`, rerun `ansible-playbook site.yml --syntax-check` to catch template errors early.
