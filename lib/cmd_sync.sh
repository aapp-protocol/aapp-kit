#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `push`, `pull`, `sync`
#
# Automated remote synchronization for isolated AAPP orphan worktrees.
# Governed by Plan P-10 (Remote Sync Automation).
# Supports three-tier strategy resolution:
#   1. CLI Positional Override: aapp push [remote] [strategy]
#   2. Local Clone Config: git config aapp.syncStrategy [builtin|hook]
#   3. Committed Repository Standard: .agents/skills/aapp-hooks/registry.tsv
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "❌ Error: Not inside a git repository." >&2
    exit 1
fi

ACTION="${1:-sync}"
shift || true

# Parse positional arguments: [remote] [strategy]
TARGET_REMOTE=""
CLI_STRATEGY=""

while [ $# -gt 0 ]; do
    arg="$1"
    case "$arg" in
        builtin|hook)
            # If a remote is already set, or if arg is explicitly a strategy and not a remote
            if [ -n "$TARGET_REMOTE" ]; then
                CLI_STRATEGY="$arg"
            else
                # Check if there is an actual git remote with this name
                if git -C "$REPO_ROOT" remote 2>/dev/null | grep -qx "$arg"; then
                    TARGET_REMOTE="$arg"
                else
                    CLI_STRATEGY="$arg"
                fi
            fi
            ;;
        --help|-h)
            echo "Usage: aapp $ACTION [remote] [strategy]"
            echo ""
            echo "Synchronize active AAPP worktrees (.plans, .agents, .githooks) with remote."
            echo ""
            echo "Arguments:"
            echo "  [remote]    Target git remote (default: git config aapp.remote or 'origin')"
            echo "  [strategy]  Sync transport strategy: 'builtin' (core git) or 'hook' (delegated)"
            echo ""
            echo "Examples:"
            echo "  aapp $ACTION"
            echo "  aapp $ACTION origin"
            echo "  aapp $ACTION origin builtin"
            echo "  aapp $ACTION hook"
            return 0 2>/dev/null || exit 0
            ;;
        *)
            if [ -z "$TARGET_REMOTE" ]; then
                TARGET_REMOTE="$arg"
            elif [ -z "$CLI_STRATEGY" ]; then
                CLI_STRATEGY="$arg"
            else
                echo "❌ Error: Unexpected argument '$arg'." >&2
                echo "Usage: aapp $ACTION [remote] [strategy]" >&2
                return 1 2>/dev/null || exit 1
            fi
            ;;
    esac
    shift
done

# Resolve remote
if [ -z "$TARGET_REMOTE" ]; then
    TARGET_REMOTE="$(git -C "$REPO_ROOT" config aapp.remote 2>/dev/null || true)"
    if [ -z "$TARGET_REMOTE" ]; then
        TARGET_REMOTE="$(git -C "$REPO_ROOT" remote 2>/dev/null | head -n 1 || true)"
        [ -z "$TARGET_REMOTE" ] && TARGET_REMOTE="origin"
    fi
fi

# Assert remote exists
if ! git -C "$REPO_ROOT" remote 2>/dev/null | grep -qx "$TARGET_REMOTE"; then
    echo "❌ Error: Git remote '$TARGET_REMOTE' does not exist." >&2
    echo "   Configure a remote using 'git remote add $TARGET_REMOTE <url>'." >&2
    return 1 2>/dev/null || exit 1
fi

# Discover active worktrees from git config aapp.syncWorktrees
RAW_WTS="$(git -C "$REPO_ROOT" config aapp.syncWorktrees 2>/dev/null || echo "plans agents githooks")"
ACTIVE_WTS=()

for token in $RAW_WTS; do
    # Try prefixed .<token>, then bare <token>
    if [ -d "$REPO_ROOT/.$token" ]; then
        ACTIVE_WTS+=(".$token")
    elif [ -d "$REPO_ROOT/$token" ]; then
        ACTIVE_WTS+=("$token")
    fi
done

