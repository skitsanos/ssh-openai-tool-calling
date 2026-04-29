#!/usr/bin/env bash

set -euo pipefail

missing=0

for binary in bash curl jq; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    echo "Missing required dependency: $binary" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "Dependencies available: bash, curl, jq"
