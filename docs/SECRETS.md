# Secrets management (SOPS + age)

This repository uses SOPS and age to encrypt secrets. Plaintext secrets must never be committed.

- Encrypted YAML secrets: `*.secret.sops.yaml`
- Encrypted env files: `*.sop.env`

The `.sops.yaml` file defines creation rules that match plaintext patterns:

- `*.secret.yaml`
- `*.env`

When you run the Make target `make encrypt-secrets TARGET=<stack|shared>`, plaintext files are encrypted and replaced with their SOPS equivalents, and the plaintext files are removed.

## Bootstrap

1) Generate an age key (or use an existing one)

- `make age-key` will generate `age.key` and set `SOPS_AGE_KEY_FILE` in `.env`.
- The public key should be added to `.sops.yaml` under the appropriate `key_groups.age` list. Commit the `.sops.yaml` change.

2) Encrypt secrets

- Place plaintext files temporarily: `shared/*.secret.yaml`, `shared/*.env`, or `stacks/<stack>/*.secret.yaml`, `stacks/<stack>/*.env`.
- Run: `make encrypt-secrets TARGET=shared` or `TARGET=<stack>`.
- Verify encrypted files are created: `*.secret.sops.yaml`, `*.sop.env`.
- Ensure `.gitignore` excludes plaintext and includes encrypted files (already configured).

## Decrypting locally

Use the helper script to decrypt into working files:

- `make decrypt-secrets TARGET=shared` or `TARGET=<stack>` (invokes `scripts/decrypt-secrets.sh`).

Caution: Decrypted outputs (`*.secret.yaml`, `*.env`) are .gitignored, but keep them secure and do not commit.

## CI and automation

- CI performs structural validation of SOPS files when possible without requiring secrets.
- Optional decryption in CI only runs if an `AGE_KEY` secret is configured for the repository.

## Key rotation

- Add the new age public key to `.sops.yaml` (do not remove the old one yet).
- Re-encrypt files (SOPS will include all recipients): `sops updatekeys` or re-encrypt via the Make target by temporarily decrypting and re-encrypting.
- After confirming the new key works, remove the old key from `.sops.yaml` and re-encrypt.

## Multi-recipient setup

To grant access to multiple operators or environments, list all recipients under the `age:` list for the matching rule in `.sops.yaml`.