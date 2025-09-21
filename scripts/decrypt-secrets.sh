#!/bin/bash
# Decrypt all SOPS-encrypted secrets and envs for a given stack or shared
# Non-destructive: keeps encrypted files, writes decrypted copies alongside.
set -euo pipefail

TARGET=${1:-}

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <stackname|shared>" >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"

if [[ "$TARGET" == "shared" ]]; then
  DIR="$script_dir/../shared"
else
  DIR="$script_dir/../stacks/$TARGET"
fi

if [[ ! -d "$DIR" ]]; then
  echo "Directory $DIR does not exist." >&2
  exit 0
fi

shopt -s nullglob
mapfile -t files < <(find "$DIR" -type f \( -name '*.sops.yaml' -o -name '*.sop.env' \) -print)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No SOPS-encrypted files found in $DIR"
  exit 0
fi

for encfile in "${files[@]}"; do
  out="${encfile/.sops.yaml/.yaml}"
  out="${out/.sop.env/.env}"
  echo "Decrypting $encfile -> $out"
  sops -d "$encfile" > "$out"
  chmod 600 "$out" || true
done
