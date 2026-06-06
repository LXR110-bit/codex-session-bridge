# Changelog

## Unreleased

- Add `start.sh`, a one-command beginner entrypoint that downloads/updates the tool, saves the ChatGPT profile, launches API setup, and optionally switches to API mode.
- Rewrite README quick start around the simplest workflow: copy one command, paste API base URL, restart Codex.
- Update `SKILL.md` so agents prefer `setup-api.sh` for first-time API setup and never ask users to paste API keys into chat.
- `setup-api.sh`: replace one-shot ping with retry loop. On unreachable / 404 base_url, ask whether to re-enter; soften failure copy from `❌ Connection failed` to a warning that still notes the config has been written.
- `setup-api.sh`: drop the `gpt-5.5` default model. Model name is now mandatory and the prompt lists examples per relay (DeepSeek, OpenRouter, OpenAI-compatible) since no single name works everywhere.
- `start.sh`: wrap the `switch.sh api` call so a Codex-still-running failure no longer kills the script under `set -e`. Print a clear fallback ("Cmd+Q Codex, then re-run switch.sh api") and always reach the "常用命令" footer.
- `start.sh`: `ask_yes_no` now accepts Chinese answers (是/要/好/否/不/不要/算了/...) in addition to y/n.

## v1.3.0

- Add `setup-api.sh` interactive wizard for first-time API profile setup. Asks for base_url and default model, generates `~/.codex/config.toml.profile.api` with chmod 600, and pings the proxy to confirm host reachability before exiting.
- `install.sh` now offers to launch the wizard automatically when the API profile is missing, instead of just printing instructions.
- Wizard explicitly does NOT ask for or store the API key. Codex Desktop prompts for the key in its GUI on first use and stores it in the macOS Keychain.
- Existing API profile is backed up to `*.bak.<timestamp>` before regeneration so re-running the wizard is safe.

## v1.0.3

- Fix ShellCheck findings in `switch.sh` so GitHub Actions CI passes cleanly.
- Keep JSONL distribution scanning filename-safe with `find -print0 | xargs -0`.

## v1.0.2

- Add Chinese README banner image.
- Add GitHub Actions CI with bash syntax, ShellCheck, and fake `CODEX_HOME` functional tests.
- Add `CONTRIBUTING.md`.
- Add `./switch.sh --list-backups`.
- Add `./switch.sh --rollback <backup-dir>` for backups created by v1.0.2+.
- Add manifest-based JSONL restore for safer rollback.
- Add basic custom provider migration support with `--provider` and `--from`.
- Add terminal demo visual asset.

## v1.0.1

- Add Chinese README section for Chinese users.
- Add sharing and installation instructions at the top of README.
- Add one-line install command.
- Add `--dry-run` preview mode.
- Add `--doctor` environment diagnosis mode.
- Add example verify screenshot asset.
- Add GitHub bug report issue template.

## v1.0.0

- Initial public release.
- Support switching Codex Desktop between ChatGPT and API profiles.
- Migrate `model_provider` in both jsonl session files and sqlite index.
- Add installer script and Claude skill support.
- Add safety backups before rewriting files.
