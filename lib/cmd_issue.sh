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

# What an issue id is, and how one is read from an argument, is defined once, in
# the id section of lib/aapp-lib.sh (P-79). Below, $n is an id's body: the id
# is "#$n" and its mini plan "$(issue_fix_name "$n")".

# The ledgers themselves are read and written by the ledger functions of
# lib/aapp-lib.sh (P-73); this file holds the issue lifecycle built on them.

# issue_mark_planned <n> <link> (P-50): promotion's lifecycle edit of an active
# row: Target Plan / Fix -> <link>, Status -> 🔵 `Planned`. Observation cells
# never change.
issue_mark_planned() { _issue_plans_dir >/dev/null || return 1; ledger_set_cell "$1" link "$2" && ledger_set_cell "$1" status '🔵 `Planned`' || return 1; }

# issue_mark_incubated <n> <link> (P-69): a plan's abort hands its issue back:
# Target Plan / Fix -> <link> (the archived plan), Status -> 🟡 `Incubated`.
issue_mark_incubated() { _issue_plans_dir >/dev/null || return 1; ledger_set_cell "$1" link "$2" && ledger_set_cell "$1" status '🟡 `Incubated`' || return 1; }

# ------------------------------------------------------------------------------
# P-78: the branch of an issue is where its fix must land. No branch named (an
# empty cell, a ledger without the column) means the development branch.
# ------------------------------------------------------------------------------

# issue_branch <n>: the branch #<n>'s fix must land on.
issue_branch() {
    local b
    b="$(ledger_branch "$1")"
    if [ -n "$b" ]; then echo "$b"; return 0; fi
    _issue_dev_branch
}

# issue_branch_cell <branch>: what the Branch cell holds for it: nothing for
# the development branch.
issue_branch_cell() {
    [ -n "$1" ] && [ "$1" != "$(_issue_dev_branch)" ] || return 0
    printf '`%s`\n' "$1"
}

# issue_plan_parent <plan_file>: the plan's parent branch; the development
# branch for a plan never started.
issue_plan_parent() {
    local b
    b="$(plan_base_branch "$1")"
    if [ -n "$b" ]; then echo "$b"; return 0; fi
    _issue_dev_branch
}

