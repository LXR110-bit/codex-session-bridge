#!/usr/bin/env bash
# codex-profile-switch — switch Codex Desktop between ChatGPT account and API proxy
# while preserving conversation history.
#
# Usage:
#   switch.sh chatgpt    # switch to ChatGPT personal account
#   switch.sh api        # switch to third-party API proxy
#   switch.sh --verify   # print current state of jsonl + sqlite
#   switch.sh --help
#
# Repo: https://github.com/LXR110-bit/codex-profile-switch

set -euo pipefail

VERSION="1.0.0"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

print_help() {
    cat <<'EOF'
codex-profile-switch — switch Codex between ChatGPT account and API proxy.

USAGE:
  switch.sh <profile>     Switch to the named profile
  switch.sh --verify      Show current jsonl + sqlite distribution
  switch.sh --help        Show this help
  switch.sh --version     Show version

PROFILES:
  chatgpt     ChatGPT personal account (model_provider = "openai")
  api         Third-party API proxy   (model_provider = "openai-custom")

PROFILE FILES (must exist before first use):
  $CODEX_HOME/config.toml.profile.chatgpt
  $CODEX_HOME/config.toml.profile.api

See README and examples/ in the repo for how to create them.

ENVIRONMENT:
  CODEX_HOME   Defaults to ~/.codex
EOF
}

verify_state() {
    echo "=== sqlite threads.model_provider ==="
    if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
        sqlite3 "$CODEX_HOME/state_5.sqlite" \
            "select model_provider, count(*) from threads group by model_provider;"
    else
        echo "(state_5.sqlite not found)"
    fi
    echo ""
    echo "=== jsonl model_provider distribution ==="
    if [ -d "$CODEX_HOME/sessions" ] || [ -d "$CODEX_HOME/archived_sessions" ]; then
        find "$CODEX_HOME/sessions" "$CODEX_HOME/archived_sessions" -type f -name "*.jsonl" 2>/dev/null \
            | xargs grep -h '"model_provider"' 2>/dev/null \
            | grep -oE '"model_provider":"[^"]+"' \
            | sort | uniq -c
    else
        echo "(no sessions / archived_sessions directories)"
    fi
}

case "${1:-}" in
    --help|-h|"") print_help; exit 0 ;;
    --version|-V) echo "codex-profile-switch $VERSION"; exit 0 ;;
    --verify) verify_state; exit 0 ;;
esac

TARGET="$1"
if [[ "$TARGET" == "chatgpt" ]]; then
    NEW_PROVIDER="openai"
    OLD_PROVIDER="openai-custom"
elif [[ "$TARGET" == "api" ]]; then
    NEW_PROVIDER="openai-custom"
    OLD_PROVIDER="openai"
else
    echo "❌ Unknown profile: $TARGET" >&2
    echo "" >&2
    print_help >&2
    exit 1
fi

PROFILE="$CODEX_HOME/config.toml.profile.$TARGET"
if [ ! -f "$PROFILE" ]; then
    echo "❌ Profile file not found: $PROFILE" >&2
    echo "   See README and examples/ for how to create profile files." >&2
    exit 1
fi

# Only block on processes that actually write to sqlite — ignore crashpad / helper services
if pgrep -lf "Codex\.app/Contents/MacOS/Codex|codex app-server" > /dev/null 2>&1; then
    echo "⚠️  Codex GUI or app-server is running." >&2
    echo "    Quit Codex completely (Cmd+Q on macOS, not just closing the window) and retry." >&2
    exit 1
fi

echo "==> [1/4] Backup current config and sqlite"
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$CODEX_HOME/jsonl_backup_$TS"
mkdir -p "$BACKUP_DIR"
[ -f "$CODEX_HOME/config.toml" ] && cp "$CODEX_HOME/config.toml" "$BACKUP_DIR/config.toml.bak"
[ -f "$CODEX_HOME/state_5.sqlite" ] && cp "$CODEX_HOME/state_5.sqlite" "$BACKUP_DIR/state_5.sqlite.bak"

echo "==> [2/4] Switch config.toml to '$TARGET' profile"
cp "$PROFILE" "$CODEX_HOME/config.toml"

echo "==> [3/4] Rewrite jsonl: $OLD_PROVIDER -> $NEW_PROVIDER"
# Use find for recursion. Don't use shell ** — macOS default bash (3.2) has no globstar
# and sessions/ is YYYY/MM/DD/*.jsonl, four levels deep. Globbing silently misses files.
COUNT=0
SEARCH_DIRS=()
[ -d "$CODEX_HOME/sessions" ] && SEARCH_DIRS+=("$CODEX_HOME/sessions")
[ -d "$CODEX_HOME/archived_sessions" ] && SEARCH_DIRS+=("$CODEX_HOME/archived_sessions")

if [ ${#SEARCH_DIRS[@]} -gt 0 ]; then
    while IFS= read -r f; do
        rel="${f#$CODEX_HOME/}"
        # encode path into filename so jsonl with same basename in different date dirs don't collide
        cp "$f" "$BACKUP_DIR/$(echo "$rel" | tr '/' '_').bak"
        sed -i.tmp "s/\"model_provider\":\"$OLD_PROVIDER\"/\"model_provider\":\"$NEW_PROVIDER\"/g" "$f"
        rm -f "$f.tmp"
        COUNT=$((COUNT + 1))
    done < <(find "${SEARCH_DIRS[@]}" -type f -name "*.jsonl" \
        -exec grep -l "\"model_provider\":\"$OLD_PROVIDER\"" {} + 2>/dev/null || true)
fi
echo "    $COUNT jsonl files rewritten"

echo "==> [4/4] Rewrite sqlite: $OLD_PROVIDER -> $NEW_PROVIDER"
if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
    sqlite3 "$CODEX_HOME/state_5.sqlite" \
        "update threads set model_provider = '$NEW_PROVIDER' where model_provider = '$OLD_PROVIDER';"
    echo "    Final sqlite distribution:"
    sqlite3 "$CODEX_HOME/state_5.sqlite" \
        "select '    ' || model_provider || ' = ' || count(*) from threads group by model_provider;"
fi

echo ""
echo "✅ Switched to '$TARGET' mode."
echo "   Backup: $BACKUP_DIR"
echo ""
echo "   Run 'switch.sh --verify' to confirm jsonl and sqlite both show only '$NEW_PROVIDER'."
echo "   Then restart Codex — all history conversations will be visible."
