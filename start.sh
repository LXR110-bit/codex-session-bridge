#!/usr/bin/env bash
# start.sh — one-command beginner entrypoint for Codex Session Bridge.
#
# Remote use:
#   bash <(curl -fsSL https://raw.githubusercontent.com/LXR110-bit/codex-session-bridge/main/start.sh)
#
# Local use:
#   ./start.sh

set -euo pipefail

REPO_URL="https://github.com/LXR110-bit/codex-session-bridge.git"
TARBALL_URL="https://github.com/LXR110-bit/codex-session-bridge/archive/refs/heads/main.tar.gz"
INSTALL_DIR="${CODEX_SESSION_BRIDGE_HOME:-${CODEX_PROFILE_SWITCH_HOME:-$HOME/.codex-session-bridge}}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

say() { printf '%s\n' "$*"; }

ask_yes_no() {
    prompt="$1"
    default="$2"
    if [ "$default" = "Y" ]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi
    printf '%s %s ' "$prompt" "$suffix"
    read -r answer || answer=""
    if [ -z "$answer" ]; then
        [ "$default" = "Y" ]
        return
    fi
    case "$answer" in
        y|Y|yes|YES|Yes|是|要|好|好的|可以|确定|确认) return 0 ;;
        n|N|no|NO|No|否|不|不要|跳过|算了) return 1 ;;
        *) return 1 ;;
    esac
}

