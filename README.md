# anh-stacks

Homelab mono-repo to manage a Docker Swarm cluster using Ansible and Komodo. Komodo watches the `stacks/` folder and deploys changes based on Git pushes. Secrets are managed with SOPS and age.

## Overview

- Orchestration: Docker Swarm
- GitOps engine: Komodo watches this repo and applies stack changes
- Edge routing: Traefik
- Secrets: SOPS + age (no plaintext secrets committed)

## Repository structure

- `komodo/` – Komodo release/stack configuration (.toml)
- `stacks/` – Swarm stack manifests, compose files, and Traefik dynamic config
- `swarm/` – Alternative/local Swarm compose stacks and configs
- `shared/` – Shared SOPS-encrypted secrets and env files
- `scripts/` – Helper scripts (e.g., decrypting secrets locally)
- `.github/` – CI, issue/PR templates, and AI guidance for contributors
- `.sops.yaml` – SOPS creation rules for age recipients and file matching
- `Makefile` – Utilities: validate, lint, age key generation, encrypt/decrypt

## Prerequisites

- age and sops installed (see Makefile `install-tools` target)
- Python 3 for validation helpers (PyYAML and toml used in CI)
- Docker Swarm cluster initialized and accessible by Komodo

## Getting started

### Quick Bootstrap (Recommended)

For a complete Docker Swarm cluster with NFS shared storage and SOPS secrets:

```bash
# Install ansible on your control machine first
sudo apt update && sudo apt install ansible

# Clone and bootstrap the entire cluster
git clone https://github.com/this-bytes/anh-stacks.git
cd anh-stacks

# Complete automated setup
make bootstrap
```

This will:
1. Install required tools (age, sops)
2. Generate age encryption key
3. Bootstrap Docker Swarm cluster via Ansible
4. Setup NFS shared storage
5. Encrypt and deploy secrets
6. Deploy core infrastructure stacks

### Manual Setup (Advanced)

1) Install dependencies
   - Option A (local): use the provided Make target
     - `make install-tools`
   - Option B: install via your distro package manager

2) Generate an age key (if you don't have one)
   - `make age-key`
   - This will create `age.key` and export `SOPS_AGE_KEY_FILE` in `.env` for convenience

3) Bootstrap the swarm cluster
   - `make site` - Deploy Docker Swarm cluster
   - `make storage` - Setup NFS shared storage

4) Encrypt secrets
   - Place any transient plaintext files named like `*.secret.yaml` or `*.env` in `shared/` or a stack folder under `stacks/<stack>/`
   - Run `make encrypt-secrets TARGET=shared` or `TARGET=<stack>`
   - The encrypted outputs will be `*.secret.sops.yaml` and `*.sop.env`; plaintext will be removed

5) Validate the repo
   - `make validate`
   - Or push a branch/PR to trigger CI

6) Deploy via Komodo
   - Komodo will watch `komodo/` and `stacks/` and deploy accordingly
   - See `docs/DEPLOYMENT.md` for topology and flow

### Custom Configuration

Before running bootstrap, you may want to customize:

- `ansible/inventories/homelab/hosts.yml` - Your server IPs
- `ansible/inventories/homelab/group_vars/managers.yml` - NFS and swarm configuration
- `shared/komodo.env` - Domain and repository settings (before encryption)

## Secrets management

This repo never stores plaintext secrets. Encrypted files end in:

- `*.secret.sops.yaml` for YAML
- `*.sop.env` for env files

See `docs/SECRETS.md` for:

- How SOPS and age are configured via `.sops.yaml`
- Key rotation and multi-recipient setups
- Local decryption and guardrails

## Traefik

Traefik configuration and dynamic routes live under:

- `stacks/traefik/` for compose and dynamic config in a Swarm-managed context
- `swarm/traefik/` as an alternative local compose stack

See `docs/OPERATIONS.md` for operational notes.

## CI

GitHub Actions validate TOML and YAML across the repository and lint shell scripts. CI does not require secrets; SOPS files are checked structurally, and optional decryption is performed only if an `AGE_KEY` secret is provided.

## Contributing

Please read `CONTRIBUTING.md` and the PR/Issue templates under `.github/`. For AI-assisted changes, the guidance in `.github/ai/agent-instructions.md` governs context and safety.
