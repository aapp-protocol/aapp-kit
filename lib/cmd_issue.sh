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
# The local ledgers are authoritative. An installed `aapp-issue-tracker` plugin
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
# shellcheck source=lib/aapp-lib.sh
if ! declare -f aapp_lib_loaded >/dev/null; then
    . "$AAPP_ISSUE_LIB_DIR/aapp-lib.sh" || {
        echo "❌ [Issue] Cannot load $AAPP_ISSUE_LIB_DIR/aapp-lib.sh" >&2
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

# issue_relink <old-rel-path> <new-rel-path> (P-50)
# Rewrites the link target `](<old>)` -> `](<new>)` in ISSUES.md *Target Plan /
# Fix* cells (the 7th cell; observation cells never change) and in
# issues_road_map.md lines. Escaped pipes (`\|`) inside cells are respected.
# Prints the number of links rewritten; non-zero only on a write failure.
issue_relink() {
    local old="$1" new="$2" plans f tmp count=0 n
    plans="$(_issue_plans_dir)" || return 1
    f="$plans/ISSUES.md"
    if [ -f "$f" ]; then
        tmp="$f.aapp-relink.$$"
        AAPP_OLD="]($old)" AAPP_NEW="]($new)" awk '
            function swap(s,    out, i, o) {
                o = ENVIRON["AAPP_OLD"]; out = ""
                while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) ENVIRON["AAPP_NEW"]; s = substr(s, i + length(o)); n++ }
                return out s
            }
            /^[[:space:]]*\|[[:space:]]*`?#[0-9]+/ {
                line = $0; gsub(/\\\|/, "\001", line)
                k = split(line, c, "|")
                if (k >= 9) {
                    c[8] = swap(c[8]); out = c[1]
                    for (j = 2; j <= k; j++) out = out "|" c[j]
                    gsub(/\001/, "\\|", out); print out; next
                }
            }
            { print }
            END { print n + 0 > "/dev/stderr" }
        ' "$f" > "$tmp" 2> "$tmp.n" || { rm -f "$tmp" "$tmp.n"; return 1; }
        n="$(cat "$tmp.n")"; rm -f "$tmp.n"
        mv "$tmp" "$f" || return 1
        count=$((count + n))
    fi
    f="$plans/issues_road_map.md"
    if [ -f "$f" ]; then
        n="$(grep -oF "]($old)" "$f" | wc -l | tr -d ' ')"
        if [ "$n" -gt 0 ]; then
            tmp="$f.aapp-relink.$$"
            AAPP_OLD="]($old)" AAPP_NEW="]($new)" awk '
                { s = $0; out = ""; o = ENVIRON["AAPP_OLD"]
                  while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) ENVIRON["AAPP_NEW"]; s = substr(s, i + length(o)) }
                  print out s }
            ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
            count=$((count + n))
        fi
    fi
    echo "$count"
}

# issue_mark_planned <n> <link> (P-50): promotion's lifecycle edit of an active
# row: Target Plan / Fix -> <link>, Status -> 🔵 `Planned`. Observation cells
# never change.
issue_mark_planned() {
    local n="$1" link="$2" plans f tmp
    plans="$(_issue_plans_dir)" || return 1
    f="$plans/ISSUES.md"
    [ -f "$f" ] || return 1
    tmp="$f.aapp-promote.$$"
    AAPP_N="$n" AAPP_LINK="$link" awk '
        {
            line = $0; gsub(/\\\|/, "\001", line)
            if (line ~ ("^[[:space:]]*\\|[[:space:]]*`?#" ENVIRON["AAPP_N"] "`?[[:space:]]*\\|")) {
                k = split(line, c, "|")
                if (k >= 10) {
                    c[8] = " " ENVIRON["AAPP_LINK"] " "; c[9] = " 🔵 `Planned` "
                    out = c[1]; for (j = 2; j <= k; j++) out = out "|" c[j]
                    gsub(/\001/, "\\|", out); print out; done = 1; next
                }
            }
            print
        }
        END { if (!done) exit 3 }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
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

