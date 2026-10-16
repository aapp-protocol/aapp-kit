#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `status`
#
# Context Recovery briefing across all 4 pillars:
# 1. Shipped   (CHANGELOG.md ## [Unreleased] / recent code)
# 2. Issues    (ISSUES.md and .plans/issues_road_map.md)
# 3. Plans     (.plans/state_matrix.md active plans)
# 4. Pickup    (.plans/pickup.md unprocessed ideas)
#
# Every section is collected into records first (tab-separated lines, raw
# values); a renderer prints them and computes nothing (P-91, P-92).
#
# An observer of the code: it never touches a working tree. On the plans branch
# it re-derives the state matrix and unblocks the plans whose fix has reached
# their parent branch (P-78).
# ==============================================================================
set -e

# REPO_ROOT is exported by the `aapp` dispatcher (P-33).
if [ -z "$REPO_ROOT" ]; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

cd "$REPO_ROOT"

# Source planning_health, plan_resolver and the output renderers.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for STATUS_LIB_FILE in planning_health.sh plan_resolver.sh output.sh; do
    if [ -f "$SCRIPT_DIR/$STATUS_LIB_FILE" ]; then
        source "$SCRIPT_DIR/$STATUS_LIB_FILE"
    elif [ -f "$REPO_ROOT/lib/$STATUS_LIB_FILE" ]; then
        source "$REPO_ROOT/lib/$STATUS_LIB_FILE"
    fi
done

# The status registry names each plan's status as a slug (P-30).
if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/plan_states.sh" ]; then
    # shellcheck source=/dev/null
    . "$AAPP_LIB/plan_states.sh" && { plan_states_load 2>/dev/null || true; }
fi

# status_rows <records>: the records with their tabs as \037, so that `read`
# keeps empty fields (a tab is whitespace to IFS, and runs of it would merge).
status_rows() { printf '%s\n' "$1" | tr '\t' '\037'; }

ADOPTION_LIB="${AAPP_BASE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/adoption.sh"
if [ -f "$ADOPTION_LIB" ]; then
    # shellcheck source=/dev/null
    source "$ADOPTION_LIB"
elif [ -f "$(dirname "${BASH_SOURCE[0]}")/adoption.sh" ]; then
    # shellcheck source=/dev/null
    source "$(dirname "${BASH_SOURCE[0]}")/adoption.sh"
fi

# ------------------------------------------------------------------------------
# Records: one function per section, tab-separated lines, raw values.
# ------------------------------------------------------------------------------

# status_issues_file / status_roadmap_file -> the ledger files, when present.
status_issues_file() { local f; f="$(ledger_path issues)" || return 0; [ -f "$f" ] && echo "$f"; return 0; }
status_roadmap_file() { local f; f="$(ledger_path roadmap)" || return 0; [ -f "$f" ] && echo "$f"; return 0; }

# status_state_matrix -> the state matrix, when present.
status_state_matrix() {
    if [ -f ".plans/state_matrix.md" ]; then echo ".plans/state_matrix.md"
    elif [ -f "state_matrix.md" ]; then echo "state_matrix.md"; fi
    return 0
}

# status_number_setting <key> <default>: a briefing setting that is a whole
# number of at least 1; fails, naming the key, otherwise.
status_number_setting() {
    local v
    v="$(git config --get "$1" 2>/dev/null)" || v="$2"
    case "$v" in ''|*[!0-9]*) ;; *) [ "$v" -ge 1 ] && { echo "$v"; return 0; } ;; esac
    echo "❌ [Status] $1 is '$v'; it must be a whole number of at least 1." >&2
    return 1
}
# status_items_max -> `aapp.statusItemsMax` (default 5): how many Shipped entries and pickup ideas the briefing lists.
status_items_max() { status_number_setting aapp.statusItemsMax 5; }
# status_text_max -> `aapp.statusTextMax` (default 220): the most characters of an item's text the briefing shows.
status_text_max() { status_number_setting aapp.statusTextMax 220; }

# status_changelog_path -> the changelog the briefing reads, when present.
status_changelog_path() {
    if [ -f "CHANGELOG.md" ]; then echo "CHANGELOG.md"
    elif [ -f ".plans/CHANGELOG.md" ]; then echo ".plans/CHANGELOG.md"; fi
    return 0
}

# status_pickup_lines -> the unworked pickup entries, as written.
status_pickup_lines() {
    [ -f ".plans/pickup.md" ] || return 0
    grep -E '^[0-9]+\.|^[\*-] ' ".plans/pickup.md" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '\[x\]|\[X\]' || true
}

# status_records_overview -> issues, next_issues, plans, roadmap_plans, pickup,
# adoption: the counts of `status short`; the id lists comma-separated.
status_records_overview() {
    local issues=0 next="" plans=0 roadmap="" pickup adoption=0 matrix
    if [ -n "$(status_issues_file)" ]; then issues="$(ledger_row_lines | wc -l | tr -d ' ')"; fi
    if [ -n "$(status_roadmap_file)" ]; then next="$(roadmap_entries | issue_id_refs | head -n 3 | paste -sd, - || true)"; fi
    if [ -d ".plans/current" ]; then
        plans="$(find .plans/current -maxdepth 1 -name "*.md" ! -name "000-*" 2>/dev/null | wc -l | tr -d ' ')"
    fi
    matrix="$(status_state_matrix)"
    if [ -n "$matrix" ]; then
        roadmap="$(awk '/## 🚦 Recommended Implementation Roadmap/ {flag=1; next} /^## / {flag=0} flag' "$matrix" 2>/dev/null | grep -o -E 'P-[0-9]+' | head -n 3 | paste -sd, - || true)"
    fi
    pickup="$(status_pickup_lines | grep -c . || true)"
    if command -v adoption_open_count >/dev/null 2>&1; then
        adoption="$(adoption_open_count ".plans/adoption.md")"
    elif [ -f ".plans/adoption.md" ]; then
        adoption="$(grep -cE '^- \[ \] `\[' ".plans/adoption.md" 2>/dev/null || echo 0)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$issues" "$next" "$plans" "$roadmap" "${pickup:-0}" "${adoption:-0}"
}

