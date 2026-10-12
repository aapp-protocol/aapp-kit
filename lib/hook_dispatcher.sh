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

# Discover repository root fail-closed (P-33). Normally exported by the `aapp`
# dispatcher; derived here when sourced standalone from a git hook.
if [ -z "${REPO_ROOT:-}" ]; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ [Hook Dispatcher] Not inside a Git repository." >&2
        return 1 2>/dev/null || exit 1
    }
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
# 3. JSON Envelope Builder (shared by lifecycle hooks and action plugins, P-32)
# ------------------------------------------------------------------------------
# json_escape <text> -> the text as a JSON string body (no surrounding quotes).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# json_field <json> <key> -> value of a flat string or number key; fails when absent.
# Plugin responses are one flat object ({"id": ...}, {"status": ...}, {"error": ...});
# nested objects such as "extra" are never read.
json_field() {
    local json="$1" key="$2" val
    val="$(printf '%s' "$json" | tr -d '\n' | sed -nE "s/.*\"$key\"[[:space:]]*:[[:space:]]*(\"([^\"\\\\]|\\\\.)*\"|-?[0-9]+).*/\\1/p")"
    [ -n "$val" ] || return 1
    val="${val#\"}"; val="${val%\"}"
    printf '%s\n' "$val"
}

# Remote identity for the envelope: a team plugin needs the project, not a local
# path. Credentials in the URL (user:secret@, or any userinfo on http/https,
# where it is a token) are stripped. Prints `null` when no remote exists.
_envelope_remote_json() {
    local name url
    name="$(git -C "$REPO_ROOT" config --get aapp.remote 2>/dev/null)" || name="origin"
    url="$(git -C "$REPO_ROOT" remote get-url "$name" 2>/dev/null)" || { printf 'null'; return 0; }
    case "$url" in
        http://*@*|https://*@*) url="$(printf '%s' "$url" | sed -E 's#^(https?://)[^/@]*@#\1#')" ;;
        *://*:*@*)              url="$(printf '%s' "$url" | sed -E 's#^([a-z+]+://[^/:@]*):[^/@]*@#\1@#')" ;;
    esac
    printf '{ "name": "%s", "url": "%s" }' "$(json_escape "$name")" "$(json_escape "$url")"
}

# run_action_plugin <entrypoint> <repo-root> <action> <event> [data-json]
# Plugin Payload Standard (Dual Delivery, P-32): the envelope on stdin, AAPP_ACTION
# and AAPP_REPO_ROOT in the environment (callers add action-specific variables).
# Prints the plugin's stdout; returns the plugin's exit code.
#
# Every plugin call runs under the watchdog, for at most aapp.pluginTimeout
# seconds (P-77), and with AAPP_PLUGIN_STEP set: the `aapp` dispatcher refuses a
# writing verb run from inside a step.
run_action_plugin() {
    local entry="$1" root="$2" action="$3" event="$4" data="${5:-}"
    REPO_ROOT="$root" build_event_envelope "$event" "$data" | \
        AAPP_ACTION="$action" AAPP_REPO_ROOT="$root" AAPP_PLUGIN_STEP="$event" \
        execute_with_watchdog "$(_plugin_timeout "$root")" "$entry"
}

# _plugin_timeout <repo-root> -> seconds a plugin call may take.
_plugin_timeout() {
    local t
    t="$(git -C "$1" config --get aapp.pluginTimeout 2>/dev/null)" || t=10
    case "$t" in ''|*[!0-9]*) t=10 ;; esac
    printf '%s\n' "$t"
}

# ------------------------------------------------------------------------------
# 3b. The plugin answer protocol (P-77; reference: docs/reference/06-plugin-protocol.md)
# ------------------------------------------------------------------------------
# A step is a short exchange: the kit sends the envelope; the plugin answers one
# flat JSON object (status, message, handled, what it produced) and may fill two
# files the kit names: AAPP_PLUGIN_LIST (one flat object per line) and
# AAPP_PLUGIN_DO (aapp commands, one per line, run after the step).
PLUGIN_PROTOCOL_VERSION="1.0"
PLUGIN_STATUS=""; PLUGIN_MESSAGE=""; PLUGIN_HANDLED=""; PLUGIN_OUT=""
PLUGIN_LIST_FILE=""; PLUGIN_DO_FILE=""

