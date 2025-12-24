# HashiCorp Vault HA Automation

This repository contains a production-focused Ansible playbook that installs and hardens a three-node HashiCorp Vault cluster running in HA mode with raft storage. Every setting is customizable through group variables, letting you adjust versions, TLS files, and unseal workflows without editing tasks.

## Prerequisites

Before running this playbook, ensure you have:

1.  **Three Running Virtual Machines (VMs):** You need three VMs (e.g., `s-vault-01`, `s-vault-02`, `s-vault-03`) up and running.
2.  **Network Connectivity:** These VMs must have network connectivity to each other (for Raft consensus) and be accessible by the machine running Ansible.
3.  **Load Balancer:** A Load Balancer must be configured to distribute traffic to these three VMs.

## Layout

- `ansible.cfg` – shared Ansible defaults for this project.
- `inventory/hosts.ini` – primary node definitions (`s-vault-01`..`03`) with their private IPs.
- `group_vars/vault.yml` – cluster-level overrides (TLS paths, advertised address, etc.).
- `roles/vault` – reusable role that installs Vault from HashiCorp’s apt repo, renders configs, and manages systemd.
- `site.yml` – entry-point play that targets the `vault` group.

## Usage

1. Ensure the SSH key listed in `inventory/hosts.ini` works for each VM-specific user (the playbook logs in as `s-vault-0X` on the matching host).
2. Generate TLS assets locally with `scripts/generate-vault-certs.sh` (see [CERTS.md](CERTS.md)). The playbook copies everything from `certs/` to `/etc/vault.d/tls/`.
3. Decide which Vault release to deploy and pass the full package version (e.g., `-e vault_version=1.21.0-1`). The role refuses to run without the exact version string apt expects.
4. Optionally set auto-unseal info (`vault_use_auto_unseal` and `vault_gcp_kms`). When using GCP KMS, include the key’s `project_id`, `region` (or `location`) such as `me-central2`, `key_ring`, and `crypto_key`.
5. Run the playbook:

```bash
ansible-playbook site.yml
```

Pass the desired Vault version plus any other overrides at runtime, for example:

```bash
ansible-playbook site.yml -e vault_version=1.17.3-1 -e vault_service_environment='{"VAULT_ADDR":"https://vault.devanshu.dev:8200"}'
```

Use `apt-cache policy vault` or `apt-cache madison vault` on any Ubuntu 24.04 host to confirm the exact package versions published in HashiCorp's repository and pass that full value (e.g., `1.21.0-1`).

## Post-Deployment

Once services start, initialize and unseal Vault manually (or via auto-unseal if configured):

```bash
# GCP
export VAULT_ADDR=http://s-vault-01.devanshu.dev:8200 vault operator init
export VAULT_ADDR=http://s-vault-01.devanshu.dev:8200 vault operator unseal

# AWS
export VAULT_ADDR=http://vault-01.devanshu.dev:8200 vault operator init
export VAULT_ADDR=http://vault-01.devanshu.dev:8200 vault operator unseal

```

Repeat the unseal step on each node to satisfy the quorum. Use a load balancer/DNS (e.g., `vault.devanshu.dev`) for clients after the cluster is initialized.

## TLS Certificates & DNS

- Store generated keys and certificates under `certs/` (git-ignored).
- Run `bash scripts/generate-vault-certs.sh` to create a CA plus per-node certs aligned with the inventory IPs and the `*.devanshu.dev` names used in Cloud DNS.
- Create an internal Cloud DNS zone (e.g., `devanshu.dev`) in GCP and add A records for `s-vault-01/02/03.devanshu.dev` pointing to the private IPs as well as an alias like `vault.devanshu.dev` for the internal load balancer.
- Review [CERTS.md](CERTS.md) for field descriptions, regeneration tips, and verification commands.