# status_records_templates -> file, reason: one per template that drifted.
status_records_templates() {
    local version="${AAPP_VERSION:-1.0.0}"
    if [ -f ".plans/plan-template.md" ]; then
        if grep -q -E "Draft|Ready for Execution" ".plans/plan-template.md" 2>/dev/null && ! grep -q "🔷 Frozen" ".plans/plan-template.md" 2>/dev/null; then
            printf '%s\t%s\n' ".plans/plan-template.md" "carries retired enum"
        elif ! grep -q -E "^[[:space:]]*<!-- AAPP-PROTOCOL:START v$version -->" ".plans/plan-template.md" 2>/dev/null; then
            printf '%s\t%s\n' ".plans/plan-template.md" "carries drifted protocol block"
        fi
    fi
    if [ -f ".agents/AGENTS.md" ] && ! grep -q -E "^[[:space:]]*<!-- AAPP-PROTOCOL:START v$version -->" ".agents/AGENTS.md" 2>/dev/null; then
        printf '%s\t%s\n' ".agents/AGENTS.md" "carries drifted protocol block"
    fi
    return 0
}

# status_pause_files -> the local pause buffer and the team's PAUSED.md, one per line.
status_pause_files() {
    local common primary shared=""
    common="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
    if [ -d "$common" ]; then primary="$(cd "$common/.." 2>/dev/null && pwd)"; else primary="$REPO_ROOT"; fi
    if [ -d "$REPO_ROOT/.plans" ]; then shared="$REPO_ROOT/.plans/PAUSED.md"
    elif [ -n "$primary" ] && [ -d "$primary/.plans" ]; then shared="$primary/.plans/PAUSED.md"; fi
    printf '%s\n%s\n' "$common/aapp_paused" "$shared"
}