script_dir() {
    case "${BASH_SOURCE[0]:-$0}" in
        /*) dirname "${BASH_SOURCE[0]:-$0}" ;;
        *) dirname "$(pwd)/${BASH_SOURCE[0]:-$0}" ;;
    esac
}

is_repo_dir() {
    dir="$1"
    [ -f "$dir/switch.sh" ] && [ -f "$dir/setup-api.sh" ] && [ -f "$dir/install.sh" ]
}

checkout_repo() {
    say "==> 准备工具目录"
    say "    $INSTALL_DIR"

    if [ -d "$INSTALL_DIR/.git" ]; then
        say "==> 已安装，尝试更新到最新版"
        if command -v git >/dev/null 2>&1; then
            git -C "$INSTALL_DIR" pull --ff-only || say "    ⚠️ 更新失败，继续使用本地已有版本。"
        else
            say "    ℹ️ 未找到 git，跳过更新。"
        fi
        return
    fi

    if [ -e "$INSTALL_DIR" ] && [ "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
        say "❌ $INSTALL_DIR 已存在但不是 Codex Session Bridge 仓库。"
        say "   请换一个目录，或设置 CODEX_SESSION_BRIDGE_HOME=/你的目录 后重试。"
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"

    if command -v git >/dev/null 2>&1; then
        rmdir "$INSTALL_DIR" 2>/dev/null || true
        git clone "$REPO_URL" "$INSTALL_DIR"
        return
    fi

    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        tmp_tar="${TMPDIR:-/tmp}/codex-session-bridge-main.$$.tar.gz"
        curl -fsSL "$TARBALL_URL" -o "$tmp_tar"
        tar -xzf "$tmp_tar" -C "$INSTALL_DIR" --strip-components=1
        rm -f "$tmp_tar"
        return
    fi

    say "❌ 需要 git，或 curl + tar，才能自动下载工具。"
    exit 1
}

find_repo_dir() {
    local_dir="$(cd "$(script_dir)" 2>/dev/null && pwd || pwd)"
    if is_repo_dir "$local_dir"; then
        printf '%s\n' "$local_dir"
        return
    fi
    checkout_repo
    printf '%s\n' "$INSTALL_DIR"
}

REPO_DIR="$(find_repo_dir)"
SWITCH="$REPO_DIR/switch.sh"
SETUP_API="$REPO_DIR/setup-api.sh"

say ""
say "=============================================="
say "Codex Session Bridge（Codex 会话桥）小白向导"
say "=============================================="
say ""
say "你只需要做 3 件事："
say "  1. 粘贴 API 地址"
say "  2. 选择是否现在桥接到 API"
say "  3. 重启 Codex，按弹窗粘贴 API key"
say ""
say "不会要求你把 API key 发给 AI，也不会把 key 写进配置文件。"
say ""

if [ ! -d "$CODEX_HOME" ]; then
    say "❌ 没找到 $CODEX_HOME"
    say "   请先安装并打开过一次 Codex Desktop，然后再运行本向导。"
    exit 1
fi

chmod +x "$SWITCH" "$SETUP_API" 2>/dev/null || true

# Optional Claude skill install. Default no, so beginners can press Enter through it.
if ask_yes_no "要顺便安装成 Claude skill 吗？之后可以直接说『codex 会话桥 / 切 api』。" "N"; then
    mkdir -p "$CLAUDE_SKILLS_DIR"
    target="$CLAUDE_SKILLS_DIR/codex-session-bridge"
    if [ -e "$target" ]; then
        say "    ℹ️ $target 已存在，跳过。"
    else
        ln -s "$REPO_DIR" "$target"
        say "    ✅ 已安装 Claude skill。"
    fi
fi

CHATGPT_PROFILE="$CODEX_HOME/config.toml.profile.chatgpt"
API_PROFILE="$CODEX_HOME/config.toml.profile.api"

say ""
say "==> 检查个人账号配置"
if [ -f "$CHATGPT_PROFILE" ]; then
    say "    ✅ 已存在：$CHATGPT_PROFILE"
else
    if [ -f "$CODEX_HOME/config.toml" ]; then
        if ask_yes_no "把当前 Codex 配置保存为『个人账号』配置吗？" "Y"; then
            cp "$CODEX_HOME/config.toml" "$CHATGPT_PROFILE"
            chmod 600 "$CHATGPT_PROFILE" 2>/dev/null || true
            say "    ✅ 已保存：$CHATGPT_PROFILE"
        else
            say "    ⚠️ 暂未创建个人账号配置。以后可手动运行："
            say "       cp ~/.codex/config.toml ~/.codex/config.toml.profile.chatgpt"
        fi
    else
        say "    ⚠️ 没找到 $CODEX_HOME/config.toml，无法自动保存个人账号配置。"
    fi
fi

say ""
say "==> 检查 API 代理配置"
if [ -f "$API_PROFILE" ]; then
    say "    ✅ 已存在：$API_PROFILE"
    if ask_yes_no "要重新粘贴 API 地址并覆盖生成 API 配置吗？旧文件会自动备份。" "N"; then
        bash "$SETUP_API"
    fi
else
    say "    还没有 API 代理配置。"
    if ask_yes_no "现在开始配置 API 地址吗？" "Y"; then
        bash "$SETUP_API"
    else
        say "    已跳过 API 配置。以后运行："
        say "       $REPO_DIR/setup-api.sh"
    fi
fi

say ""
if [ -f "$API_PROFILE" ]; then
    if ask_yes_no "现在桥接到 API 代理吗？" "Y"; then
        say ""
        say "==> 准备桥接到 API 代理"
        say "    如果提示 Codex 正在运行，请先 Cmd+Q 完全退出 Codex 后重试。"
        switch_ok=0
        if bash "$SWITCH" api; then
            switch_ok=1
        fi
        say ""
        bash "$SWITCH" --verify || true
        say ""
        if [ "$switch_ok" -eq 1 ]; then
            say "✅ 已桥接到 API 代理。"
            say ""
            say "最后一步："
            say "  1. 重新打开 Codex Desktop"
            say "  2. 如果 Codex 弹窗要 API key，就粘贴你的 sk-xxx key"
            say "  3. 历史会话应该还在"
        else
            say "⚠️ 桥接没成功（最常见原因：Codex 还在运行）。"
            say "   解决方法："
            say "     1. Cmd+Q 完全退出 Codex Desktop（关窗口不算）"
            say "     2. 重新跑：$REPO_DIR/switch.sh api"
            say "   配置已经保存好了，下次跑 switch.sh 不用再走向导。"
        fi
    else
        say "已完成配置，暂不桥接。以后运行："
        say "  $REPO_DIR/switch.sh api"
    fi
else
    say "没有 API 配置，所以没有执行桥接。"
fi

say ""
say "常用命令："
say "  桥接到 API：    $REPO_DIR/switch.sh api"
say "  桥接回个人账号：$REPO_DIR/switch.sh chatgpt"
say "  重新配置 API：  $REPO_DIR/setup-api.sh"
say ""
