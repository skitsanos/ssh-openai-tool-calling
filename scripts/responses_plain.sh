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
    instructions: "You are a concise technical explainer. Be precise: the Responses API uses input/instructions, emits output items and output_text, supports previous_response_id for continuing state, and uses function_call/function_call_output for custom tools. Do not describe it as API Labs or as only single-shot.",
    input: "In one short paragraph, explain what the OpenAI Responses API changes compared with a Chat Completions style request."
  }' > "$payload"

responses_create "$payload" > "$response"

echo "Responses API plain text response:"
jq -r '.output_text // (.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text)' "$response"
echo
print_usage_cost_fields < "$response"
