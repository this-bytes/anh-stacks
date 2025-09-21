# Contributing

Thanks for contributing to this homelab mono-repo.

## Workflow

- Fork and create feature branches
- Open PRs against `main`
- Ensure CI passes; include docs changes
- For substantial changes, add an ADR under `docs/adr/`

## Coding standards

- No plaintext secrets; use SOPS + age only
- Keep diffs minimal and focused
- Update `README.md` and `docs/` for user-facing changes

## Local commands

- Validate TOML: `make validate`
- Lint shell: `make lint`
- Encrypt secrets: `make encrypt-secrets TARGET=...`
- Decrypt secrets: `make decrypt-secrets TARGET=...`
