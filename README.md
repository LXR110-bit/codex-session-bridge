# codex-profile-switch

Switch [Codex Desktop](https://chatgpt.com/codex) between your **ChatGPT
personal account** and a **third-party OpenAI-compatible API proxy** without
losing your conversation history.

> Codex hides every conversation whose `model_provider` doesn't match the
> active profile. Naive profile switching makes your history "disappear" each
> time. This tool migrates the `model_provider` field across both the source
> jsonl files and the sqlite index so both sides always see the full session
> list.

Works as a standalone CLI **and** as a [Claude](https://claude.ai/code) skill.

---

## Quick start

```bash
git clone https://github.com/LXR110-bit/codex-profile-switch.git
cd codex-profile-switch
./install.sh
```

The installer checks dependencies, makes the script executable, optionally
symlinks it into `~/.claude/skills/` so Claude can invoke it, and tells you
which profile files you still need to create.

Then create your two profile files (one-time setup, see [Setup](#setup) below)
and switch:

```bash
./switch.sh chatgpt   # use ChatGPT personal account
./switch.sh api       # use API proxy
./switch.sh --verify  # print current state
./switch.sh --help
```

After every switch, **restart Codex** to see your full history.

---

## Why this exists

You probably hit one of these:

- Your ChatGPT subscription quota runs out near month-end and you want to
  switch to an API proxy for a few days.
- You have one provider for sensitive/personal work and another for everyday
  coding.
- You're A/B-comparing two providers but want a unified history.

In all of those cases, the moment you change `model_provider` in Codex's
`config.toml`, your previous conversations vanish from the session list.
They're not deleted — they just get filtered out, because Codex only shows
threads whose provider matches the active one.

This tool fixes that by rewriting `model_provider` everywhere it's persisted
(jsonl session files + sqlite index) every time you switch.

## How it works (one paragraph)

Each Codex conversation has a `model_provider` field stored in
`~/.codex/sessions/YYYY/MM/DD/*.jsonl` and mirrored in
`~/.codex/state_5.sqlite`. At startup, Codex rebuilds sqlite from the jsonl,
so patching only one isn't enough. `switch.sh` patches both, after backing up
everything it touches. See [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) for
the full story, and [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for the
gotchas the author has personally hit.

---

## Setup

You need two profile files in `~/.codex/`:

| Profile  | File                                       | `model_provider` |
|----------|--------------------------------------------|------------------|
| ChatGPT  | `~/.codex/config.toml.profile.chatgpt`     | `openai`         |
| API      | `~/.codex/config.toml.profile.api`         | `openai-custom`  |

The `examples/` directory has templates. Easiest path:

```bash
# ChatGPT profile — start from your current config if you're already on ChatGPT
cp ~/.codex/config.toml ~/.codex/config.toml.profile.chatgpt

# API profile — start from the template, edit base_url to point at your proxy
cp examples/config.toml.api.example ~/.codex/config.toml.profile.api
$EDITOR ~/.codex/config.toml.profile.api
```

Key rules:

- The ChatGPT profile must **not** redefine the built-in `openai` provider in
  `[model_providers]`. Recent Codex versions reject that with
  `Built-in providers cannot be overridden`.
- The API profile must declare `model_provider = "openai-custom"` and have a
  matching `[model_providers.openai-custom]` block with your proxy's
  `base_url`. The name `openai-custom` is hard-coded in `switch.sh` — if you
  change it, change it in three places (the script and both example files).

This tool does **not** manage credentials. ChatGPT auth comes from Codex's own
login. API auth comes from `OPENAI_API_KEY` or wherever your proxy stores it.

---

## Usage

### As a CLI

```bash
./switch.sh chatgpt   # switch to ChatGPT profile, migrate history
./switch.sh api       # switch to API profile, migrate history
./switch.sh --verify  # show current jsonl + sqlite state
./switch.sh --help
./switch.sh --version
```

`--verify` is the contract: both sqlite and jsonl should show **only one**
`model_provider` value. Two values = the rewrite missed something. Don't reopen
Codex in that state (it will re-sync sqlite from the bad jsonl and bake the
inconsistency in); rerun the switch or investigate.

### As a Claude skill

After `install.sh` symlinks the directory into `~/.claude/skills/`, Claude
recognizes the trigger phrases listed in [SKILL.md](SKILL.md):

- 中文: "切 api"、"切回个人账号"、"codex 切档案" …
- English: "switch codex to api", "switch codex to chatgpt", …

Claude will:
1. Check Codex isn't running (prompt Cmd+Q if it is).
2. Run `switch.sh <target>`.
3. Run `--verify` to confirm the migration is complete.
4. Tell you to restart Codex.

---

## Safety

- Every run creates a timestamped backup at `~/.codex/jsonl_backup_<TS>/`
  containing `config.toml.bak`, `state_5.sqlite.bak`, and every jsonl that
  was rewritten.
- The script refuses to run if Codex's GUI or `app-server` is still alive —
  concurrent writes would race the migration.
- Filenames in the backup directory encode the relative path
  (`sessions_2026_05_20_rollout-xyz.jsonl.bak`) to avoid same-basename
  collisions across date subdirectories.

To roll back: stop Codex, copy `.bak` files back over the originals, restart.

Backups accumulate. Clean up monthly; keep the most recent 2–3.

---

## Compatibility

- **macOS**: tested on default `/bin/bash` 3.2.
- **Linux**: should work; bash ≥ 4 is fine. Codex Desktop is currently
  macOS-only as far as we know, so this is mostly theoretical.
- **Dependencies**: `bash`, `sqlite3`, `sed`, `find`, `grep`, `pgrep` —
  all standard on macOS/Linux.

---

## Contributing

PRs and issues welcome, especially:

- Reports of new Codex versions changing the storage format.
- Compatibility fixes for different Codex builds.
- Support for additional profile types (Azure, Bedrock, etc.) — but please
  open an issue first so we can discuss the design.

When reporting a bug, please include:

- Codex Desktop version.
- Output of `./switch.sh --verify` before and after.
- Whether you're seeing missing conversations, count mismatches, or a startup
  error.

---

## License

MIT — see [LICENSE](LICENSE).
