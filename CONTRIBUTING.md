# Contributing

Thanks for helping improve `Codex Session Bridge`.

## Before opening a PR

Run these checks locally:

```bash
bash -n switch.sh
bash -n install.sh
bash -n setup-api.sh
bash -n start.sh
./switch.sh --version
./switch.sh --help
```

If you have ShellCheck installed:

```bash
shellcheck switch.sh install.sh
```

## Functional smoke test

Use a fake `CODEX_HOME` instead of your real Codex data:

```bash
tmp="$(mktemp -d)"
mkdir -p "$tmp/sessions/2026/06/06" "$tmp/archived_sessions"
printf 'model_provider = "openai"\n' > "$tmp/config.toml.profile.chatgpt"
printf 'model_provider = "openai-custom"\n[model_providers.openai-custom]\nbase_url = "https://example.invalid/v1"\n' > "$tmp/config.toml.profile.api"
printf 'model_provider = "openai"\n' > "$tmp/config.toml"
printf '{"model_provider":"openai","x":1}\n' > "$tmp/sessions/2026/06/06/test.jsonl"
sqlite3 "$tmp/state_5.sqlite" 'create table threads (id text, model_provider text); insert into threads values ("1","openai");'

CODEX_HOME="$tmp" ./switch.sh --doctor
CODEX_HOME="$tmp" ./switch.sh --dry-run api
CODEX_HOME="$tmp" ./switch.sh api
CODEX_HOME="$tmp" ./switch.sh --verify
```

## Safety rules

- Never commit real API keys, proxy URLs, access tokens, or personal paths.
- Do not test destructive changes against your real `~/.codex` unless you have a backup.
- Keep `openai` as the built-in ChatGPT provider; do not redefine it in `[model_providers]`.
- If changing backup or rollback behavior, test both bridge/switch and rollback with fake data.

## Issue reports

Please include:

- Codex Desktop version
- OS version
- Exact command
- `./switch.sh --doctor` output
- `./switch.sh --verify` output
