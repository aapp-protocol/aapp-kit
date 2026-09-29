#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `issue` (P-32)
#
# Issue ID allocation and lifecycle close.
#   aapp issue [next]                                   peek the next issue ID (read-only)
#   aapp issue allocate                                 claim an issue ID
#   aapp issue close <id> [sha <sha>] [summary "<text>"] relocate the row to the archive
#   aapp issue list [<n> | all]                         active issues in road-map order
#
# The local ledgers are authoritative. An installed `aapp-issue` provider plugin
# allocates IDs (fail closed, like `aapp-planid`) and is notified on close
# (fire-and-forget: retry and delivery are the plugin's responsibility).
# ==============================================================================

AAPP_ISSUE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/plan_resolver.sh
if ! declare -f allocate_issue_id >/dev/null; then
    . "$AAPP_ISSUE_LIB_DIR/plan_resolver.sh" || {
        echo "❌ [Issue] Cannot load $AAPP_ISSUE_LIB_DIR/plan_resolver.sh" >&2
        exit 1
    }
fi
# shellcheck source=lib/commit_engine.sh
if ! declare -f plans_commit >/dev/null; then
    . "$AAPP_ISSUE_LIB_DIR/commit_engine.sh" || {
        echo "❌ [Issue] Cannot load $AAPP_ISSUE_LIB_DIR/commit_engine.sh" >&2
        exit 1
    }
fi

# Same selector as the status briefing's Issues pillar (lib/cmd_status.sh), so
# `aapp issue list` and `aapp status` agree on order.
ISSUE_ROADMAP_ACTIVE_REGEX='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ ]?\]|\*)[[:space:]]*`?#?[0-9]+'
ISSUE_LIST_DEFAULT_CAP=20

_issue_plans_dir() {
    if [ -n "${PLANS_DIR:-}" ] && [ -d "$PLANS_DIR" ]; then
        printf '%s\n' "$PLANS_DIR"
        return 0
    fi
    local root
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || {
        echo "❌ [Issue] Not inside a Git repository." >&2
        return 1
    }
    if [ ! -d "$root/.plans" ]; then
        echo "❌ [Issue] .plans directory not found at $root/.plans. Run 'aapp init'." >&2
        return 1
    fi
    printf '%s\n' "$root/.plans"
}

# issue_normalize_id <raw> -> bare integer. Accepts 79, #79, ISSUE-79, `#079`.
issue_normalize_id() {
    local raw="$1" n
    n="${raw//\`/}"
    n="${n#\#}"
    case "$n" in ISSUE-*|issue-*) n="${n#*-}" ;; esac
    case "$n" in
        ''|*[!0-9]*)
            echo "❌ [Issue] Not an issue ID: '$raw' (use a bare number, e.g. 'aapp issue close 79')." >&2
            return 1
            ;;
    esac
    printf '%s\n' "$((10#$n))"
}

# _issue_row_regex <n> -> ERE matching the ledger row whose first cell is #<n>.
_issue_row_regex() {
    printf '^[[:space:]]*\\|[[:space:]]*`?#%s`?[[:space:]]*\\|' "$1"
}

# issue_locate <n> -> prints "active", "archive" or nothing.
issue_locate() {
    local n="$1" plans re
    plans="$(_issue_plans_dir)" || return 1
    re="$(_issue_row_regex "$n")"
    if [ -f "$plans/ISSUES.md" ] && grep -qE "$re" "$plans/ISSUES.md"; then
        echo "active"
    elif [ -f "$plans/done/000-issues-archive.md" ] && grep -qE "$re" "$plans/done/000-issues-archive.md"; then
        echo "archive"
    fi
}