# status_records_pause -> nothing when not paused; otherwise one record:
# scope (local, team), reason, paused_at, paused_label, stashes
# (`<worktree>|<branch>` comma-separated, the worktree relative to the
# repository), initiator, buffer, parsed (1 when the buffer was read), error.
status_records_pause() {
    local files local_f shared_f out
    files="$(status_pause_files)"; local_f="$(printf '%s\n' "$files" | sed -n 1p)"; shared_f="$(printf '%s\n' "$files" | sed -n 2p)"
    if [ -f "$local_f" ] && command -v python3 >/dev/null 2>&1; then
        out="$(python3 -c '
import json, sys, datetime, os
root = sys.argv[2]
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    reason = d.get("reason", "unspecified")
    ts = d.get("timestamp", "")
    label = ts
    if ts:
        try:
            dt = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
            mins = int((datetime.datetime.now(datetime.timezone.utc) - dt).total_seconds() // 60)
            if mins < 1: rel = "just now"
            elif mins == 1: rel = "1 minute ago"
            elif mins < 60: rel = f"{mins} minutes ago"
            elif mins < 1440: rel = f"{mins // 60} hour(s) ago"
            else: rel = f"{mins // 1440} day(s) ago"
            label = dt.strftime("%Y-%m-%d %H:%M:%S") + " (" + rel + ")"
        except Exception:
            label = ts
    stashes = []
    for s in d.get("snapshot", {}).get("stashes", []):
        wt = s.get("worktree", "")
        rel_wt = os.path.relpath(wt, root) if wt else ""
        stashes.append(rel_wt + "|" + (s.get("branch") or ""))
    clean = lambda v: str(v).replace("\t", " ").replace("\n", " ")
    print("\t".join(["local", clean(reason), clean(ts), clean(label), ",".join(stashes), "", "", "1", ""]))
except Exception as e:
    print("\t".join(["local", "", "", "", "", "", "", "0", str(e).replace("\t", " ").replace("\n", " ")]))
' "$local_f" "$REPO_ROOT")"
        printf '%s\n' "$out"
    elif [ -n "$shared_f" ] && [ -f "$shared_f" ]; then
        field() { grep -m 1 -E "^\*[[:space:]]+\*\*$1:\*\*" "$shared_f" | sed -E "s/^\*[[:space:]]*\*\*$1:\*\*[[:space:]]*//" || true; }
        printf 'team\t%s\t%s\t\t\t%s\t%s\t1\t\n' "$(field Reason)" "$(field Timestamp)" "$(field Initiator)" ".plans/PAUSED.md"
    elif [ -f "$local_f" ]; then
        printf 'local\t\t\t\t\t\t%s\t0\t\n' "$local_f"
    fi
    return 0
}

# status_records_shipped -> kind (entry, more), section, text, plan, issue,
# commit, date (P-88): the entries the latest commits of this branch added to
# the changelog, newest first, each once, in its current wording, up to
# `aapp.statusItemsMax`; an entry no longer in the file is skipped. With no
# history (no commits, a shallow clone, a changelog outside Git): the first
# entries under `## [Unreleased]`, without commit and date. plan / issue: the
# id an entry is tagged with. A last `more` record counts the entries under
# `## [Unreleased]` not shown.
status_records_shipped() {
    local cl dir file max hist
    cl="$(status_changelog_path)"
    [ -n "$cl" ] || return 0
    max="$(status_items_max)" || return 1
    if [ "$cl" = ".plans/CHANGELOG.md" ]; then dir=".plans"; file="CHANGELOG.md"; else dir="."; file="$cl"; fi
    hist="$(git -C "$dir" log -n 15 --first-parent -m -p --unified=0 --format='commit %h %ad' --date=short -- "$file" 2>/dev/null || true)"
    printf '%s\n' "$hist" | awk -v max="$max" -v cl="$cl" '
        function tags(t) {
            plan = ""; iss = ""
            if (match(t, /\(`?P-[0-9]+`?\)[[:space:]]*$/)) { plan = substr(t, RSTART, RLENGTH); gsub(/[^P0-9-]/, "", plan) }
            else if (match(t, /\(`?#[A-Za-z0-9-]+`?\)[[:space:]]*$/)) { iss = substr(t, RSTART, RLENGTH); gsub(/[()` ]/, "", iss) }
        }
        function emit(t, c, d) { tags(t); printf "entry\t%s\t%s\t%s\t%s\t%s\t%s\n", sec[t], t, plan, iss, c, d; shown++; if (t in unrel) shownu++ }
        BEGIN {
            # The changelog as it is now: each entry with its section, and the
            # entries under [Unreleased] in order.
            while ((getline l < cl) > 0) {
                if (l ~ /^## /) { u = (l ~ /^## \[Unreleased\]/); s = ""; continue }
                if (l ~ /^###[[:space:]]+/) { s = l; sub(/^###[[:space:]]+/, "", s); s = tolower(s); continue }
                if (l ~ /^-[[:space:]]+/) { t = l; sub(/^-[[:space:]]+/, "", t); if (!(t in sec)) sec[t] = s; if (u) { unrel[t] = 1; order[++nu] = t } }
            }
        }
        /^commit / { c = $2; d = $3; next }
        /^\+-[[:space:]]+/ {
            t = substr($0, 2); sub(/^-[[:space:]]+/, "", t)
            if (!(t in sec) || (t in seen) || shown >= max) next
            seen[t] = 1; emit(t, c, d)
        }
        END {
            if (!shown) for (i = 1; i <= nu && shown < max; i++) emit(order[i], "", "")
            if (nu - shownu > 0) printf "more\t\t%d\t\t\t\t\n", nu - shownu
        }'
}

# status_records_issues -> the work queue as `ledger_issue_records` records, the
# plan blockers then the queued issues by level, this branch's first once an
# issue names a branch; then the issues staged offline. An empty queue gives
# no queue record (#154).
status_records_issues() {
    local ids
    if [ -n "$(status_roadmap_file)" ]; then
        ids="$( { roadmap_blockers; roadmap_queued; } | awk '!seen[$0]++')"
        if [ -n "$ids" ]; then
            # shellcheck disable=SC2086
            ledger_issue_records $ids | awk -F'\t' '$14 == 0' |
                issue_records_by_branch "$(status_issue_branches | sed -n 1p)" "$(status_issue_branches | sed -n 2p)"
        fi
    fi
    if command -v ledger_offline_rows >/dev/null 2>&1 && [ -n "$(ledger_offline_rows 2>/dev/null || true)" ]; then
        # shellcheck disable=SC2046
        ledger_issue_records $(ledger_offline_rows | cut -f1) | awk -F'\t' '$14 == 1'
    fi
    return 0
}

# status_unqueued_count -> how many active issues are not on the work queue.
status_unqueued_count() {
    local queue
    [ -n "$(status_issues_file)" ] || { echo 0; return 0; }
    queue="$( { roadmap_blockers; roadmap_queued; } 2>/dev/null | sed 's/^/#/')"
    ledger_rows | cut -f1 | while IFS= read -r QID; do printf '%s\n' "$queue" | grep -qxF -- "$QID" || echo "$QID"; done | grep -c . || true
}

# status_issue_branches -> the branch issues are seen from and the development
# branch (P-78), one per line, once an issue names a branch.
status_issue_branches() {
    [ -n "$(status_issues_file)" ] && [ -n "$(ledger_branch_map)" ] && [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/cmd_issue.sh" ] || return 0
    (
        # shellcheck source=/dev/null
        . "$AAPP_LIB/cmd_issue.sh" 2>/dev/null || exit 0
        echo "$(issue_view_branch)"; echo "$(_issue_dev_branch)"
    )
}

# status_records_plans -> id, file, title, status, status_label, kind (plan,
# group), group, members (comma-separated), target_issue, blocked_on
# (comma-separated), worktree, branch, feature_branch, depth (0, or 1 for a
# member listed under its group), in briefing order.
status_records_plans() {
    local P GRP M MF
    [ -d ".plans/current" ] || return 0
    while IFS= read -r -d '' P; do
        GRP="$(parse_plan_field "$P" Group)"
        if [ -n "$GRP" ] && ls .plans/current/P"${GRP#P-}"-*.md >/dev/null 2>&1; then continue; fi
        status_plan_record "$P" 0
        if aapp_is_group_plan "$P"; then
            for M in $(group_members "$P"); do
                for MF in .plans/current/P"${M#P-}"-*.md; do
                    [ -f "$MF" ] && status_plan_record "$MF" 1
                done
            done
        fi
    done < <(find .plans/current -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
    return 0
}

# status_plan_record <file> <depth>: one plan's record.
status_plan_record() {
    local P="$1" base sline label id="" slug="" title kind=plan grp members="" target blocked wt="" wtb="" fb rec
    base="$(basename "$P")"
    sline="$(grep -m 1 -E '^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*' "$P" 2>/dev/null || echo "* **Status:** 🟣 Active")"
    label="$(echo "$sline" | sed -E 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*[[:space:]]*//')"
    if command -v get_plan_id >/dev/null 2>&1; then id="$(get_plan_id "$P" 2>/dev/null || true)"; fi
    if command -v plan_state_for_status_line >/dev/null 2>&1; then slug="$(plan_state_for_status_line "$sline" 2>/dev/null || true)"; fi
    title="$(grep -m 1 -E '^# ' "$P" | sed -E 's/^#[[:space:]]*(🗺️[[:space:]]*|🧩[[:space:]]*Group[[:space:]]+)?Plan[^:]*:[[:space:]]*//')"
    if aapp_is_group_plan "$P"; then kind=group; members="$(group_members "$P" | paste -sd, - || true)"; fi
    grp="$(parse_plan_field "$P" Group)"
    target="$(parse_plan_field "$P" "Target Issue / Milestone" | grep -oE '^#[A-Za-z0-9-]+' || true)"
    blocked="$(parse_plan_field "$P" "Blocked On" | grep -oE '#[A-Za-z0-9-]+' | paste -sd, - || true)"
    rec="$(parse_plan_worktree "$P")"
    if [ -n "$rec" ]; then wt="${rec%%$'\t'*}"; wtb="${rec#*$'\t'}"; fi
    fb="$(parse_plan_field "$P" "Feature Branch")"; [ "$fb" = "none" ] && fb=""
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$base" "$title" "$slug" "$label" "$kind" "$grp" "$members" "$target" "$blocked" "$wt" "$wtb" "$fb" "$2"
}

# status_records_pickup -> title, text, files: one per unworked entry, split by
# `pickup_entry_split`; files are the `.plans/pickup/` paths the entry names
# that exist, comma-separated.
status_records_pickup() {
    local line split title text files path
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        split="$(pickup_entry_split "$line")"
        title="${split%%$'\t'*}"; text="${split#*$'\t'}"
        files=""
        while IFS= read -r path; do
            [ -n "$path" ] && [ -e "$path" ] && files="${files:+$files,}$path"
        done < <(pickup_entry_files "$text")
        printf '%s\t%s\t%s\n' "$title" "$text" "$files"
    done < <(status_pickup_lines)
    return 0
}

# status_records_adoption -> source, open: the adoption checklist and its open tasks.
status_records_adoption() {
    printf '%s\t%s\n' ".plans/adoption.md" "$(status_records_overview | cut -f6)"
}

# status_records_offline -> nothing unless `.offline` holds work; otherwise one
# record: issues, archived (ids), plans (files), each comma-separated, outbox.
status_records_offline() {
    local d active archived plans steps
    command -v offline_mounted >/dev/null 2>&1 && offline_mounted || return 0
    d="$(offline_dir)"
    active="$(ledger_offline_ids active | sed 's/^/#/' | paste -sd, - || true)"
    archived="$(ledger_offline_ids archive | sed 's/^/#/' | paste -sd, - || true)"
    plans="$(ls "$d"/current/P*.md 2>/dev/null | sed 's|.*/|current/|' | paste -sd, - || true)"
    steps="$(grep -c . "$d/outbox" 2>/dev/null || true)"
    if [ -n "$active$archived$plans" ] || [ "${steps:-0}" -gt 0 ]; then
        printf '%s\t%s\t%s\t%s\n' "$active" "$archived" "$plans" "${steps:-0}"
    fi
    return 0
}

# status_records_next -> kind, text, command: the next action.
status_records_next() {
    local files local_f shared_f buffer active="" lane frozen="" incubator="" first ov pickup
    files="$(status_pause_files)"; local_f="$(printf '%s\n' "$files" | sed -n 1p)"; shared_f="$(printf '%s\n' "$files" | sed -n 2p)"
    buffer="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || true)"
    [ -f "$buffer" ] && active="$(tr -d '[:space:]' < "$buffer" 2>/dev/null || true)"
    # Resolved from each plan's own Status line via the status registry (P-30
    # §2.6), not by matching matrix headings.
    if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/plan_states.sh" ] && [ -d ".plans/current" ]; then
        lane="$(
            # shellcheck source=/dev/null
            . "$AAPP_LIB/plan_states.sh" 2>/dev/null || exit 0
            plan_states_load 2>/dev/null || exit 0
            heading="$(plan_state_field under-review heading 2>/dev/null || true)"
            for PF in .plans/current/*.md; do
                [ -f "$PF" ] || continue
                case "$(basename "$PF")" in 000-*|plan-template.md) continue ;; esac
                PID="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$PF" 2>/dev/null | head -n 1)"
                [ -z "$PID" ] && continue
                SLINE="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$PF" 2>/dev/null | head -n 1)"
                SLUG="$(plan_state_for_status_line "$SLINE" 2>/dev/null || true)"
                [ -z "$SLUG" ] && continue
                if [ "$SLUG" = "frozen" ]; then echo "frozen $PID"
                elif [ -n "$heading" ] && [ "$(plan_state_field "$SLUG" heading 2>/dev/null || true)" = "$heading" ]; then echo "incubator $PID"; fi
            done
        )"
        frozen="$(echo "$lane" | awk '$1=="frozen"{print $2; exit}')"
        incubator="$(echo "$lane" | awk '$1=="incubator"{print $2; exit}')"
    fi
    ov="$(status_records_overview)"
    first="$(printf '%s\n' "$ov" | cut -f2 | cut -d, -f1)"
    pickup="$(printf '%s\n' "$ov" | cut -f5)"
    if [ -f "$local_f" ] || { [ -n "$shared_f" ] && [ -f "$shared_f" ]; }; then
        printf 'paused\t%s\t%s\n' "Project is PAUSED. Run 'aapp resume' to wake, or refine notes in .plans/ (pickup, issues, current)." "aapp resume"
    elif ! { [ -d ".plans" ] && [ -d ".agents" ] && [ -d ".githooks" ]; }; then
        printf 'init\t%s\t%s\n' "Run 'aapp init' to complete AAPP worktree setup." "aapp init"
    elif [ "${pickup:-0}" -gt 0 ]; then
        printf 'digest\t%s\t%s\n' "Run '/aapp-digest <idea>' (or 'aapp digest <idea>') to work a queued pickup idea." "aapp digest <idea>"
    elif [ -n "$active" ]; then
        printf 'in-development\t%s\t%s\n' "In development on $active. Run 'aapp active' to inspect boundaries." "aapp active"
    elif [ -n "$frozen" ]; then
        printf 'start\t%s\t%s\n' "Activate frozen plan $frozen: run '/aapp-start $frozen' (or 'aapp start $frozen')." "aapp start $frozen"
    elif [ -n "$first" ]; then
        printf 'issue\t%s\t%s\n' "Promote or resolve next open issue $first, or inspect .plans/issues_road_map.md." "aapp issue fix ${first#\#}"
    elif [ -n "$incubator" ]; then
        printf 'freeze\t%s\t%s\n' "Review incubator plan $incubator, or run '/aapp-freeze $incubator' when ready." "aapp freeze $incubator"
    else
        printf 'plan\t%s\t%s\n' "Run '/aapp-plan' to draft a new blueprint, or 'aapp help' to browse available commands." "aapp draft <slug>"
    fi
}

# status_notices -> level (info, warning), section, place (before, after: the
# side of the section's items it is printed on), text: every remark a section
# makes. Reads what the briefing's own steps said (STATUS_SYNC_OUT,
# STATUS_UNBLOCK_OUT, STATUS_MATRIX_OUT).
status_notices() {
    local line level gone_id gone_branch dev drift text path
    notice() { case "$3" in ⚠️*|❌*) level=warning ;; *) level=info ;; esac; printf '%s\t%s\t%s\t%s\n' "$level" "$1" "$2" "$3"; }
    while IFS= read -r line; do [ -n "$line" ] && notice issues after "$line"; done <<< "${STATUS_SYNC_OUT:-}"
    # P-78: an issue whose branch is gone is fixed on the development branch.
    if [ -n "$(status_issues_file)" ]; then
        dev="$(status_issue_branches | sed -n 2p)"
        while IFS="$(printf '\t')" read -r gone_id gone_branch; do
            [ -n "$gone_branch" ] || continue
            aapp_branch_ref "$gone_branch" >/dev/null && continue
            notice issues after "⚠️  $gone_id targets '$gone_branch', which no longer exists: its fix will land on '${dev:-the development branch}' (another target: aapp refine issues \"<msg>\" branch ${gone_id#\#} <name>)."
        done < <(ledger_branch_map)
    fi
    if [ -n "$(status_roadmap_file)" ] && [ -n "$(status_issues_file)" ] && command -v check_pair2_referential_integrity >/dev/null 2>&1; then
        drift="$(check_pair2_referential_integrity "$(status_roadmap_file)" "$(status_issues_file)" 2>/dev/null || true)"
        while IFS= read -r line; do [ -n "$line" ] && notice issues after "$line"; done <<< "$drift"
    fi
    while IFS= read -r line; do [ -n "$line" ] && notice plans before "$line"; done <<< "${STATUS_UNBLOCK_OUT:-}"
    case "${STATUS_MATRIX_OUT:-}" in
        *"Re-derived"*)
            case "${STATUS_MATRIX_OUT:-}" in
                *"PAUSED"*) notice plans after "🔄 [Matrix] state_matrix.md re-derived from .plans/current/ (uncommittable until 'aapp resume')" ;;
                *) notice plans after "🔄 [Matrix] state_matrix.md re-derived from .plans/current/ (review and commit the diff)" ;;
            esac ;;
    esac
    # A pickup entry that names a `.plans/pickup/` file this machine lacks.
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        text="$(pickup_entry_split "$line" | cut -f2-)"
        while IFS= read -r path; do
            [ -n "$path" ] && [ ! -e "$path" ] && notice pickup after "⚠️  $(pickup_entry_split "$line" | cut -f1): names $path, which is not on this machine."
        done < <(pickup_entry_files "$text")
    done < <(status_pickup_lines)
    return 0
}

# ------------------------------------------------------------------------------
# The terminal renderer: prints the records, computes nothing.
# ------------------------------------------------------------------------------

# status_line <first-indent> <hang-indent> <text>: one line of the briefing,
# wrapped at the width.
status_line() { printf '%s\n' "$3" | out_wrap "$1" "$2" "$STATUS_WIDTH"; }

# status_notice_lines <section> <place>: the notices of a section, as lines.
status_notice_lines() {
    local level sec place text
    while IFS=$'\037' read -r level sec place text; do
        [ "$sec" = "$1" ] && [ "$place" = "$2" ] && status_line 2 4 "$text"
    done < <(status_rows "$STATUS_NOTICES")
    return 0
}

# status_overview_line -> the `📊 Overview:` line.
status_overview_line() {
    local issues next plans roadmap pickup adoption line
    IFS=$'\037' read -r issues next plans roadmap pickup adoption < <(status_rows "$STATUS_OVERVIEW")
    next="${next//,/, }"; roadmap="${roadmap//,/, }"
    line="📊 Overview: $issues issues (Next: ${next:-none}) | $plans plans (Roadmap: ${roadmap:-none}) | $pickup pickup"
    [ "${adoption:-0}" -gt 0 ] && line="$line | $adoption adoption"
    printf '%s\n' "$line"
}

status_render_terminal() {
    local frame version count first files sname reason label stashes initiator buffer parsed error names s wt br
    local kind sec text cnt title t id base st lbl k g m tg bl w wb fb depth line active archived plans steps fl f
    frame="$(printf '%*s' "$STATUS_WIDTH" '' | tr ' ' '=')"
    version="${AAPP_VERSION:-1.0.0}"

    echo "$frame"
    status_line 2 4 "🧭 AAPP Context Recovery Briefing"
    status_line 2 4 "📍 Repo: $REPO_ROOT"
    status_line 2 4 "$(status_overview_line)"
    count="$(printf '%s' "$STATUS_TEMPLATES" | grep -c . || true)"
    first="$(printf '%s\n' "$STATUS_TEMPLATES" | head -n 1 | tr '\t' ' ')"
    if [ "$count" -eq 0 ]; then status_line 2 4 "📑 Templates:  All worktree templates synced (v$version)"
    elif [ "$count" -eq 1 ]; then status_line 2 4 "📑 Templates:  1 template drifted -> run 'aapp init' ($first)"
    else status_line 2 4 "📑 Templates:  $count templates drifted -> run 'aapp init' ($first, ...)"; fi
    echo "$frame"

    # 0. Master Emergency Brake / Pause Banner
    if [ -n "$STATUS_PAUSE" ]; then
        IFS=$'\037' read -r sname reason t label stashes initiator buffer parsed error < <(status_rows "$STATUS_PAUSE")
        echo ""
        echo "🛑 PROJECT STATUS: PAUSED"
        if [ "$sname" = "team" ]; then
            echo "   Scope  : Team-Wide (.plans/PAUSED.md)"
            [ -z "$reason" ] || echo "   Reason : $reason"
            [ -z "$t" ] || echo "   Timestamp : $t"
            [ -z "$initiator" ] || echo "   Initiator : $initiator"
        elif [ "$parsed" = "1" ]; then
            echo "   Reason : $reason"
            echo "   Paused : $label"
            if [ -n "$stashes" ]; then
                names=""
                IFS=',' read -r -a s <<< "$stashes"
                for line in "${s[@]}"; do
                    wt="${line%%|*}"; br="${line#*|}"
                    wt="$(basename "$wt")"; [ -n "$br" ] && wt="$wt ($br)"
                    names="${names:+$names, }$wt"
                done
                echo "   Stashes: ${#s[@]} worktree(s) quarantined ($names)"
            else
                echo "   Stashes: 0 worktrees quarantined (clean on pause)"
            fi
        elif [ -n "$error" ]; then
            echo "   (Failed to parse pause buffer: $error)"
        else
            echo "   Buffer : $buffer"
        fi
        if [ "$parsed" = "1" ] || [ -z "$error" ]; then
            echo "   Notice : All codebase modifications and commits are strictly refused."
            echo "   To resume: aapp resume"
        fi
    fi

    # 1. Shipped
    echo ""
    echo "📦 [1/4] SHIPPED (Recently Landed / Unreleased)"
    if [ -z "$(status_changelog_path)" ]; then
        echo "  (CHANGELOG.md not found)"
    elif [ -z "$STATUS_SHIPPED" ]; then
        echo "  (No unreleased changelog entries yet)"
    else
        while IFS=$'\037' read -r kind sec text _; do
            case "$kind" in
                entry) printf -- '- %s\n' "$(printf '%s' "$text" | out_cut "$STATUS_TEXT_MAX")" | out_wrap 2 4 "$STATUS_WIDTH" ;;
                more)  status_line 2 3 "(more in $(status_changelog_path))" ;;
            esac
        done < <(status_rows "$STATUS_SHIPPED")
    fi

    # 2. Issues
    echo ""
    echo "🐛 [2/4] ISSUES (Work Queue & Ledger)"
    if [ -n "$STATUS_ISSUES" ]; then
        printf '%s\n' "$STATUS_ISSUES" |
            issue_records_by_branch "$(printf '%s\n' "$STATUS_BRANCHES" | sed -n 1p)" "$(printf '%s\n' "$STATUS_BRANCHES" | sed -n 2p)" fill |
            issue_render_terminal "$STATUS_WIDTH" "$STATUS_TEXT_MAX"
    fi
    if [ -z "$STATUS_ISSUES" ] && [ "${STATUS_UNQUEUED:-0}" -eq 0 ]; then
        status_line 2 3 "(No open issues)"
    elif [ -z "$STATUS_ISSUES" ]; then
        status_line 2 3 "(Nothing queued for work: a person queues an issue with 'aapp issue queue <num>')"
    fi
    if [ "${STATUS_UNQUEUED:-0}" -gt 0 ]; then
        status_line 2 4 "ℹ️  $STATUS_UNQUEUED more issue(s) logged, not queued for work: aapp issue list"
    fi
    status_notice_lines issues after

    # 3. Plans
    echo ""
    echo "🗺️  [3/4] PLANS (State Matrix / Active Blueprints)"
    status_notice_lines plans before
    if [ -d ".plans/current" ]; then
        if [ -z "$STATUS_PLANS" ]; then
            status_line 2 3 "(No active plans in .plans/current/)"
        else
            while IFS=$'\037' read -r id base title st lbl k g m tg bl w wb fb depth; do
                [ -n "$base" ] || continue
                [ -n "$w" ] && lbl="$lbl → $w"
                line="$base  ($lbl)"; [ -n "$id" ] && line="$id: $line"
                if [ "$depth" = "1" ]; then status_line 6 8 "↳ $line"; else status_line 2 4 "• $line"; fi
            done < <(status_rows "$STATUS_PLANS")
        fi
        status_notice_lines plans after
    else
        status_line 2 3 "(.plans/ worktree not mounted. Run 'aapp init' to mount)"
    fi

    # 4. Pickup
    echo ""
    echo "💡 [4/4] PICKUP QUEUE (Unprocessed Ideas)"
    if [ -f ".plans/pickup.md" ]; then
        if [ -n "$STATUS_PICKUP" ]; then
            cnt="$(printf '%s\n' "$STATUS_PICKUP" | grep -c . || true)"
            echo "  ($cnt unworked ideas found in pickup.md):"
            while IFS=$'\037' read -r title text files; do
                if [ -n "$title" ]; then
                    status_line 2 8 "- [ ] $title"
                    [ -z "$text" ] || printf '%s' "$text" | out_cut "$STATUS_TEXT_MAX" | out_wrap 8 8 "$STATUS_WIDTH"
                else
                    printf -- '- [ ] %s\n' "$(printf '%s' "$text" | out_cut "$STATUS_TEXT_MAX")" | out_wrap 2 8 "$STATUS_WIDTH"
                fi
                if [ -n "$files" ]; then
                    IFS=',' read -r -a fl <<< "$files"
                    for f in "${fl[@]}"; do echo "        files: $f"; done
                fi
            done < <(status_rows "$STATUS_PICKUP" | head -n "$STATUS_ITEMS")
            [ "$cnt" -gt "$STATUS_ITEMS" ] && echo "  ... and $((cnt - STATUS_ITEMS)) more (see .plans/pickup.md)"
        else
            status_line 2 4 "Pickup: empty (All ideas digested!)"
        fi
        status_notice_lines pickup after
    else
        status_line 2 4 "Pickup: empty (.plans/pickup.md not found)"
    fi

    if [ "$(printf '%s\n' "$STATUS_ADOPTION" | cut -f2)" -gt 0 ]; then
        echo ""
        status_line 0 4 "📋 Adoption: $(printf '%s\n' "$STATUS_ADOPTION" | cut -f2) open task(s) in $(printf '%s\n' "$STATUS_ADOPTION" | cut -f1)"
    fi

    echo ""
    echo "$frame"
    # P-75: what is staged in `.offline`, waiting for the provider.
    if [ -n "$STATUS_OFFLINE" ]; then
        IFS=$'\037' read -r active archived plans steps < <(status_rows "$STATUS_OFFLINE")
        echo ""
        echo "📡 Staged Offline Work (.offline):"
        if [ -n "$active$archived" ]; then
            line="- Issues: $(printf '%s' "$active" | awk -F',' '{ print (NF ? NF : 0) }') staged${active:+ (${active//,/, })}"
            [ -z "$archived" ] || line="$line | $(printf '%s' "$archived" | awk -F',' '{ print NF }') staged in the local archive (${archived//,/, })"
            status_line 3 5 "$line"
        fi
        [ -z "$plans" ] || status_line 3 5 "- Draft Plans: $(printf '%s' "$plans" | awk -F',' '{ print NF }') offline blueprint(s) (${plans//,/, })"
        [ "${steps:-0}" -eq 0 ] || status_line 3 5 "- Outbox: $steps step(s) not yet sent to the provider"
        status_line 3 5 "Action: Run 'aapp offline sync' when online to publish."
    fi
    status_line 0 4 "➡️  Next Action: $(printf '%s\n' "$STATUS_NEXT" | cut -f2)"
}

# ------------------------------------------------------------------------------
# The JSON renderer (P-94): the records as one document, the fields of
# docs/reference/08-output-json.md; computes nothing the records do not hold.
# ------------------------------------------------------------------------------

# status_json_plan <record fields…> <members json>: one `plan` object.
status_json_plan() {
    out_json_obj id "$(out_json_strn "$1")" file "$(out_json_str "$2")" title "$(out_json_str "$3")" \
        kind "$(out_json_str "$6")" status "$(out_json_strn "$4")" \
        status_label "$(out_json_str "$(printf '%s' "$5" | LC_ALL=C sed -E 's/^[^A-Za-z]+//')")" \
        group "$(out_json_strn "$7")" target_issue "$(out_json_strn "$9")" blocked_on "$(out_json_strlist "${10}")" \
        worktree "$(out_json_strn "${11}")" branch "$(out_json_strn "${12}")" feature_branch "$(out_json_strn "${13}")" \
        members "${15}"
}

status_render_json() {
    local env issues next plans roadmap pickup adoption overview templates pause shipped items more
    local file reason sname preason pat label stashes initiator buffer parsed error s wt br list kind sec text plan iss commit date
    local id base title slug lbl k g m tg bl w wb fb depth cur="" curm="" pl="" title_ txt files cnt
    local active archived oplans steps offline nk ntext ncmd
    env="$(out_json_envelope status "$(printf '%s\n' "$STATUS_NOTICES" | awk -F'\t' 'NF { print $1 "\t" $2 "\t" $4 }' | out_json_notices)")" || return 1

    IFS=$'\037' read -r issues next plans roadmap pickup adoption < <(status_rows "$STATUS_OVERVIEW")
    overview="$(out_json_obj issues "$(out_json_num "$issues")" next_issues "$(out_json_strlist "$next")" plans "$(out_json_num "$plans")" \
        roadmap_plans "$(out_json_strlist "$roadmap")" pickup "$(out_json_num "$pickup")" adoption "$(out_json_num "$adoption")")"

    list=""
    while IFS=$'\037' read -r file reason; do
        [ -n "$file" ] && list="${list:+$list,}$(out_json_obj file "$(out_json_str "$file")" reason "$(out_json_str "$reason")")"
    done < <(status_rows "$STATUS_TEMPLATES")
    templates="$(out_json_obj synced "$(out_json_bool "$([ -z "$list" ] && echo 1)")" version "$(out_json_str "${AAPP_VERSION:-1.0.0}")" drifted "[$list]")"

    pause=null
    if [ -n "$STATUS_PAUSE" ]; then
        IFS=$'\037' read -r sname preason pat label stashes initiator buffer parsed error < <(status_rows "$STATUS_PAUSE")
        list=""
        if [ -n "$stashes" ]; then
            IFS=',' read -r -a s <<< "$stashes"
            for m in "${s[@]}"; do
                wt="${m%%|*}"; br="${m#*|}"
                list="${list:+$list,}$(out_json_obj worktree "$(out_json_str "${wt:-.}")" branch "$(out_json_strn "$br")")"
            done
        fi
        pause="$(out_json_obj scope "$(out_json_str "$sname")" reason "$(out_json_strn "$preason")" paused_at "$(out_json_strn "$pat")" stashes "[$list]")"
    fi

    list=""; more=0
    while IFS=$'\037' read -r kind sec text plan iss commit date; do
        case "$kind" in
            entry) list="${list:+$list,}$(out_json_obj section "$(out_json_strn "$sec")" text "$(out_json_str "$text")" plan "$(out_json_strn "$plan")" \
                       issue "$(out_json_strn "$iss")" commit "$(out_json_strn "$commit")" date "$(out_json_strn "$date")")" ;;
            more)  more="$text" ;;
        esac
    done < <(status_rows "$STATUS_SHIPPED")
    shipped="$(out_json_obj source "$(out_json_strn "$(status_changelog_path)")" entries "[$list]" more "$(out_json_num "$more")")"

    items="$(printf '%s' "$STATUS_ISSUES" | issue_render_json)"
    issues="$(out_json_obj queue "$items" unqueued "$(out_json_num "$STATUS_UNQUEUED")")"

    # A group's members follow it with depth 1: they go into its `members`.
    while IFS=$'\037' read -r id base title slug lbl k g m tg bl w wb fb depth; do
        [ -n "$base" ] || continue
        if [ "$depth" = "1" ] && [ -n "$cur" ]; then
            curm="${curm:+$curm,}$(status_json_plan "$id" "$base" "$title" "$slug" "$lbl" "$k" "$g" "$m" "$tg" "$bl" "$w" "$wb" "$fb" "$depth" "[]")"
            continue
        fi
        [ -z "$cur" ] || pl="${pl:+$pl,}$(eval "status_json_plan $cur \"[\$curm]\"")"
        cur="$(printf '%q ' "$id" "$base" "$title" "$slug" "$lbl" "$k" "$g" "$m" "$tg" "$bl" "$w" "$wb" "$fb" "$depth")"; curm=""
    done < <(status_rows "$STATUS_PLANS")
    [ -z "$cur" ] || pl="${pl:+$pl,}$(eval "status_json_plan $cur \"[\$curm]\"")"
    plans="$(out_json_obj items "[$pl]")"

    list=""; cnt=0
    while IFS=$'\037' read -r title_ txt files; do
        [ -n "$title_$txt" ] || continue
        list="${list:+$list,}$(out_json_obj title "$(out_json_strn "$title_")" text "$(out_json_str "$txt")" files "$(out_json_strlist "$files")")"
    done < <(status_rows "$STATUS_PICKUP" | head -n "$STATUS_ITEMS")
    [ -z "$STATUS_PICKUP" ] || cnt="$(printf '%s\n' "$STATUS_PICKUP" | grep -c . || true)"
    pickup="$(out_json_obj source "$(out_json_strn "$([ -f .plans/pickup.md ] && echo .plans/pickup.md)")" items "[$list]" total "$(out_json_num "$cnt")")"

    adoption="$(out_json_obj source "$(out_json_str "$(printf '%s\n' "$STATUS_ADOPTION" | cut -f1)")" open "$(out_json_num "$(printf '%s\n' "$STATUS_ADOPTION" | cut -f2)")")"

    offline=null
    if [ -n "$STATUS_OFFLINE" ]; then
        IFS=$'\037' read -r active archived oplans steps < <(status_rows "$STATUS_OFFLINE")
        offline="$(out_json_obj issues "$(out_json_strlist "$active")" archived "$(out_json_strlist "$archived")" plans "$(out_json_strlist "$oplans")" outbox "$(out_json_num "$steps")")"
    fi

    IFS=$'\037' read -r nk ntext ncmd < <(status_rows "$STATUS_NEXT")
    printf '{%s,"overview":%s,"templates":%s,"pause":%s,"shipped":%s,"issues":%s,"plans":%s,"pickup":%s,"adoption":%s,"offline":%s,"next_action":%s}' \
        "$env" "$overview" "$templates" "$pause" "$shipped" "$issues" "$plans" "$pickup" "$adoption" "$offline" \
        "$(out_json_obj kind "$(out_json_str "$nk")" text "$(out_json_str "$ntext")" command "$(out_json_str "$ncmd")")" | out_json_pretty
}

# Library use (P-92): the records and renderers without running the briefing.
if [ -n "${AAPP_STATUS_LIB_ONLY:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# The tokens: `short` (alias `summary`) for the one-line pulse, `json` for the
# JSON document (P-94); the two do not combine.
STATUS_SHORT=0; STATUS_JSON=0
for STATUS_ARG in "$@"; do
    case "$STATUS_ARG" in
        short|summary) STATUS_SHORT=1 ;;
        json) STATUS_JSON=1 ;;
    esac
done
if [ "$STATUS_SHORT" -eq 1 ] && [ "$STATUS_JSON" -eq 1 ]; then
    echo "❌ [Status] Usage: aapp status [short | json]; the overview is the JSON's \`overview\`." >&2
    return 1 2>/dev/null || exit 1
fi

STATUS_OVERVIEW="$(status_records_overview)"
if [ "$STATUS_SHORT" -eq 1 ]; then
    status_overview_line
    return 0 2>/dev/null || exit 0
fi

# The width and the text limit are the terminal's; the item cap is both outputs'.
if [ "$STATUS_JSON" -eq 0 ]; then
    STATUS_WIDTH="$(out_width)" || { return 1 2>/dev/null || exit 1; }
    STATUS_TEXT_MAX="$(status_text_max)" || { return 1 2>/dev/null || exit 1; }
fi
STATUS_ITEMS="$(status_items_max)" || { return 1 2>/dev/null || exit 1; }

# P-74: where a tracker keeps the issues, the briefing brings them up to date
# first, at most once per aapp.issueSyncWindow minutes (counted from the last
# attempt, so an unreachable tracker does not slow every briefing). Not while a
# plugin step runs.
STATUS_SYNC_OUT=""
if [ -z "${AAPP_PLUGIN_STEP:-}" ] && [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/cmd_issue.sh" ] && [ -d ".agents/skills/aapp-issue-tracker" ]; then
    STATUS_SYNC_OUT="$(
        # shellcheck source=/dev/null
        . "$AAPP_LIB/cmd_issue.sh" 2>/dev/null || exit 0
        issue_sync 2>&1 || true
    )"
fi

# P-78: a plan left blocked on a closed issue resumes once the fix commit is in
# its parent branch. The briefing is where that is noticed: the plan is
# unblocked (one commit on the plans branch) and the lines are shown under
# Plans. Not while a plugin step runs.
STATUS_UNBLOCK_OUT=""
if [ -z "${AAPP_PLUGIN_STEP:-}" ] && [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/cmd_issue.sh" ] && \
   grep -qs '^\* \*\*Blocked On:\*\*' .plans/current/*.md; then
    STATUS_UNBLOCK_OUT="$(
        # shellcheck source=/dev/null
        . "$AAPP_LIB/cmd_issue.sh" 2>/dev/null || exit 0
        issue_unblock_landed 2>&1 || true
    )"
fi

# Re-derive the matrix before anything reads it, so the briefing reports the
# real board rather than a stale cache (P-30 §2.10). While paused this still
# writes: the uncommittable diff is the visible record of what reflection
# changed, and the notice says the commit waits for 'aapp resume'.
STATUS_MATRIX_OUT=""
if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/cmd_matrix.sh" ] && [ -d ".plans/current" ]; then
    STATUS_MATRIX_OUT="$(
        AAPP_MATRIX_LIB_ONLY=1
        export AAPP_MATRIX_LIB_ONLY
        # shellcheck source=/dev/null
        . "$AAPP_LIB/cmd_matrix.sh" 2>/dev/null || exit 0
        cmd_matrix 2>/dev/null || true
    )"
fi

# The records, collected once, after the steps above changed what they read.
STATUS_OVERVIEW="$(status_records_overview)"
STATUS_TEMPLATES="$(status_records_templates)"
STATUS_PAUSE="$(status_records_pause)"
STATUS_SHIPPED="$(status_records_shipped)"
STATUS_ISSUES="$(status_records_issues)"
STATUS_UNQUEUED="$(status_unqueued_count)"
STATUS_BRANCHES="$(status_issue_branches)"
STATUS_PLANS="$(status_records_plans)"
STATUS_PICKUP="$(status_records_pickup)"
STATUS_ADOPTION="$(status_records_adoption)"
STATUS_OFFLINE="$(status_records_offline)"
STATUS_NEXT="$(status_records_next)"
STATUS_NOTICES="$(status_notices)"

if [ "$STATUS_JSON" -eq 1 ]; then
    # Built whole first: a failure on the way prints nothing on stdout.
    STATUS_DOC="$(status_render_json)" || { return 1 2>/dev/null || exit 1; }
    printf '%s\n' "$STATUS_DOC"
else
    status_render_terminal
fi
