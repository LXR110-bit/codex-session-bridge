#!/usr/bin/env bash
# Codex Session Bridge — bridge Codex Desktop between ChatGPT account and API proxy
# while preserving conversation history.
#
# Repo: https://github.com/LXR110-bit/codex-session-bridge

set -euo pipefail

VERSION="1.4.1"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

DRY_RUN=0
TARGET=""
CUSTOM_NEW_PROVIDER=""
CUSTOM_OLD_PROVIDER=""
ROLLBACK_DIR=""

print_help() {
    cat <<'EOF_HELP'
Codex Session Bridge — keep Codex conversations visible across ChatGPT/API modes.

USAGE:
  switch.sh <profile>                 Bridge to the named profile and migrate session ownership
  switch.sh --dry-run <profile>       Preview bridge changes, without writing files
  switch.sh <profile> --dry-run       Same preview mode
  switch.sh api --provider <name>     Use a custom target model_provider
  switch.sh api --from <name>         Use a custom source model_provider
  switch.sh --verify                  Show current jsonl + sqlite distribution
  switch.sh --doctor                  Diagnose dependencies, profiles, Codex process, and data files
  switch.sh --list-backups            List backup folders created by this tool
  switch.sh --rollback <backup-dir>   Restore config/sqlite/jsonl from a backup folder
  switch.sh --help                    Show this help
  switch.sh --version                 Show version

PROFILES:
  chatgpt     ChatGPT personal account (default provider: openai)
  api         Third-party API proxy   (default provider: openai-custom)

PROFILE FILES (must exist before first use):
  $CODEX_HOME/config.toml.profile.chatgpt
  $CODEX_HOME/config.toml.profile.api

CUSTOM PROVIDERS:
  The profile file still controls Codex's config.toml. --provider only controls
  history migration. If you use --provider my-proxy, make sure the target
  profile file also has model_provider = "my-proxy" and a matching
  [model_providers.my-proxy] block when needed.

ENVIRONMENT:
  CODEX_HOME   Defaults to ~/.codex
EOF_HELP
}

codex_is_running() {
    pgrep -lf "Codex\.app/Contents/MacOS/Codex|codex app-server" > /dev/null 2>&1
}

require_codex_stopped() {
    if codex_is_running; then
        echo "⚠️  Codex GUI or app-server is running." >&2
        echo "    Quit Codex completely (Cmd+Q on macOS, not just closing the window) and retry." >&2
        exit 1
    fi
}

provider_for_profile() {
    case "$1" in
        chatgpt) echo "openai" ;;
        api) echo "openai-custom" ;;
        *) return 1 ;;
    esac
}

default_old_provider_for_profile() {
    case "$1" in
        chatgpt) echo "openai-custom" ;;
        api) echo "openai" ;;
        *) return 1 ;;
    esac
}

profile_path_for() {
    echo "$CODEX_HOME/config.toml.profile.$1"
}

find_jsonl_dirs() {
    [ -d "$CODEX_HOME/sessions" ] && printf '%s\n' "$CODEX_HOME/sessions"
    [ -d "$CODEX_HOME/archived_sessions" ] && printf '%s\n' "$CODEX_HOME/archived_sessions"
}