# issue_close_local <n> <sha> [summary]
# Moves the active row to the top of the archive and prunes the road map.
# Does not commit. Returns 0 when moved; fails when the row is not active.
issue_close_local() {
    local n="$1" sha="$2" summary="${3:-}"
    local plans active archive roadmap re row today archive_row tmp
    plans="$(_issue_plans_dir)" || return 1
    active="$plans/ISSUES.md"
    archive="$plans/done/000-issues-archive.md"
    roadmap="$plans/issues_road_map.md"
    re="$(_issue_row_regex "$n")"

    if [ ! -f "$archive" ]; then
        echo "❌ [Issue] Archive not found: $archive" >&2
        return 1
    fi
    row="$(grep -m 1 -E "$re" "$active" 2>/dev/null)" || {
        echo "❌ [Issue] #$n is not an active row in $active." >&2
        return 1
    }

    today="$(date +%Y-%m-%d)"
    # Active:  | # | Sev | Type | Date | Location | Symptom | Target Plan / Fix | Status |
    # Archive: | # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
    # Escaped pipes (\|) inside cells are preserved.
    archive_row="$(AAPP_SHA="$sha" AAPP_SUMMARY="$summary" AAPP_TODAY="$today" awk '
        {
            gsub(/\\\|/, "\001")
            n = split($0, c, "|")
            for (i = 1; i <= n; i++) {
                gsub(/^[ \t]+|[ \t]+$/, "", c[i])
                gsub("\001", "\\|", c[i])
            }
            s = ENVIRON["AAPP_SUMMARY"]
            if (s == "") s = "Direct fix (no plan): " c[8]
            gsub(/\\\|/, "\001", s); gsub(/\|/, "\001", s); gsub("\001", "\\|", s)
            printf "| %s | %s | %s | %s | %s | `%s` | %s |\n", c[2], c[3], c[4], c[5], ENVIRON["AAPP_TODAY"], ENVIRON["AAPP_SHA"], s
        }' <<< "$row")"

    tmp="$archive.aapp-issue.$$"
    AAPP_ROW="$archive_row" awk '
        { print }
        !done && /^\|[[:space:]]*:---/ { print ENVIRON["AAPP_ROW"]; done = 1 }
        END { if (!done) exit 3 }
    ' "$archive" > "$tmp" || {
        rm -f "$tmp"
        echo "❌ [Issue] No table header separator found in $archive." >&2
        return 1
    }
    mv "$tmp" "$archive"

    tmp="$active.aapp-issue.$$"
    grep -v -E "$re" "$active" > "$tmp"
    mv "$tmp" "$active"

    if [ -f "$roadmap" ]; then
        tmp="$roadmap.aapp-issue.$$"
        # grep -v exits 1 when every line matched; an empty board is still valid.
        grep -v -E "^[[:space:]]*([0-9]+\.|[-*][[:space:]]*\[[ xX]?\]|\*)[[:space:]]*\`?#$n([^0-9]|\$)" "$roadmap" > "$tmp" || [ $? -eq 1 ]
        mv "$tmp" "$roadmap"
    fi
    return 0
}

# issue_notify_close <n> <sha> <summary>
# Fire-and-forget hand-off to an installed `aapp-issue` plugin. Registered in the
# P-32 Fallback Inventory: a failing plugin only warns, because the local archive
# is authoritative and delivery/retry is the plugin implementer's responsibility.
issue_notify_close() {
    local n="$1" sha="$2" summary="$3" root pdir entry
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || return 0
    pdir="$root/.agents/skills/aapp-issue"
    [ -d "$pdir" ] || return 0
    entry="$(resolve_plugin_entrypoint "$pdir" "aapp-issue" 2>/dev/null)" || return 0
    if ! AAPP_ACTION=close AAPP_REPO_ROOT="$root" AAPP_ISSUE_ID="#$n" \
         AAPP_COMMIT_SHA="$sha" AAPP_SUMMARY="$summary" "$entry" >/dev/null; then
        echo "⚠️  [Issue] #$n closed locally; the aapp-issue plugin reported a failure (delivery is the plugin's responsibility)." >&2
    fi
    return 0
}

cmd_issue_next() {
    local id
    id="$(get_next_issue_id)" || return 1
    echo "Next available issue ID: $id"
}

