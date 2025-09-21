# Deployment and GitOps flow

This repository is designed for GitOps: Komodo monitors the repository and applies changes to a Docker Swarm cluster.

## Components

- Docker Swarm: Cluster providing scheduling and networking
- Komodo: Watches this repo and deploys defined stacks
- Traefik: Entry point and routing
- Secrets: SOPS + age encrypted files committed to the repo

## High-level flow

1. Developer updates files under `stacks/` (compose, configs) or `komodo/` (release/stack definitions)
2. Changes are pushed to the main branch (after PR review)
3. Komodo detects repository changes and reconciles the Swarm state
4. Services are updated with zero-downtime strategies where defined

## Folder conventions

- `komodo/release/*.toml` and `komodo/stacks/*.toml`: Komodo descriptors
- `stacks/<stack>/docker-compose.yml`: Swarm stack definition
- `stacks/<stack>/*.secret.sops.yaml` and `*.sop.env`: SOPS-encrypted inputs

## Traefik specifics

- Traefik Stack:
  - `stacks/traefik/docker-compose.yml`
  - Dynamic configuration: `stacks/traefik/dynamic_conf.toml`
- Alternative local/standalone compose for testing: `swarm/traefik/`

## Environments

This repo targets a homelab Swarm cluster. If you later add environments, prefer branch- or path-based separation and environment-specific SOPS recipients.

## Rollback strategy

- Use Git to revert commits, which will trigger Komodo to reconcile back to the previous state.
- Keep secrets compatible across versions or update SOPS files as needed.