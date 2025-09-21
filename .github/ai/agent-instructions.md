# AI contribution guidance

Purpose: Constrain AI-assisted changes to be safe for a GitOps + SOPS/age mono-repo.

Core rules:

1. Never commit plaintext secrets. Only `*.secret.sops.yaml` and `*.sop.env` belong in git.
2. Respect `.sops.yaml` creation rules and `.gitignore` patterns.
3. Preserve Komodo conventions under `komodo/` and `stacks/` structure.
4. Avoid destructive script changes; prefer additive changes and documentation updates.
5. Update documentation under `docs/` and `README.md` when behavior changes.
6. Keep CI minimal, offline, and secrets-free. Optional decryption only with provided secrets.
7. Follow PR templates and include tests or validation steps for scripts.

Scope and context limits:

- Only read or modify files relevant to the stated task.
- Do not reformat or rename unrelated files.
- For large changes, propose an ADR under `docs/adr/` and link it in the PR.

Checklist before opening a PR:

- [ ] No plaintext secrets added
- [ ] Docs updated (README or docs/*)
- [ ] CI passes locally (make validate, lint)
- [ ] Komodo/TOML/YAML validated
- [ ] ADR added/updated if appropriate