# issue_view_branch: the branch issues are seen from, for the views that list
# its issues first: the current one; in a plan's or a fix's worktree that
# plan's parent branch. Empty when detached. It never decides an issue's
# branch: a row names one only when a person or an agent gives it (#136).
issue_view_branch() {
    local plans here prim pf rec abs b
    plans="$(_issue_plans_dir)" || return 0
    here="$(git rev-parse --show-toplevel 2>/dev/null)" && here="$(cd "$here" && pwd -P)" || return 0
    prim="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)" || return 0
    if [ "$here" != "$prim" ]; then
        for pf in "$plans"/current/*.md; do
            [ -f "$pf" ] || continue
            case "$(basename "$pf")" in 000-*) continue ;; esac
            rec="$(parse_plan_worktree "$pf")"
            [ -n "$rec" ] || continue
            abs="$(aapp_abs_path "${rec%%$'\t'*}" "$prim")"
            [ -d "$abs" ] && [ "$(cd "$abs" && pwd -P)" = "$here" ] || continue
            issue_plan_parent "$pf"
            return 0
        done
    fi
    b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
    [ "$b" = "HEAD" ] || echo "$b"
}

# issue_move_branch <old> <new>: the open issues targeting <old> target <new>.
# Prints the ids it changed, on one line; does not commit.
issue_move_branch() {
    local moved
    moved="$(ledger_move_branch "$1" "$(issue_branch_cell "$2")")" || return 1
    [ -z "$moved" ] || printf '%s\n' "$moved" | paste -sd, - | sed 's/,/, /g'
}

# _issue_branch_state <n>: sets ISSUE_BRANCH (where #<n>'s fix lands) and
# ISSUE_BRANCH_GONE (the branch its row names, when it no longer exists here or
# on a remote: the fix then lands on the development branch). Writes nothing.
_issue_branch_state() {
    local b
    ISSUE_BRANCH_GONE=""
    b="$(ledger_cell "$1" branch | tr -d '`')"
    if [ -n "$b" ] && ! aapp_branch_ref "$b" >/dev/null; then
        ISSUE_BRANCH_GONE="$b"; b=""
    fi
    [ -n "$b" ] || b="$(_issue_dev_branch)"
    ISSUE_BRANCH="$b"
}

# _issue_clear_gone_branch <n>: after _issue_branch_state found the branch
# gone, clears the cell and says so. The caller commits the ledger.
_issue_clear_gone_branch() {
    [ -n "${ISSUE_BRANCH_GONE:-}" ] || return 0
    ledger_set_cell "$1" branch "" || return 1
    echo "ℹ️  [Issue] #$1 targeted $ISSUE_BRANCH_GONE, which no longer exists; it now targets ${ISSUE_BRANCH:-the development branch}."
}

# _issue_ask_branch <plans> <n> <file>… (P-83): which branch owns an issue's
# files is the team's knowledge. Puts the issue and the fix's files to the
# team's `aapp-issue-branch` plugin and sets ISSUE_ASKED_BRANCH: the branch it
# answers, or nothing (no plugin installed, or `declined`: the development
# branch). Returns 1, having said why and how to get past it, when the plugin
# fails, times out, answers no branch or one that does not exist: a fix is
# never sent to the development branch because the plugin broke. Only called
# for a row that names no branch.
_issue_ask_branch() {
    local plans="$1" n="$2" root pdir entry cells data files_json="" f b why=""
    shift 2
    ISSUE_ASKED_BRANCH=""
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || return 0
    pdir="$root/.agents/skills/aapp-issue-branch"
    [ -d "$pdir" ] || return 0
    entry="$(resolve_plugin_entrypoint "$pdir" "aapp-issue-branch" 2>/dev/null)" || return 0
    for f in "$@"; do files_json="${files_json:+$files_json, }\"$(json_escape "$f")\""; done
    cells="$(PLANS_DIR="$plans" ledger_rows | awk -F'\t' -v id="#$n" '$1 == id { print; exit }' | tr -d '`')"
    data="{\"id\": \"#$n\", \"sev\": \"$(json_escape "$(printf '%s' "$cells" | cut -f2)")\", \"type\": \"$(json_escape "$(printf '%s' "$cells" | cut -f3)")\", \"date\": \"$(json_escape "$(printf '%s' "$cells" | cut -f4)")\", \"symptom\": \"$(json_escape "$(printf '%s' "$cells" | cut -f6)")\", \"status\": \"$(json_escape "$(printf '%s' "$cells" | cut -f8)")\", \"files\": [$files_json]}"
    if AAPP_ISSUE_ID="#$n" plugin_step "$entry" "$root" branch issue.branch "$data" 2>/dev/null; then
        _plugin_files_drop
        [ "$PLUGIN_STATUS" = "declined" ] && return 0
        if ! b="$(json_field "$PLUGIN_OUT" branch)"; then
            why="it answered without a branch"
        elif ! aapp_branch_ref "$b" >/dev/null; then
            why="it answered '$b', a branch that exists neither here nor on a remote"
        else
            ISSUE_ASKED_BRANCH="$b"
            return 0
        fi
    else
        # A `failed` answer's message is already shown by the step.
        if [ "$(json_field "$PLUGIN_OUT" status 2>/dev/null)" != "failed" ]; then why="${PLUGIN_MESSAGE:-it gave no answer}"; fi
    fi
    echo "❌ [Issue] The aapp-issue-branch plugin did not say where #$n's fix lands${why:+ ($why)}; nothing is opened or closed." >&2
    echo "   Name the branch yourself: aapp refine issues \"<msg>\" branch $n <name>" >&2
    return 1
}

# issue_bring_fix_to_groups <n> <sha> (P-83): a plan takes fixes by rebasing
# onto its parent branch, so the fix must first be there. For each plan blocked
# on #<n> whose parent is a group's feature branch, when the fix commit is in
# that group's own parent, the group's parent is merged into the feature branch
# (the merge the group's `done` makes, made early). No other branch is merged
# into: a branch the team owns takes its fixes when the team merges them. A
# conflict changes nothing and is said; the plan then waits as before.
issue_bring_fix_to_groups() {
    local n="$1" sha="$2" plans pf list parent owner gf gparent gref seen=""
    plans="$(_issue_plans_dir)" || return 0
    _issue_load_plan_lib || return 0
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        list="$(plan_blocked_on_parse "$(sed -nE 's/^\* \*\*Blocked On:\*\* //p' "$pf" | head -n 1)" | sed -n 1p)"
        printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -qxF "#$n" || continue
        parent="$(plan_base_branch "$pf")"
        [ -n "$parent" ] || continue
        owner="$(PLANS_DIR="$plans" _group_owning_branch "$parent")" || continue
        case " $seen " in *" $owner "*) continue ;; esac
        seen="$seen $owner"
        gf="$plans/current/$owner.md"
        [ "$(plan_status_slug "$gf")" = "in-development" ] || continue
        gparent="$(plan_base_branch "$gf")"
        [ -n "$gparent" ] && gref="$(aapp_branch_ref "$gparent")" || continue
        git merge-base --is-ancestor "$sha^{commit}" "$gref" 2>/dev/null || continue
        git merge-base --is-ancestor "$sha^{commit}" "$parent" 2>/dev/null && continue
        if group_merge_parent "$gf"; then
            echo "🔀 [Issue] Merged '$gparent' into '$parent': #$n's fix is there for the members of $(parse_plan_field "$gf" "Plan ID")."
        else
            echo "⚠️  [Issue] '$gparent' does not merge cleanly into '$parent': #$n's fix is not there yet. Resolve the merge on '$parent'; 'aapp status' then unblocks the plans that wait for it." >&2
        fi
    done
    return 0
}

# _issue_fix_in_parent <plan_file> <sha>: true when the commit is reachable
# from the plan's parent branch. The fix is recognised by its commit and by
# nothing else: a squash, a cherry-pick or a rebase gives it another one.
_issue_fix_in_parent() {
    local parent ref
    parent="$(issue_plan_parent "$1")"
    # No parent branch to look at: nothing to wait for.
    [ -n "$parent" ] && ref="$(aapp_branch_ref "$parent")" || return 0
    git merge-base --is-ancestor "$2^{commit}" "$ref" 2>/dev/null
}

# issue_unblock_landed [quiet] (P-78): a plan left blocked on a closed issue
# resumes once the fix commit is in its parent branch (`aapp status`, and
# `done` after it integrates). One commit for the plans it changes. Without
# `quiet`, a plan still waiting gets a line naming the commit and the branch.
issue_unblock_landed() {
    local quiet="${1:-}" plans pf line list id commit parent from pid paths=() names=""
    plans="$(_issue_plans_dir)" || return 1
    _issue_load_plan_lib || return 1
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        line="$(grep -m 1 -E '^\* \*\*Blocked On:\*\*' "$pf" || true)"
        [ -n "$line" ] || continue
        list="$(plan_blocked_on_parse "${line#\* \*\*Blocked On:\*\* }" | sed -n 1p)"
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
        [ -n "$pid" ] || pid="$(basename "$pf" .md)"
        for id in $(printf '%s\n' "$list" | tr ',' '\n' | tr -d ' #'); do
            [ "$(PLANS_DIR="$plans" ledger_locate "$id")" = "archive" ] || continue
            commit="$(PLANS_DIR="$plans" ledger_cell "$id" commit archive | tr -d '`')"
            parent="$(issue_plan_parent "$pf")"
            if [ "$commit" = "aborted" ] || _issue_fix_in_parent "$pf" "$commit"; then
                plan_unblock "$pf" "$id" || continue
                printf '%s\n' "${paths[@]}" | grep -qxF "current/$(basename "$pf")" || paths+=("current/$(basename "$pf")")
                names="${names:+$names, }$pid"
                if [ "$commit" = "aborted" ]; then
                    echo "🔓 [Issue] $pid no longer waits for #$id: the issue was withdrawn."
                else
                    echo "🔓 [Issue] $pid no longer waits for #$id: its fix (\`$commit\`) is in '$parent'."
                fi
            elif [ -z "$quiet" ]; then
                from="$(PLANS_DIR="$plans" ledger_branch "$id")"; [ -n "$from" ] || from="$(_issue_dev_branch)"
                echo "⏳ [Issue] $pid waits for #$id: fixed on '$from' (\`$commit\`), not yet in '$parent'."
                echo "   It resumes once '$parent' holds that commit (a merge keeps it; a squash, cherry-pick or rebase does not: 'aapp refine $pid unblocked $id')."
            fi
        done
    done
    [ ${#paths[@]} -gt 0 ] || return 0
    sync_state_matrix
    [ -f "$plans/state_matrix.md" ] && paths+=("state_matrix.md")
    plans_commit "issue(unblock): fix reached the parent branch" "${paths[@]}" || return 1
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
    # The answer is read by the plugin protocol (P-77): its message is shown and
    # its `do` list runs once this step is over.
    if AAPP_ISSUE_ID="#$n" AAPP_COMMIT_SHA="$sha" AAPP_SUMMARY="$summary" \
       plugin_step "$entry" "$root" close issue.close "$data" 2>/dev/null; then
        status="$(json_field "$PLUGIN_OUT" status)" || status="accepted"
        echo "📨 [Issue] #$n handed to aapp-issue-tracker: $status"
    else
        status="$(json_field "$PLUGIN_OUT" error)" || status="${PLUGIN_MESSAGE:-no error text}"
        echo "⚠️  [Issue] #$n closed locally; aapp-issue-tracker failed ($status). Delivery is the plugin's responsibility." >&2
    fi
    plugin_run_do issue aapp-issue-tracker
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

# _issue_drop_fix_worktree <worktree> <branch>: removes a fix's worktree, its
# kit links and its branch.
_issue_drop_fix_worktree() {
    local l
    for l in .githooks .agents .plans .claude; do [ -L "$1/$l" ] && rm -f "$1/$l"; done
    git worktree remove --force "$1" >/dev/null 2>&1 || echo "⚠️  Could not remove $1; remove it with 'git worktree remove --force $1'." >&2
    git branch -D "$2" >/dev/null 2>&1 || echo "⚠️  Could not delete $2; delete it with 'git branch -D $2'." >&2
}

# _issue_land_fix <num> <mini-plan> (P-64, P-78): a fix made in its own
# worktree lands on the branch it was cut from (the mini plan's Base): that
# branch is fast-forwarded to `fix/<num>` (rebased first when the branch moved),
# then the fix worktree and branch go. Refuses with both branches unchanged.
_issue_land_fix() {
    local n="$1" mp="$2" rec wt br gid gf fb ref holder
    _issue_load_plan_lib || return 1
    rec="$(parse_plan_worktree "$mp")"
    wt="$(aapp_abs_path "${rec%%$'\t'*}" "$PRIMARY_ROOT")"; br="${rec#*$'\t'}"
    fb="$(plan_base_branch "$mp")"
    if [ -z "$fb" ]; then
        # A fix opened before P-78 records its group only.
        gid="$(parse_plan_field "$mp" Group)"
        gf="$(resolve_plan_file "$gid" "close")" || return 1
        fb="$(parse_plan_field "$gf" "Feature Branch")"
    fi
    ref="$(aapp_branch_ref "$fb")" || {
        echo "❌ [Issue] '$fb', the branch #$n's fix was cut from, no longer exists; the fix stays on $br in .workspace/fix-$n." >&2
        return 1
    }
    if [ -n "$(git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
        echo "❌ [Issue] .workspace/fix-$n has uncommitted changes; commit them with 'aapp commit' there first." >&2
        return 1
    fi
    if ! git merge-base --is-ancestor "$ref" "$br"; then
        if ! git -C "$wt" rebase -q "$ref" >/dev/null 2>&1; then
            git -C "$wt" rebase --abort >/dev/null 2>&1
            echo "❌ [Issue] fix/$n does not rebase cleanly onto $fb; resolve it in .workspace/fix-$n, then close again." >&2
            return 1
        fi
    fi
    # A branch checked out in a worktree is moved there; any other by its ref.
    holder="$(git worktree list --porcelain | awk -v b="refs/heads/$fb" '/^worktree / { w = substr($0, 10) } $1 == "branch" && $2 == b { print w; exit }')"
    if [ -n "$holder" ]; then
        git -C "$holder" merge -q --ff-only "$br" >/dev/null 2>&1 || {
            echo "❌ [Issue] Could not fast-forward $fb to fix/$n in $holder (uncommitted changes in the fix's files there?)." >&2; return 1; }
    else
        git fetch -q . "$br:$fb" || {
            echo "❌ [Issue] Could not fast-forward $fb to fix/$n." >&2; return 1; }
    fi
    _issue_drop_fix_worktree "$wt" "$br"
    echo "🔀 [Issue] #$n landed on $fb ($(git rev-parse --short "$fb"))."
}

# _issue_archive_active <n> <commit-cell> <summary> <subject> [<mini-plan> [<entry>]]
# One commit that takes an active issue out of the backlog: the row moves to the
# archive, plans blocked on it resume, an open mini plan goes. Shared by `close`
# and `abort` (P-76). An empty summary with a mini plan becomes its changelog
# entry. Sets IA_TOUCHED (the unblocked plans' paths) and IA_SUMMARY.
_issue_archive_active() {
    local n="$1" cell="$2" summary="$3" subject="$4" mp="${5:-}" entry="${6:-}"
    local plans touched p unblocked="" paths=()
    plans="$(_issue_plans_dir)" || return 1
    # P-78: a fix unblocks the plans whose parent branch holds its commit; a
    # withdrawn issue has no commit and unblocks them all.
    if [ "$cell" = "aborted" ]; then
        touched="$(issue_unblock_plans "$n")" || return 1
    else
        touched="$(issue_unblock_plans "$n" "$cell")" || return 1
    fi
    for p in $touched; do
        unblocked="${unblocked:+$unblocked, }$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plans/$p" | head -n 1)"
    done
    if [ -z "$summary" ] && [ -n "$mp" ]; then
        summary="$entry${unblocked:+; unblocks $unblocked}"
    fi
    ledger_archive_row "$n" "$cell" "$summary" || return 1
    paths=(); while IFS= read -r p; do [ -n "$p" ] && paths+=("$p"); done < <(ledger_commit_paths)
    for p in $touched; do paths+=("$p"); done
    if [ -n "$mp" ]; then
        _issue_load_plan_lib || return 1
        # A group fix was bound in its own worktree, removed on landing.
        [ -n "$(parse_plan_worktree "$mp")" ] || _issue_restore_buffer
        rm -f "$mp"
        paths+=("current/fix-$n.md")
    fi
    _issue_reapply_stash "$n"
    if [ -n "$touched" ]; then
        _issue_load_plan_lib || return 1
        sync_state_matrix
        [ -f "$plans/state_matrix.md" ] && paths+=("state_matrix.md")
    fi
    plans_commit "$subject" "${paths[@]}" || return 1
    IA_TOUCHED="$touched"; IA_SUMMARY="$summary"
}

# _issue_report_unblocked <plans> <plan-path>…: which plans resumed, which still wait.
_issue_report_unblocked() {
    local plans="$1" p wt
    shift
    for p in "$@"; do
        if grep -q '^\* \*\*Status:\*\* 🟥' "$plans/$p"; then
            echo "   $(basename "$p" .md) is still blocked: $(sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$plans/$p" | head -n 1)"
        else
            wt="$(sed -nE 's/^\* \*\*Worktree:\*\*[[:space:]]*//p' "$plans/$p" | head -n 1)"
            echo "   $(basename "$p" .md) is unblocked.${wt:+ Next: in $wt, rebase the plan branch onto its parent branch '$(issue_plan_parent "$plans/$p")'.}"
        fi
    done
}

