---
name: codex-profile-switch
description: Switch Codex Desktop between a ChatGPT personal account and a third-party OpenAI-compatible API proxy, automatically migrating conversation history so both sides see the full session list. Trigger phrases (Chinese + English):「切 api / 切回个人账号 / 切 chatgpt / codex 切档案 / codex 换 api」「switch codex to api / switch codex to chatgpt / codex profile / codex switch account」.
---

# Codex Profile Switch

ChatGPT subscription quota running out at month-end is a common case for
switching to an API proxy. The blocker is that Codex hides any conversation
whose `model_provider` doesn't match the active profile, so naive switching
"loses" all your history.

This skill wraps a battle-tested switch + history-migration script so both
sides see the full conversation list.

## When to trigger this skill

Any of:

- "切 api" / "切到 api" / "换 api" / "switch to api"
- "切 chatgpt" / "切回个人" / "切回个人账号" / "switch to chatgpt"
- "codex 切档案" / "codex 切配置" / "codex profile" / "codex switch account"

## Execution

### 1. Verify Codex is not running

Just call the script — it self-checks. Only the GUI main process
(`Codex.app/Contents/MacOS/Codex`) and `codex app-server` block; crashpad /
helper services are ignored.

If blocked, tell the user: **"Cmd+Q to fully quit Codex (closing the window is
not enough), then retry."**

### 2. Diagnose or preview when appropriate

If setup looks suspicious, run doctor first:

```bash
~/.claude/skills/codex-profile-switch/switch.sh --doctor
```

If the user wants to preview changes before writing files, run dry-run:

```bash
~/.claude/skills/codex-profile-switch/switch.sh --dry-run chatgpt
~/.claude/skills/codex-profile-switch/switch.sh --dry-run api
```

If the user needs rollback support, list backups first:

```bash
~/.claude/skills/codex-profile-switch/switch.sh --list-backups
~/.claude/skills/codex-profile-switch/switch.sh --rollback <backup-dir>
```

For non-default API provider names, use explicit migration providers:

```bash
~/.claude/skills/codex-profile-switch/switch.sh api --provider my-proxy --from openai
```

### 3. Run the switch

```bash
~/.claude/skills/codex-profile-switch/switch.sh chatgpt   # to ChatGPT account
~/.claude/skills/codex-profile-switch/switch.sh api       # to API proxy
```

The script:
1. Backs up `config.toml`, `state_5.sqlite`, and every jsonl it touches into
   `~/.codex/jsonl_backup_<timestamp>/`.
2. Copies `config.toml.profile.<target>` to `config.toml`.
3. Uses `find` to recursively rewrite `"model_provider"` in every jsonl under
   `sessions/YYYY/MM/DD/` and `archived_sessions/`. (Do not use `**` glob —
   macOS bash 3.2 doesn't expand it.)
4. Updates the `threads.model_provider` column in `state_5.sqlite`.

### 4. Verify (mandatory)

```bash
~/.claude/skills/codex-profile-switch/switch.sh --verify
```

Both sqlite and jsonl must show **only one** `model_provider` value. If two
appear, the rewrite missed something — investigate before letting the user
reopen Codex (Codex will re-sync sqlite from jsonl at launch and bake the
inconsistency in).

### 5. Tell the user to restart Codex

After verification passes: "Restart Codex — all history conversations will
be visible."

## Core invariants

- ChatGPT mode uses `model_provider = "openai"` (Codex built-in, cannot be
  redefined in `[model_providers]` in recent versions).
- API mode uses `model_provider = "openai-custom"` (any non-built-in name
  works; this one is hard-coded across script + examples for consistency).
- Both jsonl and sqlite must be migrated together. Patching one and not the
  other gets reverted at the next Codex launch.

## Profile files (must exist before first use)

- `~/.codex/config.toml.profile.chatgpt`
- `~/.codex/config.toml.profile.api`

If either is missing, point the user at the templates in `examples/` and the
[README](README.md) setup section.

## Backups and rollback

Every run leaves a timestamped folder in `~/.codex/jsonl_backup_<TS>/`
containing `config.toml.bak`, `state_5.sqlite.bak`, `manifest.tsv`, and every
rewritten jsonl. To roll back: stop Codex and run
`switch.sh --rollback <backup-dir>`. Backups created before v1.0.2 do not have
`manifest.tsv`, so automated rollback restores config/sqlite only for those older backups.

## When the user changes config inside Codex GUI

GUI changes land in `~/.codex/config.toml` only — neither profile file is
updated. After helping the user change something via GUI, ask: **"Should this
change be saved into the chatgpt profile, the api profile, or both? Otherwise
the next switch will lose it."**

Sync command:

```bash
cp ~/.codex/config.toml ~/.codex/config.toml.profile.chatgpt    # or .api
```

## Further reading

- [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) — internal mechanics
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — war stories worth reading before debugging

