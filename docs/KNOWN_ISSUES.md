# Codex Session Bridge known issues / war stories

Real bugs and gotchas, documented so future you (or future contributors)
don't waste time re-discovering them.

## Codex hides conversations whose provider doesn't match the active one

The original motivation for Codex Session Bridge. See [HOW_IT_WORKS.md](HOW_IT_WORKS.md).

## Built-in `openai` provider cannot be overridden

Recent Codex versions refuse to start with this in `config.toml`:

```toml
[model_providers.openai]
base_url = "https://my-proxy/v1"
```

Error: `Built-in providers cannot be overridden`. Use any other name (the
examples use `openai-custom`) and set `model_provider = "openai-custom"` at
the top of your API profile.

## Patching sqlite without patching jsonl gets silently reverted

Codex re-syncs `threads.model_provider` from the jsonl at startup. If you only
update sqlite, the next launch wipes your change. `switch.sh` patches both, in
the right order.

## macOS bash 3.2 doesn't expand `**` recursively

A previous version of `switch.sh` used `~/.codex/sessions/**/*.jsonl` to
enumerate jsonl files. On macOS (default `/bin/bash` is 3.2) without
`shopt -s globstar`, this matches only **one** directory level. Real session
paths are 4 levels (`sessions/YYYY/MM/DD/`), so the glob silently skipped
files older than the current day-of-month structure. Symptom: switching
appears to succeed, but after restarting Codex many conversations are
"missing." Fix: use `find ... -name "*.jsonl"`.

If you adapt this script for other tools, never trust `**` in a portable
shell. Either set `shopt -s globstar` *and* require bash ≥ 4, or use `find`.

## `pgrep -lf "Codex"` is too broad

Matches `chrome_crashpad_handler` and `SkyComputerUseService` after Codex
exits, blocking the bridge/switch even though those processes don't write sqlite.
Match `Codex\.app/Contents/MacOS/Codex|codex app-server` instead.

## Two jsonl with the same basename in different date dirs collide on backup

If the backup step uses `basename`, two files like
`sessions/2026/05/20/rollout-abc.jsonl` and
`sessions/2026/05/27/rollout-abc.jsonl` (different days) would overwrite each
other in the flat backup directory. The current script encodes the relative
path as the backup filename (`sessions_2026_05_20_rollout-abc.jsonl.bak`).

## Configuration drift between profiles

If you change something inside Codex GUI (model, MCP server, reasoning effort,
trusted projects), the change lands in `~/.codex/config.toml` only — not in
either profile file. Next bridge/switch, the change is lost.

Recommended habit: after any GUI change you want to keep, decide whether it
belongs to one profile or both, then `cp` the live config over the relevant
profile file(s).

## Credentials

This tool does not touch credentials. The ChatGPT side uses the Codex GUI's
own auth (stored under `~/Library/Application Support/Codex/` on macOS, not
`~/.codex/auth.json` in recent versions). The API side picks up
`OPENAI_API_KEY` from the environment or the proxy's own mechanism. If
auth is broken after a bridge/switch, fix it in Codex's normal login flow.
