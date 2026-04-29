#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source scripts/lib/openai.sh
load_env

messages="$(mktemp)"
payload="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "$messages" "$payload" "$response"' EXIT

jq -n '[
  {
    role: "system",
    content: "You are a concise CLI assistant. Keep answers practical and direct."
  }
]' > "$messages"

echo "Chat Completions CLI demo"
echo "Model: ${OPENAI_MODEL}"
echo "Type /exit or press Ctrl-D to quit."
echo

while true; do
  printf "you> "
  if ! IFS= read -r user_input; then
    echo
    break
  fi

  case "$user_input" in
    /exit|/quit) break ;;
    "") continue ;;
  esac

  jq \
    --arg content "$user_input" \
    '. + [{role: "user", content: $content}]' "$messages" > "${messages}.next"
  mv "${messages}.next" "$messages"

  jq -n \
    --arg model "$OPENAI_MODEL" \
    --slurpfile messages "$messages" \
    '{
      model: $model,
      messages: $messages[0]
    }' > "$payload"

  chat_completions "$payload" > "$response"

  assistant_content="$(jq -r '.choices[0].message.content // ""' "$response")"
  printf "assistant> %s\n\n" "$assistant_content"

  jq \
    --arg content "$assistant_content" \
    '. + [{role: "assistant", content: $content}]' "$messages" > "${messages}.next"
  mv "${messages}.next" "$messages"
done
