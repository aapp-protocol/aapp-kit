#!/usr/bin/env bash
# ==============================================================================
# Asymmetric Agent Planning Protocol (AAPP) - Plan Shorthand Resolver Engine
#
# Resolves shorthand queries (Plan IDs, slugs, filenames) to canonical paths
# under .plans/.
#
# Supported Query Formats:
#   1. Exact Filepath:  .plans/current/P9-guard-path-authorization.md
#   2. Plan ID:         P-9, p-9, P9, p9, 9 (bare number in command position)
#   3. Slug Substring:  guard-path, remote-sync, flat-issues
#   4. Rejection:       #9 (fails with guidance: "#9 is an issue, did you mean P-9?")
#   5. Empty query:     Allowed for read-only verbs if 1 plan; rejected for freeze/done
# ==============================================================================

# Source the hook dispatcher for resolve_plugin_entrypoint(), used by
# allocate_plan_id() to discover an optional `aapp-planid` provider plugin.
# hook_dispatcher.sh is safe to source (no top-level dispatcher); lib/cmd_hook.sh
# is not, which is why the helper lives in the dispatcher.
DISPATCHER_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_dispatcher.sh"
if [ -f "$DISPATCHER_LIB" ]; then
    # hook_dispatcher.sh sets -e at top level. Sourcing it would silently impose
    # that on every caller of this resolver, so the prior state is restored.
    # `aapp` and lib/cmd_plan.sh already set -e; nothing else should inherit it.
    __AAPP_PR_ERREXIT=0
    case "$-" in *e*) __AAPP_PR_ERREXIT=1 ;; esac
    # shellcheck source=/dev/null
    source "$DISPATCHER_LIB"
    [ "$__AAPP_PR_ERREXIT" -eq 1 ] || set +e
    unset __AAPP_PR_ERREXIT
fi

