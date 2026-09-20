#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `hooks`, `plugins`, `hook-test`, `hook-hash`
#
# Governed by Plan P-12 (Lifecycle Plugin Hooks & Event Architecture).
# Dedicated CLI actions for lifecycle hooks and extension-agnostic action plugins.
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "❌ Error: Not inside a git repository." >&2
    exit 1
fi

# Source hook dispatcher engine
DISPATCHER_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_dispatcher.sh"
if [ -f "$DISPATCHER_LIB" ]; then
    # shellcheck source=/dev/null
    source "$DISPATCHER_LIB"
fi

# ------------------------------------------------------------------------------
# 1. Action: `aapp hooks` (Lifecycle Hook Audit)
# ------------------------------------------------------------------------------
cmd_hooks_status() {
    local reg_file="$REPO_ROOT/.agents/skills/aapp-hooks/registry.tsv"
    local TAB
    TAB="$(printf '\t')"
    local found=0

    echo "🪝 AAPP Lifecycle Hooks (.agents/skills/aapp-hooks/registry.tsv)"

    if [ -f "$reg_file" ]; then
        while IFS="$TAB" read -r ev hp expected_hash to md extra || [ -n "$ev" ]; do
            [ -z "$ev" ] && continue
            [ "${ev#\#}" != "$ev" ] && continue

            to="${to:-10}"
            md="${md:-gate}"
            found=$((found + 1))

            local handler_path
            if [[ "$hp" = /* ]]; then
                handler_path="$hp"
            else
                handler_path="$REPO_ROOT/$hp"
            fi

            local status_badge="✅ VALID"
            if [ ! -f "$handler_path" ]; then
                status_badge="❌ MISSING"
            elif [ ! -x "$handler_path" ]; then
                status_badge="❌ NOT EXECUTABLE"
            else
                local clean_expected="${expected_hash#sha256:}"
                local actual_hash
                actual_hash="$(compute_file_sha256 "$handler_path" 2>/dev/null || true)"
                if [ -n "$clean_expected" ] && [ "$clean_expected" != "$actual_hash" ]; then
                    status_badge="⚠️  SHA MISMATCH"
                fi
            fi

            printf "  • %-12s -> %-45s [%s, %ss] (%s)\n" "$ev" "$hp" "$md" "$to" "$status_badge"
        done < "$reg_file"
    fi

    # Local git config overrides
    local allow_local
    allow_local="$(git -C "$REPO_ROOT" config aapp.allowLocalHooks 2>/dev/null || echo "true")"
    local cfg_hooks
    cfg_hooks="$(git -C "$REPO_ROOT" config --get-regexp '^aapp\.hook\.' 2>/dev/null || true)"

    if [ -n "$cfg_hooks" ]; then
        echo ""
        echo "🔧 Local Clone Overrides (git config aapp.hook.*, mode=notify)"
        if [ "$allow_local" = "false" ]; then
            echo "  ⚠️  Local hooks disabled via git config aapp.allowLocalHooks false (CI confinement)"
        fi
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local key val ev
            key="$(echo "$line" | awk '{print $1}')"
            val="$(echo "$line" | cut -d' ' -f2-)"
            ev="${key#aapp.hook.}"
            found=$((found + 1))

            local hpath
            if [[ "$val" = /* ]]; then
                hpath="$val"
            else
                hpath="$REPO_ROOT/$val"
            fi

            local badge="✅ VALID"
            if [ ! -f "$hpath" ]; then
                badge="❌ MISSING"
            elif [ ! -x "$hpath" ]; then
                badge="❌ NOT EXECUTABLE"
            fi
            printf "  • %-12s -> %-45s [notify, git config] (%s)\n" "$ev" "$val" "$badge"
        done <<< "$cfg_hooks"
    fi

    if [ "$found" -eq 0 ]; then
        echo "  ℹ️  No lifecycle hooks registered in registry.tsv or git config."
    fi
}

# ------------------------------------------------------------------------------
# 2. Action: `aapp plugins` (Action Plugin Discovery Inspection)
# ------------------------------------------------------------------------------

cmd_plugins_status() {
    local skills_dir="$REPO_ROOT/.agents/skills"
    echo "🔌 Installed Action Plugins (.agents/skills/)"

    if [ ! -d "$skills_dir" ]; then
        echo "  ℹ️  No .agents/skills/ directory found."
        return 0
    fi

    local count=0
    for sdir in "$skills_dir"/*; do
        [ ! -d "$sdir" ] && continue
        local sname
        sname="$(basename "$sdir")"
        case "$sname" in
            aapp-*|aapp|plan) continue ;; # Skip core protocol skills
        esac

        local entrypoint
        entrypoint="$(resolve_plugin_entrypoint "$sdir" "$sname" || true)"
        if [ -n "$entrypoint" ]; then
            count=$((count + 1))
            local rel_entry="${entrypoint#$REPO_ROOT/}"
            printf "  • %-20s -> %s (executable)\n" "$sname" "$rel_entry"
        fi
    done

    if [ "$count" -eq 0 ]; then
        echo "  ℹ️  No action plugins found in .agents/skills/."
    fi
}

# ------------------------------------------------------------------------------
# 3. Action: `aapp hook-test <event> [plan-id]` (Dry-Run Gate)
# ------------------------------------------------------------------------------
cmd_hook_test() {
    local event="${1:-}"
    local plan_id="${2:-}"

    if [ -z "$event" ]; then
        echo "❌ Error: Missing event name for hook-test." >&2
        echo "Usage: aapp hook-test <event> [plan-id]" >&2
        echo "Available events: on-pickup, on-digest, on-freeze, on-start, on-done, on-pause, on-resume, pre-sync, on-sync, post-sync" >&2
        return 1
    fi

    local data_json="{}"
    if [ -n "$plan_id" ]; then
        export AAPP_PLAN_ID="$plan_id"
        data_json="{\"plan_id\": \"$plan_id\", \"test\": true}"
    else
        data_json="{\"test\": true}"
    fi

    echo "🧪 Testing lifecycle event '$event' (dry-run mode)..."
    if dispatch_hook "$event" "$data_json"; then
        echo "✅ Hook execution succeeded for '$event'."
        return 0
    else
        echo "❌ Hook execution failed or rejected '$event'." >&2
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 4. Action: `aapp hook-hash <path> [event] [timeout] [mode]` (Registration Helper)
# ------------------------------------------------------------------------------
cmd_hook_hash() {
    local target_path="${1:-}"
    local event="${2:-on-freeze}"
    local timeout="${3:-10}"
    local mode="${4:-gate}"

    if [ -z "$target_path" ]; then
        echo "❌ Error: Missing handler file path." >&2
        echo "Usage: aapp hook-hash <path> [event] [timeout] [mode]" >&2
        echo "Example: aapp hook-hash .agents/skills/migration-guard/scripts/check.sh on-freeze 30 gate" >&2
        return 1
    fi

    local full_path
    if [[ "$target_path" = /* ]]; then
        full_path="$target_path"
    else
        full_path="$REPO_ROOT/$target_path"
    fi

    if [ ! -f "$full_path" ]; then
        echo "❌ Error: File '$target_path' does not exist." >&2
        return 1
    fi

    if [ ! -x "$full_path" ]; then
        echo "⚠️  Warning: File '$target_path' is not executable. Run 'chmod +x $target_path'." >&2
    fi

    local hash
    hash="$(compute_file_sha256 "$full_path")"
    if [ -z "$hash" ]; then
        echo "❌ Error: Could not compute SHA256 for '$target_path'." >&2
        return 1
    fi

    local rel_path
    if [[ "$target_path" = /* ]]; then
        rel_path="${target_path#$REPO_ROOT/}"
    else
        rel_path="$target_path"
    fi

    local TAB
    TAB="$(printf '\t')"
    echo "📋 Generated 5-column line for .agents/skills/aapp-hooks/registry.tsv:"
    printf "%s%s%s%ssha256:%s%s%s%s%s\n" "$event" "$TAB" "$rel_path" "$TAB" "$hash" "$TAB" "$timeout" "$TAB" "$mode"
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
SUBCMD="${1:-hooks}"
shift || true

case "$SUBCMD" in
    hooks|hook-status)
        cmd_hooks_status "$@"
        ;;
    plugins|plugin-status)
        cmd_plugins_status "$@"
        ;;
    hook-test|hook-run)
        cmd_hook_test "$@"
        ;;
    hook-hash)
        cmd_hook_hash "$@"
        ;;
    --help|-h|help)
        echo "Usage: aapp hooks | plugins | hook-test <event> [id] | hook-hash <path> [event] [timeout] [mode]"
        echo ""
        echo "Commands:"
        echo "  hooks                 Audit registered lifecycle hooks and verify SHA256 hashes"
        echo "  plugins               Inspect discovered standalone action plugins (.agents/skills/*/)"
        echo "  hook-test <event>     Dry-run test a lifecycle event and inspect stdout/stderr"
        echo "  hook-hash <path>      Compute SHA256 hash and format 5-column registry.tsv line"
        ;;
    *)
        echo "❌ Unknown hook command: '$SUBCMD'" >&2
        echo "   Available: hooks, plugins, hook-test, hook-hash" >&2
        exit 1
        ;;
esac
