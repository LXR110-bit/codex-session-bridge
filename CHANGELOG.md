# Changelog

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