# issue_notify_close <n> <sha> <summary> [plan-id]
# Fire-and-forget `issue.close` hand-off to an installed `aapp-issue-tracker`
# plugin (Plugin Payload Standard). Registered in the P-32 Fallback Inventory: a
# failing plugin only warns, because the local archive is authoritative and
# delivery/retry is the plugin implementer's responsibility.
issue_notify_close() {
    local n="$1" sha="$2" summary="$3" plan="${4:-}" root pdir entry data out status plan_json="null"
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || return 0
    pdir="$root/.agents/skills/aapp-issue-tracker"
    [ -d "$pdir" ] || return 0
    entry="$(resolve_plugin_entrypoint "$pdir" "aapp-issue-tracker" 2>/dev/null)" || return 0
    [ -n "$plan" ] && plan_json="\"$(json_escape "$plan")\""
    data="{\"id\": \"#$n\", \"commit\": \"$(json_escape "$sha")\", \"summary\": \"$(json_escape "$summary")\", \"plan\": $plan_json}"
    if out="$(AAPP_ISSUE_ID="#$n" AAPP_COMMIT_SHA="$sha" AAPP_SUMMARY="$summary" \
              run_action_plugin "$entry" "$root" close issue.close "$data" 2>/dev/null)"; then
        status="$(json_field "$out" status)" || status="accepted"
        echo "📨 [Issue] #$n handed to aapp-issue-tracker: $status"
    else
        status="$(json_field "$out" error)" || status="no error text"
        echo "⚠️  [Issue] #$n closed locally; aapp-issue-tracker failed ($status). Delivery is the plugin's responsibility." >&2
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
    # P-52: an open mini plan supplies the SHA (its last recorded commit) and
    # the summary, and is deleted in the close commit.
    local plans mp="" mini_files="" last touched paths=() p unblocked="" wt
    plans="$(_issue_plans_dir)" || return 1
    if [ -f "$plans/current/fix-$n.md" ]; then
        mp="$plans/current/fix-$n.md"
        last="$(parse_plan_commits "$mp" | tail -n 1 | awk '{print $1}')"
        if [ -z "$last" ]; then
            echo "❌ [Issue] #$n's fix recorded no commit; commit it with 'aapp commit' (or drop it with 'aapp issue fix $n abort')." >&2
            return 1
        fi
        [ -n "$sha" ] || sha="$last"
        mini_files="$(parse_plan_target_paths "$mp" | paste -sd, - | sed 's/,/, /g')"
    fi
    if [ -z "$sha" ]; then
        sha="$(git -C "$root" rev-parse --short=7 HEAD)" || return 1
    fi

    where="$(issue_locate "$n")" || return 1
    case "$where" in
        active)
            touched="$(issue_unblock_plans "$n")" || return 1
            for p in $touched; do
                unblocked="${unblocked:+$unblocked, }$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plans/$p" | head -n 1)"
            done
            if [ -z "$summary" ] && [ -n "$mp" ]; then
                summary="Fixed via aapp issue fix: $mini_files${unblocked:+; unblocks $unblocked}"
            fi
            issue_close_local "$n" "$sha" "$summary" || return 1
            paths=(ISSUES.md done/000-issues-archive.md issues_road_map.md)
            for p in $touched; do paths+=("$p"); done
            if [ -n "$mp" ]; then
                _issue_load_plan_lib || return 1
                rm -f "$mp"
                _issue_restore_buffer
                paths+=("current/fix-$n.md")
            fi
            _issue_reapply_stash "$n"
            if [ -n "$touched" ]; then
                _issue_load_plan_lib || return 1
                sync_state_matrix
                [ -f "$plans/state_matrix.md" ] && paths+=("state_matrix.md")
            fi
            plans_commit "issue(close): archive #$n" "${paths[@]}" || return 1
            echo "✅ [Issue] #$n archived to done/000-issues-archive.md (commit \`$sha\`)."
            for p in $touched; do
                if grep -q '^\* \*\*Status:\*\* 🟥' "$plans/$p"; then
                    echo "   $(basename "$p" .md) is still blocked: $(sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$plans/$p" | head -n 1)"
                else
                    wt="$(sed -nE 's/^\* \*\*Worktree:\*\*[[:space:]]*//p' "$plans/$p" | head -n 1)"
                    echo "   $(basename "$p" .md) is unblocked.${wt:+ Next: in $wt, rebase the plan branch onto the development branch.}"
                fi
            done
            ;;
        archive)
            echo "ℹ️  [Issue] #$n is already archived; re-notifying the aapp-issue-tracker plugin only."
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

# ------------------------------------------------------------------------------
# P-52: hotfixes, mini-plan fixes, the issue lock
# ------------------------------------------------------------------------------

