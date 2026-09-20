#!/usr/bin/env bash
# ==============================================================================
# AAPP Lifecycle Hook Dispatcher & Registry Engine
#
# Governed by Plan P-12 (Lifecycle Plugin Hooks & Event Architecture).
# Enforces the Protected Registry & Hash-Lock Contract:
#   - Protected Registry: .agents/skills/aapp-hooks/registry.tsv
#   - Pure POSIX line-oriented TSV parsing (dash compatible)
#   - Portable SHA256 resolution chain (fail-closed invariant)
#   - Dual Delivery: streams JSON envelope to STDIN and exports POSIX env vars
#   - Exit code handling: 0=proceed, 1=abort (gate) / warn (notify), 2=warn
#   - Subshell timeout watchdog per handler
#   - Local overrides via git config aapp.hook.<event> (mode=notify only)
# ==============================================================================
set -e

# Discover repository root
if [ -z "${REPO_ROOT:-}" ]; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

# ------------------------------------------------------------------------------
# 1. Portable SHA256 Resolution Chain (Fail-Closed)
# ------------------------------------------------------------------------------
resolve_sha256_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then
        echo "sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        echo "shasum -a 256"
    elif command -v sha256 >/dev/null 2>&1; then
        echo "sha256 -q"
    elif command -v openssl >/dev/null 2>&1; then
        echo "openssl dgst -sha256"
    else
        echo "❌ [Security Abort] No SHA256 utility found (sha256sum, shasum, sha256, openssl)." >&2
        echo "   Fail-closed invariant: Hash verification cannot be skipped." >&2
        return 1
    fi
}

compute_file_sha256() {
    local target_file="$1"
    local sha_tool
    sha_tool="$(resolve_sha256_cmd)" || return 1

    if [ ! -f "$target_file" ]; then
        return 1
    fi

    local raw_out
    raw_out="$($sha_tool "$target_file" 2>/dev/null || true)"

    # Extract hex string (first 64-char hex occurrence)
    local hex
    hex="$(echo "$raw_out" | grep -oE '[0-9a-fA-F]{64}' | head -n 1 || true)"
    if [ -z "$hex" ]; then
        return 1
    fi
    echo "$hex" | tr '[:upper:]' '[:lower:]'
}

# ------------------------------------------------------------------------------
# 2. Portable Timeout Watchdog
# ------------------------------------------------------------------------------
execute_with_watchdog() {
    local max_time="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "$max_time" "$@"
        return $?
    fi

    # POSIX background watchdog fallback
    "$@" &
    local cmd_pid=$!
    (
        sleep "$max_time"
        kill -TERM "$cmd_pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$cmd_pid" 2>/dev/null || true
    ) >/dev/null 2>&1 &
    local watch_pid=$!

    wait "$cmd_pid" 2>/dev/null
    local rc=$?
    kill -KILL "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" 2>/dev/null || true
    return $rc
}

# ------------------------------------------------------------------------------
# 3. JSON Envelope Builder
# ------------------------------------------------------------------------------
build_event_envelope() {
    local event="$1"
    local data_json="${2:-{}}"
    local actor="${AAPP_ACTOR:-developer}"
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"
    local branch
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

    cat <<EOF
{
  "version": "1.0",
  "event": "$event",
  "timestamp": "$timestamp",
  "actor": "$actor",
  "repository": {
    "root": "$REPO_ROOT",
    "branch": "$branch"
  },
  "data": $data_json
}
EOF
}

