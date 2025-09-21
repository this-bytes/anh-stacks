# Operations guide

This guide captures day-2 ops for the homelab Swarm cluster managed via Komodo.

## Daily tasks

- Review CI results on PRs and main
- Inspect Komodo sync status and Swarm service health
- Rotate and refresh certificates (e.g., via Traefik/acme) as needed

## Secrets

- Use `make encrypt-secrets` and `make decrypt-secrets` as documented in `docs/SECRETS.md`
- Never commit plaintext `*.secret.yaml` or `*.env` files (they are .gitignored)

## Backups

- Back up the Git repo and any external volumes used by stacks (e.g., Traefik ACME storage)
- Store `age.key` securely (not in the repo)

## Troubleshooting

- Validate config: `make validate`
- Lint shell scripts: `make lint`
- Check Traefik routing via dashboard (if enabled) and logs

## Upgrades

- Incrementally update stack compose files and Komodo descriptors via PRs
- Use Git revert for rollbacks if a change causes regressions