#!/usr/bin/env bash
# Installer for Codex Session Bridge.
# - Verifies dependencies
# - Optionally symlinks the skill into ~/.claude/skills/ so Claude can invoke it
# - Optionally creates initial profile files from your current config.toml

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

echo "==> Codex Session Bridge installer"
echo "    Repo:        $REPO_DIR"
echo "    CODEX_HOME:  $CODEX_HOME"
echo ""

# 1. Dependency check
echo "==> Checking dependencies"
for cmd in sqlite3 sed find grep pgrep; do
    if ! command -v "$cmd" > /dev/null; then
        echo "❌ Missing dependency: $cmd" >&2
        exit 1
    fi
done
echo "    ✅ all required commands found"

if [ ! -d "$CODEX_HOME" ]; then
    echo "⚠️  $CODEX_HOME does not exist. Is Codex Desktop installed and run at least once?"
fi

# 2. Make scripts executable
chmod +x "$REPO_DIR/switch.sh"
[ -f "$REPO_DIR/setup-api.sh" ] && chmod +x "$REPO_DIR/setup-api.sh"
[ -f "$REPO_DIR/start.sh" ] && chmod +x "$REPO_DIR/start.sh"

# 3. Offer to symlink into ~/.claude/skills/
echo ""
read -r -p "Symlink skill into $CLAUDE_SKILLS_DIR/codex-session-bridge ? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    mkdir -p "$CLAUDE_SKILLS_DIR"
    target="$CLAUDE_SKILLS_DIR/codex-session-bridge"
    if [ -e "$target" ]; then
        echo "    $target already exists — skipping (remove it manually if you want to overwrite)"
    else
        ln -s "$REPO_DIR" "$target"
        echo "    ✅ symlinked"
    fi
fi

# 4. Offer to seed profile files
echo ""
echo "==> Profile files"
for p in chatgpt api; do
    f="$CODEX_HOME/config.toml.profile.$p"
    if [ -f "$f" ]; then
        echo "    ✅ $f already exists"
    else
        echo "    ❌ $f missing"
        if [ "$p" = "api" ] && [ -f "$REPO_DIR/setup-api.sh" ]; then
            read -r -p "       Run the interactive API setup wizard now? [Y/n] " yn
            if [[ ! "$yn" =~ ^[Nn]$ ]]; then
                bash "$REPO_DIR/setup-api.sh"
                continue
            fi
        fi
        echo "       Sample:   $REPO_DIR/examples/config.toml.$p.example"
        echo "       Suggestion: cp the example, edit it to match your setup, then save as the path above."
        if [ "$p" = "chatgpt" ]; then
            echo "       Or, if Codex is already logged into your ChatGPT account:"
            echo "         cp $CODEX_HOME/config.toml $f"
        fi
    fi
done

echo ""
echo "==> Done."
echo ""
echo "Beginner start:"
echo "    $REPO_DIR/start.sh"
echo ""
echo "Quick commands:"
echo "    $REPO_DIR/switch.sh --help"
echo "    $REPO_DIR/switch.sh --verify"
echo "    $REPO_DIR/switch.sh chatgpt"
echo "    $REPO_DIR/switch.sh api"
