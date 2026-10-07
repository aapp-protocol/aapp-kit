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
    # Explicit argument wins; otherwise inherit the root the `aapp` dispatcher
    # exported, and only derive it when sourced standalone (P-33).
    local REPO_ROOT="${4:-${REPO_ROOT:-}}"

    if [ -z "$REPO_ROOT" ]; then
        REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            echo "❌ [Plan Resolver] Not inside a Git repository." >&2
            return 1
        }
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
                find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" ! -name "fix-*" -exec basename {} \; 2>/dev/null | sort
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
                        done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" ! -name "fix-*" -print0 2>/dev/null)
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
                done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" ! -name "fix-*" -print0 2>/dev/null)
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
                done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" ! -name "fix-*" -print0 2>/dev/null)
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
# Plan & Issue ID Allocation (config-backed, P-32)
# ------------------------------------------------------------------------------
# Two independent counters: `aapp.planId` (P-<n>) and `aapp.issueId` (#<n>).
# Each stores the NEXT id to hand out, as a bare integer. The prefix is a
# namespace marker applied on output (#69) -- it is never part of the stored value.
#
# An unset key legitimately means 1 (a project that never ran `aapp init`).
# A non-empty, non-numeric value means something external corrupted the key:
# we refuse rather than silently restarting the sequence at 1, which would
# collide with every existing id. `aapp init` repairs it (it has a filesystem
# scan to repair from); allocation refuses and names the repair.

# Returns the NEXT free issue ID from the ledgers: numeric max across BOTH the
# active ledger (priority-ordered) and the archive (resolved rows), plus one.
# Template example rows (dated YYYY-MM-DD) are skipped, so a new project gets 1.
# Returns 2 when neither ledger exists.
# seed_issue_id <plans-dir>
seed_issue_id() {
    local PLANS="$1"
    local F LINE N MAX=0 FOUND=0

    for F in "$PLANS/ISSUES.md" "$PLANS/done/000-issues-archive.md"; do
        [ -f "$F" ] || continue
        FOUND=1
        while IFS= read -r LINE; do
            case "$LINE" in
                *YYYY-MM-DD*) continue ;;
                '| #'*) N="${LINE#*'| #'}" ;;
                '|  #'*) N="${LINE#*'|  #'}" ;;
                *) continue ;;
            esac
            N="${N%%[!0-9]*}"
            [ -n "$N" ] || continue
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done < "$F"
    done

    [ "$FOUND" -eq 1 ] || return 2
    printf '%s\n' "$((MAX + 1))"
}

# Seeder for an unset aapp.issueId. Git config is not cloned, so a clone starts
# without a counter: continue from the ledgers it brought down. No ledgers at all
# means the IDs live with a remote authority whose provider is not installed.
_seed_issue_counter() {
    local ROOT RC=0 N
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
    N="$(seed_issue_id "$ROOT/.plans")" || RC=$?
    if [ "$RC" -eq 2 ]; then
        echo "❌ [Issue ID] No issue ledgers in .plans/ and no aapp-issue-tracker provider installed." >&2
        echo "   Issue IDs come from the team provider: install it at .agents/skills/aapp-issue-tracker/run." >&2
        return 1
    fi
    [ "$RC" -eq 0 ] || return 1
    printf '%s\n' "$N"
}

# Repair hint for a corrupt counter: a first-use seeder reseeds once the key is
# unset; otherwise `aapp init` holds the filesystem scan.
_reseed_hint() {
    if [ -n "$2" ]; then echo "Run 'git config --unset $1' to reseed from the ledgers."
    else echo "Run 'aapp init' to reseed."; fi
}

# Read-only peek at the next id. Never mutates. Safe for status output.
# _next_id <config-key> <prefix> <label> [seeder]
_next_id() {
    local KEY="$1" PREFIX="$2" LABEL="$3" SEEDER="${4:-}" CUR
    CUR="$(git config --get "$KEY" 2>/dev/null || true)"
    case "$CUR" in
        '')       if [ -n "$SEEDER" ]; then CUR="$("$SEEDER")" || return 1; else CUR=1; fi ;;
        *[!0-9]*) echo "❌ [$LABEL] $KEY is not an integer: '$CUR'. $(_reseed_hint "$KEY" "$SEEDER")" >&2
                  return 1 ;;
    esac
    printf '%s%s\n' "$PREFIX" "$CUR"
}

