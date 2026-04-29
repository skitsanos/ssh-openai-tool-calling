# OpenAI Shell Demos: Chat Completions and Responses API

This repository is a shell-only research demo for systems that can run `bash`.
It demonstrates four Chat Completions patterns:

- Plain text responses
- Structured JSON responses with `response_format: { "type": "json_schema" }`
- Tool calling where each tool is implemented as a shell script
- Interactive CLI chat with local message history

It also includes a small Responses API comparison:

- Plain text responses
- Structured JSON responses with `text.format`
- Function tool calling using the same shell tools

The demos use `curl` for HTTP and `jq` for JSON parsing and construction.

## Requirements

- `bash`
- `curl`
- `jq`
- [Task](https://taskfile.dev/) if you want to use `Taskfile.yaml`

## Environment

Create a local `.env` file. It is intentionally ignored by git.

```bash
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4.1-mini
OPENAI_BASE_URL=https://api.openai.com/v1
```

`OPENAI_MODEL` defaults to `gpt-4.1-mini` when omitted.
`OPENAI_BASE_URL` defaults to `https://api.openai.com/v1` when omitted.

## Run

```bash
task plain
task json
task tools
task chat

task responses:plain
task responses:json
task responses:tools
task all
```

You can also run scripts directly:

```bash
bash scripts/chat_plain.sh
bash scripts/chat_json_schema.sh
bash scripts/chat_tool_calling.sh
bash scripts/chat_cli.sh

bash scripts/responses_plain.sh
bash scripts/responses_json_schema.sh
bash scripts/responses_tool_calling.sh
```

`task chat` starts an interactive shell loop. Type `/exit` or press `Ctrl-D` to
quit. The conversation history is kept in a temporary JSON file for the life of
the process.

## Responses API Comparison

The Responses API examples are intentionally separate from the Chat Completions
examples. They show the newer `/v1/responses` request shape:

- `input` and `instructions` instead of `messages`
- `output_text` extraction from the response
- `text.format` for JSON Schema output
- Flat function tool definitions and `function_call_output` messages

## Tool Scripts

Tool definitions live in [tools/tools.json](tools/tools.json), and each tool maps to
a same-named executable shell script:

- [tools/get_current_time.sh](tools/get_current_time.sh)
- [tools/count_files.sh](tools/count_files.sh)
- [tools/summarize_text.sh](tools/summarize_text.sh)

Each tool receives a single JSON object as its first argument and prints a JSON
object to stdout. This keeps the interface predictable and makes it easy to add
or replace tools.

## Checks

```bash
task check
```

This validates shell syntax and the JSON tool manifest.
