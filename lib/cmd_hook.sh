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
AAPP_BASE="${AAPP_BASE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source hook dispatcher engine
DISPATCHER_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_dispatcher.sh"
if [ -f "$DISPATCHER_LIB" ]; then
    # shellcheck source=/dev/null
    source "$DISPATCHER_LIB"
fi

# ------------------------------------------------------------------------------
# 1. Action: `aapp hooks` (Lifecycle Hook Audit)
# ------------------------------------------------------------------------------
print_lifecycle_events_catalog() {
    echo "📋 Supported Lifecycle Events Catalog (Pre/On/Post Timing Taxonomy):"
    echo ""
    echo "  1. Pre-Mutation Gates (Gating, exit != 0 aborts before state change):"
    echo "     • pre-freeze    Runs before locking plan into frozen backlog spec"
    echo "     • pre-start     Runs before activating plan into ⚡ In Development"
    echo "     • pre-done      Runs before archiving plan to .plans/done/"
    echo "     • pre-sync      Runs before synchronizing remote worktrees"
    echo ""
    echo "  2. On-Mutation Observers (Synchronous, inherits environment/stdin):"
    echo "     • on-freeze     Triggers immediately after plan freeze state mutation"
    echo "     • on-start      Triggers immediately after plan activation into development"
    echo "     • on-done       Triggers immediately after plan archive state mutation"
    echo "     • on-sync       Triggers immediately after worktree git fetch/rebase"
    echo ""
    echo "  3. Post-Mutation Actions (Non-blocking background or reporting):"
    echo "     • post-freeze   Runs after plan freeze commits land"
    echo "     • post-start    Runs after plan start commits land"
    echo "     • post-done     Runs after plan done commits land"
    echo "     • post-sync     Runs after worktree sync completes"
}

