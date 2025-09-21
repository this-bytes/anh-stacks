# ADR 0001: Repository governance and secrets

Status: accepted
Deciders: repo maintainers
Date: 2025-09-20

## Context

We need a clear governance model for a homelab GitOps mono-repo and a secure approach to secrets.

## Decision

- Use GitHub PRs for all changes to `main`
- Document operations and deployment flows under `docs/`
- Adopt SOPS + age with creation rules in `.sops.yaml`
- Store only encrypted secrets in the repo
- Provide Make targets and scripts for secure local workflows

## Consequences

- Simpler onboarding with documented workflows
- Reduced risk of committing plaintext secrets
- Consistent CI checks and safer reviews