# cmd_issue_abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm] (P-76)
# Withdraws an issue with what was opened for it: its promoted plan (through
# `plan abort`) or its open mini plan. Plans it blocked resume. One-way: a
# plan's abort and `fix <num> abort` never withdraw the issue.
cmd_issue_abort() {
    local usage='aapp issue abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]'
    local raw="${1:-}" reason="Withdrawn" pass=() n plans where mp row cell link pid="" summary went=""
    if [ -z "$raw" ]; then echo "❌ [Issue] Usage: $usage" >&2; return 1; fi
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            reason) if [ $# -lt 2 ] || [ -z "$2" ]; then echo "❌ [Issue] 'reason' needs a text." >&2; return 1; fi
                    reason="$2"; shift 2 ;;
            keep-branch|force|force-cleanup|confirm) pass+=("$1"); shift ;;
            *) echo "❌ [Issue] Unknown token '$1'. Usage: $usage" >&2; return 1 ;;
        esac
    done
    case "$reason" in *$'\n'*) echo "❌ [Issue] The reason must be a single line." >&2; return 1 ;; esac
    n="$(issue_id_body "$raw")" || return 1
    plans="$(_issue_plans_dir)" || return 1
    where="$(ledger_locate "$n")" || return 1
    case "$where" in
        active)  ;;
        archive) echo "❌ [Issue] #$n is already archived." >&2; return 1 ;;
        *)       echo "❌ [Issue] #$n not found in ISSUES.md or done/000-issues-archive.md." >&2; return 1 ;;
    esac
    _issue_load_plan_lib || return 1
    mp="$plans/current/fix-$n.md"
    if [ -f "$mp" ] && [ -n "$(parse_plan_commits "$mp" 2>/dev/null)" ]; then
        echo "❌ [Issue] #$n's fix has recorded commits: the fix is made. Close the issue with 'aapp issue close $n'." >&2
        return 1
    fi

    # What was opened for it goes first, through its own code and commit; a
    # refusal there leaves everything as it was.
    cell="$(ledger_cell "$n" link)"
    link="$(printf '%s\n' "$cell" | sed -nE 's/^\[(P-[0-9]+)\]\(current\/([^)]+)\)$/\1 \2/p')"
    if [ -n "$link" ] && [ -f "$plans/current/${link#* }" ]; then
        pid="${link%% *}"
        ( cmd_plan_abort "$pid" reason "Issue #$n aborted: $reason" "${pass[@]}" ) || return 1
        went="plan $pid"
    fi
    if [ -f "$mp" ]; then
        _issue_fix_abort "$plans" "$n" >/dev/null || return 1
        went="${went:+$went, }its open fix"
    fi

    # The row now links the aborted plan, when one went (also on a second run).
    cell="$(ledger_cell "$n" link)"
    link="$(printf '%s\n' "$cell" | sed -nE 's/^\[(P-[0-9]+)\]\(aborted\/([^)]+)\)$/[\1](..\/aborted\/\2)/p')"
    summary="Aborted: $reason${link:+ ($link)}"
    _issue_archive_active "$n" "aborted" "$summary" "issue(abort): withdraw #$n" || return 1
    echo "🗑️  [Issue] #$n withdrawn to done/000-issues-archive.md: $reason"
    [ -z "$went" ] || echo "   Removed with it: $went."
    _issue_report_unblocked "$plans" $IA_TOUCHED
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

    n="$(issue_id_body "$raw")" || return 1
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || {
        echo "❌ [Issue] Not inside a Git repository." >&2
        return 1
    }
    # P-52: an open mini plan supplies the SHA (its last recorded commit) and
    # the summary, and is deleted in the close commit.
    local plans mp="" mini_list=() last p entry="" landed=0 bref=""
    plans="$(_issue_plans_dir)" || return 1
    where="$(PLANS_DIR="$plans" ledger_locate "$n")" || return 1
    # P-78: closing follows the code. The commit must be in the issue's branch;
    # a fix made in its own worktree lands there below.
    ISSUE_BRANCH=""; ISSUE_BRANCH_GONE=""
    ISSUE_ASKED_BRANCH=""
    if [ "$where" = "active" ]; then
        PLANS_DIR="$plans" _issue_branch_state "$n"
        # P-83: a row that names no branch, closed with no fix open: the
        # team's plugin says where its files belong.
        if [ ! -f "$plans/current/fix-$n.md" ] && { [ -z "$(PLANS_DIR="$plans" ledger_cell "$n" branch)" ] || [ -n "$ISSUE_BRANCH_GONE" ]; }; then
            # shellcheck disable=SC2046
            _issue_ask_branch "$plans" "$n" $(issue_location_paths "$(PLANS_DIR="$plans" ledger_row "$n")") || return 1
            [ -z "$ISSUE_ASKED_BRANCH" ] || ISSUE_BRANCH="$ISSUE_ASKED_BRANCH"
        fi
        [ -z "$ISSUE_BRANCH" ] || bref="$(aapp_branch_ref "$ISSUE_BRANCH")" || bref=""
        if [ -n "$sha" ] && [ -n "$bref" ] && ! git merge-base --is-ancestor "$sha^{commit}" "$bref" 2>/dev/null; then
            echo "❌ [Issue] Commit \`$sha\` is not in '$ISSUE_BRANCH', the branch #$n's fix lands on; #$n stays open." >&2
            echo "   Bring the fix into '$ISSUE_BRANCH' (merge or pull it), then close again. Another target: aapp refine issues \"<msg>\" branch $n <name>" >&2
            return 1
        fi
    fi
    if [ -f "$plans/current/fix-$n.md" ]; then
        mp="$plans/current/fix-$n.md"
        last="$(parse_plan_commits "$mp" | tail -n 1 | awk '{print $1}')"
        if [ -z "$last" ]; then
            echo "❌ [Issue] #$n's fix recorded no commit; commit it with 'aapp commit' (or drop it with 'aapp issue fix $n abort')." >&2
            return 1
        fi
        # P-66: the fix wrote its changelog entry; it is also the archive's resolution.
        if ! entry="$(aapp_plan_changelog_decl "$mp")"; then
            echo "❌ [Issue] #$n's fix has no changelog entry; commit it with 'aapp commit \"<msg>\" changelog \"<what the fix changed>\"'." >&2
            return 1
        fi
        entry="${entry#*|}"
        # P-64, P-78: a fix made in its own worktree lands on its branch first.
        if [ -n "$(parse_plan_worktree "$mp")" ]; then
            _issue_land_fix "$n" "$mp" || return 1
            last="$(parse_plan_commits "$mp" | tail -n 1 | awk '{print $1}')"
            landed=1
        fi
        if [ -z "$sha" ]; then
            sha="$last"
            if [ "$landed" -eq 0 ] && [ -n "$bref" ] && ! git merge-base --is-ancestor "$sha^{commit}" "$bref" 2>/dev/null; then
                echo "❌ [Issue] #$n's fix (\`$sha\`) is not in '$ISSUE_BRANCH', the branch its fix lands on; #$n stays open." >&2
                echo "   Bring the fix into '$ISSUE_BRANCH' (merge or pull it), then close again. Another target: aapp refine issues \"<msg>\" branch $n <name>" >&2
                return 1
            fi
        fi
        while IFS= read -r p; do [ -n "$p" ] && mini_list+=("$p"); done < <(parse_plan_target_paths "$mp")
    fi
    if [ -z "$sha" ]; then
        # No commit named: the issue's branch as it stands.
        sha="$(git -C "$root" rev-parse --short=7 "${bref:-HEAD}")" || return 1
    fi

    case "$where" in
        active)
            PLANS_DIR="$plans" _issue_clear_gone_branch "$n" || return 1
            if [ -n "$ISSUE_ASKED_BRANCH" ]; then
                PLANS_DIR="$plans" ledger_set_cell "$n" branch "$(issue_branch_cell "$ISSUE_ASKED_BRANCH")" || return 1
            fi
            # P-83: a member of a group that waits for this fix gets it first.
            issue_bring_fix_to_groups "$n" "$sha"
            _issue_archive_active "$n" "$sha" "$summary" "issue(close): archive #$n" "$mp" "$entry" || return 1
            summary="$IA_SUMMARY"
            echo "✅ [Issue] #$n archived to done/000-issues-archive.md (commit \`$sha\`)."
            _issue_report_unblocked "$plans" $IA_TOUCHED
            [ ${#mini_list[@]} -eq 0 ] || _issue_notice_listing_plans "$plans" "${mini_list[@]}"
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
    roadmap="$(PLANS_DIR="$plans" ledger_path roadmap)"
    if [ ! -f "$roadmap" ]; then
        echo "❌ [Issue] Road map not found: $roadmap" >&2
        return 1
    fi
    # The same lines, in the same order, as the status briefing's Issues pillar:
    # with their branch, this branch's issues first, once any issue names one (P-78).
    lines="$(PLANS_DIR="$plans" roadmap_entries_by_branch "$(issue_view_branch)" "$(_issue_dev_branch)")"
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
    sed -nE 's/^\* \*\*Emergency Hotfixes:\*\*[[:space:]]*//p' "$1" | head -n 1 | tr ',' '\n' | tr -d ' ' | grep -E "^${AAPP_ISSUE_REF_RE}\$" || true
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

# issue_unblock_plans <n> [<sha>]: removes #<n> from the `Blocked On:` of the
# plans waiting on it (plan_unblock). With the fix commit <sha>, only from the
# plans whose parent branch holds it (P-78); the others are named and wait
# (issue_unblock_landed). Without it (a withdrawn issue) from every plan.
# Prints the plan paths (relative to .plans) it changed.
issue_unblock_plans() {
    local n="$1" sha="${2:-}" plans pf rc list
    plans="$(_issue_plans_dir)" || return 1
    _issue_load_plan_lib || return 1
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        list="$(plan_blocked_on_parse "$(sed -nE 's/^\* \*\*Blocked On:\*\* //p' "$pf" | head -n 1)" | sed -n 1p)"
        printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -qxF "#$n" || continue
        if [ -n "$sha" ] && ! _issue_fix_in_parent "$pf" "$sha"; then
            echo "   $(parse_plan_field "$pf" "Plan ID") stays blocked: #$n's fix (\`$sha\`) is not yet in its parent branch '$(issue_plan_parent "$pf")'; 'aapp status' unblocks it once it is." >&2
            continue
        fi
        rc=0; plan_unblock "$pf" "$n" || rc=$?
        [ "$rc" -eq 0 ] || continue
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

# issue_drop_stash_records <root> <n>… (P-69): an aborted plan's work set aside
# by `hotfix` is never re-applied: its lines leave the record, the stashes stay.
issue_drop_stash_records() {
    local root="$1" buf n sha ref tmp
    shift
    buf="$(git -C "$root" rev-parse --git-path aapp_hotfix_stash 2>/dev/null)" || return 0
    case "$buf" in /*) ;; *) buf="$root/$buf" ;; esac
    [ -s "$buf" ] || return 0
    for n in "$@"; do
        sha="$(awk -v k="#$n" '$2 == k { print $1; exit }' "$buf")"
        [ -n "$sha" ] || continue
        ref="$(git -C "$root" stash list --format='%gd %H' | awk -v s="$sha" '$2 == s { print $1; exit }')"
        tmp="$buf.tmp.$$"
        awk -v k="#$n" '$2 != k' "$buf" > "$tmp" && mv "$tmp" "$buf" || { rm -f "$tmp"; return 1; }
        echo "📦 [Abort] The work set aside for #$n stays in the stash list as ${ref:-$sha}; 'aapp issue close $n' no longer re-applies it."
    done
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
    local text="${1:-}" files=() want_plan=0 plans buf bound pf prel pid f n row loc today max count list slug t target=""
    if [ -z "$text" ]; then
        echo "❌ [Issue] Usage: aapp issue hotfix \"<text>\" [file <path>]… [branch <name>] [plan]" >&2
        return 1
    fi
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            file) [ $# -ge 2 ] || { echo "❌ [Issue] 'file' needs a path." >&2; return 1; }
                  files+=("$2"); shift 2 ;;
            branch) [ $# -ge 2 ] && [ -n "$2" ] || { echo "❌ [Issue] 'branch' needs a branch name." >&2; return 1; }
                  target="$2"; shift 2 ;;
            plan) want_plan=1; shift ;;
            *)    echo "❌ [Issue] Unknown token '$1'. Usage: aapp issue hotfix \"<text>\" [file <path>]… [branch <name>] [plan]" >&2; return 1 ;;
        esac
    done
    if [ -n "$target" ] && ! aapp_branch_ref "$target" >/dev/null; then
        echo "❌ [Issue] Branch '$target' does not exist, here or on a remote." >&2
        return 1
    fi
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
    PLANS_DIR="$plans" ledger_add_row "$row" || {
        _issue_lock_release
        echo "❌ [Issue] No table header separator in ISSUES.md." >&2; return 1; }
    # P-83: two ways in. Every file named is one of the plan's own Target
    # Files: the fix belongs to the plan's line of work, its parent branch.
    # Otherwise the row names no branch, and the team's plugin (or the
    # development branch) decides when the fix opens. `branch` names one anyway.
    if [ -z "$target" ] && [ ${#files[@]} -gt 0 ]; then
        local own=1 tf
        tf="$(parse_plan_target_paths "$pf")"
        for f in "${files[@]}"; do
            printf '%s\n' "$tf" | grep -qxF "$f" || { own=0; break; }
        done
        [ "$own" -eq 0 ] || target="$(issue_plan_parent "$pf")"
    fi
    PLANS_DIR="$plans" ledger_set_cell "$n" branch "$(issue_branch_cell "$target")" || {
        _issue_lock_release
        echo "❌ [Issue] Could not record the branch of #$n in ISSUES.md." >&2; return 1; }
    [ "$want_plan" -eq 1 ] || PLANS_DIR="$plans" roadmap_add_blocker "$n" "$text" "$pid"
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
    local paths=("$prel") lp
    while IFS= read -r lp; do [ -n "$lp" ] && paths+=("$lp"); done < <(PLANS_DIR="$plans" ledger_commit_paths issues roadmap)
    [ -f "$plans/state_matrix.md" ] && paths+=("state_matrix.md")
    plans_commit "issue(hotfix): #$n blocks $pid" "${paths[@]}" || { _issue_lock_release; return 1; }
    _issue_lock_release
    echo "🧯 [Issue] #$n logged; $pid is blocked on it. Stop here: the fix runs in the main checkout ('aapp issue fix next-blocker')."
    if [ "$want_plan" -eq 1 ]; then
        slug="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | sed 's/[ _]/-/g' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//' | cut -c1-40)"
        cmd_draft "${slug:-issue-$n}" issue "$n" || return 1
    fi
}

# issue_location_paths <row>: the paths in an issue row's Location cell (P-58):
# backticked tokens that exist in the working tree or are path-shaped (a `/` or
# a file extension), with any `:lines` suffix stripped. A hand-written
# `` `a/b.sh` (`SOME_REGEX`) `` yields just `a/b.sh`.
issue_location_paths() {
    local root t
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    while IFS= read -r t; do
        case "$t" in
            '') ;;
            */*|*.?*) echo "$t" ;;
            *) if [ -n "$root" ] && [ -e "$root/$t" ]; then echo "$t"; fi ;;
        esac
    done < <(printf '%s\n' "$1" | sed 's/\\|/\x01/g' | awk -F'|' '{print $6}' | grep -oE '`[^`]+`' | tr -d '`' | sed -E 's/:[0-9][0-9,-]*$//')
}

# issue_queued_blockers <plans>: the 🧱 Plan Blockers in road-map order whose row
# is active and not Planned (a promoted blocker has left the queue).
issue_queued_blockers() {
    local plans="$1" id row
    for id in $(PLANS_DIR="$plans" roadmap_blockers); do
        row="$(PLANS_DIR="$plans" ledger_row "$id")" || continue
        printf '%s' "$row" | grep -q 'Planned' && continue
        echo "$id"
    done
}

# _issue_dirty_files <file>…: those with uncommitted changes in this working copy.
_issue_dirty_files() {
    local f
    for f; do
        if [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]; then echo "$f"; fi
    done
}

# _issue_next_blocker <plans>: sets _ISSUE_PICK to the top queued blocker whose
# files are clean here (P-52's skip). Returns 1 when none is queued, 2 when
# every queued blocker has uncommitted files (P-58: the caller waits); the
# busy files are left in _ISSUE_DIRTY.
_issue_next_blocker() {
    local plans="$1" id row any=0 busy f
    _ISSUE_PICK=""; _ISSUE_DIRTY=()
    for id in $(issue_queued_blockers "$plans"); do
        any=1
        row="$(PLANS_DIR="$plans" ledger_row "$id")"
        busy=0
        while IFS= read -r f; do
            [ -n "$f" ] && { busy=1; _ISSUE_DIRTY+=("$f"); }
        done < <(_issue_dirty_files $(issue_location_paths "$row"))
        if [ "$busy" -eq 0 ]; then _ISSUE_PICK="$id"; return 0; fi
    done
    [ "$any" -eq 1 ] && return 2
    return 1
}

# _issue_roll <what>: one step of the wait roller (2 s, 3 s, …, printed), on the
# caller's `waited`, `step` and `limit`; returns 1 once aapp.issueFixWait is used up.
_issue_roll() {
    [ "$waited" -lt "$limit" ] || return 1
    echo "⏳ [Issue] $1; waiting ${step}s…" >&2
    sleep "$step"; waited=$((waited + step)); step=$((step + 1))
}

# _issue_busy_refusal <plans> <file>…: the message when the wait for uncommitted
# files runs out (P-58). Files the plan bound here lists are that plan's own
# work: nobody else will clear them, and only a hotfix from it sets them aside.
# The fixer never commits or stashes another plan's work itself.
_issue_busy_refusal() {
    local plans="$1" buf bound pf pid own=() t f
    shift
    buf="$(git rev-parse --git-path aapp_active_plan 2>/dev/null)"
    bound="$(tr -d '[:space:]' < "$buf" 2>/dev/null)" || bound=""
    case "$bound" in ''|'#'*) ;; *)
        if pf="$(_issue_plan_file_for "$plans" "$bound")"; then
            pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
            while IFS= read -r t; do
                for f; do
                    if [ "$t" = "$f" ]; then own+=("$f"); fi
                done
            done < <(parse_plan_target_paths "$pf")
        fi ;;
    esac
    if [ ${#own[@]} -gt 0 ]; then
        echo "❌ [Issue] ${own[*]}: uncommitted work of ${pid:-$bound}, the plan bound in this checkout; nothing else will clear it." >&2
        echo "   From that plan, set it aside with: aapp issue hotfix \"<text>\" file <path>…" >&2
    else
        echo "❌ [Issue] $* has uncommitted changes here; still busy after the wait (aapp.issueFixWait)." >&2
        echo "   Retry later, or take another blocker ('aapp issue fix next-blocker')." >&2
    fi
}

# _issue_notice_listing_plans <plans> <file>…: at close, one line per other
# active plan (⚡ or BLOCKED) whose Target Files include a fixed file (P-58).
# Output only; nothing is written.
_issue_notice_listing_plans() {
    local plans="$1" pf pid t f
    shift
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        grep -qE '^\* \*\*Status:\*\*.*(⚡|🟥)' "$pf" || continue
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
        while IFS= read -r t; do
            for f; do
                if [ "$t" = "$f" ]; then
                    echo "ℹ️  ${pid:-$(basename "$pf" .md)} also lists $f: it picks this fix up at its next rebase."
                fi
            done
        done < <(parse_plan_target_paths "$pf")
    done
}

# _issue_write_mini <plans> <n> <changelog-text> <file>…
_issue_write_mini() {
    local plans="$1" n="$2" text="$3" f mp
    shift 3
    mp="$plans/current/fix-$n.md"
    {
        echo "# 🩹 Issue Fix #$n"
        echo "* **Plan ID:** #$n"
        echo "* **Target Issue / Milestone:** #$n"
        echo "* **Changelog:** Fixed:${text:+ $text}"
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

# _issue_refuse_in_plan_worktree <plans>: issue fixes are made in the main
# checkout. A fix committed on a plan branch would be swallowed by the plan's
# squash and its recorded SHA would dangle (P-54).
_issue_refuse_in_plan_worktree() {
    local plans="$1" here prim pf rec abs pid
    here="$(git rev-parse --show-toplevel 2>/dev/null)" && here="$(cd "$here" && pwd -P)" || return 0
    prim="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)" || return 0
    [ "$here" = "$prim" ] && return 0
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in 000-*|fix-*) continue ;; esac
        rec="$(parse_plan_worktree "$pf")"
        [ -n "$rec" ] || continue
        abs="$(aapp_abs_path "${rec%%$'\t'*}" "$prim")"
        [ -d "$abs" ] && [ "$(cd "$abs" && pwd -P)" = "$here" ] || continue
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
        echo "❌ [Issue] This is the plan worktree of ${pid:-$(basename "$pf" .md)}; issue fixes are made in the main checkout: cd $prim" >&2
        echo "   A blocking bug here: 'aapp issue hotfix \"<text>\" file <path>…', then stop." >&2
        return 1
    done
    return 0
}

# cmd_issue_fix next-blocker | <num> file <path>… | <num> abort (P-52 2.2, 2.5)
# _issue_dev_branch: the development branch (aapp.devBranch), else the default
# branch (origin/HEAD, main, master); empty when none exists.
_issue_dev_branch() {
    local b
    b="$(aapp_dev_branch)"
    [ -n "$b" ] && { echo "$b"; return 0; }
    b="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" && { echo "${b#origin/}"; return 0; }
    for b in main master; do
        git show-ref --verify --quiet "refs/heads/$b" && { echo "$b"; return 0; }
    done
    return 0
}

# _issue_group_hint <plans> <file>… (P-64): names active groups whose feature
# branch differs from the development branch in these files; the human decides.
_issue_group_hint() {
    local plans="$1" dev pf fb gid
    shift
    dev="$(_issue_dev_branch)"; [ -n "$dev" ] || return 0
    for pf in "$plans"/current/*.md; do
        [ -f "$pf" ] && aapp_is_group_plan "$pf" || continue
        [ "$(plan_status_slug "$pf")" = "in-development" ] || continue
        fb="$(parse_plan_field "$pf" "Feature Branch")"
        git show-ref --verify --quiet "refs/heads/$fb" || continue
        git diff --quiet "$dev" "$fb" -- "$@" 2>/dev/null && continue
        gid="$(parse_plan_field "$pf" "Plan ID")"
        echo "ℹ️  [Issue] Group $gid changes these files on '$fb'. If its work caused the bug, fix it there: 'aapp issue fix <num> group $gid' (abort this one first)."
    done
}

# _issue_group_branch <group-file> (P-64): the feature branch of a group that
# is ⚡ In Development; refuses any other group.
_issue_group_branch() {
    local fb
    fb="$(parse_plan_field "$1" "Feature Branch")"
    if [ "$(plan_status_slug "$1")" != "in-development" ] || ! git show-ref --verify --quiet "refs/heads/$fb"; then
        echo "❌ [Issue] Group $(parse_plan_field "$1" "Plan ID") is not ⚡ In Development with a feature branch." >&2
        return 1
    fi
    echo "$fb"
}

# _issue_fix_worktree <num> <branch> (P-64, P-78): `.workspace/fix-<num>` on
# `fix/<num>`, cut from the branch the fix lands on, with the kit links; prints
# its path.
_issue_fix_worktree() {
    local n="$1" fb="$2" ref wt
    ref="$(aapp_branch_ref "$fb")" || { echo "❌ [Issue] Branch '$fb' does not exist." >&2; return 1; }
    wt="$PRIMARY_ROOT/.workspace/fix-$n"
    if [ -e "$wt" ] || git show-ref --verify --quiet "refs/heads/fix/$n"; then
        echo "❌ [Issue] .workspace/fix-$n or branch fix/$n already exists." >&2
        return 1
    fi
    git worktree add -q --no-track -b "fix/$n" "$wt" "$ref" || return 1
    _wt_link_kit "$wt" "Issue" "$fb" >&2 || { git worktree remove --force "$wt" >/dev/null 2>&1; git branch -D "fix/$n" >/dev/null 2>&1; return 1; }
    echo "$wt"
}

cmd_issue_fix() {
    local sub="${1:-}" n="" files=() plans open limit waited step row="" text f pf pid st t grp="" gfile="" gwt="" fixbr="" gbr="" use_wt=0 asked=0 asked_branch=""
    plans="$(_issue_plans_dir)" || return 1
    _issue_refuse_in_plan_worktree "$plans" || return 1
    case "$sub" in
        '') echo "❌ [Issue] Usage: aapp issue fix next-blocker | <num> [file <path>…] | <num> abort" >&2; return 1 ;;
        next-blocker) shift ;;
        *) n="$(issue_id_body "$sub")" || return 1; shift
           if [ "${1:-}" = "abort" ]; then _issue_fix_abort "$plans" "$n"; return; fi ;;
    esac
    while [ $# -gt 0 ]; do
        case "$1" in
            file) [ $# -ge 2 ] || { echo "❌ [Issue] 'file' needs a path." >&2; return 1; }
                  files+=("$2"); shift 2 ;;
            group) [ $# -ge 2 ] || { echo "❌ [Issue] 'group' needs a group plan." >&2; return 1; }
                   grp="$2"; shift 2 ;;
            *)    echo "❌ [Issue] Unknown token '$1'." >&2; return 1 ;;
        esac
    done
    _issue_load_plan_lib || return 1
    if [ -n "$grp" ]; then
        [ -n "$n" ] || { echo "❌ [Issue] 'group' needs an issue number: aapp issue fix <num> group <group>." >&2; return 1; }
        gfile="$(_group_resolve "$grp" "Issue")" || return 1
        gbr="$(_issue_group_branch "$gfile")" || return 1
    fi

    # Adding files to the open mini plan of #<num>.
    if [ -n "$n" ] && [ -f "$plans/current/fix-$n.md" ]; then
        [ ${#files[@]} -gt 0 ] || { echo "❌ [Issue] #$n is already being fixed; add files with 'file <path>'." >&2; return 1; }
        # Re-render with the combined list (the §4 parser stays in aapp-lib.sh),
        # keeping the changelog text, the recorded commits and, for a group's
        # fix, its worktree and group (#132: `close` lands the fix by them).
        local mp="$plans/current/fix-$n.md" all=() cl commits wtline grp base
        while IFS= read -r f; do [ -n "$f" ] && all+=("$f"); done < <(parse_plan_target_paths "$mp")
        for f in "${files[@]}"; do
            printf '%s\n' "${all[@]}" | grep -qxF "$f" || all+=("$f")
        done
        cl="$(sed -nE 's/^\* \*\*Changelog:\*\* Fixed: //p' "$mp" | head -n 1)"
        commits="$(grep -m 1 -E '^\* \*\*Commits:\*\*' "$mp")"
        base="$(sed -nE 's/^\* \*\*Base:\*\* //p' "$mp" | head -n 1)"
        wtline="$(sed -nE 's/^\* \*\*Worktree:\*\* //p' "$mp" | head -n 1)"
        grp="$(sed -nE 's/^\* \*\*Group:\*\* //p' "$mp" | head -n 1)"
        _issue_write_mini "$plans" "$n" "$cl" "${all[@]}"
        AAPP_LINE="$commits" awk '/^\* \*\*Commits:\*\*/ && !d { print ENVIRON["AAPP_LINE"]; d = 1; next } { print }' "$mp" > "$mp.tmp" && mv "$mp.tmp" "$mp"
        if [ -n "$base" ]; then write_plan_field "$mp" Base "$base" Status || return 1; fi
        if [ -n "$wtline" ]; then write_plan_field "$mp" Worktree "$wtline" "${base:+Base}" || return 1; fi
        if [ -n "$grp" ]; then write_plan_field "$mp" Group "$grp" Worktree || return 1; fi
        plans_commit "fix(files): #$n" "current/fix-$n.md" || return 1
        echo "🩹 [Issue] #$n: files added (${files[*]})."
        return 0
    fi

    # One fix at a time, and never over uncommitted work: wait (verbose) while
    # another mini plan is open or a file is busy, up to aapp.issueFixWait.
    local root pdir entry pout raw busy=() pick_rc
    root="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    pdir="$root/.agents/skills/aapp-issue-tracker"
    limit="$(_issue_wait_limit)"; waited=0; step=2
    while :; do
        if open="$(_issue_open_mini "$plans")"; then
            _issue_roll "#$open is being fixed" && continue
            echo "⏳ [Issue] #$open is still being fixed; retry later." >&2
            return 1
        fi
        _issue_lock_acquire || return 1
        if _issue_open_mini "$plans" >/dev/null; then _issue_lock_release; continue; fi

        if [ -z "$n" ]; then
            # With the aapp-issue-tracker provider installed, it is the authority
            # for the claim (fail closed, like `allocate`); otherwise the local queue.
            if [ -d "$pdir" ] && entry="$(resolve_plugin_entrypoint "$pdir" "aapp-issue-tracker" 2>/dev/null)"; then
                pout="$(run_action_plugin "$entry" "$root" next-blocker issue.next-blocker 2>/dev/null)" || {
                    _issue_lock_release; echo "❌ [Issue] The aapp-issue-tracker provider refused next-blocker; not claiming locally." >&2; return 1; }
                raw="$(json_field "$pout" id)" || {
                    _issue_lock_release; echo "❌ [Issue] Provider must print {\"id\": ...} for next-blocker (got: '$pout')." >&2; return 1; }
                n="$(issue_id_body "$raw")" || { _issue_lock_release; return 1; }
            else
                _issue_next_blocker "$plans" && pick_rc=0 || pick_rc=$?
                case "$pick_rc" in
                    0) n="$_ISSUE_PICK" ;;
                    2) _issue_lock_release
                       _issue_roll "every queued blocker has uncommitted changes here (${_ISSUE_DIRTY[*]})" && continue
                       _issue_busy_refusal "$plans" "${_ISSUE_DIRTY[@]}"; return 1 ;;
                    *) _issue_lock_release
                       echo "❌ [Issue] No plan blockers are queued (🧱 Plan Blockers in issues_road_map.md)." >&2; return 1 ;;
                esac
            fi
        fi
        if [ -z "$row" ]; then
            row="$(PLANS_DIR="$plans" ledger_row "$n")" || {
                _issue_lock_release; echo "❌ [Issue] #$n is not an active issue in ISSUES.md." >&2; return 1; }
            # The files come from the issue log; `file` only adds one it does not name.
            local all_files=()
            while IFS= read -r f; do [ -n "$f" ] && all_files+=("$f"); done < <(issue_location_paths "$row")
            for f in "${files[@]}"; do
                printf '%s\n' "${all_files[@]}" | grep -qxF "$f" || all_files+=("$f")
            done
            files=("${all_files[@]}")
            if [ ${#files[@]} -eq 0 ]; then
                _issue_lock_release; echo "❌ [Issue] No files known for #$n: give them with 'file <path>'." >&2; return 1
            fi
        fi
        # P-78: the fix is made on the issue's branch: here when this checkout
        # is on it, otherwise in its own worktree cut from it (as a group's
        # fix on its feature branch, P-64, which `group` names).
        if [ -n "$gbr" ]; then
            fixbr="$gbr"; ISSUE_BRANCH_GONE=""
        else
            PLANS_DIR="$plans" _issue_branch_state "$n"
            # P-83: a row that names no branch: the team's plugin says where
            # these files belong (asked once, however long the wait below).
            if [ "$asked" -eq 0 ] && { [ -z "$(PLANS_DIR="$plans" ledger_cell "$n" branch)" ] || [ -n "$ISSUE_BRANCH_GONE" ]; }; then
                _issue_ask_branch "$plans" "$n" "${files[@]}" || { _issue_lock_release; return 1; }
                asked=1; asked_branch="$ISSUE_ASKED_BRANCH"
            fi
            fixbr="${asked_branch:-$ISSUE_BRANCH}"
        fi
        use_wt=0
        if [ -n "$fixbr" ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" != "$fixbr" ]; then use_wt=1; fi
        # Uncommitted changes in these files would mix into the fix commit:
        # wait for their owner to commit them (P-58). A fix in its own worktree
        # meets none.
        busy=()
        [ "$use_wt" -eq 0 ] && while IFS= read -r f; do [ -n "$f" ] && busy+=("$f"); done < <(_issue_dirty_files "${files[@]}")
        if [ ${#busy[@]} -gt 0 ]; then
            _issue_lock_release
            _issue_roll "${busy[*]} has uncommitted changes here" && continue
            _issue_busy_refusal "$plans" "${busy[@]}"; return 1
        fi
        break
    done
    if [ "$use_wt" -eq 1 ]; then
        gwt="$(_issue_fix_worktree "$n" "$fixbr")" || { _issue_lock_release; return 1; }
    fi
    # The ledger changes with the fix's start: a branch that is gone leaves the
    # row, a group's fix targets the group's feature branch.
    local start_paths=("current/fix-$n.md") lp owner=""
    [ -z "$asked_branch" ] || ISSUE_BRANCH="$asked_branch"
    PLANS_DIR="$plans" _issue_clear_gone_branch "$n" || { _issue_lock_release; return 1; }
    if [ -n "$gbr" ]; then
        PLANS_DIR="$plans" ledger_set_cell "$n" branch "$(issue_branch_cell "$gbr")" || { _issue_lock_release; return 1; }
    elif [ -n "$asked_branch" ]; then
        # The plugin's answer is recorded: it is not asked again for this issue.
        PLANS_DIR="$plans" ledger_set_cell "$n" branch "$(issue_branch_cell "$asked_branch")" || { _issue_lock_release; return 1; }
    fi
    while IFS= read -r lp; do
        if [ -n "$lp" ] && [ -n "$(git -C "$plans" status --porcelain -- "$lp")" ]; then start_paths+=("$lp"); fi
    done < <(PLANS_DIR="$plans" ledger_commit_paths issues)
    # P-66: the entry is written by the fix's first commit (`changelog "<text>"`), never copied from the row.
    _issue_write_mini "$plans" "$n" "" "${files[@]}"
    if [ -n "$gwt" ]; then
        local gbuf mp="$plans/current/fix-$n.md"
        # Base names the branch the fix lands on; `close` reads it.
        write_plan_field "$mp" Base "\`$(git rev-parse --short "fix/$n")\` ($fixbr)" Status
        write_plan_field "$mp" Worktree ".workspace/fix-$n (fix/$n)" Base
        if [ -n "$gfile" ]; then
            owner="$(parse_plan_field "$gfile" "Plan ID")"
        elif owner="$(PLANS_DIR="$plans" _group_owning_branch "$fixbr")"; then
            owner="$(parse_plan_field "$plans/current/$owner.md" "Plan ID")"
        fi
        [ -z "$owner" ] || write_plan_field "$mp" Group "$owner" Worktree
        gbuf="$(git -C "$gwt" rev-parse --git-path aapp_active_plan)"
        case "$gbuf" in /*) ;; *) gbuf="$gwt/$gbuf" ;; esac
        write_active_buffer "#$n" "$gbuf"
    else
        write_active_buffer "#$n"
    fi
    plans_commit "fix(start): #$n" "${start_paths[@]}" || { _issue_lock_release; return 1; }
    _issue_lock_release
    if [ -n "$gwt" ]; then
        echo "🩹 [Issue] Fixing #$n${owner:+ for group $owner} in .workspace/fix-$n (fix/$n from $fixbr, files: ${files[*]})."
        echo "   Work and 'aapp commit' there; 'aapp issue close $n' lands it on $fixbr."
        return 0
    fi
    echo "🩹 [Issue] Fixing #$n in current/fix-$n.md (files: ${files[*]}). Commit with 'aapp commit', then 'aapp issue close $n'."
    _issue_group_hint "$plans" "${files[@]}"
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
    # A fix in its own worktree goes with it (nothing was committed there);
    # one made in this checkout hands the buffer back.
    local rec
    rec="$(parse_plan_worktree "$mp")"
    if [ -n "$rec" ]; then
        _issue_drop_fix_worktree "$(aapp_abs_path "${rec%%$'\t'*}" "$PRIMARY_ROOT")" "${rec#*$'\t'}"
    else
        _issue_restore_buffer
    fi
    rm -f "$mp"
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
        abort)    cmd_issue_abort "$@" ;;
        list)     cmd_issue_list "$@" ;;
        *)
            echo "❌ [Issue] Unknown subcommand '$sub'." >&2
            echo "Usage: aapp issue [next | allocate | hotfix \"<text>\" [file <path>]… [branch <name>] [plan] | fix next-blocker | fix <num> [file <path>…] | fix <num> abort | close <id> [sha <sha>] [summary \"<text>\"] | abort <num> [reason \"<text>\"] | list [<n> | all]]" >&2
            return 1
            ;;
    esac
}
