#!/usr/bin/env bash
# codex-profile-switch — switch Codex Desktop between ChatGPT account and API proxy
# while preserving conversation history.
#
# Usage:
#   switch.sh chatgpt           # switch to ChatGPT personal account
#   switch.sh api               # switch to third-party API proxy
#   switch.sh --dry-run api     # preview without changing files
#   switch.sh --verify          # print current state of jsonl + sqlite
#   switch.sh --doctor          # diagnose environment and profile setup
#   switch.sh --help
#
# Repo: https://github.com/LXR110-bit/codex-profile-switch

set -euo pipefail

VERSION="1.0.1"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

print_help() {
    cat <<'EOF_HELP'
codex-profile-switch — switch Codex between ChatGPT account and API proxy.

USAGE:
  switch.sh <profile>          Switch to the named profile
  switch.sh --dry-run <profile> Preview what would change, without writing files
  switch.sh <profile> --dry-run Preview what would change, without writing files
  switch.sh --verify           Show current jsonl + sqlite distribution
  switch.sh --doctor           Diagnose dependencies, profiles, Codex process, and data files
  switch.sh --help             Show this help
  switch.sh --version          Show version

PROFILES:
  chatgpt     ChatGPT personal account (model_provider = "openai")
  api         Third-party API proxy   (model_provider = "openai-custom")

PROFILE FILES (must exist before first use):
  $CODEX_HOME/config.toml.profile.chatgpt
  $CODEX_HOME/config.toml.profile.api

See README and examples/ in the repo for how to create them.

ENVIRONMENT:
  CODEX_HOME   Defaults to ~/.codex
EOF_HELP
}

codex_is_running() {
    pgrep -lf "Codex\.app/Contents/MacOS/Codex|codex app-server" > /dev/null 2>&1
}

print_provider_distribution_jsonl() {
    if [ -d "$CODEX_HOME/sessions" ] || [ -d "$CODEX_HOME/archived_sessions" ]; then
        find "$CODEX_HOME/sessions" "$CODEX_HOME/archived_sessions" -type f -name "*.jsonl" 2>/dev/null \
            | xargs grep -h '"model_provider"' 2>/dev/null \
            | grep -oE '"model_provider":"[^"]+"' \
            | sort | uniq -c || true
    else
        echo "(no sessions / archived_sessions directories)"
    fi
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
    print_provider_distribution_jsonl
}

expected_provider_for_profile() {
    case "$1" in
        chatgpt) echo "openai" ;;
        api) echo "openai-custom" ;;
        *) return 1 ;;
    esac
}

old_provider_for_profile() {
    case "$1" in
        chatgpt) echo "openai-custom" ;;
        api) echo "openai" ;;
        *) return 1 ;;
    esac
}

profile_path_for() {
    echo "$CODEX_HOME/config.toml.profile.$1"
}