# Normalises a provider-supplied id. Accepts "<prefix>42" or bare "42"; anything
# that is not a plain integer is an error. Emitting a well-formed id is the third
# party's responsibility -- we do not repair or interpret their output.
# _normalize_id <raw> <prefix> <label>
_normalize_id() {
    local RAW="$1" PREFIX="$2" LABEL="$3"
    local N="${RAW#"$PREFIX"}"
    case "$N" in
        ''|*[!0-9]*)
            echo "❌ [$LABEL] Provider must return an integer id (got: '$RAW')" >&2
            return 1
            ;;
    esac
    printf '%s%s\n' "$PREFIX" "$N"
}

# Claims an id and persists the increment. Delegates to a provider plugin when
# one is installed; otherwise uses the local counter. Only plugin ABSENCE falls
# back -- a plugin that is present and fails is fatal, never a silent local allocation.
# _allocate_id <config-key> <prefix> <plugin-name> <label> [seeder]
# [seeder] names a function printing the first id for an unset counter;
# without one, unset means 1.
_allocate_id() {
    local KEY="$1" PREFIX="$2" PLUGIN="$3" LABEL="$4" EVENT="$5" SEEDER="${6:-}"
    # Resolve from the current directory, fail-closed (P-33). This deliberately
    # does NOT prefer an inherited REPO_ROOT: the counter is per-repository, and
    # a stale exported root would allocate against the wrong repo.
    local ROOT PDIR ENTRY RAW OUT CUR ISSUED
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ [$LABEL] Not inside a Git repository." >&2
        return 1
    }
    PDIR="$ROOT/.agents/skills/$PLUGIN"

    # 1. Delegate to the provider plugin when one is installed (Plugin Payload
    #    Standard: envelope on stdin, one JSON object on stdout).
    if [ -d "$PDIR" ] && ENTRY="$(resolve_plugin_entrypoint "$PDIR" "$PLUGIN" 2>/dev/null)"; then
        OUT="$(run_action_plugin "$ENTRY" "$ROOT" allocate "$EVENT" 2>/dev/null)" || {
            RAW="$(json_field "$OUT" error)" || RAW="no error text"
            echo "❌ [$LABEL] Provider plugin failed ($RAW); refusing to allocate locally." >&2
            return 1
        }
        RAW="$(json_field "$OUT" id)" || {
            echo "❌ [$LABEL] Provider must print {\"id\": ...} (got: '$OUT')" >&2
            return 1
        }
        OUT="$(_normalize_id "$RAW" "$PREFIX" "$LABEL")" || return 1
        # Ratchet the local counter past the issued id so the fallback never regresses.
        CUR="$(git config --get "$KEY" 2>/dev/null || true)"
        case "$CUR" in ''|*[!0-9]*) CUR=0 ;; esac   # unusable -> 0, so the write below repairs it
        ISSUED="${OUT#"$PREFIX"}"
        if [ "$ISSUED" -ge "$CUR" ]; then git config "$KEY" "$((ISSUED + 1))"; fi
        printf '%s\n' "$OUT"
        return 0
    fi

    # 2. No plugin installed -> local git config counter.
    CUR="$(git config --get "$KEY" 2>/dev/null || true)"
    case "$CUR" in
        '')       if [ -n "$SEEDER" ]; then CUR="$("$SEEDER")" || return 1; else CUR=1; fi ;;
        *[!0-9]*) echo "❌ [$LABEL] $KEY is not an integer: '$CUR'. $(_reseed_hint "$KEY" "$SEEDER")" >&2
                  return 1 ;;
    esac
    git config "$KEY" "$((CUR + 1))" || return 1
    printf '%s%s\n' "$PREFIX" "$CUR"
}

get_next_plan_id()  { _next_id aapp.planId "P-" "Plan ID"; }
normalize_plan_id() { _normalize_id "$1" "P-" "Plan ID"; }
allocate_plan_id()  { _allocate_id aapp.planId "P-" aapp-planid "Plan ID" plan.allocate; }

get_next_issue_id() { _next_id aapp.issueId "#" "Issue ID" _seed_issue_counter; }
allocate_issue_id() { _allocate_id aapp.issueId "#" aapp-issue-tracker "Issue ID" issue.allocate _seed_issue_counter; }