if [ ${#ACTIVE_WTS[@]} -eq 0 ]; then
    echo "⚠️  No active AAPP worktrees found on disk from '$RAW_WTS'."
    return 0 2>/dev/null || exit 0
fi

# Helper: Find registered on-sync handler
find_on_sync_handler() {
    local reg_file="$REPO_ROOT/.agents/skills/aapp-hooks/registry.tsv"
    local handler=""
    local TAB
    TAB="$(printf '\t')"

    # Check committed registry.tsv
    if [ -f "$reg_file" ]; then
        while IFS="$TAB" read -r ev hp hash to md extra || [ -n "$ev" ]; do
            # Skip empty lines or comments
            [ -z "$ev" ] && continue
            [ "${ev#\#}" != "$ev" ] && continue
            # Check if event is on-sync
            if [ "$ev" = "on-sync" ]; then
                # Resolve relative path against repo root
                if [[ "$hp" = /* ]]; then
                    handler="$hp"
                else
                    handler="$REPO_ROOT/$hp"
                fi
                if [ -x "$handler" ]; then
                    echo "$handler"
                    return 0
                fi
            fi
        done < "$reg_file"
    fi

    # Check local git config clone overrides
    local cfg_handlers
    cfg_handlers="$(git -C "$REPO_ROOT" config --get-all aapp.hook.on-sync 2>/dev/null || true)"
    if [ -n "$cfg_handlers" ]; then
        while IFS= read -r hp; do
            [ -z "$hp" ] && continue
            if [[ "$hp" = /* ]]; then
                handler="$hp"
            else
                handler="$REPO_ROOT/$hp"
            fi
            if [ -x "$handler" ]; then
                echo "$handler"
                return 0
            fi
        done <<< "$cfg_handlers"
    fi

    return 1
}

# Resolve Three-Tier Strategy
RESOLVED_STRATEGY=""
if [ -n "$CLI_STRATEGY" ]; then
    RESOLVED_STRATEGY="$CLI_STRATEGY"
else
    RESOLVED_STRATEGY="$(git -C "$REPO_ROOT" config aapp.syncStrategy 2>/dev/null || true)"
    if [ -z "$RESOLVED_STRATEGY" ]; then
        if find_on_sync_handler >/dev/null 2>&1; then
            RESOLVED_STRATEGY="hook"
        else
            RESOLVED_STRATEGY="builtin"
        fi
    fi
fi

if [ "$RESOLVED_STRATEGY" != "builtin" ] && [ "$RESOLVED_STRATEGY" != "hook" ]; then
    echo "❌ Error: Invalid sync strategy '$RESOLVED_STRATEGY'. Supported: 'builtin', 'hook'." >&2
    return 1 2>/dev/null || exit 1
fi

# If hook strategy, verify executable on-sync handler exists (fail-closed refusal)
ON_SYNC_HANDLER=""
if [ "$RESOLVED_STRATEGY" = "hook" ]; then
    ON_SYNC_HANDLER="$(find_on_sync_handler 2>/dev/null || true)"
    if [ -z "$ON_SYNC_HANDLER" ]; then
        echo "❌ aapp.syncStrategy=hook but no executable handler is registered for on-sync in .agents/skills/aapp-hooks/registry.tsv or git config." >&2
        return 1 2>/dev/null || exit 1
    fi
fi

# Observer hook dispatcher helper
dispatch_observer_hook() {
    local event_name="$1"
    if [ -f "$REPO_ROOT/lib/hook_dispatcher.sh" ]; then
        # shellcheck source=/dev/null
        source "$REPO_ROOT/lib/hook_dispatcher.sh"
    fi
    if declare -f dispatch_hook >/dev/null 2>&1; then
        local obs_wts=""
        for w in "${ACTIVE_WTS[@]}"; do
            bname="$(basename "$w")"
            bname="${bname#.}"
            if [ -z "$obs_wts" ]; then obs_wts="\"$bname\""; else obs_wts="$obs_wts, \"$bname\""; fi
        done
        dispatch_hook "$event_name" "{\"action\": \"$ACTION\", \"remote\": \"$TARGET_REMOTE\", \"worktrees\": [$obs_wts]}" || true
    fi
}

# Pre-flight Cleanliness Check for pull / sync operations
if [ "$ACTION" = "pull" ] || [ "$ACTION" = "sync" ]; then
    for wt in "${ACTIVE_WTS[@]}"; do
        wt_dir="$REPO_ROOT/$wt"
        dirty="$(git -C "$wt_dir" status --porcelain 2>/dev/null || true)"
        if [ -n "$dirty" ]; then
            echo "❌ Pre-flight check failed: uncommitted changes detected in $wt ($wt_dir)." >&2
            echo "   Aborting $ACTION to preserve uncommitted work and prevent merge conflicts." >&2
            return 1 2>/dev/null || exit 1
        fi
    done
fi

# Execute transport based on resolved strategy
if [ "$RESOLVED_STRATEGY" = "hook" ]; then
    # Fire pre-sync observer hook
    dispatch_observer_hook "pre-sync"

    # Build worktrees JSON array
    WTS_JSON=""
    for wt in "${ACTIVE_WTS[@]}"; do
        base_name="$(basename "$wt")"
        base_name="${base_name#.}"
        if [ -z "$WTS_JSON" ]; then
            WTS_JSON="\"$base_name\""
        else
            WTS_JSON="$WTS_JSON, \"$base_name\""
        fi
    done

    echo "🚀 Delegating '$ACTION' transport to on-sync hook ($ON_SYNC_HANDLER)..."

    export AAPP_EVENT="on-sync"
    export AAPP_ACTION="$ACTION"
    export AAPP_REMOTE="$TARGET_REMOTE"
    export AAPP_WORKTREES="${ACTIVE_WTS[*]}"
    export AAPP_MODE="gate"

    sync_data="{\"action\": \"$ACTION\", \"remote\": \"$TARGET_REMOTE\", \"worktrees\": [$WTS_JSON]}"
    if [ -f "$REPO_ROOT/lib/hook_dispatcher.sh" ]; then
        # shellcheck source=/dev/null
        source "$REPO_ROOT/lib/hook_dispatcher.sh"
        if ! dispatch_hook "on-sync" "$sync_data"; then
            echo "❌ Hook transport failed during $ACTION." >&2
            return 1 2>/dev/null || exit 1
        fi
    else
        PAYLOAD="{\"event\": \"on-sync\", \"data\": $sync_data}"
        if ! echo "$PAYLOAD" | "$ON_SYNC_HANDLER"; then
            echo "❌ Hook transport failed during $ACTION." >&2
            return 1 2>/dev/null || exit 1
        fi
    fi

    # Fire post-sync observer hook
    dispatch_observer_hook "post-sync"

    echo "✨ All AAPP worktrees synchronized successfully via hook."
    return 0 2>/dev/null || exit 0
fi

# ------------------------------------------------------------------------------
# Built-in Native Git Transport
# ------------------------------------------------------------------------------

# Helper: Pull single worktree
pull_worktree() {
    local wt="$1"
    local wt_dir="$REPO_ROOT/$wt"
    local branch
    branch="$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$branch" ]; then
        echo "    • $wt/    --> (skip: no active branch)"
        return 0
    fi

    local pull_strategy
    pull_strategy="$(git -C "$REPO_ROOT" config aapp.pullStrategy 2>/dev/null || echo "ff-only")"

    # Execute git pull with configured strategy
    local pull_output
    if ! pull_output="$(git -C "$wt_dir" pull "$TARGET_REMOTE" "$branch" "--$pull_strategy" 2>&1)"; then
        echo "    • $wt/    --> ❌ pull failed" >&2
        echo "$pull_output" >&2
        echo "❌ Error pulling $wt from $TARGET_REMOTE/$branch. Fast-forward or network failure." >&2
        return 1
    fi

    if echo "$pull_output" | grep -q "Already up to date"; then
        echo "    • $wt/    --> up to date"
    else
        echo "    • $wt/    --> updated from $TARGET_REMOTE/$branch"
    fi
}

# Helper: Push single worktree
push_worktree() {
    local wt="$1"
    local wt_dir="$REPO_ROOT/$wt"
    local branch
    branch="$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$branch" ]; then
        echo "    • $wt/    --> (skip: no active branch)"
        return 0
    fi

    # Check if upstream tracking is set
    local upstream
    upstream="$(git -C "$wt_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

    local push_output
    if [ -z "$upstream" ]; then
        # Set upstream tracking on initial push
        if ! push_output="$(git -C "$wt_dir" push -u "$TARGET_REMOTE" "$branch" 2>&1)"; then
            echo "    • $wt/    --> ❌ push failed" >&2
            echo "$push_output" >&2
            echo "❌ Error pushing $wt to $TARGET_REMOTE/$branch." >&2
            return 1
        fi
    else
        if ! push_output="$(git -C "$wt_dir" push "$TARGET_REMOTE" "$branch" 2>&1)"; then
            echo "    • $wt/    --> ❌ push failed" >&2
            echo "$push_output" >&2
            echo "❌ Error pushing $wt to $TARGET_REMOTE/$branch." >&2
            return 1
        fi
    fi

    echo "    • $wt/    --> $TARGET_REMOTE/$branch (synced)"
}

# Dispatch pre-sync observer
dispatch_observer_hook "pre-sync"

PULL_STRAT="$(git -C "$REPO_ROOT" config aapp.pullStrategy 2>/dev/null || echo "ff-only")"

case "$ACTION" in
    pull)
        echo "🚀 Pulling AAPP worktrees from '$TARGET_REMOTE' (--$PULL_STRAT)..."
        for wt in "${ACTIVE_WTS[@]}"; do
            pull_worktree "$wt" || return 1 2>/dev/null || exit 1
        done
        echo "✨ All AAPP worktrees pulled successfully."
        ;;
    push)
        echo "🚀 Pushing AAPP worktrees to '$TARGET_REMOTE'..."
        for wt in "${ACTIVE_WTS[@]}"; do
            push_worktree "$wt" || return 1 2>/dev/null || exit 1
        done
        echo "✨ All AAPP worktrees pushed successfully."
        ;;
    sync)
        echo "🚀 Syncing AAPP worktrees with '$TARGET_REMOTE'..."
        echo "  📥 Pulling updates (--$PULL_STRAT)..."
        for wt in "${ACTIVE_WTS[@]}"; do
            pull_worktree "$wt" || return 1 2>/dev/null || exit 1
        done
        echo "  📤 Pushing worktrees..."
        for wt in "${ACTIVE_WTS[@]}"; do
            push_worktree "$wt" || return 1 2>/dev/null || exit 1
        done
        echo "✨ All AAPP worktrees synchronized successfully."
        ;;
esac

# Dispatch post-sync observer
dispatch_observer_hook "post-sync"
