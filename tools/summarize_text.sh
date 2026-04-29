#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 0 ]]; then
  args="$1"
else
  args='{}'
fi
text="$(jq -r '.text // ""' <<< "$args")"

word_count="$(wc -w <<< "$text" | tr -d ' ')"
char_count="${#text}"
summary="$(awk '{
  for (i = 1; i <= NF && i <= 12; i++) {
    printf "%s%s", (i == 1 ? "" : " "), $i
  }
  if (NF > 12) {
    printf "..."
  }
  printf "\n"
}' <<< "$text")"

jq -n \
  --arg summary "$summary" \
  --argjson word_count "$word_count" \
  --argjson char_count "$char_count" \
  '{summary: $summary, word_count: $word_count, char_count: $char_count}'
