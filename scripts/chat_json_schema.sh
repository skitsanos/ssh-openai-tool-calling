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
        content: "Return only data that satisfies the requested schema."
      },
      {
        role: "user",
        content: "Create a compact research note comparing plain text responses, JSON Schema responses, and tool calling in Chat Completions."
      }
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "chat_completions_research_note",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: ["title", "patterns", "recommendation"],
          properties: {
            title: { type: "string" },
            patterns: {
              type: "array",
              minItems: 3,
              maxItems: 3,
              items: {
                type: "object",
                additionalProperties: false,
                required: ["name", "best_for", "tradeoff"],
                properties: {
                  name: { type: "string" },
                  best_for: { type: "string" },
                  tradeoff: { type: "string" }
                }
              }
            },
            recommendation: { type: "string" }
          }
        }
      }
    }
  }' > "$payload"

chat_completions "$payload" > "$response"

echo "Structured JSON response:"
jq -r '.choices[0].message.content' "$response" | jq .
echo
jq -r 'if .usage then "tokens prompt=\(.usage.prompt_tokens) completion=\(.usage.completion_tokens) total=\(.usage.total_tokens)" else "tokens unavailable" end' "$response"