# _issue_load_plan_lib: plan_block_on, sync_state_matrix, write_active_buffer,
# cmd_draft and the buffer paths, loaded in-process from cmd_plan.sh (P-49).
_issue_load_plan_lib() {
    declare -f plan_block_on >/dev/null && declare -f sync_state_matrix >/dev/null && return 0
    # shellcheck source=lib/cmd_plan.sh
    AAPP_PLAN_LIB_ONLY=1 . "$AAPP_ISSUE_LIB_DIR/cmd_plan.sh" || {
        echo "❌ [Issue] Cannot load $AAPP_ISSUE_LIB_DIR/cmd_plan.sh" >&2
        return 1
    }
}

# _issue_wait_limit: seconds `fix` and the issue lock wait (aapp.issueFixWait, minutes).
_issue_wait_limit() {
    local m
    m="$(git config --get aapp.issueFixWait 2>/dev/null)" || m=5
    case "$m" in ''|*[!0-9]*) m=5 ;; esac
    echo $((m * 60))
}

# _issue_open_mini <plans>: prints the open mini plan's issue number, if any.
_issue_open_mini() {
    local f
    for f in "$1"/current/fix-*.md; do
        [ -f "$f" ] || continue
        f="${f##*/fix-}"; echo "${f%.md}"; return 0
    done
    return 1
}

_issue_lock_release() {
    [ -n "${_ISSUE_LOCK:-}" ] && rm -rf "$_ISSUE_LOCK"
    _ISSUE_LOCK=""
}

# _issue_lock_acquire: the one issue lock, shared by every worktree (P-52 2.6).
# Waits with the roller; a lock whose holder PID is gone, or that never got a
# PID within a few seconds, is stale and taken over with a notice.
_issue_lock_acquire() {
    local lock common limit waited=0 step=2 pid mtime age
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
    case "$common" in /*) ;; *) common="$(cd "$common" && pwd)" ;; esac
    lock="$common/aapp_issue.lock"
    limit="$(_issue_wait_limit)"
    while ! mkdir "$lock" 2>/dev/null; do
        pid="$(cat "$lock/pid" 2>/dev/null || true)"
        if [ -z "$pid" ]; then
            mtime="$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || date +%s)"
            age=$(( $(date +%s) - mtime ))
            if [ "$age" -ge 5 ]; then
                echo "⚠️  [Issue] Taking over a stale issue lock (no holder PID)." >&2
                rm -rf "$lock"; continue
            fi
        elif ! kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  [Issue] Taking over a stale issue lock (holder $pid is gone)." >&2
            rm -rf "$lock"; continue
        fi
        if [ "$waited" -ge "$limit" ]; then
            echo "⏳ [Issue] The issue lock is still held${pid:+ by $pid}; retry later." >&2
            return 1
        fi
        echo "⏳ [Issue] Issue lock held${pid:+ by $pid}; waiting ${step}s…" >&2
        sleep "$step"; waited=$((waited + step)); step=$((step + 1))
    done
    echo "$$" > "$lock/pid"
    _ISSUE_LOCK="$lock"
    trap '_issue_lock_release' EXIT
}

# _issue_plan_file_for <plans> <id>: the plan in current/ for a buffer id.
_issue_plan_file_for() {
    local plans="$1" want="$2" pf pid b
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        b="$(basename "$pf" .md)"
        case "$b" in 000-*|fix-*) continue ;; esac
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
        if [ "$pid" = "$want" ] || [ "P-$want" = "$pid" ] || [ "$b" = "$want" ] || \
           [[ "$b" == "$want-"* ]] || [[ "$b" == "P${want#P-}-"* ]]; then
            echo "$pf"; return 0
        fi
    done
    return 1
}

# _issue_hotfix_list <plan_file>: the issues in `* **Emergency Hotfixes:**`, one per line.
_issue_hotfix_list() {
    sed -nE 's/^\* \*\*Emergency Hotfixes:\*\*[[:space:]]*//p' "$1" | head -n 1 | tr ',' '\n' | tr -d ' ' | grep -E '^#[0-9]+$' || true
}

# _issue_record_hotfix <plan_file> <n>: append-only, no duplicates; inserted
# after the Status line the first time.
_issue_record_hotfix() {
    local pf="$1" n="$2" cur tmp
    _issue_hotfix_list "$pf" | grep -qxF "#$n" && return 0
    cur="$(_issue_hotfix_list "$pf" | paste -sd, - | sed 's/,/, /g')"
    tmp="$pf.aapp-hotfix.$$"
    if [ -n "$cur" ]; then
        AAPP_LINE="* **Emergency Hotfixes:** $cur, #$n" awk '/^\* \*\*Emergency Hotfixes:\*\*/ && !d { print ENVIRON["AAPP_LINE"]; d = 1; next } { print }' "$pf" > "$tmp"
    else
        AAPP_LINE="* **Emergency Hotfixes:** #$n" awk '{ print } /^\* \*\*Status:\*\*/ && !d { print ENVIRON["AAPP_LINE"]; d = 1 }' "$pf" > "$tmp"
    fi
    mv "$tmp" "$pf"
}

