#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 0 ]]; then
  args="$1"
else
  args='{}'
fi
timezone="$(jq -r '.timezone // "UTC"' <<< "$args")"

if [[ -z "$timezone" || "$timezone" == "null" ]]; then
  timezone="UTC"
fi

if ! timestamp="$(TZ="$timezone" date +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null)"; then
  jq -n --arg timezone "$timezone" '{error: "Invalid timezone", timezone: $timezone}'
  exit 0
fi

jq -n \
  --arg timezone "$timezone" \
  --arg timestamp "$timestamp" \
  '{timezone: $timezone, timestamp: $timestamp}'
