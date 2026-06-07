# How Codex Session Bridge works

> Internal mechanics, written down so the next person debugging this doesn't
> have to re-derive everything from scratch.

## The problem

Codex Desktop ties every conversation to a `model_provider` value. When you
move between profiles (e.g. ChatGPT account ↔ third-party API proxy), the new profile
declares a *different* `model_provider`, and Codex hides any conversation whose
provider doesn't match the active one. Your history looks "lost" every time the active provider changes.

## Where history is stored

Two places, kept in sync:

| Layer  | Path                                        | Role             |
|--------|---------------------------------------------|------------------|
| Source | `~/.codex/sessions/YYYY/MM/DD/*.jsonl`       | Authoritative    |
| Source | `~/.codex/archived_sessions/*.jsonl`         | Authoritative    |
| Index  | `~/.codex/state_5.sqlite` (`threads` table)  | Built from jsonl |

Each jsonl line contains `"model_provider":"<name>"` in the session-meta record.
The sqlite `threads.model_provider` column mirrors it.

## The crucial detail: Codex rebuilds sqlite from jsonl on startup

At launch, Codex reads `session_meta.payload.model_provider` from the jsonl
files and updates the corresponding `threads.model_provider` rows in sqlite.

That means **patching sqlite alone is useless** — the next startup will
overwrite it from the jsonl on disk. You must rewrite both.

It also means **partially rewriting jsonl is worse than not rewriting at all**:
the rewritten threads show up under the new provider, but the un-rewritten ones
get re-synced into sqlite under the old provider, and the count looks "wrong"
in a way that's hard to diagnose.

## What `switch.sh` does, in order

1. **Refuse to run if Codex is live.** Matches `Codex.app/Contents/MacOS/Codex`
   and `codex app-server`. Crashpad and ComputerUseService stragglers are
   ignored — they don't write sqlite.
2. **Back up** `config.toml`, `state_5.sqlite`, and every jsonl about to be
   rewritten, into `~/.codex/jsonl_backup_<timestamp>/`. Filenames include the
   relative path encoded with `_` so two jsonl in different date directories
   with the same basename never collide.
3. **Copy profile**: `cp ~/.codex/config.toml.profile.<target> ~/.codex/config.toml`.
4. **Rewrite jsonl** using `find ... -name "*.jsonl"` (recursion). Don't try to
   use shell `**` — macOS ships bash 3.2 by default and `**` only matches one
   level there, silently skipping deeper files. Real paths are 4 levels deep
   (`sessions/YYYY/MM/DD/*.jsonl`) and this exact mistake has bitten the
   author personally (see KNOWN_ISSUES).
5. **Rewrite sqlite** with a single `UPDATE threads SET model_provider = ?`.

## Provider naming constraint

ChatGPT mode must use `model_provider = "openai"` (the built-in name). Recent
Codex versions explicitly forbid redefining `"openai"` in `[model_providers]`
("Built-in providers cannot be overridden"). API mode must therefore use a
*different* name; this skill hard-codes `"openai-custom"`. If you change it,
change it in `switch.sh` and both example profiles at once.

## Backup and rollback

Every run creates `~/.codex/jsonl_backup_<timestamp>/`. To roll back: stop
Codex, copy the `.bak` files back over the originals, restart. Backups
accumulate — clean up monthly, keep the most recent 2-3.

## Validation

After every bridge/switch, run:

```sh
./switch.sh --verify
```

You should see exactly one provider in both sqlite and the jsonl distribution.
Two values means the script missed something — investigate before re-opening
Codex, because opening Codex will re-sync sqlite from jsonl and bake the
inconsistency in.