# _issue_queue_blocker <roadmap> <n> <text> <plan-id>: append to 🧱 Plan Blockers,
# creating the subheader at the top of the board (before the first `## `).
_issue_queue_blocker() {
    local rm="$1" line tmp
    line="- [ ] #$2 -> $3 (blocks $4)"
    tmp="$rm.aapp-queue.$$"
    if grep -q '^## 🧱 Plan Blockers' "$rm"; then
        AAPP_LINE="$line" awk '
            function flush() { for (i = 1; i <= nb; i++) print blank[i]; nb = 0 }
            in_q && /^## / { print ENVIRON["AAPP_LINE"]; flush(); in_q = 0; done = 1 }
            in_q && /^[[:space:]]*$/ { blank[++nb] = $0; next }
            in_q { flush() }
            /^## 🧱 Plan Blockers/ { in_q = 1 }
            { print }
            END { if (in_q && !done) print ENVIRON["AAPP_LINE"]; flush() }
        ' "$rm" > "$tmp"
    else
        AAPP_LINE="$line" awk '
            !done && /^## / { print "## 🧱 Plan Blockers"; print ENVIRON["AAPP_LINE"]; print ""; done = 1 }
            { print }
            END { if (!done) { print ""; print "## 🧱 Plan Blockers"; print ENVIRON["AAPP_LINE"] } }
        ' "$rm" > "$tmp"
    fi
    mv "$tmp" "$rm"
}