cmd_issue_allocate() {
    allocate_issue_id
}

cmd_issue_close() {
    local raw="${1:-}" sha="" summary="" n where root
    if [ -z "$raw" ]; then
        echo "❌ [Issue] Usage: aapp issue close <id> [sha <sha>] [summary \"<text>\"]" >&2
        return 1
    fi
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            sha)     [ $# -ge 2 ] || { echo "❌ [Issue] 'sha' needs a value." >&2; return 1; }
                     sha="$2"; shift 2 ;;
            summary) [ $# -ge 2 ] || { echo "❌ [Issue] 'summary' needs a value." >&2; return 1; }
                     summary="$2"; shift 2 ;;
            *)       echo "❌ [Issue] Unknown token '$1'. Usage: aapp issue close <id> [sha <sha>] [summary \"<text>\"]" >&2
                     return 1 ;;
        esac
    done

    n="$(issue_normalize_id "$raw")" || return 1
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || {
        echo "❌ [Issue] Not inside a Git repository." >&2
        return 1
    }
    if [ -z "$sha" ]; then
        sha="$(git -C "$root" rev-parse --short=7 HEAD)" || return 1
    fi

    where="$(issue_locate "$n")" || return 1
    case "$where" in
        active)
            issue_close_local "$n" "$sha" "$summary" || return 1
            plans_commit "issue(close): archive #$n" ISSUES.md done/000-issues-archive.md issues_road_map.md || return 1
            echo "✅ [Issue] #$n archived to done/000-issues-archive.md (commit \`$sha\`)."
            ;;
        archive)
            echo "ℹ️  [Issue] #$n is already archived; re-notifying the aapp-issue plugin only."
            ;;
        *)
            echo "❌ [Issue] #$n not found in ISSUES.md or done/000-issues-archive.md." >&2
            return 1
            ;;
    esac
    issue_notify_close "$n" "$sha" "$summary"
}

cmd_issue_list() {
    local arg="${1:-}" cap plans roadmap lines total
    case "$arg" in
        '')          cap="$ISSUE_LIST_DEFAULT_CAP" ;;
        all)         cap=0 ;;
        *[!0-9]*)    echo "❌ [Issue] Usage: aapp issue list [<n> | all]" >&2; return 1 ;;
        *)           cap="$arg" ;;
    esac
    plans="$(_issue_plans_dir)" || return 1
    roadmap="$plans/issues_road_map.md"
    if [ ! -f "$roadmap" ]; then
        echo "❌ [Issue] Road map not found: $roadmap" >&2
        return 1
    fi
    # grep exits 1 on no match; an empty board is a valid state, reported below.
    lines="$(grep -E "$ISSUE_ROADMAP_ACTIVE_REGEX" "$roadmap" | grep -v '\[Feature or Problem Title\]' | grep -v -E '✅|[Rr]esolved|DONE')" || [ $? -eq 1 ]
    if [ -z "$lines" ]; then
        echo "  (No open issues in issues_road_map.md)"
        return 0
    fi
    total="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
    if [ "$cap" -eq 0 ] || [ "$total" -le "$cap" ]; then
        printf '%s\n' "$lines" | sed 's/^/  /'
    else
        printf '%s\n' "$lines" | head -n "$cap" | sed 's/^/  /'
        echo "  … $((total - cap)) more (aapp issue list all)"
    fi
}

cmd_issue() {
    local sub="${1:-next}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        next)     cmd_issue_next "$@" ;;
        allocate) cmd_issue_allocate "$@" ;;
        close)    cmd_issue_close "$@" ;;
        list)     cmd_issue_list "$@" ;;
        *)
            echo "❌ [Issue] Unknown subcommand '$sub'." >&2
            echo "Usage: aapp issue [next | allocate | close <id> [sha <sha>] [summary \"<text>\"] | list [<n> | all]]" >&2
            return 1
            ;;
    esac
}
