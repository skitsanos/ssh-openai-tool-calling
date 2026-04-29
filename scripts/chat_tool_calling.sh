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
messages="$(mktemp)"
assistant_message="$(mktemp)"
tool_messages="$(mktemp)"
trap 'rm -f "$payload" "$response1" "$response2" "$messages" "$assistant_message" "$tool_messages"' EXIT

jq -n '[
  {
    role: "system",
    content: "You are a concise shell demo assistant. Use tools when they help answer with concrete local facts."
  },
  {
    role: "user",
    content: "Use the available tools to tell me the current UTC time, count files in this repo, and summarize the sentence: Shell tools make OpenAI tool calling easy to inspect and debug."
  }
]' > "$messages"

jq -n \
  --arg model "$OPENAI_MODEL" \
  --slurpfile messages "$messages" \
  --slurpfile tools tools/tools.json \
  '{
    model: $model,
    messages: $messages[0],
    tools: $tools[0],
    tool_choice: "auto"
  }' > "$payload"

chat_completions "$payload" > "$response1"

jq '.choices[0].message' "$response1" > "$assistant_message"

tool_call_count="$(jq '.tool_calls | length // 0' "$assistant_message")"

if [[ "$tool_call_count" -eq 0 ]]; then
  echo "Model did not request a tool call. Response:"
  jq -r '.content // ""' "$assistant_message"
  exit 0
fi

: > "$tool_messages"

for index in $(seq 0 $((tool_call_count - 1))); do
  tool_call_id="$(jq -r ".tool_calls[$index].id" "$assistant_message")"
  tool_name="$(jq -r ".tool_calls[$index].function.name" "$assistant_message")"
  tool_args="$(jq -r ".tool_calls[$index].function.arguments" "$assistant_message")"
  tool_script="tools/${tool_name}.sh"

  if [[ ! -x "$tool_script" ]]; then
    tool_result="$(jq -n --arg error "No executable shell tool found for ${tool_name}" '{error: $error}')"
  else
    echo "Running tool: ${tool_name} ${tool_args}" >&2
    tool_result="$("$tool_script" "$tool_args")"
  fi

  jq -n \
    --arg role "tool" \
    --arg tool_call_id "$tool_call_id" \
    --arg content "$tool_result" \
    '{role: $role, tool_call_id: $tool_call_id, content: $content}' >> "$tool_messages"
done

jq -s \
  --slurpfile original "$messages" \
  --slurpfile assistant "$assistant_message" \
  '$original[0] + [$assistant[0]] + .' "$tool_messages" > "${messages}.next"
mv "${messages}.next" "$messages"

jq -n \
  --arg model "$OPENAI_MODEL" \
  --slurpfile messages "$messages" \
  '{
    model: $model,
    messages: $messages[0]
  }' > "$payload"

chat_completions "$payload" > "$response2"

echo "Tool-assisted response:"
jq -r '.choices[0].message.content' "$response2"
echo
jq -r 'if .usage then "second call tokens prompt=\(.usage.prompt_tokens) completion=\(.usage.completion_tokens) total=\(.usage.total_tokens)" else "tokens unavailable" end' "$response2"