print_provider_distribution_jsonl() {
    dirs=()
    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(find_jsonl_dirs)
    if [ ${#dirs[@]} -gt 0 ]; then
        find "${dirs[@]}" -type f -name "*.jsonl" -print0 2>/dev/null \
            | xargs -0 grep -h '"model_provider"' 2>/dev/null \
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

count_jsonl_to_rewrite() {
    old_provider="$1"
    dirs=()
    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(find_jsonl_dirs)
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "0"
        return
    fi
    (find "${dirs[@]}" -type f -name "*.jsonl" \
        -exec grep -l "\"model_provider\":\"$old_provider\"" {} + 2>/dev/null || true) \
        | wc -l | tr -d ' '
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

list_backups() {
    echo "==> Backups under $CODEX_HOME"
    if [ ! -d "$CODEX_HOME" ]; then
        echo "(CODEX_HOME not found)"
        return
    fi
    find "$CODEX_HOME" -maxdepth 1 -type d -name 'jsonl_backup_*' -print 2>/dev/null | sort -r || true
}

rollback_backup() {
    backup_dir="$1"
    if [ -z "$backup_dir" ]; then
        echo "❌ --rollback requires a backup directory" >&2
        exit 1
    fi
    if [ ! -d "$backup_dir" ]; then
        echo "❌ Backup directory not found: $backup_dir" >&2
        exit 1
    fi

    require_codex_stopped

    echo "==> Rolling back from $backup_dir"
    if [ -f "$backup_dir/config.toml.bak" ]; then
        cp "$backup_dir/config.toml.bak" "$CODEX_HOME/config.toml"
        echo "    ✅ restored config.toml"
    else
        echo "    ℹ️  config.toml.bak not found"
    fi

    if [ -f "$backup_dir/state_5.sqlite.bak" ]; then
        cp "$backup_dir/state_5.sqlite.bak" "$CODEX_HOME/state_5.sqlite"
        echo "    ✅ restored state_5.sqlite"
    else
        echo "    ℹ️  state_5.sqlite.bak not found"
    fi

    manifest="$backup_dir/manifest.tsv"
    restored=0
    if [ -f "$manifest" ]; then
        while IFS=$'\t' read -r src bak; do
            [ -n "${src:-}" ] || continue
            [ -n "${bak:-}" ] || continue
            if [ -f "$bak" ]; then
                mkdir -p "$(dirname "$src")"
                cp "$bak" "$src"
                restored=$((restored + 1))
            else
                echo "    ⚠️  missing backup file: $bak" >&2
            fi
        done < "$manifest"
        echo "    ✅ restored $restored jsonl file(s) from manifest"
    else
        echo "    ⚠️  manifest.tsv not found; this looks like an older backup."
        echo "       Restored config/sqlite only. JSONL rollback needs backups created by v1.0.2+."
    fi

    echo ""
    echo "✅ Rollback complete. Run './switch.sh --verify', then restart Codex."
}

doctor() {
    echo "==> Codex Session Bridge doctor"
    echo "    version:    $VERSION"
    echo "    CODEX_HOME: $CODEX_HOME"
    echo ""

    echo "==> Dependencies"
    for cmd in bash sqlite3 sed find grep pgrep cp mkdir sort uniq wc; do
        if command -v "$cmd" > /dev/null 2>&1; then
            echo "    ✅ $cmd"
        else
            echo "    ❌ $cmd missing"
        fi
    done
    if command -v shellcheck > /dev/null 2>&1; then
        echo "    ✅ shellcheck (optional contributor check)"
    else
        echo "    ℹ️  shellcheck missing (optional; CI runs it)"
    fi
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
        expected=$(provider_for_profile "$p")
        if [ -f "$f" ]; then
            if grep -q "model_provider[[:space:]]*=[[:space:]]*\"$expected\"" "$f"; then
                echo "    ✅ $p profile exists and mentions model_provider = \"$expected\""
            else
                echo "    ⚠️  $p profile exists but default model_provider = \"$expected\" was not found: $f"
                echo "       This is OK only if you intentionally use --provider."
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
    list_backups
    echo ""
    echo "==> Dry-run hints"
    echo "    ./switch.sh --dry-run chatgpt"
    echo "    ./switch.sh --dry-run api"
    echo "    ./switch.sh api --provider my-proxy --from openai"
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h) print_help; exit 0 ;;
            --version|-V) echo "codex-session-bridge $VERSION"; exit 0 ;;
            --verify) verify_state; exit 0 ;;
            --doctor) doctor; exit 0 ;;
            --list-backups) list_backups; exit 0 ;;
            --rollback)
                shift
                [ "$#" -gt 0 ] || { echo "❌ --rollback requires a backup directory" >&2; exit 1; }
                ROLLBACK_DIR="$1"
                rollback_backup "$ROLLBACK_DIR"
                exit 0
                ;;
            --dry-run)
                DRY_RUN=1
                if [ -z "$TARGET" ]; then
                    shift
                    [ "$#" -gt 0 ] || { echo "❌ --dry-run requires a profile" >&2; exit 1; }
                    TARGET="$1"
                fi
                ;;
            --provider)
                shift
                [ "$#" -gt 0 ] || { echo "❌ --provider requires a value" >&2; exit 1; }
                CUSTOM_NEW_PROVIDER="$1"
                ;;
            --from)
                shift
                [ "$#" -gt 0 ] || { echo "❌ --from requires a value" >&2; exit 1; }
                CUSTOM_OLD_PROVIDER="$1"
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

