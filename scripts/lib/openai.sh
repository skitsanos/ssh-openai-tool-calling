#!/usr/bin/env bash

set -euo pipefail

load_env() {
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
  fi

  : "${OPENAI_BASE_URL:=https://api.openai.com/v1}"
  : "${OPENAI_MODEL:=gpt-4.1-mini}"

  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "OPENAI_API_KEY is required. Add it to .env or export it in your shell." >&2
    exit 1
  fi
}

chat_completions() {
  local payload_file="$1"

  curl --fail-with-body --silent --show-error \
    "${OPENAI_BASE_URL%/}/chat/completions" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "@${payload_file}"
}

responses_create() {
  local payload_file="$1"

  curl --fail-with-body --silent --show-error \
    "${OPENAI_BASE_URL%/}/responses" \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "@${payload_file}"
}

print_usage_cost_fields() {
  jq -r '
    if .usage then
      if .usage.prompt_tokens then
        "tokens prompt=\(.usage.prompt_tokens) completion=\(.usage.completion_tokens) total=\(.usage.total_tokens)"
      else
        "tokens input=\(.usage.input_tokens) output=\(.usage.output_tokens) total=\(.usage.total_tokens)"
      end
    else
      "tokens unavailable"
    end
  '
}