_plugin_files_drop() {
    [ -n "$PLUGIN_LIST_FILE" ] && rm -f "$PLUGIN_LIST_FILE"
    [ -n "$PLUGIN_DO_FILE" ] && rm -f "$PLUGIN_DO_FILE"
    PLUGIN_LIST_FILE=""; PLUGIN_DO_FILE=""
    return 0
}

# plugin_step <entrypoint> <repo-root> <action> <event> [data-json]
# Runs one step and reads the answer into PLUGIN_STATUS (ok | declined | failed),
# PLUGIN_MESSAGE (also printed), PLUGIN_HANDLED and PLUGIN_OUT (the raw answer).
# Returns 0 for ok and declined; non-zero when the plugin failed, timed out, said
# `failed`, or answered from a protocol version newer than this kit's.
plugin_step() {
    local rc=0 ver
    PLUGIN_STATUS=""; PLUGIN_MESSAGE=""; PLUGIN_HANDLED=""; PLUGIN_OUT=""
    _plugin_files_drop
    PLUGIN_LIST_FILE="$(mktemp)" || return 1
    PLUGIN_DO_FILE="$(mktemp)" || return 1
    PLUGIN_OUT="$(AAPP_PLUGIN_LIST="$PLUGIN_LIST_FILE" AAPP_PLUGIN_DO="$PLUGIN_DO_FILE" run_action_plugin "$@")" || rc=$?
    if [ "$rc" -ne 0 ]; then
        PLUGIN_STATUS="failed"
        PLUGIN_MESSAGE="$(json_field "$PLUGIN_OUT" error 2>/dev/null)" || PLUGIN_MESSAGE=""
        [ "$rc" -eq 124 ] && PLUGIN_MESSAGE="no answer within $(_plugin_timeout "$2")s"
        _plugin_files_drop
        return "$rc"
    fi
    ver="$(json_field "$PLUGIN_OUT" version 2>/dev/null)" || ver=""
    if [ -n "$ver" ] && ! awk -v a="$ver" -v b="$PLUGIN_PROTOCOL_VERSION" 'BEGIN { split(a, x, "."); split(b, y, "."); exit !((x[1] + 0 < y[1] + 0) || (x[1] + 0 == y[1] + 0 && x[2] + 0 <= y[2] + 0)) }'; then
        PLUGIN_STATUS="failed"
        PLUGIN_MESSAGE="answer is protocol version $ver; this kit speaks $PLUGIN_PROTOCOL_VERSION"
        echo "❌ [Plugin] The plugin's $PLUGIN_MESSAGE." >&2
        _plugin_files_drop
        return 1
    fi
    PLUGIN_STATUS="$(json_field "$PLUGIN_OUT" status 2>/dev/null)" || PLUGIN_STATUS="ok"
    PLUGIN_MESSAGE="$(json_field "$PLUGIN_OUT" message 2>/dev/null)" || PLUGIN_MESSAGE=""
    [ -n "$PLUGIN_MESSAGE" ] && echo "💬 [Plugin] $PLUGIN_MESSAGE"
    case "$PLUGIN_STATUS" in
        declined) _plugin_files_drop; return 0 ;;
        failed)   _plugin_files_drop; return 1 ;;
        *)        PLUGIN_STATUS="ok" ;;
    esac
    PLUGIN_HANDLED="$(json_field "$PLUGIN_OUT" handled 2>/dev/null)" || PLUGIN_HANDLED=""
    return 0
}