NEW_PROVIDER="${CUSTOM_NEW_PROVIDER:-$(provider_for_profile "$TARGET")}"
OLD_PROVIDER="${CUSTOM_OLD_PROVIDER:-$(default_old_provider_for_profile "$TARGET")}"
PROFILE=$(profile_path_for "$TARGET")

if [ ! -f "$PROFILE" ]; then
    echo "❌ Profile file not found: $PROFILE" >&2
    echo "   See README and examples/ for how to create profile files." >&2
    exit 1
fi

if ! grep -q "model_provider[[:space:]]*=[[:space:]]*\"$NEW_PROVIDER\"" "$PROFILE"; then
    echo "⚠️  Target profile does not mention model_provider = \"$NEW_PROVIDER\": $PROFILE" >&2
    echo "    Continue only if this is intentional; otherwise update the profile or --provider value." >&2
    if [ "$DRY_RUN" -eq 0 ]; then
        echo "    Refusing to switch. Use --dry-run to inspect, or fix the profile." >&2
        exit 1
    fi
fi

JSONL_COUNT=$(count_jsonl_to_rewrite "$OLD_PROVIDER")
SQLITE_COUNT=$(count_sqlite_to_rewrite "$OLD_PROVIDER")

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Dry run: bridge to '$TARGET' mode"
    echo "    CODEX_HOME:      $CODEX_HOME"
    echo "    Profile file:    $PROFILE"
    echo "    Provider change: $OLD_PROVIDER -> $NEW_PROVIDER"
    echo ""
    echo "Would do:"
    echo "    - Backup config.toml and state_5.sqlite if present"
    echo "    - Write a manifest.tsv for exact JSONL rollback"
    echo "    - Copy $PROFILE to $CODEX_HOME/config.toml"
    echo "    - Rewrite $JSONL_COUNT jsonl file(s) containing $OLD_PROVIDER"
    echo "    - Rewrite $SQLITE_COUNT sqlite thread row(s) containing $OLD_PROVIDER"
    echo ""
    if codex_is_running; then
        echo "⚠️  Codex GUI or app-server appears to be running. Real bridge would refuse to run."
    else
        echo "✅ Codex GUI/app-server not detected. Real bridge can proceed."
    fi
    exit 0
fi

require_codex_stopped

echo "==> [1/4] Backup current config, sqlite, and jsonl manifest"
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$CODEX_HOME/jsonl_backup_$TS"
MANIFEST="$BACKUP_DIR/manifest.tsv"
mkdir -p "$BACKUP_DIR"
: > "$MANIFEST"
[ -f "$CODEX_HOME/config.toml" ] && cp "$CODEX_HOME/config.toml" "$BACKUP_DIR/config.toml.bak"
[ -f "$CODEX_HOME/state_5.sqlite" ] && cp "$CODEX_HOME/state_5.sqlite" "$BACKUP_DIR/state_5.sqlite.bak"

echo "==> [2/4] Bridge config.toml to '$TARGET' profile"
cp "$PROFILE" "$CODEX_HOME/config.toml"

echo "==> [3/4] Rewrite jsonl: $OLD_PROVIDER -> $NEW_PROVIDER"
COUNT=0
SEARCH_DIRS=()
while IFS= read -r dir; do
    SEARCH_DIRS+=("$dir")
done < <(find_jsonl_dirs)
if [ ${#SEARCH_DIRS[@]} -gt 0 ]; then
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        rel="${f#"$CODEX_HOME"/}"
        bak="$BACKUP_DIR/$(echo "$rel" | tr '/' '_').bak"
        cp "$f" "$bak"
        printf '%s\t%s\n' "$f" "$bak" >> "$MANIFEST"
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
echo "✅ Bridged to '$TARGET' mode."
echo "   Backup: $BACKUP_DIR"
echo "   Rollback: ./switch.sh --rollback '$BACKUP_DIR'"
echo ""
echo "   Run './switch.sh --verify' to confirm jsonl and sqlite both show only '$NEW_PROVIDER'."
echo "   Then restart Codex — all history conversations will be visible."
