#!/usr/bin/env bash
# lib/commit_engine.sh - Single Authoritative Commit Engine for .plans worktree (P-39)
# Sourced; functions only. Provides path-limited, attributed, retried, loud commits.

# Sourced dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$_LIB_DIR/attribution.sh" ] && . "$_LIB_DIR/attribution.sh"

# plans_commit <subject> <path>...
# Parameters or flags for attribution:
# Optionally accepts attribution identity variables if set in caller, or reads environment.
plans_commit() {
    local subject="$1"
    shift
    if [ $# -eq 0 ]; then
        echo "❌ [Commit Engine Error] plans_commit requires at least one target path." >&2
        return 1
    fi

    local plans_dir=""
    if [ -n "${PLANS_DIR:-}" ] && [ -d "$PLANS_DIR" ]; then
        plans_dir="$PLANS_DIR"
    else
        local git_common primary_root repo_root
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
        git_common="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
        if [ -d "$git_common" ]; then
            primary_root="$(cd "$git_common/.." 2>/dev/null && pwd)"
        else
            primary_root="$repo_root"
        fi

        if [ -d "$repo_root/.plans" ]; then
            plans_dir="$repo_root/.plans"
        elif [ -n "$primary_root" ] && [ -d "$primary_root/.plans" ]; then
            plans_dir="$primary_root/.plans"
        elif [ -d ".plans" ]; then
            plans_dir=".plans"
        elif [ -d "../.plans" ]; then
            plans_dir="../.plans"
        fi
    fi

    if [ ! -d "$plans_dir" ]; then
        echo "❌ [Commit Engine Error] .plans directory not found at '$plans_dir'." >&2
        return 1
    fi

    # 1. Pathspec-limited stage
    git -C "$plans_dir" add -- "$@" || {
        echo "❌ [Commit Engine Error] Failed to stage paths in $plans_dir: $*" >&2
        return 1
    }

    # 2. Attribution
    local identity=""
    if declare -f resolve_ai_identity >/dev/null; then
        identity="$(resolve_ai_identity "${AAPP_AGENT_NAME:-}" "${AAPP_AGENT_VENDOR:-}" "${AAPP_AGENT_MODEL:-}")"
    fi

    local tmp_msg
    tmp_msg="$(mktemp)"
    printf "%s\n" "$subject" > "$tmp_msg"

    if declare -f attribution_decorate >/dev/null; then
        attribution_decorate "$tmp_msg" "$identity" || {
            local dec_rc=$?
            rm -f "$tmp_msg"
            echo "❌ [Commit Engine Error] Attribution decoration failed (strict mode requires valid AI identity)." >&2
            return $dec_rc
        }
    fi

    # 3. Lock-retry commit loop
    local max_attempts=5
    local attempt=1
    local commit_output=""
    local commit_rc=0

    while [ "$attempt" -le "$max_attempts" ]; do
        commit_output="$(git -C "$plans_dir" commit -F "$tmp_msg" -- "$@" 2>&1)"
        commit_rc=$?
        if [ "$commit_rc" -eq 0 ]; then
            rm -f "$tmp_msg"
            return 0
        fi

        # Check if index.lock is the cause of failure
        if echo "$commit_output" | grep -qiE '(index\.lock|Unable to create.*lock)'; then
            if [ "$attempt" -lt "$max_attempts" ]; then
                echo "⏳ [.plans Index Locked] Attempt $attempt/$max_attempts: waiting for index.lock release..." >&2
                sleep 0.5
                attempt=$((attempt + 1))
                continue
            else
                echo "❌ [.plans Lock Contention] Exhausted $max_attempts attempts waiting for .plans/index.lock." >&2
                echo "$commit_output" >&2
                return "$commit_rc"
            fi
        fi

        # Other commit failure (hook failure, etc.) - fail immediately and loudly
        echo "$commit_output" >&2
        return "$commit_rc"
    done

    return "$commit_rc"
}