# resolve_plan_path <query> <context_verb> [search_scope: current|done|all] [repo_root]
resolve_plan_path() {
    local QUERY="$1"
    local VERB="${2:-inspect}"
    local SCOPE="${3:-current}"
    local REPO_ROOT="${4:-}"

    if [ -z "$REPO_ROOT" ]; then
        REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi

    local PLANS_DIR="$REPO_ROOT/.plans"
    if [ ! -d "$PLANS_DIR" ]; then
        echo "❌ [Plan Resolver] .plans/ directory not found in '$REPO_ROOT'." >&2
        return 1
    fi

    # Determine search directories based on scope
    local SEARCH_DIRS=()
    case "$SCOPE" in
        current)
            [ -d "$PLANS_DIR/current" ] && SEARCH_DIRS+=("$PLANS_DIR/current")
            ;;
        done)
            [ -d "$PLANS_DIR/done" ] && SEARCH_DIRS+=("$PLANS_DIR/done")
            ;;
        all)
            [ -d "$PLANS_DIR/current" ] && SEARCH_DIRS+=("$PLANS_DIR/current")
            [ -d "$PLANS_DIR/done" ] && SEARCH_DIRS+=("$PLANS_DIR/done")
            ;;
        *)
            echo "❌ [Plan Resolver] Invalid search scope: '$SCOPE' (must be current, done, or all)." >&2
            return 1
            ;;
    esac

    # Helper to list available blueprints in search scope
    list_available_plans() {
        for DIR in "${SEARCH_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" -exec basename {} \; 2>/dev/null | sort
            fi
        done
    }

    # 1. Direct File Check
    if [ -n "$QUERY" ] && [ -f "$QUERY" ]; then
        # Return path relative to repo root if possible
        if [[ "$QUERY" == "$REPO_ROOT/"* ]]; then
            echo "${QUERY#$REPO_ROOT/}"
        else
            echo "$QUERY"
        fi
        return 0
    fi

    for DIR in "${SEARCH_DIRS[@]}"; do
        if [ -n "$QUERY" ] && [ -f "$DIR/$QUERY" ]; then
            local REL_PATH="${DIR#$REPO_ROOT/}/$QUERY"
            echo "$REL_PATH"
            return 0
        fi
    done

    # 2. Empty-Query Guard
    if [ -z "$QUERY" ]; then
        case "$VERB" in
            freeze|done)
                echo "❌ [Plan Resolver] You must explicitly specify a target plan for '$VERB'." >&2
                local AVAIL
                AVAIL="$(list_available_plans)"
                if [ -n "$AVAIL" ]; then
                    echo "   Active blueprints in scope:" >&2
                    echo "$AVAIL" | sed 's/^/     • /' >&2
                else
                    echo "   (No active blueprints found in $SCOPE/)" >&2
                fi
                return 1
                ;;
            *)
                # Read-only verbs: auto-resolve if exactly one blueprint exists
                local PLAN_FILES=()
                for DIR in "${SEARCH_DIRS[@]}"; do
                    if [ -d "$DIR" ]; then
                        while IFS= read -r -d '' F; do
                            [ -n "$F" ] && PLAN_FILES+=("$F")
                        done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" -print0 2>/dev/null)
                    fi
                done

                if [ ${#PLAN_FILES[@]} -eq 1 ]; then
                    local TARGET="${PLAN_FILES[0]}"
                    echo "${TARGET#$REPO_ROOT/}"
                    return 0
                elif [ ${#PLAN_FILES[@]} -eq 0 ]; then
                    echo "❌ [Plan Resolver] No blueprints found in $SCOPE/." >&2
                    return 1
                else
                    echo "❌ [Plan Resolver] Multiple blueprints found in $SCOPE/. Please specify a plan:" >&2
                    list_available_plans | sed 's/^/     • /' >&2
                    return 1
                fi
                ;;
        esac
    fi

    # 3. Issue Namespace Collision Guard (#-prefixed reference)
    if [[ "$QUERY" =~ ^#[0-9]+$ ]]; then
        local SUGGEST_ID="P-${QUERY#\#}"
        echo "❌ [Plan Resolver] '$QUERY' is an Issue reference, not a plan." >&2
        echo "   Did you mean '$SUGGEST_ID'?" >&2
        return 1
    fi

    # 4. Numeric Plan ID Matching (e.g. P-9, p-9, P9, p9, 9)
    local NUM_ID=""
    if [[ "$QUERY" =~ ^[pP]-?([0-9]+)$ ]]; then
        NUM_ID="${BASH_REMATCH[1]}"
    elif [[ "$QUERY" =~ ^[0-9]+$ ]]; then
        NUM_ID="$QUERY"
    fi

    local MATCHES=()

    if [ -n "$NUM_ID" ]; then
        # Strip leading zeros for exact numeric comparison
        local INT_ID
        INT_ID=$((10#$NUM_ID))

        for DIR in "${SEARCH_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                while IFS= read -r -d '' F; do
                    local BNAME
                    BNAME="$(basename "$F")"
                    # Match filename prefix: P<NUM>- or P0*<NUM>-
                    if [[ "$BNAME" =~ ^[pP]0*${INT_ID}- ]]; then
                        MATCHES+=("$F")
                        continue
                    fi
                    # Match header metadata: Plan ID: P-<NUM> or P-0*<NUM>
                    local id_regex="^[[:space:]]*[\*|-][[:space:]]*\*\*Plan ID:\*\*[[:space:]]*[\`]?P-0*${INT_ID}[\`]?"
                    if grep -q -E "$id_regex" "$F" 2>/dev/null; then
                        MATCHES+=("$F")
                        continue
                    fi
                done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" -print0 2>/dev/null)
            fi
        done
    fi

    # 5. Slug / Keyword Substring Matcher (if no numeric ID match found)
    if [ ${#MATCHES[@]} -eq 0 ]; then
        local LOWER_QUERY
        LOWER_QUERY="$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')"

        for DIR in "${SEARCH_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                while IFS= read -r -d '' F; do
                    local BNAME
                    BNAME="$(basename "$F" | tr '[:upper:]' '[:lower:]')"
                    if [[ "$BNAME" == *"$LOWER_QUERY"* ]]; then
                        MATCHES+=("$F")
                    fi
                done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" -print0 2>/dev/null)
            fi
        done
    fi

    # 6. Evaluation & Diagnostics
    if [ ${#MATCHES[@]} -eq 0 ]; then
        echo "❌ [Plan Resolver] Plan '$QUERY' not found." >&2
        local AVAIL
        AVAIL="$(list_available_plans)"
        if [ -n "$AVAIL" ]; then
            echo "   Available blueprints in scope ($SCOPE):" >&2
            echo "$AVAIL" | sed 's/^/     • /' >&2
        fi
        return 1
    elif [ ${#MATCHES[@]} -gt 1 ]; then
        echo "⚠️  [Plan Resolver] Ambiguous plan reference '$QUERY'. Multiple candidates matched:" >&2
        for M in "${MATCHES[@]}"; do
            echo "     • ${M#$REPO_ROOT/}" >&2
        done
        return 1
    else
        local MATCH="${MATCHES[0]}"
        echo "${MATCH#$REPO_ROOT/}"
        return 0
    fi
}

# Extracts Plan ID from plan file: returns "P-<num>" or ""
get_plan_id() {
    local PLAN_FILE="$1"
    if [ ! -f "$PLAN_FILE" ]; then
        return 1
    fi

    # Check header: * **Plan ID:** P-XX
    local HEADER_ID
    HEADER_ID="$(grep -m 1 -E '^[[:space:]]*[\*|-][[:space:]]*\*\*Plan ID:\*\*' "$PLAN_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Plan ID:\*\*[[:space:]]*//; s/[[:space:]]*$//' | tr -d '`')"
    if [ -n "$HEADER_ID" ]; then
        echo "$HEADER_ID"
        return 0
    fi

    # Fallback to filename prefix P<num>-
    local BNAME
    BNAME="$(basename "$PLAN_FILE")"
    if [[ "$BNAME" =~ ^[pP]([0-9]+)- ]]; then
        echo "P-${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Plan ID Allocation (config-backed)
# ------------------------------------------------------------------------------
# `aapp.planId` stores the NEXT id to hand out, as a bare integer. The "P-"
# prefix is a namespace marker applied on output to distinguish a plan id from
# an issue id (#69) -- it is never part of the stored value.
#
# An unset key legitimately means 1 (a project that never ran `aapp init`).
# A non-empty, non-numeric value means something external corrupted the key:
# we refuse rather than silently restarting the sequence at P-1, which would
# collide with every existing plan. `aapp init` repairs it (it has a filesystem
# scan to repair from); allocation refuses and names the repair.

# Read-only peek at the next Plan ID. Never mutates. Safe for status output.
get_next_plan_id() {
    local CUR
    CUR="$(git config --get aapp.planId 2>/dev/null || true)"
    case "$CUR" in
        '')       CUR=1 ;;
        *[!0-9]*) echo "❌ [Plan ID] aapp.planId is not an integer: '$CUR'. Run 'aapp init' to reseed." >&2
                  return 1 ;;
    esac
    printf 'P-%s\n' "$CUR"
}

# Normalises a provider-supplied id. Accepts "P-42" or bare "42"; anything that
# is not a plain integer is an error. Emitting a well-formed id is the third
# party's responsibility -- we do not repair or interpret their output.
normalize_plan_id() {
    local N="${1#P-}"
    case "$N" in
        ''|*[!0-9]*)
            echo "❌ [Plan ID] Provider must return an integer id (got: '$1')" >&2
            return 1
            ;;
    esac
    printf 'P-%s\n' "$N"
}

# Claims a Plan ID and persists the increment. Called exactly once per plan
# creation. Delegates to an `aapp-planid` provider plugin when one is installed;
# otherwise uses the local counter. Only plugin ABSENCE falls back -- a plugin
# that is present and fails is fatal, never a silent local allocation.
allocate_plan_id() {
    local ROOT PDIR ENTRY RAW OUT CUR ISSUED
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    PDIR="$ROOT/.agents/skills/aapp-planid"

    # 1. Delegate to the provider plugin when one is installed.
    if [ -d "$PDIR" ] && ENTRY="$(resolve_plugin_entrypoint "$PDIR" "aapp-planid" 2>/dev/null)"; then
        OUT="$(AAPP_ACTION=allocate AAPP_REPO_ROOT="$ROOT" "$ENTRY" 2>/dev/null)" || {
            echo "❌ [Plan ID] Provider plugin failed; refusing to allocate locally." >&2
            return 1
        }
        # Capture into RAW first: assigning the substitution straight back into
        # OUT would clobber it before the || branch could report the value.
        RAW="$OUT"
        OUT="$(normalize_plan_id "$RAW")" || return 1
        # Ratchet the local counter past the issued id so the fallback never regresses.
        CUR="$(git config --get aapp.planId 2>/dev/null || true)"
        case "$CUR" in ''|*[!0-9]*) CUR=0 ;; esac   # unusable -> 0, so the write below repairs it
        ISSUED="${OUT#P-}"
        if [ "$ISSUED" -ge "$CUR" ]; then git config aapp.planId "$((ISSUED + 1))"; fi
        printf '%s\n' "$OUT"
        return 0
    fi

    # 2. No plugin installed -> local git config counter.
    CUR="$(git config --get aapp.planId 2>/dev/null || true)"
    case "$CUR" in
        '')       CUR=1 ;;
        *[!0-9]*) echo "❌ [Plan ID] aapp.planId is not an integer: '$CUR'. Run 'aapp init' to reseed." >&2
                  return 1 ;;
    esac
    git config aapp.planId "$((CUR + 1))" || return 1
    printf 'P-%s\n' "$CUR"
}
