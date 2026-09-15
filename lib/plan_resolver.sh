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

# Calculates next auto-incrementing Plan ID: returns "P-<num>"
get_next_plan_id() {
    local REPO_ROOT="${1:-}"
    if [ -z "$REPO_ROOT" ]; then
        REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi

    local PLANS_DIR="$REPO_ROOT/.plans"
    local MAX_ID=0

    # Scan active and archived blueprints
    for DIR in "$PLANS_DIR/current" "$PLANS_DIR/done"; do
        if [ -d "$DIR" ]; then
            while IFS= read -r -d '' F; do
                local BNAME
                BNAME="$(basename "$F")"
                if [[ "$BNAME" =~ ^[pP]([0-9]+)- ]]; then
                    local NUM=$((10#${BASH_REMATCH[1]}))
                    [ "$NUM" -gt "$MAX_ID" ] && MAX_ID="$NUM"
                fi
                local PID
                PID="$(get_plan_id "$F" 2>/dev/null || true)"
                if [[ "$PID" =~ ^P-([0-9]+)$ ]]; then
                    local NUM=$((10#${BASH_REMATCH[1]}))
                    [ "$NUM" -gt "$MAX_ID" ] && MAX_ID="$NUM"
                fi
            done < <(find "$DIR" -maxdepth 1 -name "*.md" ! -name "000-*" -print0 2>/dev/null)
        fi
    done

    # Scan archive ledger table rows if present
    local LEDGER="$PLANS_DIR/done/000-archive-ledger.md"
    if [ -f "$LEDGER" ]; then
        while IFS= read -r LINE; do
            if [[ "$LINE" =~ \|[[:space:]]*`?P-([0-9]+)`?[[:space:]]*\| ]]; then
                local NUM=$((10#${BASH_REMATCH[1]}))
                [ "$NUM" -gt "$MAX_ID" ] && MAX_ID="$NUM"
            fi
        done < "$LEDGER"
    fi

    echo "P-$((MAX_ID + 1))"
}
