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
    instructions: "Return only data that satisfies the requested schema. Use these facts: Chat Completions uses messages, returns choices[].message, and represents custom tool calls as assistant tool_calls followed by role=tool messages. Responses uses input and instructions, returns output items plus output_text, can continue with previous_response_id, and sends custom tool results back as function_call_output items.",
    input: "Create a compact comparison of Chat Completions and Responses API for shell-based demos.",
    text: {
      format: {
        type: "json_schema",
        name: "responses_api_comparison",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: ["title", "chat_completions", "responses_api", "when_to_use_responses"],
          properties: {
            title: { type: "string" },
            chat_completions: { type: "string" },
            responses_api: { type: "string" },
            when_to_use_responses: { type: "string" }
          }
        }
      }
    }
  }' > "$payload"

responses_create "$payload" > "$response"

echo "Responses API structured JSON response:"
jq -r '.output_text // (.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text)' "$response" | jq .
echo
print_usage_cost_fields < "$response"