cmd_hooks_status() {
    if [ "$1" = "--events" ] || [ "$1" = "-e" ]; then
        print_lifecycle_events_catalog
        return 0
    fi

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
            if [[ "$hp" == *.sample ]]; then
                status_badge="⚠️  INERT SAMPLE"
            elif [ ! -f "$handler_path" ]; then
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
            if [[ "$val" == *.sample ]]; then
                badge="⚠️  INERT SAMPLE"
            elif [ ! -f "$hpath" ]; then
                badge="❌ MISSING"
            elif [ ! -x "$hpath" ]; then
                badge="❌ NOT EXECUTABLE"
            fi
            printf "  • %-12s -> %-45s [notify, git config] (%s)\n" "$ev" "$val" "$badge"
        done <<< "$cfg_hooks"
    fi

    if [ "$found" -eq 0 ]; then
        echo "  ℹ️  No lifecycle hooks registered in registry.tsv or git config."
        echo ""
        print_lifecycle_events_catalog
    fi

    # Available Samples Discovery (Zero Repo Clutter)
    echo ""
    if [ "${AAPP_IS_DROP_IN:-0}" -eq 0 ] && [ -d "$AAPP_BASE/examples/hooks" ]; then
        local hook_sample_count=0
        local hook_sample_names=""
        for hfile in "$AAPP_BASE/examples/hooks"/*; do
            [ ! -f "$hfile" ] && continue
            hook_sample_count=$((hook_sample_count + 1))
            hook_sample_names="${hook_sample_names:+${hook_sample_names}, }$(basename "$hfile")"
        done
        if [ "$hook_sample_count" -gt 0 ]; then
            echo "  📦 Available Hook Samples ($hook_sample_count):"
            echo "    • Location:  ${AAPP_BASE/#$HOME/\~}/examples/hooks/"
            echo "    • Available: $hook_sample_names"
            echo "    • To adopt:  cp \"$AAPP_BASE/examples/hooks/<file>\" .githooks/ && aapp hook-hash ..."
        fi
    else
        echo "  📦 Reference Samples:"
        echo "    • Documented in MANUAL.md and at:"
        echo "      https://github.com/aapp-protocol/aapp-kit/tree/main/examples/hooks"
        echo "    • Install globally to retain local samples: 'aapp install'"
    fi
}

# ------------------------------------------------------------------------------
# 2. Action: `aapp plugins` (Action Plugin Discovery Inspection)
# ------------------------------------------------------------------------------

cmd_plugins_status() {
    local skills_dir="$REPO_ROOT/.agents/skills"
    echo "🔌 AAPP Action Plugins & Extension Points (.agents/skills/)"
    echo ""

    # 1. Standard Extension Points (Hardcoded Runtime Authority)
    echo "  Standard Extension Points:"
    
    # aapp-planid
    if [ -d "$skills_dir/aapp-planid" ] && resolve_plugin_entrypoint "$skills_dir/aapp-planid" "aapp-planid" >/dev/null 2>&1; then
        local entry="$(resolve_plugin_entrypoint "$skills_dir/aapp-planid" "aapp-planid")"
        printf "    • %-16s [Team Plan ID Authority] -> %s (ACTIVE)\n" "aapp-planid" "${entry#$REPO_ROOT/}"
    elif [ -d "$skills_dir/aapp-planid" ]; then
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> .agents/skills/aapp-planid/ (CONFIGURED BUT NOT EXECUTABLE)\n" "aapp-planid"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    elif [ -d "$AAPP_BASE/examples/plugins/aapp-planid" ]; then
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> NOT INSTALLED (SAMPLE AVAILABLE in %s)\n" "aapp-planid" "${AAPP_BASE/#$HOME/\~}/examples/plugins/aapp-planid/"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    else
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> NOT INSTALLED\n" "aapp-planid"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    fi

    # hello-tool (showcase)
    if [ -d "$skills_dir/hello-tool" ] && resolve_plugin_entrypoint "$skills_dir/hello-tool" "hello-tool" >/dev/null 2>&1; then
        local entry="$(resolve_plugin_entrypoint "$skills_dir/hello-tool" "hello-tool")"
        printf "    • %-16s [Custom CLI Showcase]   -> %s (ACTIVE)\n" "hello-tool" "${entry#$REPO_ROOT/}"
    elif [ -d "$skills_dir/hello-tool" ]; then
        printf "    • %-16s [Custom CLI Showcase]   -> .agents/skills/hello-tool/ (CONFIGURED BUT NOT EXECUTABLE)\n" "hello-tool"
    fi

    echo ""
    echo "  Custom Action Plugins:"
    local custom_count=0
    if [ -d "$skills_dir" ]; then
        for sdir in "$skills_dir"/*; do
            [ ! -d "$sdir" ] && continue
            local sname="$(basename "$sdir")"
            case "$sname" in
                aapp-*|aapp|plan|hello-tool|*.sample|node_modules|vendor) continue ;; # Skip core skills, standard points, and samples
            esac
            local entrypoint="$(resolve_plugin_entrypoint "$sdir" "$sname" || true)"
            if [ -n "$entrypoint" ]; then
                custom_count=$((custom_count + 1))
                printf "    • %-16s -> %s (executable via 'aapp %s')\n" "$sname" "${entrypoint#$REPO_ROOT/}" "$sname"
            fi
        done
    fi
    if [ "$custom_count" -eq 0 ]; then
        echo "    ℹ️  No custom action plugins found."
    fi

    # 3. Available Samples Discovery (Zero Repo Clutter)
    echo ""
    if [ "${AAPP_IS_DROP_IN:-0}" -eq 0 ] && [ -d "$AAPP_BASE/examples/plugins" ]; then
        local sample_count=0
        local sample_names=""
        for edir in "$AAPP_BASE/examples/plugins"/*; do
            [ ! -d "$edir" ] && continue
            sample_count=$((sample_count + 1))
            sample_names="${sample_names:+${sample_names}, }$(basename "$edir")"
        done
        if [ "$sample_count" -gt 0 ]; then
            echo "  📦 Available Plugin Samples ($sample_count):"
            echo "    • Location:  ${AAPP_BASE/#$HOME/\~}/examples/plugins/"
            echo "    • Available: $sample_names"
            echo "    • To adopt:  cp -r \"$AAPP_BASE/examples/plugins/<name>\" \"$skills_dir/\""
        fi
    else
        echo "  📦 Reference Samples:"
        echo "    • Documented in MANUAL.md and at:"
        echo "      https://github.com/aapp-protocol/aapp-kit/tree/main/examples/plugins"
        echo "    • Install globally to retain local samples: 'aapp install'"
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
        echo "Usage: aapp hooks [--events] | plugins | hook-test <event> [id] | hook-hash <path> [event] [timeout] [mode]"
        echo ""
        echo "Commands:"
        echo "  hooks [--events]      Audit registered lifecycle hooks or list supported events catalog"
        echo "  plugins               Inspect discovered standalone action plugins (.agents/skills/*/)"
        echo "  hook-test <event>     Dry-run test a lifecycle event and inspect stdout/stderr"
        echo "  hook-hash <path>      Compute SHA256 hash and format 5-column registry.tsv line"
        ;;
    *)
        echo "❌ Unknown hook command: '$SUBCMD'" >&2
        echo "   Available: hooks, plugins, hook-test, hook-run, hook-hash" >&2
        exit 1
        ;;
esac