# plugin_handled <part>: true when the last step's plugin took care of <part>.
# Whatever it did not name is the kit's to do.
plugin_handled() {
    [ "$PLUGIN_STATUS" = "ok" ] || return 1
    case ",$(printf '%s' "$PLUGIN_HANDLED" | tr -d '[:space:]')," in
        *",$1,"*) return 0 ;;
    esac
    return 1
}

# plugin_list_lines -> the flat objects of the last step's list file, one per line.
plugin_list_lines() {
    [ -n "$PLUGIN_LIST_FILE" ] && [ -f "$PLUGIN_LIST_FILE" ] || return 0
    grep -v '^[[:space:]]*$' "$PLUGIN_LIST_FILE" || true
}

# plugin_run_do <subject> <plugin-name>: runs the last step's `do` list, after
# the step has finished and released its lock. Each line is an aapp command as a
# person types it; only the commands listed for <subject> in lib/plugin_do.tsv
# are accepted. They run in order, through the CLI, each taking the lock it
# needs; a refused line is reported and the rest still run. <plugin-name> is not
# called again by them.
plugin_run_do() {
    local subject="$1" name="$2" lines line cmd allowed rc
    local -a args
    [ -n "$PLUGIN_DO_FILE" ] && [ -s "$PLUGIN_DO_FILE" ] || { _plugin_files_drop; return 0; }
    lines="$(cat "$PLUGIN_DO_FILE")"
    _plugin_files_drop
    while IFS= read -r line; do
        [ -n "${line//[[:space:]]/}" ] || continue
        allowed=0
        while IFS="$(printf '\t')" read -r s cmd; do
            [ "$s" = "$subject" ] || continue
            case "$line" in "$cmd"|"$cmd "*) allowed=1 ;; esac
        done < "${AAPP_LIB:-$(dirname "${BASH_SOURCE[0]}")}/plugin_do.tsv"
        if [ "$allowed" -ne 1 ]; then
            echo "⛔ [Plugin] do: '$line' is not an accepted $subject command; skipped." >&2
            continue
        fi
        # Words are split as a shell would quote them, without any expansion.
        args=()
        while IFS= read -r cmd; do args+=("$cmd"); done < <(printf '%s\n' "$line" | xargs printf '%s\n' 2>/dev/null)
        if [ ${#args[@]} -eq 0 ]; then
            echo "⛔ [Plugin] do: '$line' cannot be read as a command; skipped." >&2
            continue
        fi
        echo "▶️  [Plugin] do: $line"
        rc=0
        AAPP_PLUGIN_MUTED="$name" "${AAPP_SCRIPT_DIR:?}/aapp" "${args[@]}" || rc=$?
        [ "$rc" -eq 0 ] || echo "⚠️  [Plugin] do: '$line' was refused (exit $rc)." >&2
    done <<< "$lines"
    return 0
}

build_event_envelope() {
    local event="$1"
    local data_json="${2:-}"
    [ -n "$data_json" ] || data_json='{}'
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
    "root": "$(json_escape "$REPO_ROOT")",
    "branch": "$branch",
    "remote": $(_envelope_remote_json)
  },
  "data": $data_json,
  "extra": {}
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
    local data_json="${2:-}"
    [ -n "$data_json" ] || data_json='{}'

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
                if [ -z "$md" ]; then
                    case "$ev" in
                        post-*) md="notify" ;;
                        *)      md="gate" ;;
                    esac
                fi
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

    # A command run from a plugin's `do` list does not call that plugin again
    # (P-77): to it the plugin is absent, so the kit does everything.
    if [ -n "${AAPP_PLUGIN_MUTED:-}" ] && [ "$AAPP_PLUGIN_MUTED" = "$name" ]; then
        return 1
    fi

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

    # 3. Extension-Agnostic Pattern Search (skipping .sample and backup files)
    for f in "$pdir/$name".* "$pdir/run".* "$pdir/scripts/$name".* "$pdir/scripts/run".*; do
        case "$f" in
            *.sample|*.sample.*|*.bak|*~) continue ;;
        esac
        if [ -x "$f" ]; then echo "$f"; return 0; fi
    done

    return 1
}