count_jsonl_to_rewrite() {
    old_provider="$1"
    count=0
    search_dirs=()
    [ -d "$CODEX_HOME/sessions" ] && search_dirs+=("$CODEX_HOME/sessions")
    [ -d "$CODEX_HOME/archived_sessions" ] && search_dirs+=("$CODEX_HOME/archived_sessions")
    if [ ${#search_dirs[@]} -gt 0 ]; then
        count=$( (find "${search_dirs[@]}" -type f -name "*.jsonl" \
            -exec grep -l "\"model_provider\":\"$old_provider\"" {} + 2>/dev/null || true) \
            | wc -l | tr -d ' ')
    fi
    echo "$count"
}

count_sqlite_to_rewrite() {
    old_provider="$1"
    if [ -f "$CODEX_HOME/state_5.sqlite" ]; then
        sqlite3 "$CODEX_HOME/state_5.sqlite" \
            "select count(*) from threads where model_provider = '$old_provider';" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

doctor() {
    echo "==> codex-profile-switch doctor"
    echo "    version:    $VERSION"
    echo "    CODEX_HOME: $CODEX_HOME"
    echo ""

    echo "==> Dependencies"
    for cmd in bash sqlite3 sed find grep pgrep cp mkdir; do
        if command -v "$cmd" > /dev/null 2>&1; then
            echo "    ✅ $cmd"
        else
            echo "    ❌ $cmd missing"
        fi
    done
    echo ""

    echo "==> Codex process"
    if codex_is_running; then
        echo "    ⚠️  Codex GUI or app-server appears to be running. Quit Codex before switching."
    else
        echo "    ✅ Codex GUI/app-server not detected"
    fi
    echo ""

    echo "==> Profile files"
    for p in chatgpt api; do
        f=$(profile_path_for "$p")
        expected=$(expected_provider_for_profile "$p")
        if [ -f "$f" ]; then
            if grep -q "model_provider[[:space:]]*=[[:space:]]*\"$expected\"" "$f"; then
                echo "    ✅ $p profile exists and mentions model_provider = \"$expected\""
            else
                echo "    ⚠️  $p profile exists but expected model_provider = \"$expected\" was not found: $f"
            fi
        else
            echo "    ❌ $p profile missing: $f"
        fi
    done
    echo ""

    echo "==> Data files"
    [ -d "$CODEX_HOME" ] && echo "    ✅ CODEX_HOME exists" || echo "    ❌ CODEX_HOME missing"
    [ -f "$CODEX_HOME/config.toml" ] && echo "    ✅ config.toml exists" || echo "    ⚠️  config.toml missing"
    [ -f "$CODEX_HOME/state_5.sqlite" ] && echo "    ✅ state_5.sqlite exists" || echo "    ⚠️  state_5.sqlite missing"
    [ -d "$CODEX_HOME/sessions" ] && echo "    ✅ sessions directory exists" || echo "    ⚠️  sessions directory missing"
    [ -d "$CODEX_HOME/archived_sessions" ] && echo "    ✅ archived_sessions directory exists" || echo "    ℹ️  archived_sessions directory missing"
    echo ""

    verify_state
    echo ""
    echo "==> Dry-run hints"
    echo "    ./switch.sh --dry-run chatgpt"
    echo "    ./switch.sh --dry-run api"
}

parse_args() {
    DRY_RUN=0
    TARGET=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h) print_help; exit 0 ;;
            --version|-V) echo "codex-profile-switch $VERSION"; exit 0 ;;
            --verify) verify_state; exit 0 ;;
            --doctor) doctor; exit 0 ;;
            --dry-run)
                DRY_RUN=1
                if [ -z "$TARGET" ]; then
                    shift
                    [ "$#" -gt 0 ] || { echo "❌ --dry-run requires a profile" >&2; exit 1; }
                    TARGET="$1"
                fi
                ;;
            chatgpt|api) TARGET="$1" ;;
            *) echo "❌ Unknown argument: $1" >&2; echo "" >&2; print_help >&2; exit 1 ;;
        esac
        shift
    done

    if [ -z "$TARGET" ]; then
        print_help
        exit 0
    fi
}

parse_args "$@"

NEW_PROVIDER=$(expected_provider_for_profile "$TARGET")
OLD_PROVIDER=$(old_provider_for_profile "$TARGET")
PROFILE=$(profile_path_for "$TARGET")

if [ ! -f "$PROFILE" ]; then
    echo "❌ Profile file not found: $PROFILE" >&2
    echo "   See README and examples/ for how to create profile files." >&2
    exit 1
fi

JSONL_COUNT=$(count_jsonl_to_rewrite "$OLD_PROVIDER")
SQLITE_COUNT=$(count_sqlite_to_rewrite "$OLD_PROVIDER")

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: switch to '$TARGET' mode"
    echo "    CODEX_HOME:      $CODEX_HOME"
    echo "    Profile file:    $PROFILE"
    echo "    Provider change: $OLD_PROVIDER -> $NEW_PROVIDER"
    echo ""
    echo "Would do:"
    echo "    - Backup config.toml and state_5.sqlite if present"
    echo "    - Copy $PROFILE to $CODEX_HOME/config.toml"
    echo "    - Rewrite $JSONL_COUNT jsonl file(s) containing $OLD_PROVIDER"
    echo "    - Rewrite $SQLITE_COUNT sqlite thread row(s) containing $OLD_PROVIDER"
    echo ""
    if codex_is_running; then
        echo "⚠️  Codex GUI or app-server appears to be running. Real switch would refuse to run."
    else
        echo "✅ Codex GUI/app-server not detected. Real switch can proceed."
    fi
    exit 0
fi

# Only block on processes that actually write to sqlite — ignore crashpad / helper services.
if codex_is_running; then
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
