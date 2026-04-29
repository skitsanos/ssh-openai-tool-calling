#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck disable=SC1091
source scripts/lib/openai.sh
load_env

payload="$(mktemp)"
response1="$(mktemp)"
response2="$(mktemp)"
responses_tools="$(mktemp)"
tool_outputs="$(mktemp)"
trap 'rm -f "$payload" "$response1" "$response2" "$responses_tools" "$tool_outputs"' EXIT

jq '[
  .[] | {
    type: "function",
    name: .function.name,
    description: .function.description,
    parameters: .function.parameters,
    strict: true
  }
]' tools/tools.json > "$responses_tools"

jq -n \
  --arg model "$OPENAI_MODEL" \
  --slurpfile tools "$responses_tools" \
  '{
    model: $model,
    instructions: "You are a concise shell demo assistant. Use tools when they help answer with concrete local facts. Report the requested facts only and do not ask a follow-up question.",
    input: "Use the available tools to tell me the current UTC time, count files in this repo, and summarize the sentence: Shell tools make OpenAI tool calling easy to inspect and debug.",
    tools: $tools[0],
    tool_choice: "auto"
  }' > "$payload"

responses_create "$payload" > "$response1"

function_call_count="$(jq '[.output[]? | select(.type == "function_call")] | length' "$response1")"

if [[ "$function_call_count" -eq 0 ]]; then
  echo "Model did not request a function call. Response:"
  jq -r '.output_text // (.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text)' "$response1"
  exit 0
fi

: > "$tool_outputs"

for index in $(seq 0 $((function_call_count - 1))); do
  tool_call="$(jq "[.output[]? | select(.type == \"function_call\")][$index]" "$response1")"
  call_id="$(jq -r '.call_id' <<< "$tool_call")"
  tool_name="$(jq -r '.name' <<< "$tool_call")"
  tool_args="$(jq -r '.arguments' <<< "$tool_call")"
  tool_script="tools/${tool_name}.sh"

  if [[ ! -x "$tool_script" ]]; then
    tool_result="$(jq -n --arg error "No executable shell tool found for ${tool_name}" '{error: $error}')"
  else
    echo "Running tool: ${tool_name} ${tool_args}" >&2
    tool_result="$("$tool_script" "$tool_args")"
  fi

  jq -n \
    --arg call_id "$call_id" \
    --arg output "$tool_result" \
    '{type: "function_call_output", call_id: $call_id, output: $output}' >> "$tool_outputs"
done

jq -n \
  --arg model "$OPENAI_MODEL" \
  --arg previous_response_id "$(jq -r '.id' "$response1")" \
  --slurpfile input "$tool_outputs" \
  '{
    model: $model,
    instructions: "Report the requested facts only. Do not ask a follow-up question.",
    previous_response_id: $previous_response_id,
    input: $input
  }' > "$payload"

responses_create "$payload" > "$response2"

echo "Responses API tool-assisted response:"
jq -r '.output_text // (.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text)' "$response2"
echo
print_usage_cost_fields < "$response2"
