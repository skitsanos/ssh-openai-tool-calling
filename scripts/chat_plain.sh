#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source scripts/lib/openai.sh
load_env

payload="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "$payload" "$response"' EXIT

jq -n \
  --arg model "$OPENAI_MODEL" \
  '{
    model: $model,
    messages: [
      {
        role: "system",
        content: "You are a concise technical explainer."
      },
      {
        role: "user",
        content: "In one short paragraph, explain why shell scripts are useful for prototyping OpenAI tool calls."
      }
    ]
  }' > "$payload"

chat_completions "$payload" > "$response"

echo "Plain text response:"
jq -r '.choices[0].message.content' "$response"
echo
jq -r 'if .usage then "tokens prompt=\(.usage.prompt_tokens) completion=\(.usage.completion_tokens) total=\(.usage.total_tokens)" else "tokens unavailable" end' "$response"
