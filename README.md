# codex-profile-switch

![Codex Profile Switch 横幅](docs/assets/codex-profile-switch-banner.png)

> 中文说明在前，English README follows below.

**不懂开发也能用：复制 API 地址，运行安装命令，就能在 Codex 的「个人账号」和「API 代理」之间一键切换，历史会话不会消失。**

你不需要会读 TOML，也不需要知道 `wire_api`、`model_provider` 是什么。第一次配置 API 代理时，跟着向导填两样东西就行：

1. API 地址，例如 `https://api.deepseek.com/v1`；
2. 默认模型，例如 `deepseek-chat`，不知道就直接回车用默认值。

API key 不需要发给 AI，也不会写进这个仓库。切到 API 模式后，Codex Desktop 会自己弹窗让你粘贴 key，并保存到 macOS Keychain。

---

## 一句话介绍

```text
Codex Profile Switch：给不会开发的人用的 Codex 账号/API 切换工具。复制 API 地址，运行安装命令，就能在个人账号和 API 代理之间一键切换，历史会话不消失。
```

---

## 如何分享 / 如何安装

把这个仓库链接发给别人即可：

```text
https://github.com/LXR110-bit/codex-profile-switch
```

对方只需要复制这一行命令到终端里运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LXR110-bit/codex-profile-switch/main/start.sh)
```

这个小白向导会自动完成：

- 下载/更新工具；
- 保存当前 Codex 个人账号配置；
- 让用户粘贴 API 地址；
- 询问是否现在切到 API；
- 提醒重启 Codex，并由 Codex 弹窗收 API key。

> 不需要把 API key 发给 AI。key 由 Codex Desktop 自己弹窗接收，并保存到 macOS Keychain。

---

## 中文快速开始：只做 3 件事

### 第 1 步：复制一行命令

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LXR110-bit/codex-profile-switch/main/start.sh)
```

### 第 2 步：粘贴 API 地址

向导会问你 API 地址，例如：

```text
https://api.deepseek.com/v1
```

模型不知道填什么就直接回车。

### 第 3 步：重启 Codex

如果你选择“现在切到 API”，脚本会自动切换并检查状态。

然后你只需要：

1. 完全退出 Codex Desktop；
2. 重新打开 Codex Desktop；
3. 如果 Codex 弹窗要 API key，就粘贴你的 `sk-...` key。

历史会话不会消失。

---

## 高级/手动安装

如果你不想用一行命令，也可以手动下载仓库：

```bash
git clone https://github.com/LXR110-bit/codex-profile-switch.git
cd codex-profile-switch
./start.sh
```

只想安装、不马上配置，可以运行：

```bash
./install.sh
```

只想重新配置 API 地址，可以运行：

```bash
./setup-api.sh
```

只想切换账号/API，可以运行：

```bash
./switch.sh api      # 切到 API 代理
./switch.sh chatgpt  # 切回个人 ChatGPT 账号
```

每次切换后，请**完全退出并重启 Codex Desktop**，历史会话列表才会刷新。

---

## 常用命令

```bash
./start.sh                  # 小白向导：安装/配置/切换一条龙
./setup-api.sh              # 只重新配置 API 地址
./switch.sh api             # 切到 API 代理
./switch.sh chatgpt         # 切回个人账号
./switch.sh --verify        # 检查当前状态
./switch.sh --doctor        # 诊断环境和配置
./switch.sh --dry-run api   # 只预览，不改文件
./switch.sh --list-backups  # 查看备份
./switch.sh --rollback <backup-dir> # 从备份恢复
```

---

## 适合谁

- ChatGPT 额度快用完，想临时切到 API 代理；
- 买了 API 中转站，但不想手改 Codex 配置；
- 切换后发现历史会话“没了”，想让它们重新显示；
- 不懂开发，只想复制 API 地址，然后让工具帮你处理剩下的事。

---

## 它解决什么问题

Codex Desktop 会按当前账号 / API 配置过滤历史会话。你切到 API 后，旧的个人账号会话可能看不见；切回个人账号后，API 期间的会话也可能看不见。

这些会话没有被删除，只是被过滤了。

这个工具会在切换时同步处理 Codex 的会话记录和索引，让两边都能看到完整历史。

![switch.sh --verify 示例](docs/assets/verify-example.svg)

![命令行流程示意](docs/assets/terminal-demo.svg)

---

## 安全说明

- 不会要求你把 API key 发给 AI；
- 不会把 API key 写进仓库；
- 每次切换前都会自动备份；
- Codex 正在运行时会拒绝切换，避免写坏数据；
- 出问题可以用 `./switch.sh --rollback <backup-dir>` 回滚。

---

## 高级说明：profile / provider / 回滚

普通用户只需要运行 `./start.sh` 或上面的一行命令。下面是给想了解细节的人看的。

