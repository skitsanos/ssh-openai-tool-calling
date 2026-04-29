#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 0 ]]; then
  args="$1"
else
  args='{}'
fi
path="$(jq -r '.path // "."' <<< "$args")"

case "$path" in
  ""|"null") path="." ;;
  /*|*..*) jq -n --arg path "$path" '{error: "Path must be relative and must not contain ..", path: $path}'; exit 0 ;;
esac

if [[ ! -d "$path" ]]; then
  jq -n --arg path "$path" '{error: "Path does not exist or is not a directory", path: $path}'
  exit 0
fi

count="$(find "$path" -path "$path/.git" -prune -o -type f -print | wc -l | tr -d ' ')"

jq -n \
  --arg path "$path" \
  --argjson count "$count" \
  '{path: $path, file_count: $count}'