# issue_unblock_plans <n>: removes #<n> from every plan's `Blocked On:`; when the
# list empties and the block is not permanent, restores the recorded previous
# status. Prints the plan paths (relative to .plans) it changed.
issue_unblock_plans() {
    local n="$1" plans pf line fields list was perm newlist tmp
    plans="$(_issue_plans_dir)" || return 1
    _issue_load_plan_lib || return 1
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        line="$(grep -m 1 -E '^\* \*\*Blocked On:\*\*' "$pf" || true)"
        [ -n "$line" ] || continue
        fields="$(plan_blocked_on_parse "${line#\* \*\*Blocked On:\*\* }")"
        list="$(sed -n 1p <<< "$fields")"; was="$(sed -n 2p <<< "$fields")"; perm="$(sed -n 3p <<< "$fields")"
        printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -qxF "#$n" || continue
        newlist="$(printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -E '^#[0-9]+$' | grep -vxF "#$n" | paste -sd, - | sed 's/,/, /g')"
        tmp="$pf.aapp-unblock.$$"
        if [ -n "$newlist" ] || [ -n "$perm" ]; then
            AAPP_LINE="$(plan_blocked_on_line "$newlist" "$was" "$perm")" awk '/^\* \*\*Blocked On:\*\*/ && !d { print ENVIRON["AAPP_LINE"]; d = 1; next } { print }' "$pf" > "$tmp"
        elif [ -n "$was" ]; then
            AAPP_STATUS="* **Status:** $was" awk '
                /^\* \*\*Blocked On:\*\*/ { next }
                /^\* \*\*Status:\*\*/ && !d { print ENVIRON["AAPP_STATUS"]; d = 1; next }
                { print }' "$pf" > "$tmp"
        else
            awk '/^\* \*\*Blocked On:\*\*/ { next } { print }' "$pf" > "$tmp"
            echo "ℹ️  [Issue] $(basename "$pf" .md) has no blockers left but no recorded previous status; set it with 'aapp refine'." >&2
        fi
        mv "$tmp" "$pf"
        echo "current/$(basename "$pf")"
    done
}

# _issue_reapply_stash <n>: single-checkout mode; re-applies the plan's work
# set aside by `hotfix` for #<n> (by SHA) on top of the fix. A conflict keeps
# the stash and reports it; nothing is lost.
_issue_reapply_stash() {
    local n="$1" buf sha ref tmp
    buf="$(git rev-parse --git-path aapp_hotfix_stash 2>/dev/null)" || return 0
    [ -s "$buf" ] || return 0
    sha="$(awk -v k="#$n" '$2 == k { print $1; exit }' "$buf")"
    [ -n "$sha" ] || return 0
    ref="$(git stash list --format='%gd %H' | awk -v s="$sha" '$2 == s { print $1; exit }')"
    tmp="$buf.tmp.$$"
    if [ -z "$ref" ]; then
        echo "⚠️  [Issue] The work set aside for #$n ($sha) is no longer in the stash list." >&2
    elif git stash apply -q "$ref" 2>/dev/null; then
        git stash drop -q "$ref" >/dev/null 2>&1 || echo "⚠️  [Issue] Applied, but could not drop $ref; drop it by hand." >&2
        echo "📦 [Issue] Re-applied the plan's work set aside for #$n on top of the fix."
    else
        echo "⚠️  [Issue] Re-applying the work set aside for #$n conflicts; it is kept as $ref ($sha). Resolve, then 'git stash drop $ref'." >&2
        return 0
    fi
    awk -v k="#$n" '$2 != k' "$buf" > "$tmp" && mv "$tmp" "$buf"
}

# _issue_restore_buffer: back to the plan a fix interrupted (the .prev slot).
_issue_restore_buffer() {
    local prev
    prev="$(head -n 1 "$PREV_FILE" 2>/dev/null | tr -d '[:space:]' || true)"
    if [ -n "$prev" ]; then
        echo "$prev" > "$ACTIVE_FILE"; rm -f "$PREV_FILE"
    else
        rm -f "$ACTIVE_FILE"
    fi
}

# cmd_issue_hotfix "<text>" [file <path>]… [plan] (P-52 2.1)
cmd_issue_hotfix() {
    local text="${1:-}" files=() want_plan=0 plans buf bound pf prel pid f n row loc today max count list slug t
    if [ -z "$text" ]; then
        echo "❌ [Issue] Usage: aapp issue hotfix \"<text>\" [file <path>]… [plan]" >&2
        return 1
    fi
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            file) [ $# -ge 2 ] || { echo "❌ [Issue] 'file' needs a path." >&2; return 1; }
                  files+=("$2"); shift 2 ;;
            plan) want_plan=1; shift ;;
            *)    echo "❌ [Issue] Unknown token '$1'. Usage: aapp issue hotfix \"<text>\" [file <path>]… [plan]" >&2; return 1 ;;
        esac
    done
    plans="$(_issue_plans_dir)" || return 1
    buf="$(git rev-parse --git-path aapp_active_plan 2>/dev/null)" || return 1
    bound="$(tr -d '[:space:]' < "$buf" 2>/dev/null || true)"
    case "$bound" in
        '') echo "❌ [Issue] No plan is bound in this worktree; a hotfix is raised from the plan it blocks ('aapp active <id>')." >&2; return 1 ;;
        '#'*) echo "❌ [Issue] A mini plan (#${bound#\#}) is bound here; raise the hotfix from the plan it blocks." >&2; return 1 ;;
    esac
    pf="$(_issue_plan_file_for "$plans" "$bound")" || {
        echo "❌ [Issue] The bound plan '$bound' is not in .plans/current/." >&2; return 1; }
    prel="current/$(basename "$pf")"
    pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
    [ -n "$pid" ] || pid="$bound"
    # Plan work vs hotfix is decided by scope, not by file (P-52): a file of the
    # plan's own targets is accepted.

    _issue_load_plan_lib || return 1
    _issue_lock_acquire || return 1
    n="$(allocate_issue_id)" || { _issue_lock_release; return 1; }
    n="${n#\#}"
    # Single-checkout mode: the fix will share this working copy, so the plan's
    # uncommitted work in the listed files is set aside (only those files).
    if [ ${#files[@]} -gt 0 ] && ! grep -q '^\* \*\*Worktree:\*\*' "$pf" && \
       [ -n "$(git status --porcelain -- "${files[@]}" 2>/dev/null)" ]; then
        if ! git stash push --include-untracked -q -m "aapp-hotfix:$pid:#$n" -- "${files[@]}"; then
            _issue_lock_release; echo "❌ [Issue] Could not stash the uncommitted work in ${files[*]}." >&2; return 1
        fi
        printf '%s #%s\n' "$(git rev-parse stash@{0})" "$n" >> "$(git rev-parse --git-path aapp_hotfix_stash)"
        echo "📦 [Issue] Set aside $pid's uncommitted work in ${files[*]}; 'aapp issue close $n' re-applies it." >&2
    fi
    today="$(date +%Y-%m-%d)"
    loc="—"
    if [ ${#files[@]} -gt 0 ]; then
        loc=""; for f in "${files[@]}"; do loc="${loc:+$loc, }\`$f\`"; done
    fi
    t="${text//|/\\|}"
    row="| #$n | \`High\` | \`CORE\` | $today | $loc | $t | blocks [$pid]($prel) | 🟡 \`Incubated\` |"
    AAPP_ROW="$row" awk '{ print } !d && /^\|[[:space:]]*:---/ { print ENVIRON["AAPP_ROW"]; d = 1 } END { if (!d) exit 3 }' \
        "$plans/ISSUES.md" > "$plans/ISSUES.md.aapp-hotfix.$$" || {
        rm -f "$plans/ISSUES.md.aapp-hotfix.$$"; _issue_lock_release
        echo "❌ [Issue] No table header separator in ISSUES.md." >&2; return 1; }
    mv "$plans/ISSUES.md.aapp-hotfix.$$" "$plans/ISSUES.md"
    [ "$want_plan" -eq 1 ] || _issue_queue_blocker "$plans/issues_road_map.md" "$n" "$text" "$pid"
    _issue_record_hotfix "$pf" "$n"
    plan_block_on "$pf" "$n" || [ $? -eq 3 ]
    max="$(git config --get aapp.maxEmergencyHotfixes 2>/dev/null)" || max=2
    case "$max" in ''|*[!0-9]*) max=2 ;; esac
    count="$(_issue_hotfix_list "$pf" | wc -l | tr -d ' ')"
    if [ "$count" -gt "$max" ] && ! grep -q '^\* \*\*Blocked On:\*\*.*hotfix limit reached' "$pf"; then
        list="$(_issue_hotfix_list "$pf" | paste -sd, - | sed 's/,/, /g')"
        sed -i -E "s|^(\* \*\*Blocked On:\*\*.*)$|\1; hotfix limit reached ($list)|" "$pf"
        echo "🛑 [Issue] $pid has had $count emergency hotfixes (limit $max): it stays BLOCKED until you re-scope it." >&2
    fi
    sync_state_matrix
    local paths=("ISSUES.md" "$prel")
    [ -f "$plans/issues_road_map.md" ] && paths+=("issues_road_map.md")
    [ -f "$plans/state_matrix.md" ] && paths+=("state_matrix.md")
    plans_commit "issue(hotfix): #$n blocks $pid" "${paths[@]}" || { _issue_lock_release; return 1; }
    _issue_lock_release
    echo "🧯 [Issue] #$n logged; $pid is blocked on it. Stop here: the fix runs in the main checkout ('aapp issue fix next-blocker')."
    if [ "$want_plan" -eq 1 ]; then
        slug="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | sed 's/[ _]/-/g' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//' | cut -c1-40)"
        cmd_draft "${slug:-issue-$n}" issue "$n" || return 1
    fi
}

# _issue_next_blocker <plans>: the top 🧱 Plan Blocker whose row is active and not Planned.
_issue_next_blocker() {
    local plans="$1" id row dirty f
    for id in $(awk '/^## 🧱 Plan Blockers/ { q = 1; next } /^## / { q = 0 } q' "$plans/issues_road_map.md" 2>/dev/null |
                sed -nE 's/^[[:space:]]*-[[:space:]]*\[[ ]?\][[:space:]]*#([0-9]+).*/\1/p'); do
        row="$(grep -m 1 -E "$(_issue_row_regex "$id")" "$plans/ISSUES.md" 2>/dev/null || true)"
        printf '%s' "$row" | grep -q 'Planned' && continue
        # Skip a blocker whose files have uncommitted changes here (P-52).
        dirty=0
        while IFS= read -r f; do
            [ -n "$f" ] && [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ] && dirty=1
        done < <(printf '%s\n' "$row" | sed 's/\\|/\x01/g' | awk -F'|' '{print $6}' | grep -oE '`[^`]+`' | tr -d '`' | sed -E 's/:[0-9][0-9,-]*$//')
        [ "$dirty" -eq 1 ] && continue
        [ "$(issue_locate "$id")" = "active" ] && { echo "$id"; return 0; }
    done
    return 1
}

# _issue_write_mini <plans> <n> <changelog-text> <file>…
_issue_write_mini() {
    local plans="$1" n="$2" text="$3" f mp
    shift 3
    mp="$plans/current/fix-$n.md"
    {
        echo "# 🩹 Issue Fix #$n: $text"
        echo "* **Plan ID:** #$n"
        echo "* **Target Issue / Milestone:** #$n"
        echo "* **Changelog:** Fixed: $text"
        echo "* **Status:** ⚡ In Development"
        echo "* **Commits:** none"
        echo ""
        echo "Temporary mini plan (P-52): deleted by \`aapp issue close $n\`; the issue row is the record."
        echo ""
        echo "## 💥 4. Blast Radius & System Boundaries"
        echo ""
        echo "### 📂 Target Files (Modifications & Additions)"
        for f in "$@"; do echo "- [ ] \`$f\`"; done
        echo ""
        echo "### 🛑 Out of Bounds (Do Not Touch)"
    } > "$mp"
}

# cmd_issue_fix next-blocker | <num> file <path>… | <num> abort (P-52 2.2, 2.5)
cmd_issue_fix() {
    local sub="${1:-}" n="" files=() plans open limit waited step row loc text f pf pid st t
    plans="$(_issue_plans_dir)" || return 1
    case "$sub" in
        '') echo "❌ [Issue] Usage: aapp issue fix next-blocker | <num> file <path>… | <num> abort" >&2; return 1 ;;
        next-blocker) shift ;;
        *) n="$(issue_normalize_id "$sub")" || return 1; shift
           if [ "${1:-}" = "abort" ]; then _issue_fix_abort "$plans" "$n"; return; fi ;;
    esac
    while [ $# -gt 0 ]; do
        case "$1" in
            file) [ $# -ge 2 ] || { echo "❌ [Issue] 'file' needs a path." >&2; return 1; }
                  files+=("$2"); shift 2 ;;
            *)    echo "❌ [Issue] Unknown token '$1'." >&2; return 1 ;;
        esac
    done
    _issue_load_plan_lib || return 1

    # Adding files to the open mini plan of #<num>.
    if [ -n "$n" ] && [ -f "$plans/current/fix-$n.md" ]; then
        [ ${#files[@]} -gt 0 ] || { echo "❌ [Issue] #$n is already being fixed; add files with 'file <path>'." >&2; return 1; }
        # Re-render with the combined list (the §4 parser stays in aapp-lib.sh),
        # keeping the changelog text and the recorded commits.
        local mp="$plans/current/fix-$n.md" all=() cl commits
        while IFS= read -r f; do [ -n "$f" ] && all+=("$f"); done < <(parse_plan_target_paths "$mp")
        for f in "${files[@]}"; do
            printf '%s\n' "${all[@]}" | grep -qxF "$f" || all+=("$f")
        done
        cl="$(sed -nE 's/^\* \*\*Changelog:\*\* Fixed: //p' "$mp" | head -n 1)"
        commits="$(grep -m 1 -E '^\* \*\*Commits:\*\*' "$mp")"
        _issue_write_mini "$plans" "$n" "$cl" "${all[@]}"
        AAPP_LINE="$commits" awk '/^\* \*\*Commits:\*\*/ && !d { print ENVIRON["AAPP_LINE"]; d = 1; next } { print }' "$mp" > "$mp.tmp" && mv "$mp.tmp" "$mp"
        plans_commit "fix(files): #$n" "current/fix-$n.md" || return 1
        echo "🩹 [Issue] #$n: files added (${files[*]})."
        return 0
    fi

    # One fix at a time: wait (verbose) while another mini plan is open.
    limit="$(_issue_wait_limit)"; waited=0; step=2
    while :; do
        if open="$(_issue_open_mini "$plans")"; then
            if [ "$waited" -ge "$limit" ]; then
                echo "⏳ [Issue] #$open is still being fixed; retry later." >&2
                return 1
            fi
            echo "⏳ [Issue] #$open is being fixed; waiting ${step}s…" >&2
            sleep "$step"; waited=$((waited + step)); step=$((step + 1))
            continue
        fi
        _issue_lock_acquire || return 1
        if open="$(_issue_open_mini "$plans")"; then _issue_lock_release; continue; fi
        break
    done

    if [ -z "$n" ]; then
        # With the aapp-issue-tracker provider installed, it is the authority
        # for the claim (fail closed, like `allocate`); otherwise the local queue.
        local root pdir entry pout raw
        root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
        pdir="$root/.agents/skills/aapp-issue-tracker"
        if [ -d "$pdir" ] && entry="$(resolve_plugin_entrypoint "$pdir" "aapp-issue-tracker" 2>/dev/null)"; then
            pout="$(run_action_plugin "$entry" "$root" next-blocker issue.next-blocker 2>/dev/null)" || {
                _issue_lock_release; echo "❌ [Issue] The aapp-issue-tracker provider refused next-blocker; not claiming locally." >&2; return 1; }
            raw="$(json_field "$pout" id)" || {
                _issue_lock_release; echo "❌ [Issue] Provider must print {\"id\": ...} for next-blocker (got: '$pout')." >&2; return 1; }
            n="$(issue_normalize_id "$raw")" || { _issue_lock_release; return 1; }
        else
            n="$(_issue_next_blocker "$plans")" || {
                _issue_lock_release; echo "❌ [Issue] No plan blockers are queued (🧱 Plan Blockers in issues_road_map.md)." >&2; return 1; }
        fi
    fi
    row="$(grep -m 1 -E "$(_issue_row_regex "$n")" "$plans/ISSUES.md" 2>/dev/null || true)"
    if [ -z "$row" ]; then
        _issue_lock_release; echo "❌ [Issue] #$n is not an active issue in ISSUES.md." >&2; return 1
    fi
    if [ ${#files[@]} -eq 0 ]; then
        loc="$(printf '%s\n' "$row" | sed 's/\\|/\x01/g' | awk -F'|' '{print $6}')"
        while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(printf '%s\n' "$loc" | grep -oE '`[^`]+`' | tr -d '`' | sed -E 's/:[0-9][0-9,-]*$//')
    fi
    if [ ${#files[@]} -eq 0 ]; then
        _issue_lock_release; echo "❌ [Issue] No files known for #$n: give them with 'file <path>'." >&2; return 1
    fi
    # The only real hazard: uncommitted changes in these files would mix into
    # the fix commit. Which plan lists a file no longer matters (P-52).
    for f in "${files[@]}"; do
        if [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]; then
            _issue_lock_release
            echo "❌ [Issue] $f has uncommitted changes here; commit or stash them first." >&2
            return 1
        fi
    done
    text="$(printf '%s\n' "$row" | sed 's/\\|/\x01/g' | awk -F'|' '{print $8}' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    case "$text" in
        blocks\ \[*|'') text="$(printf '%s\n' "$row" | sed 's/\\|/\x01/g' | awk -F'|' '{print $7}' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')" ;;
    esac
    text="$(printf '%s' "$text" | tr '\001' '|')"
    _issue_write_mini "$plans" "$n" "$text" "${files[@]}"
    write_active_buffer "#$n"
    plans_commit "fix(start): #$n" "current/fix-$n.md" || { _issue_lock_release; return 1; }
    _issue_lock_release
    echo "🩹 [Issue] Fixing #$n in current/fix-$n.md (files: ${files[*]}). Commit with 'aapp commit', then 'aapp issue close $n'."
}

# _issue_fix_abort <plans> <n>: drop an uncommitted mini plan; the issue stays.
_issue_fix_abort() {
    local plans="$1" n="$2" mp
    mp="$plans/current/fix-$n.md"
    [ -f "$mp" ] || { echo "❌ [Issue] #$n has no open fix." >&2; return 1; }
    if [ -n "$(parse_plan_commits "$mp" 2>/dev/null)" ]; then
        echo "❌ [Issue] #$n's fix has recorded commits; close it with 'aapp issue close $n'." >&2
        return 1
    fi
    _issue_load_plan_lib || return 1
    rm -f "$mp"
    _issue_restore_buffer
    plans_commit "fix(abort): #$n" "current/fix-$n.md" || return 1
    echo "↩️  [Issue] #$n's fix abandoned; the issue stays open."
}

cmd_issue() {
    local sub="${1:-next}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        next)     cmd_issue_next "$@" ;;
        allocate) cmd_issue_allocate "$@" ;;
        hotfix)   cmd_issue_hotfix "$@" ;;
        fix)      cmd_issue_fix "$@" ;;
        close)    cmd_issue_close "$@" ;;
        list)     cmd_issue_list "$@" ;;
        *)
            echo "❌ [Issue] Unknown subcommand '$sub'." >&2
            echo "Usage: aapp issue [next | allocate | hotfix \"<text>\" [file <path>]… [plan] | fix next-blocker | fix <num> file <path>… | fix <num> abort | close <id> [sha <sha>] [summary \"<text>\"] | list [<n> | all]]" >&2
            return 1
            ;;
    esac
}
