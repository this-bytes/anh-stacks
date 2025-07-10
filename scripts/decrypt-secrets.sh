#!/bin/bash
# Decrypt all SOPS-encrypted secrets and envs for a given stack or shared
set -euo pipefail

TARGET=${1:-}

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <stackname|shared>"
  exit 1
fi

if [[ "$TARGET" == "shared" ]]; then
  DIR="$(dirname "$0")/../shared"
else
  DIR="$(dirname "$0")/../stacks/$TARGET"
fi

if [[ ! -d "$DIR" ]]; then
  echo "Directory $DIR does not exist."
  exit 0
fi

find "$DIR" -type f \( -name '*.sops.yaml' -o -name '*.sop.env' \) | while read -r encfile; do
  out="${encfile/.sops.yaml/.yaml}"
  out="${out/.sop.env/.env}"
  echo "Decrypting $encfile -> $out"
  sops -d "$encfile" > "$out"
    rm -f "$encfile"
done