# ------------------------------------------------------------------------------
# 4. Handler Dispatch & Execution
# ------------------------------------------------------------------------------
dispatch_single_handler() {
    local event="$1"
    local handler_rel="$2"
    local expected_hash="$3"
    local timeout="$4"
    local mode="$5"
    local source_type="$6" # registry | local_config
    local payload="$7"

    # Resolve handler absolute path
    local handler_path
    if [[ "$handler_rel" = /* ]]; then
        handler_path="$handler_rel"
    else
        handler_path="$REPO_ROOT/$handler_rel"
    fi

    # Existence and executable assertion
    if [ ! -f "$handler_path" ] || [ ! -x "$handler_path" ]; then
        if [ "$mode" = "gate" ]; then
            echo "❌ [Hook Refusal] Handler '$handler_rel' for event '$event' does not exist or is not executable." >&2
            return 1
        else
            echo "⚠️  [Hook Warning] Handler '$handler_rel' for event '$event' is missing or not executable (skipping)." >&2
            return 0
        fi
    fi

    # SHA256 integrity verification (for registry entries)
    if [ "$source_type" = "registry" ] && [ -n "$expected_hash" ]; then
        local clean_expected="${expected_hash#sha256:}"
        local actual_hash
        actual_hash="$(compute_file_sha256 "$handler_path")"
        if [ -z "$actual_hash" ]; then
            echo "❌ [Hook Integrity Violation] Failed to compute SHA256 for handler '$handler_rel'." >&2
            return 1
        fi

        if [ "$clean_expected" != "$actual_hash" ]; then
            echo "❌ [Hook Integrity Violation] SHA256 mismatch for handler '$handler_rel' (event: $event)!" >&2
            echo "   Expected : sha256:$clean_expected" >&2
            echo "   Computed : sha256:$actual_hash" >&2
            echo "   Tamper-evident gate: Handler script cannot be altered without updating registry.tsv." >&2
            return 1
        fi
    fi

    # Dual Delivery: Export POSIX environment variables
    export AAPP_EVENT="$event"
    export AAPP_PLAN_ID="${AAPP_PLAN_ID:-}"
    export AAPP_PLAN_FILE="${AAPP_PLAN_FILE:-}"
    export AAPP_ACTION="${AAPP_ACTION:-}"
    export AAPP_REMOTE="${AAPP_REMOTE:-}"
    export AAPP_MODE="$mode"
    export AAPP_TIMEOUT="$timeout"
    export AAPP_ACTOR="${AAPP_ACTOR:-developer}"

    # Execute handler streaming JSON envelope via STDIN
    local stderr_file
    stderr_file="$(mktemp)"
    local rc=0

    set +e
    echo "$payload" | execute_with_watchdog "$timeout" "$handler_path" 2>"$stderr_file"
    rc=$?
    set -e

    local err_output
    err_output="$(cat "$stderr_file" 2>/dev/null || true)"
    rm -f "$stderr_file"

    # Evaluate POSIX exit codes
    if [ "$rc" -eq 0 ]; then
        [ -n "$err_output" ] && echo "$err_output" >&2
        return 0
    elif [ "$rc" -eq 2 ]; then
        # Warning & Continue (non-blocking across all modes)
        echo "⚠️  [Hook Notice] Handler '$handler_rel' emitted advisory warning (exit 2):" >&2
        [ -n "$err_output" ] && echo "$err_output" >&2
        return 0
    elif [ "$rc" -eq 124 ]; then
        # Watchdog timeout
        if [ "$mode" = "gate" ]; then
            echo "❌ [Hook Timeout Gate] Handler '$handler_rel' exceeded timeout (${timeout}s) during '$event'." >&2
            [ -n "$err_output" ] && echo "$err_output" >&2
            return 1
        else
            echo "⚠️  [Hook Timeout Warning] Handler '$handler_rel' exceeded timeout (${timeout}s) during '$event' (notify mode)." >&2
            [ -n "$err_output" ] && echo "$err_output" >&2
            return 0
        fi
    else
        # Any other exit code (1, 127, 137, etc.) is treated as failure
        if [ "$mode" = "gate" ]; then
            echo "❌ [Hook Gate Refusal] Handler '$handler_rel' rejected event '$event' (exit $rc):" >&2
            [ -n "$err_output" ] && echo "$err_output" >&2
            return 1
        else
            echo "⚠️  [Hook Warning] Handler '$handler_rel' failed for event '$event' (exit $rc, notify mode):" >&2
            [ -n "$err_output" ] && echo "$err_output" >&2
            return 0
        fi
    fi
}

# ------------------------------------------------------------------------------
# 5. Master Hook Dispatcher Function
# ------------------------------------------------------------------------------
dispatch_hook() {
    local event="$1"
    local data_json="${2:-{}}"

    local reg_file="$REPO_ROOT/.agents/skills/aapp-hooks/registry.tsv"
    local payload
    payload="$(build_event_envelope "$event" "$data_json")"

    local handlers_dispatched=0
    local TAB
    TAB="$(printf '\t')"

    # 1. Dispatch Committed Registry Handlers (gate or notify)
    if [ -f "$reg_file" ]; then
        while IFS="$TAB" read -r ev hp expected_hash to md extra || [ -n "$ev" ]; do
            # Skip empty lines and comments
            [ -z "$ev" ] && continue
            [ "${ev#\#}" != "$ev" ] && continue

            # Validate column count (no unexpected 6th field)
            if [ -n "$extra" ]; then
                echo "❌ Malformed registry line in $reg_file: unexpected 6th field" >&2
                return 1
            fi

            if [ "$ev" = "$event" ]; then
                to="${to:-10}"
                md="${md:-gate}"
                handlers_dispatched=$((handlers_dispatched + 1))
                dispatch_single_handler "$event" "$hp" "$expected_hash" "$to" "$md" "registry" "$payload" || return 1
            fi
        done < "$reg_file"
    fi

    # 2. Dispatch Local Overrides (git config aapp.hook.<event>, notify mode only)
    local allow_local
    allow_local="$(git -C "$REPO_ROOT" config aapp.allowLocalHooks 2>/dev/null || echo "true")"
    if [ "$allow_local" != "false" ]; then
        local local_handlers
        local_handlers="$(git -C "$REPO_ROOT" config --get-all "aapp.hook.$event" 2>/dev/null || true)"
        if [ -n "$local_handlers" ]; then
            local global_timeout
            global_timeout="$(git -C "$REPO_ROOT" config aapp.hookTimeout 2>/dev/null || echo "10")"
            while IFS= read -r hp; do
                [ -z "$hp" ] && continue
                handlers_dispatched=$((handlers_dispatched + 1))
                dispatch_single_handler "$event" "$hp" "" "$global_timeout" "notify" "local_config" "$payload" || true
            done <<< "$local_handlers"
        fi
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Action Plugin Entrypoint Resolution
# ------------------------------------------------------------------------------
# Locates a plugin's executable entrypoint under .agents/skills/<name>/.
# Extension-agnostic by design: a provider may be a shell script, a Python file
# or a compiled binary. Lives here rather than in lib/cmd_hook.sh because that
# file carries a top-level dispatcher and cannot be sourced without side effects.
resolve_plugin_entrypoint() {
    local pdir="$1"
    local name="$2"

    # 1. Canonical Extensionless
    if [ -x "$pdir/run" ]; then
        echo "$pdir/run"; return 0
    elif [ -x "$pdir/$name" ]; then
        echo "$pdir/$name"; return 0
    fi

    # 2. Subdirectory Extensionless
    if [ -x "$pdir/scripts/run" ]; then
        echo "$pdir/scripts/run"; return 0
    elif [ -x "$pdir/scripts/$name" ]; then
        echo "$pdir/scripts/$name"; return 0
    fi

    # 3. Extension-Agnostic Pattern Search (Any Extension)
    for f in "$pdir/$name".*; do
        if [ -x "$f" ]; then echo "$f"; return 0; fi
    done
    for f in "$pdir/run".*; do
        if [ -x "$f" ]; then echo "$f"; return 0; fi
    done
    for f in "$pdir/scripts/$name".*; do
        if [ -x "$f" ]; then echo "$f"; return 0; fi
    done
    for f in "$pdir/scripts/run".*; do
        if [ -x "$f" ]; then echo "$f"; return 0; fi
    done

    return 1
}