第一次使用前，工具会准备两份 Codex profile：

| 用途 | 文件 | 默认 provider |
|---|---|---|
| 个人 ChatGPT 账号 | `~/.codex/config.toml.profile.chatgpt` | `openai` |
| API 代理 | `~/.codex/config.toml.profile.api` | `openai-custom` |

如果你的 API profile 使用其他 provider 名，可以指定迁移口径：

```bash
./switch.sh api --provider my-proxy --from openai
```

查看备份：

```bash
./switch.sh --list-backups
```

从某个备份恢复：

```bash
./switch.sh --rollback ~/.codex/jsonl_backup_YYYYMMDD_HHMMSS
```

说明：v1.0.2 之后创建的备份会带 `manifest.tsv`，可以恢复 config、sqlite 和被改写的 jsonl。更早版本的备份没有 manifest，只能安全恢复 config/sqlite。


## 常见问题

### 我需要把 API 中转站地址发给 AI 吗？

不需要。普通用户直接运行 `./setup-api.sh`，在本机输入 API 地址即可。这个地址只会写到你自己的 `~/.codex/config.toml.profile.api`，不需要发到聊天里。

### 我需要把 API key 发给 AI 吗？

不建议，也不需要。

API key 不在向导里填，也不建议发到聊天里。第一次切到 API 后，Codex Desktop 会弹窗让你粘贴 key，并保存到 macOS Keychain。

### 为什么我配置好了 profile，Claude 才能帮我切？

因为 Claude skill 本质上是在你的电脑上调用 `switch.sh`。第一次使用前，先用 `./setup-api.sh` 生成 API profile；之后就可以直接说“切 api / 切回个人账号”。

### 切换后为什么要重启 Codex？

因为 Codex Desktop 需要重新读取配置和会话索引。每次切换后，请重启 Codex Desktop，这样会话列表才会按新的 provider 状态刷新。

---

## CI / 贡献

本仓库已配置 GitHub Actions，会自动检查：

- `bash -n switch.sh install.sh setup-api.sh`
- `shellcheck switch.sh install.sh setup-api.sh`
- fake `CODEX_HOME` 下的切换、验证、回滚流程

贡献说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 版本记录

版本记录见 [CHANGELOG.md](CHANGELOG.md)。

---

## English README


Switch Codex Desktop between your **ChatGPT personal account** and an **API proxy** without losing your conversation history.

Built for non-developers: paste an API base URL, run the installer, and switch. You do not need to understand TOML, `wire_api`, or `model_provider` to get started.

API keys are not handled by this repo. Codex Desktop prompts for the key on first API use and stores it in the macOS Keychain.

---

## Quick start

```bash
git clone https://github.com/LXR110-bit/codex-profile-switch.git
cd codex-profile-switch
./install.sh
```

The installer checks dependencies, makes scripts executable, optionally symlinks the repo into `~/.claude/skills/`, and offers to run the API setup wizard when needed.

For first-time API setup:

```bash
./setup-api.sh
```

The wizard asks for your API base URL and default model, then writes `~/.codex/config.toml.profile.api` for you.

Then switch:

```bash
./switch.sh chatgpt        # use ChatGPT personal account
./switch.sh api            # use API proxy
./switch.sh --dry-run api  # preview changes without writing files
./switch.sh --verify       # print current state
./switch.sh --doctor       # diagnose environment and profile setup
./switch.sh --list-backups # list backups
./switch.sh --rollback <backup-dir> # restore from backup
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

Easiest path:

```bash
# ChatGPT profile — start from your current config if you're already on ChatGPT
cp ~/.codex/config.toml ~/.codex/config.toml.profile.chatgpt

# API profile — use the interactive wizard
./setup-api.sh
```

The `examples/` directory still has templates if you prefer manual setup.

Key rules:

- The ChatGPT profile must **not** redefine the built-in `openai` provider in
  `[model_providers]`. Recent Codex versions reject that with
  `Built-in providers cannot be overridden`.
- The API profile must declare `model_provider = "openai-custom"` and have a
  matching `[model_providers.openai-custom]` block with your proxy's
  `base_url`. `setup-api.sh` writes this for you.

This tool does **not** manage credentials. ChatGPT auth comes from Codex's own login. API auth is handled by Codex Desktop's GUI prompt and macOS Keychain on first API use.

---

## Usage

### As a CLI

```bash
./switch.sh chatgpt        # switch to ChatGPT profile, migrate history
./switch.sh api            # switch to API profile, migrate history
./switch.sh --dry-run api  # preview changes without writing files
./switch.sh --verify       # show current jsonl + sqlite state
./switch.sh --doctor       # diagnose environment and profile setup
./switch.sh --list-backups # list backups
./switch.sh --rollback <backup-dir> # restore from backup
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
