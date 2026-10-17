#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `active`, `plan-status`, `plan`, `start`, `freeze-start`
#
# Multi-Agent Planning Switchboard & Active Execution Buffer Manager
# ==============================================================================
set -e

# Shared plan parsing (P-37). Resolved relative to this file, not $AAPP_LIB,
# which is unset when this module is sourced outside the dispatcher.
AAPP_LIB_FILE="$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"
# shellcheck source=lib/aapp-lib.sh
if ! . "$AAPP_LIB_FILE" 2>/dev/null || ! declare -f aapp_lib_loaded >/dev/null; then
    echo "❌ [AAPP] Shared library missing or unreadable: $AAPP_LIB_FILE" >&2
    echo "   Reinstall the kit: ./aapp-kit/aapp install" >&2
    exit 1
fi

# Status registry (P-30): lifecycle verbs gate on a plan's status slug (#89).
AAPP_STATES_FILE="$(dirname "${BASH_SOURCE[0]}")/plan_states.sh"
# shellcheck source=lib/plan_states.sh
if ! . "$AAPP_STATES_FILE" 2>/dev/null || ! declare -f plan_state_for_status_line >/dev/null; then
    echo "❌ [AAPP] Status registry missing or unreadable: $AAPP_STATES_FILE" >&2
    echo "   Reinstall the kit: ./aapp-kit/aapp install" >&2
    exit 1
fi

# Commit engine (P-39): plans_commit is the single lifecycle commit engine.
AAPP_COMMIT_ENGINE="$(dirname "${BASH_SOURCE[0]}")/commit_engine.sh"
# shellcheck source=lib/commit_engine.sh
if [ -f "$AAPP_COMMIT_ENGINE" ]; then
    . "$AAPP_COMMIT_ENGINE"
fi

# Hook dispatcher (P-12): lifecycle plugin hooks & event architecture
AAPP_HOOK_DISPATCHER="$(dirname "${BASH_SOURCE[0]}")/hook_dispatcher.sh"
[ -f "$AAPP_HOOK_DISPATCHER" ] || AAPP_HOOK_DISPATCHER="$REPO_ROOT/lib/hook_dispatcher.sh"

# REPO_ROOT is exported by the `aapp` dispatcher, which asserts repository
# membership before dispatch (P-33). It carries the *active worktree* root, so
# GIT_COMMON_DIR/PRIMARY_ROOT resolution below stays necessary to find .plans
# when running from inside a linked worktree.
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
if [ -d "$GIT_COMMON_DIR" ]; then
    PRIMARY_ROOT="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
else
    PRIMARY_ROOT="$REPO_ROOT"
fi

if [ -d "$REPO_ROOT/.plans" ]; then
    PLANS_DIR="$REPO_ROOT/.plans"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    PLANS_DIR="$PRIMARY_ROOT/.plans"
else
    PLANS_DIR=""
fi

ACTIVE_FILE="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || echo ".git/aapp_active_plan")"
PREV_FILE="$(git rev-parse --git-path aapp_active_plan.prev 2>/dev/null || echo ".git/aapp_active_plan.prev")"

# Source plan resolver for shorthand resolution if available
if [ -f "$AAPP_LIB/plan_resolver.sh" ]; then
    source "$AAPP_LIB/plan_resolver.sh"
elif [ -f "$PRIMARY_ROOT/lib/plan_resolver.sh" ]; then
    source "$PRIMARY_ROOT/lib/plan_resolver.sh"
elif [ -f "$REPO_ROOT/lib/plan_resolver.sh" ]; then
    source "$REPO_ROOT/lib/plan_resolver.sh"
fi

# Re-derive state_matrix.md from the plan files before a lifecycle commit, so
# the commit records a correct board (P-30). Replaces per-verb in-place sed,
# which could rewrite a row's emoji but never relocate it between sections.
sync_state_matrix() {
    local lib_dir=""
    for cand in "$AAPP_LIB" "$PRIMARY_ROOT/lib" "$REPO_ROOT/lib"; do
        if [ -n "${cand:-}" ] && [ -f "$cand/cmd_matrix.sh" ]; then
            lib_dir="$cand"
            break
        fi
    done
    [ -z "$lib_dir" ] && return 0

    (
        AAPP_MATRIX_LIB_ONLY=1
        export AAPP_MATRIX_LIB_ONLY
        # shellcheck source=/dev/null
        . "$lib_dir/cmd_matrix.sh" 2>/dev/null || exit 0
        cmd_matrix >/dev/null 2>&1 || true
    ) || true
    return 0
}

resolve_plan_file() {
    local query="$1"
    local verb="${2:-inspect}"

    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
        echo "❌ [Plan Switchboard] .plans/current directory not found." >&2
        return 1
    fi

    if [ -z "$query" ]; then
        echo "❌ [Plan Switchboard] You must specify a target plan for '$verb'." >&2
        return 1
    fi

    if declare -f resolve_plan_path >/dev/null 2>&1; then
        local rel_path
        rel_path=$(resolve_plan_path "$query" "$verb" current "$PRIMARY_ROOT" 2>/dev/null || true)
        if [ -n "$rel_path" ] && [ -f "$PRIMARY_ROOT/$rel_path" ]; then
            echo "$PRIMARY_ROOT/$rel_path"
            return 0
        fi
    fi

    # Fallback resolution
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        local pid bname
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        bname="$(basename "$pf" .md)"
        if [ "$query" = "$pid" ] || [ "$query" = "$bname" ] || \
           [[ "$bname" == "$query-"* ]] || [[ "$bname" == "P$query-"* ]] || \
           [[ "$bname" == "P-$query-"* ]]; then
            echo "$pf"
            return 0
        fi
    done

    echo "❌ [Plan Switchboard] Plan '$query' not found in $PLANS_DIR/current/." >&2
    return 1
}

# validate_plan_changelog_decl <plan-file> <label> (P-48): the plan must declare
# its single CHANGELOG.md entry as `* **Changelog:** <Added|Changed|Fixed>: <text>`,
# and the rendered bullet must fit aapp.changelogMaxLen.
validate_plan_changelog_decl() {
    local plan_file="$1" label="$2" decl plan_id bullet max
    if ! decl="$(aapp_plan_changelog_decl "$plan_file")"; then
        echo "❌ [$label] Plan has no valid '* **Changelog:** <Added|Changed|Fixed>: <text>' header line." >&2
        echo "   Declare the plan's single CHANGELOG.md entry, then commit it with 'aapp refine'." >&2
        return 1
    fi
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" | head -n 1)"
    bullet="$(aapp_render_changelog_bullet "${decl#*|}" "${plan_id:-P-?}")"
    max="$(git config --int aapp.changelogMaxLen 2>/dev/null)" || max=300
    if [ "${#bullet}" -gt "$max" ]; then
        echo "❌ [$label] Changelog entry is ${#bullet} characters; the limit is $max (aapp.changelogMaxLen)." >&2
        return 1
    fi
    return 0
}

check_disjointness_activation_gate() {
    local target_plan="$1"
    local target_bname
    target_bname="$(basename "$target_plan")"

    local my_targets=()
    while IFS= read -r t; do
        [ -n "$t" ] && my_targets+=("$t")
    done < <(parse_plan_target_paths "$target_plan")

    [ ${#my_targets[@]} -eq 0 ] && return 0

    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        [ "$(basename "$pf")" = "$target_bname" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac

        if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*⚡[[:space:]]*In Development' "$pf" 2>/dev/null; then
            local other_targets=()
            while IFS= read -r ot; do
                [ -n "$ot" ] && other_targets+=("$ot")
            done < <(parse_plan_target_paths "$pf")

            for mt in "${my_targets[@]}"; do
                for ot in "${other_targets[@]}"; do
                    if [ "$mt" = "$ot" ] && aapp_is_shared_doc "$mt"; then
                        # Shared docs never block concurrent plans (P-48).
                        echo "ℹ️  [Shared Doc] $(basename "$target_plan" .md) and $(basename "$pf" .md) both update '$mt' (shared docs never block; see union merge)."
                    elif [ "$mt" = "$ot" ]; then
                        echo "❌ [Activation Gate] Cannot activate $(basename "$target_plan" .md):" >&2
                        echo "   Shares Target File '$mt' with in-flight plan '$(basename "$pf" .md)'!" >&2
                        echo "   Finish '$(basename "$pf" .md)' first or isolate on a separate git worktree/branch." >&2
                        return 1
                    fi
                done
            done
        fi
    done

    # A queued 🧱 Plan Blocker is about to change its files: a plan does not
    # start on them (P-58). A plan with a recorded Base was started before,
    # whatever its Status now (a ⚡ re-run, or re-frozen after a re-scope): not
    # a fresh start (#103). Shared docs never gate (P-48).
    if [ -f "$(ledger_path issues)" ] && [ -z "$(parse_plan_base "$target_plan")" ]; then
        _load_issue_module
        local qid qrow qf
        for qid in $(issue_queued_blockers "$PLANS_DIR"); do
            qrow="$(ledger_row "$qid")"
            while IFS= read -r qf; do
                aapp_is_shared_doc "$qf" && continue
                for mt in "${my_targets[@]}"; do
                    if [ "$mt" = "$qf" ]; then
                        echo "❌ [Activation Gate] $qf has a pending fix (#$qid); fix it first ('aapp issue fix next-blocker') or start another plan." >&2
                        return 1
                    fi
                done
            done < <(issue_location_paths "$qrow")
        done
    fi

    return 0
}

# plan_status_slug <file>: the registry slug of the plan's Status line, or
# empty when it matches no registry entry (including `✅ Done`, which only
# archived plans carry).
plan_status_slug() {
    local line
    line="$(grep -m 1 -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$1" || true)"
    plan_state_for_status_line "$line" || true
}

# refuse_unless_incubator <file> <verb-label>: freeze and freeze-start start
# from the incubator. Frozen, in-development, blocked and unrecognised plans
# (including archived ones) are refused; custom statuses count as incubator.
refuse_unless_incubator() {
    local slug
    slug="$(plan_status_slug "$1")"
    case "$slug" in
        frozen|in-development|blocked|"")
            echo "❌ [$2 Refusal] Plan is not in the incubator (current status: $(grep -m 1 -E '\*\*Status:\*\*' "$1" | sed -E 's/^.*\*\*Status:\*\*[[:space:]]*//'))." >&2
            echo "   Only 🟣 Under Review or 📝 Refining plans can be frozen." >&2
            exit 1
            ;;
    esac
}

# refuse_uncommitted_plan_edits <file> <verb-label>: freezing approves the design
# as last committed; uncommitted edits would ride in the lifecycle commit (#107).
# A never-committed (untracked) plan has no earlier design to protect.
refuse_uncommitted_plan_edits() {
    if [ -n "$(git -C "$PLANS_DIR" status --porcelain --untracked-files=no -- "current/$(basename "$1")" 2>/dev/null)" ]; then
        echo "❌ [$2 Refusal] $(basename "$1") has uncommitted edits; commit them with 'aapp refine <id> \"<what changed>\"' first." >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Group plans (P-64)
# ------------------------------------------------------------------------------
# _group_resolve <query> <label>: the group plan's file in current/; anything else refuses.
_group_resolve() {
    local gf
    gf="$(resolve_plan_file "$1" "group")" || return 1
    if ! aapp_is_group_plan "$gf"; then
        echo "❌ [$2] $(basename "$gf" .md) is not a group plan." >&2
        return 1
    fi
    echo "$gf"
}

# _group_owning_branch <branch>: the group plan whose feature branch is <branch>.
_group_owning_branch() {
    local pf
    for pf in "$PLANS_DIR"/current/*.md; do
        [ -f "$pf" ] || continue
        aapp_is_group_plan "$pf" || continue
        [ "$(parse_plan_field "$pf" "Feature Branch")" = "$1" ] && { basename "$pf" .md; return 0; }
    done
    return 1
}

# _group_start <group-plan> [base <branch>]: cuts `feature/<slug>` from the parent
# (default: the development branch) and records Base and Feature Branch. A group
# writes no code: no worktree, no buffer. Groups do not nest.
_group_start() {
    local gf="$1" gid b slug parent="" ref sha fb today
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            base) [ $# -ge 2 ] || { echo "❌ [Start Refusal] 'base' needs a branch." >&2; exit 1; }
                  parent="$2"; shift 2 ;;
            *)    echo "❌ [Start Refusal] Unknown token '$1'. Usage: <group> [base <branch>]" >&2; exit 1 ;;
        esac
    done
    gid="$(sed -nE 's/^\* \*\*Plan ID:\*\*[[:space:]]*(P-[0-9]+).*/\1/p' "$gf" | head -n 1)"
    if [ "$(plan_status_slug "$gf")" != "frozen" ]; then
        echo "❌ [Start Refusal] Group $gid is not 🔷 Frozen; freeze it first." >&2
        exit 1
    fi
    [ -n "$parent" ] || parent="$(aapp_dev_branch)"
    if [ -z "$parent" ] || ! ref="$(aapp_branch_ref "$parent")"; then
        echo "❌ [Start Refusal] No branch '${parent:-<development branch>}' to start group $gid from." >&2
        exit 1
    fi
    local owner
    if owner="$(_group_owning_branch "$parent")"; then
        echo "❌ [Start Refusal] '$parent' is the feature branch of group $owner; groups do not nest." >&2
        exit 1
    fi
    b="$(basename "$gf" .md)"; slug="${b#P${gid#P-}-}"; fb="feature/$slug"
    if git show-ref --verify --quiet "refs/heads/$fb"; then
        echo "❌ [Start Refusal] Branch '$fb' already exists; a group never reuses a branch." >&2
        exit 1
    fi
    sha="$(git rev-parse --short "$ref")" || exit 1
    git branch --no-track "$fb" "$ref" >/dev/null || exit 1
    write_plan_base "$gf" "\`$sha\` ($parent)"
    write_plan_field "$gf" "Feature Branch" "$fb" Base
    sed -i -E 's/^\* \*\*Status:\*\*.*/* **Status:** ⚡ In Development/' "$gf"
    today="$(date +%Y-%m-%d)"
    grep -q '^## 📦 6\. Change Log' "$gf" && \
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Group started: \`$fb\` from \`$parent\`." "$gf"
    # P-101: the amendments member has no design to review and no files to lock:
    # the group's start greenlights it here and starts it below.
    local af aid paths=("current/$(basename "$gf")" "state_matrix.md")
    if af="$(group_amendments_member "$gf")"; then
        aid="$(parse_plan_field "$af" "Plan ID")"
        sed -i -E 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$af"
        paths+=("current/$(basename "$af")")
    fi
    sync_state_matrix
    if ! plans_commit "plan(start): start group $gid on $fb" "${paths[@]}"; then
        git branch -D "$fb" >/dev/null
        exit 1
    fi
    echo "🧩 [Start] Group $gid started: $fb from $parent ($sha)."
    echo "   Members start from $fb; 'aapp done $gid' merges it into $parent."
    if [ -n "${aid:-}" ]; then
        # Its own worktree whatever aapp.planWorktrees says, as a plan made for an issue.
        local wt_tok=()
        [ "$(git config --get aapp.planWorktrees 2>/dev/null)" = "on" ] || wt_tok=(worktree ".workspace/P${aid#P-}")
        if ! "$AAPP_SCRIPT_DIR/aapp" start "$aid" "${wt_tok[@]}" </dev/null; then
            echo "❌ [Start] Group $gid is started, but its amendments member $aid is not; start it with 'aapp start $aid ${wt_tok[*]}'." >&2
            exit 1
        fi
    fi
}

# _group_stamp_sections <group-plan>: base lines for sections without one, from
# ARCHITECTURE.md on the group's parent branch (the development branch before
# start) and from .agents/CODEMAP.md as it is now.
_group_stamp_sections() {
    local gf="$1" parent ref arch rc=0
    # shellcheck source=/dev/null
    . "$(dirname "${BASH_SOURCE[0]}")/group_docs.sh"
    parent="$(sed -nE 's/^\* \*\*Base:\*\*[[:space:]]*`[0-9a-fA-F]+`[[:space:]]*\(([^)]+)\).*/\1/p' "$gf" | head -n 1)"
    [ -n "$parent" ] || parent="$(aapp_dev_branch)"
    arch="$(mktemp)" || return 1
    if [ -n "$parent" ] && ref="$(aapp_branch_ref "$parent")"; then
        # No ARCHITECTURE.md on the parent: every section is new.
        git show "$ref:ARCHITECTURE.md" > "$arch" 2>/dev/null || : > "$arch"
    fi
    group_docs_stamp "$gf" ARCHITECTURE.md "$arch" || rc=1
    rm -f "$arch"
    [ "$rc" -eq 0 ] || return 1
    if [ -f "$PRIMARY_ROOT/.agents/CODEMAP.md" ]; then
        group_docs_stamp "$gf" .agents/CODEMAP.md "$PRIMARY_ROOT/.agents/CODEMAP.md" || return 1
    else
        group_docs_stamp "$gf" .agents/CODEMAP.md /dev/null || return 1
    fi
}

# _group_done_prepare <group-plan> <group-id>: the checks before the normal `done`
# path, no delivery claim (P-102). Refuses (feature branch and parent unchanged)
# while a member is open, a section changed under its base line, or the parent
# cannot merge. Then: the feature branch in `.workspace/P<n>` (recorded as the
# group's Worktree, so the gate runs there and P-55 fast-forwards the parent) and
# the moved parent merged in. The docs follow the gate (_group_done_docs).
_group_done_prepare() {
    local gf="$1" gid="$2" m open="" fb parent pref wt wt_rel tmp
    # shellcheck source=/dev/null
    . "$(dirname "${BASH_SOURCE[0]}")/group_docs.sh"
    for m in $(group_members "$gf"); do
        [ -n "$(ls "$PLANS_DIR"/current/P"${m#P-}"-*.md 2>/dev/null)" ] && open="$open $m"
    done
    if [ -n "$open" ]; then
        echo "❌ [Done Refusal] Group $gid has members not archived:$open. Archive them first ('aapp done <id>')." >&2
        exit 1
    fi
    fb="$(parse_plan_field "$gf" "Feature Branch")"
    parent="$(resolve_plan_integrate_target "$gf")" || parent=""
    if ! git show-ref --verify --quiet "refs/heads/$fb" || [ -z "$parent" ] || \
       ! pref="$(aapp_branch_ref "$parent")"; then
        echo "❌ [Done Refusal] Group $gid: feature branch '$fb' or parent '${parent:-?}' not found." >&2
        exit 1
    fi
    # Dry runs: the sections must apply to the parent's ARCHITECTURE.md and to CODEMAP.md.
    tmp="$(mktemp -d)" || exit 1
    git show "$pref:ARCHITECTURE.md" > "$tmp/arch" 2>/dev/null || : > "$tmp/arch"   # none on the parent: all sections new
    cp "$PRIMARY_ROOT/.agents/CODEMAP.md" "$tmp/map" 2>/dev/null || : > "$tmp/map"    # none yet: all sections new
    if ! group_docs_apply "$gf" ARCHITECTURE.md "$tmp/arch" >/dev/null || \
       ! group_docs_apply "$gf" .agents/CODEMAP.md "$tmp/map" >/dev/null; then
        rm -rf "$tmp"; exit 1
    fi
    rm -rf "$tmp"

    wt_rel=".workspace/P${gid#P-}"; wt="$PRIMARY_ROOT/$wt_rel"
    if [ -d "$wt" ]; then
        if [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)" != "$fb" ]; then
            echo "❌ [Done Refusal] $wt_rel exists and is not on '$fb'." >&2
            exit 1
        fi
    else
        git worktree add -q "$wt" "$fb" || { echo "❌ [Done Refusal] git worktree add failed for '$wt_rel'." >&2; exit 1; }
        _wt_link_kit "$wt" "Done Refusal" "$fb" || { _group_done_drop_wt "$wt"; exit 1; }
    fi
    if ! git merge-base --is-ancestor "$pref" "$fb"; then
        if ! _group_merge_parent_in "$wt" "$pref"; then
            _group_done_drop_wt "$wt"
            echo "❌ [Done Refusal] '$parent' does not merge cleanly into '$fb'; resolve it on the feature branch (a group-caused fix), then run 'aapp done $gid' again." >&2
            exit 1
        fi
        echo "🔀 [Done] Merged '$parent' into '$fb'."
    fi

    write_plan_field "$gf" Worktree "$wt_rel ($fb)" "Feature Branch" || exit 1
    local buf
    buf="$(git -C "$wt" rev-parse --git-path aapp_active_plan)" || exit 1
    case "$buf" in /*) ;; *) buf="$wt/$buf" ;; esac
    write_active_buffer "$gid" "$buf"
}

# _group_done_docs <group-plan> <group-id>: after the gate (P-102), the
# ARCHITECTURE.md sections and the umbrella changelog entry, committed in the
# group's worktree as the group's recorded commit. A refusal (a hook, the
# changelog) restores the worktree, which `done` checked clean before the gate,
# and exits with nothing archived; a retry applies everything again.
_group_done_docs() {
    local gf="$1" gid="$2" wt_rel wt out
    # shellcheck source=/dev/null
    . "$(dirname "${BASH_SOURCE[0]}")/group_docs.sh"
    wt_rel=".workspace/P${gid#P-}"; wt="$PRIMARY_ROOT/$wt_rel"
    if ! out="$(group_docs_apply "$gf" ARCHITECTURE.md "$wt/ARCHITECTURE.md")" || ! (
        if [ -n "$out" ]; then printf '%s\n' "$out" | sed 's/^/   ARCHITECTURE.md /'; fi
        cd "$wt" || exit 1
        # shellcheck source=/dev/null
        . "$(dirname "${BASH_SOURCE[0]}")/cmd_commit.sh"
        changelog_sync_plan_entry "$gf" "$gid" >/dev/null || exit 1
        if [ -f ARCHITECTURE.md ]; then git add ARCHITECTURE.md; fi
        if [ -f CHANGELOG.md ]; then git add CHANGELOG.md; fi
        if ! git diff --cached --quiet; then
            "$AAPP_SCRIPT_DIR/aapp" commit "docs: group $gid architecture and changelog" || exit 1
        fi
    ); then
        git -C "$wt" reset -q --hard HEAD || echo "⚠️  [Done] Could not restore $wt_rel; run 'git -C $wt_rel reset --hard HEAD'." >&2
        echo "❌ [Done Refusal] Could not commit the group's ARCHITECTURE.md and changelog in $wt_rel; nothing archived. Run 'aapp done $gid' again once the cause is fixed." >&2
        exit 1
    fi
}

# _group_merge_parent_in <worktree> <parent-ref>: merges the group's parent
# into the feature branch checked out in <worktree>. Always a merge, never a
# rebase: the feature branch holds its members' recorded commits. The parent's
# commits passed the hooks where they were made; this merge is their mechanical
# sum, so it skips them (as P-55's squash does). A conflict is aborted: the
# branch is as it was.
_group_merge_parent_in() {
    if ! git -C "$1" merge -q --no-edit --no-verify "$2" >/dev/null 2>&1; then
        git -C "$1" merge --abort >/dev/null 2>&1
        return 1
    fi
}

# group_merge_parent <group-plan> (P-83): the same merge, made before the
# group's `done`, when a fix its members wait for has landed on the group's
# parent. Works in the worktree that has the feature branch checked out, or in
# a temporary one. Returns 0 when the feature branch holds its parent, 1 with
# nothing changed.
group_merge_parent() {
    local gf="$1" fb parent pref holder tmp rc=0
    fb="$(parse_plan_field "$gf" "Feature Branch")"
    parent="$(plan_base_branch "$gf")"
    git show-ref --verify --quiet "refs/heads/$fb" || return 1
    [ -n "$parent" ] && pref="$(aapp_branch_ref "$parent")" || return 1
    git merge-base --is-ancestor "$pref" "$fb" && return 0
    holder="$(git worktree list --porcelain | awk -v b="refs/heads/$fb" '/^worktree / { w = substr($0, 10) } $1 == "branch" && $2 == b { print w; exit }')"
    if [ -n "$holder" ]; then
        # Someone's work in progress there is not merged over.
        [ -z "$(git -C "$holder" status --porcelain --untracked-files=no 2>/dev/null)" ] || return 1
        _group_merge_parent_in "$holder" "$pref"
        return
    fi
    tmp="$(mktemp -d)" || return 1
    rmdir "$tmp"
    git worktree add -q "$tmp" "$fb" >/dev/null 2>&1 || return 1
    _group_merge_parent_in "$tmp" "$pref" || rc=1
    git worktree remove --force "$tmp" >/dev/null 2>&1 || echo "⚠️  Could not remove '$tmp'; remove it with 'git worktree remove --force $tmp'." >&2
    return "$rc"
}

# _group_done_drop_wt <worktree>: removes a temporary group worktree and its links.
_group_done_drop_wt() {
    local l
    for l in .githooks .agents .plans .claude; do [ -L "$1/$l" ] && rm -f "$1/$l"; done
    git worktree remove --force "$1" >/dev/null 2>&1 || \
        echo "⚠️  Could not remove '$1'; remove it with 'git worktree remove --force $1'." >&2
}

# _group_done_codemap <group-plan> <group-id>: after the merge, the CODEMAP.md
# sections land in .agents in one commit.
_group_done_codemap() {
    local gf="$1" gid="$2" map="$PRIMARY_ROOT/.agents/CODEMAP.md" out
    # shellcheck source=/dev/null
    . "$(dirname "${BASH_SOURCE[0]}")/group_docs.sh"
    out="$(group_docs_apply "$gf" .agents/CODEMAP.md "$map")" || {
        echo "❌ [Done] $gid is merged, but its CODEMAP.md sections did not apply; update .agents/CODEMAP.md by hand." >&2; return 1; }
    [ -n "$out" ] || return 0
    printf '%s\n' "$out" | sed 's/^/   .agents\/CODEMAP.md /'
    git -C "$PRIMARY_ROOT/.agents" add CODEMAP.md && \
        git -C "$PRIMARY_ROOT/.agents" commit -q -m "rules(agents): codemap sections of group $gid" || {
        echo "❌ [Done] Could not commit .agents/CODEMAP.md for $gid; commit it by hand." >&2; return 1; }
}

# _member_group_check <plan> <label>: a group member starts only in a plan
# worktree (WT_MODE) and only once its group is ⚡ In Development.
_member_group_check() {
    local grp gf
    grp="$(parse_plan_field "$1" Group)"
    [ -n "$grp" ] || return 0
    gf="$(resolve_plan_file "$grp" "start")" || return 1
    if [ "$(plan_status_slug "$gf")" != "in-development" ]; then
        echo "❌ [$2] Its group $grp is not ⚡ In Development; start the group first ('aapp start $grp')." >&2
        return 1
    fi
    if [ "$WT_MODE" -ne 1 ]; then
        echo "❌ [$2] A member of group $grp needs a plan worktree: set aapp.planWorktrees on, or add 'worktree <path>'." >&2
        return 1
    fi
}

# validate_group_plan <plan> <label>: a group plan keeps `## Architecture & Codemap`.
validate_group_plan() {
    aapp_is_group_plan "$1" || return 0
    grep -q '^## Architecture & Codemap' "$1" && return 0
    echo "❌ [$2] Group plan $(basename "$1" .md) has no '## Architecture & Codemap' section; write the changed sections, or 'No changes.' under each file." >&2
    return 1
}

# write_active_buffer <plan_id> [buffer_file]: binds the plan in this worktree's
# buffer, or in [buffer_file] (another worktree's, P-54); the previous value
# moves to the `.prev` slot beside it.
write_active_buffer() {
    local plan_id="$1" buf="${2:-$ACTIVE_FILE}" prev
    if [ -n "${2:-}" ]; then prev="$buf.prev"; else prev="$PREV_FILE"; fi
    mkdir -p "$(dirname "$buf")"
    if [ -f "$buf" ]; then
        local cur
        cur="$(head -n 1 "$buf" 2>/dev/null | tr -d '[:space:]')"
        if [ -n "$cur" ] && [ "$cur" != "$plan_id" ]; then
            echo "$cur" > "$prev"
        fi
    fi
    echo "$plan_id" > "$buf"
}

# ------------------------------------------------------------------------------
# Plan worktrees (P-54): `start` / `freeze-start` create the plan's branch and
# worktree, all or nothing.
# ------------------------------------------------------------------------------
# _wt_parse_tokens <label> [worktree <path>] [branch <name>]: sets WT_REQ_PATH,
# WT_REQ_BRANCH and WT_MODE (1 = create a plan worktree).
_wt_parse_tokens() {
    local label="$1"; shift
    WT_REQ_PATH=""; WT_REQ_BRANCH=""; WT_MODE=0
    while [ $# -gt 0 ]; do
        case "$1" in
            worktree) [ $# -ge 2 ] || { echo "❌ [$label] 'worktree' needs a path." >&2; return 1; }
                      WT_REQ_PATH="$2"; shift 2 ;;
            branch)   [ $# -ge 2 ] || { echo "❌ [$label] 'branch' needs a name." >&2; return 1; }
                      WT_REQ_BRANCH="$2"; shift 2 ;;
            *)        echo "❌ [$label] Unknown token '$1'. Usage: <id> [worktree <path> [branch <name>]]" >&2; return 1 ;;
        esac
    done
    if [ -n "$WT_REQ_PATH" ] || [ "$(git config --get aapp.planWorktrees 2>/dev/null)" = "on" ]; then
        WT_MODE=1
    elif [ -n "$WT_REQ_BRANCH" ]; then
        echo "❌ [$label] 'branch' needs a plan worktree: set aapp.planWorktrees on, or add 'worktree <path>'." >&2
        return 1
    fi
}

# _wt_prepare <plan_file> <plan_id> <label>: renders the branch and path and
# resolves the base; refuses (nothing changed) on an existing branch or path, or
# no base branch. Sets WT_BRANCH, WT_PATH, WT_BASE_NAME, WT_BASE_REF, WT_BASE_SHA.
_wt_prepare() {
    local pf="$1" pid="$2" label="$3" b slug repo tpl_b tpl_p origin_head
    b="$(basename "$pf" .md)"; slug="${b#P${pid#P-}-}"
    repo="$(basename "$PRIMARY_ROOT")"
    tpl_b="$(git config --get aapp.planBranch 2>/dev/null)" || tpl_b='plan/{id}-{slug}'
    tpl_p="$(git config --get aapp.planWorktreePath 2>/dev/null)" || tpl_p='.workspace/{id}'
    WT_BRANCH="${WT_REQ_BRANCH:-$(aapp_render_plan_template "$tpl_b" "$pid" "$slug" "$repo")}"
    WT_PATH="$(aapp_abs_path "${WT_REQ_PATH:-$(aapp_render_plan_template "$tpl_p" "$pid" "$slug" "$repo")}" "$PRIMARY_ROOT")"
    if ! git check-ref-format --branch "$WT_BRANCH" >/dev/null 2>&1; then
        echo "❌ [$label] '$WT_BRANCH' is not a valid branch name (aapp.planBranch or 'branch')." >&2; return 1
    fi
    if git show-ref --verify --quiet "refs/heads/$WT_BRANCH"; then
        echo "❌ [$label] Branch '$WT_BRANCH' already exists; a plan worktree never reuses a branch." >&2; return 1
    fi
    if [ -e "$WT_PATH" ]; then
        echo "❌ [$label] Path '$WT_PATH' already exists; a plan worktree never reuses a path." >&2; return 1
    fi
    # Base: the group's feature branch for a member (P-64); else the development
    # branch; only `start` falls back to the default branch.
    local grp gf
    grp="$(parse_plan_field "$pf" Group)"
    if [ -n "$grp" ]; then
        gf="$(resolve_plan_file "$grp" "start")" || return 1
        WT_BASE_NAME="$(parse_plan_field "$gf" "Feature Branch")"
    else
        WT_BASE_NAME="$(aapp_dev_branch)"
    fi
    if [ -z "$WT_BASE_NAME" ] && [ -z "$grp" ]; then
        origin_head="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" || origin_head=""
        if [ -n "$origin_head" ]; then WT_BASE_NAME="${origin_head#origin/}"
        elif aapp_branch_ref main >/dev/null; then WT_BASE_NAME=main
        elif aapp_branch_ref master >/dev/null; then WT_BASE_NAME=master
        fi
    fi
    if [ -z "$WT_BASE_NAME" ] || ! WT_BASE_REF="$(aapp_branch_ref "$WT_BASE_NAME")"; then
        echo "❌ [$label] No base branch: none of aapp.devBranch ($(git config --get aapp.devBranch 2>/dev/null || echo 'develop dev development')) exists, and no default branch (origin/HEAD, main, master)." >&2
        return 1
    fi
    WT_BASE_SHA="$(git rev-parse --short "$WT_BASE_REF")" || return 1
}

# _wt_create <plan_id> <label>: the worktree (no upstream), the kit links and
# their info/exclude entries, and the plan bound in the new worktree's buffer.
# A link that cannot be made fails: never a copy (a second plan store).
_wt_create() {
    local pid="$1" label="$2" buf
    git worktree add -q --no-track -b "$WT_BRANCH" "$WT_PATH" "$WT_BASE_REF" || {
        echo "❌ [$label] git worktree add failed for '$WT_PATH'." >&2; return 1; }
    WT_CREATED=1
    _wt_link_kit "$WT_PATH" "$label" "$WT_BASE_NAME" || return 1
    buf="$(git -C "$WT_PATH" rev-parse --git-path aapp_active_plan)" || return 1
    case "$buf" in /*) ;; *) buf="$WT_PATH/$buf" ;; esac
    write_active_buffer "$pid" "$buf"
}

# _wt_locate <plan_id>: reads back where the plan's worktree is after on-start
# (it may rename the branch or move the worktree): sets WT_PATH and WT_BRANCH.
_wt_locate() {
    local wt line cur=""
    wt="$(find_worktree_holding_plan "$1")" || return 1
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) cur="${line#worktree }" ;;
            "branch refs/heads/"*) if [ "$cur" = "$wt" ]; then WT_PATH="$wt"; WT_BRANCH="${line#branch refs/heads/}"; return 0; fi ;;
        esac
    done < <(git worktree list --porcelain)
    return 1
}

# _wt_rollback: removes what this start created (worktree, links, branch, the
# new buffer) and restores the plan file and state_matrix.md from the snapshot.
# _wt_link_kit <worktree> <label> <branch>: links .githooks, .agents, .plans and
# .claude from the primary checkout into <worktree>, listed in info/exclude.
_wt_link_kit() {
    local wt="$1" label="$2" l rel exclude
    exclude="$(git rev-parse --git-common-dir)/info/exclude"
    mkdir -p "$(dirname "$exclude")" || return 1
    case "$wt" in
        "$PRIMARY_ROOT"/*)
            local wt_rel="${wt#"$PRIMARY_ROOT"/}"
            local wt_top="${wt_rel%%/*}"
            if [ -n "$wt_top" ]; then
                grep -qxF "/$wt_top" "$exclude" 2>/dev/null || echo "/$wt_top" >> "$exclude" || return 1
            fi
            ;;
    esac
    for l in .githooks .agents .plans .claude; do
        grep -qxF "/$l" "$exclude" 2>/dev/null || echo "/$l" >> "$exclude" || return 1
        [ -e "$PRIMARY_ROOT/$l" ] || continue
        if [ -e "$wt/$l" ] || [ -L "$wt/$l" ]; then
            echo "❌ [$label] Cannot link $l into the plan worktree: '$3' already has $l there." >&2; return 1
        fi
        rel="$(aapp_rel_path "$wt" "$PRIMARY_ROOT/$l")"
        ln -s "$rel" "$wt/$l" || { echo "❌ [$label] Cannot link $l into the plan worktree." >&2; return 1; }
    done
}

_wt_rollback() {
    local wt="$WT_PATH" br="$WT_BRANCH"
    if [ "${WT_CREATED:-0}" -eq 1 ]; then
        _wt_locate "$WT_ID" || true   # the hook may have moved or renamed; else the planned names
        [ -n "$WT_PATH" ] && wt="$WT_PATH"; [ -n "$WT_BRANCH" ] && br="$WT_BRANCH"
        git worktree remove --force "$wt" >/dev/null 2>&1 || {
            echo "⚠️  Could not remove the worktree '$wt'; remove it with 'git worktree remove --force $wt'." >&2; }
        git branch -D "$br" >/dev/null 2>&1 || echo "⚠️  Could not delete branch '$br'; delete it with 'git branch -D $br'." >&2
    fi
    git -C "$PLANS_DIR" reset -q -- "current/$(basename "$WT_PLAN_FILE")" state_matrix.md >/dev/null 2>&1 || \
        echo "⚠️  Could not unstage the plan in .plans; check 'git -C .plans status'." >&2
    cp "$WT_SNAP/plan" "$WT_PLAN_FILE"
    [ -f "$WT_SNAP/sm" ] && cp "$WT_SNAP/sm" "$PLANS_DIR/state_matrix.md"
    rm -rf "$WT_SNAP"
}

_wt_fail() {
    echo "❌ [$1] $2; rolled back: no worktree, branch or plan change is left." >&2
    _wt_rollback
    exit 1
}

# _wt_session <plan_file> <plan_id> <worktree>: aapp.planSession, run detached in
# the worktree and never waited on; placeholders are shell-quoted. A launch
# failure only warns: the plan has started (Fallback Inventory).
_wt_session() {
    local pf="$1" pid="$2" wt="$3" tpl b slug cmd first log
    tpl="$(git config --get aapp.planSession 2>/dev/null)" || tpl=""
    if [ -z "$tpl" ]; then echo "   Next         : cd $wt"; return 0; fi
    b="$(basename "$pf")"; slug="${b%.md}"; slug="${slug#P${pid#P-}-}"
    cmd="$tpl"
    cmd="${cmd//\{path\}/$(printf '%q' "$wt")}"
    cmd="${cmd//\{id\}/$(printf '%q' "P${pid#P-}")}"
    cmd="${cmd//\{branch\}/$(printf '%q' "$WT_BRANCH")}"
    cmd="${cmd//\{slug\}/$(printf '%q' "$slug")}"
    cmd="${cmd//\{plan_file\}/$(printf '%q' ".plans/current/$b")}"
    first="${tpl%%[[:space:];]*}"
    if ! command -v "$first" >/dev/null 2>&1; then
        echo "⚠️  [Session] aapp.planSession: '$first' not found; the plan has started. Next: cd $wt" >&2
        return 0
    fi
    log="$(git -C "$wt" rev-parse --git-path aapp_session.log)"
    case "$log" in /*) ;; *) log="$wt/$log" ;; esac
    # Only the session is backgrounded, with its own descriptors, so nothing
    # holds this command's output open (a caller capturing it must not wait).
    ( cd "$wt" || exit 1
      export AAPP_PLAN_ID="$pid" AAPP_WORKTREE="$wt" AAPP_BRANCH="$WT_BRANCH" AAPP_SLUG="$slug" \
             AAPP_PLAN_FILE=".plans/current/$b"
      nohup bash -c "$cmd" >>"$log" 2>&1 </dev/null &
    ) || {
        echo "⚠️  [Session] aapp.planSession could not be launched; the plan has started. Next: cd $wt" >&2
        return 0
    }
    echo "🖥️  [Session] Opened via aapp.planSession in $wt (log: $log)."
}

# _wt_start <plan_file> <plan_id> <label> <log_line> <subject> <freeze>: the
# worktree path of `start` / `freeze-start` (P-54 2.2). Any failure from the
# worktree on rolls everything back.
_wt_start() {
    local pf="$1" pid="$2" label="$3" log_line="$4" subject="$5" freeze="$6"
    local sm_file="$PLANS_DIR/state_matrix.md" data targets_json="" t prim_p wt_p rel today
    _wt_prepare "$pf" "$pid" "$label" || exit 1
    if [ -n "$(git -C "$PRIMARY_ROOT" status --porcelain 2>/dev/null)" ]; then
        echo "ℹ️  [$label] Uncommitted changes stay in the primary checkout; the plan worktree starts from $WT_BASE_NAME."
    fi
    WT_SNAP="$(mktemp -d)" || exit 1
    WT_PLAN_FILE="$pf"; WT_ID="$pid"; WT_CREATED=0
    cp "$pf" "$WT_SNAP/plan" || exit 1
    if [ -f "$sm_file" ]; then cp "$sm_file" "$WT_SNAP/sm" || exit 1; fi

    _wt_create "$pid" "$label" || _wt_fail "$label" "the plan worktree could not be set up"

    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        while IFS= read -r t; do
            [ -n "$t" ] && targets_json="${targets_json:+$targets_json, }\"$t\""
        done < <(parse_plan_target_paths "$pf")
        data="{\"plan_id\": \"$pid\", \"plan_file\": \"$pf\", \"target_files\": [$targets_json], \"worktree\": \"$WT_PATH\", \"branch\": \"$WT_BRANCH\"}"
        dispatch_hook "on-start" "$data" || _wt_fail "$label" "an on-start hook refused"
    fi

    _wt_locate "$pid" || _wt_fail "$label" "the plan worktree was not found after on-start"
    prim_p="$(cd "$PRIMARY_ROOT" && pwd -P)" && wt_p="$(cd "$WT_PATH" && pwd -P)" || \
        _wt_fail "$label" "the plan worktree path could not be resolved"
    rel="$(aapp_rel_path "$prim_p" "$wt_p")"
    write_plan_base "$pf" "\`$WT_BASE_SHA\` ($WT_BASE_NAME)" || _wt_fail "$label" "Base could not be recorded"
    write_plan_worktree "$pf" "$rel ($WT_BRANCH)" || _wt_fail "$label" "Worktree could not be recorded"
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ⚡ In Development/' "$pf"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$pf"
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$pf"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* $log_line" "$pf"
    fi
    sync_state_matrix
    local paths=("current/$(basename "$pf")")
    [ -f "$sm_file" ] && paths+=("state_matrix.md")
    plans_commit "$subject" "${paths[@]}" || _wt_fail "$label" "the start commit failed"
    rm -rf "$WT_SNAP"

    # Dispatch post-mutation observers after commit
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        if [ "$freeze" = "1" ]; then
            local freeze_data="{\"command\": \"plan\", \"event\": \"freeze\", \"plan_id\": \"$pid\", \"plan_file\": \"current/$(basename "$pf")\"}"
            dispatch_hook "post-freeze" "$freeze_data" || true
        fi
        local start_data="{\"command\": \"plan\", \"event\": \"start\", \"plan_id\": \"$pid\", \"plan_file\": \"current/$(basename "$pf")\", \"worktree\": \"$wt_p\", \"branch\": \"$WT_BRANCH\"}"
        dispatch_hook "post-start" "$start_data" || true
    fi

    echo "⚡ [$label] Plan '$pid' activated into ⚡ In Development in its own worktree."
    echo "   Worktree     : $wt_p"
    echo "   Branch       : $WT_BRANCH (from $WT_BASE_NAME \`$WT_BASE_SHA\`, no upstream)"
    _member_guide_line "$pf"
    _wt_session "$pf" "$pid" "$wt_p"
}

# _member_guide_line <plan_file>: a group member's start points its agent at the
# group plan's `## Architecture & Codemap`, the one guide (P-101).
_member_guide_line() {
    local grp gfile
    grp="$(parse_plan_field "$1" Group)"
    [ -n "$grp" ] || return 0
    gfile="$(ls "$PLANS_DIR"/current/P"${grp#P-}"-*.md 2>/dev/null | head -n 1)"
    [ -n "$gfile" ] || return 0
    echo "   Guide        : member of group $grp: read its ## Architecture & Codemap in .plans/current/$(basename "$gfile") before coding."
}

# ------------------------------------------------------------------------------
# Plan branch integration on `done` (P-55): squash / fast-forward / on-integrate,
# with every check run before the archive.
# ------------------------------------------------------------------------------
# _ig_parse_tokens [integrate [squash|ff|hook] [target <b>] [no-cleanup]
#   [force-cleanup] [override-hotfix-cap]] | [no-integrate]
_ig_parse_tokens() {
    IG_REQ=0; IG_NO=0; IG_STRATEGY=""; IG_TARGET=""; IG_NOCLEAN=0; IG_FORCECLEAN=0; IG_OVERRIDE_CAP=0
    while [ $# -gt 0 ]; do
        case "$1" in
            integrate)           IG_REQ=1 ;;
            no-integrate)        IG_NO=1 ;;
            squash|ff|hook)      IG_STRATEGY="$1"; IG_REQ=1 ;;
            target)              [ $# -ge 2 ] || { echo "❌ [Done Refusal] 'target' needs a branch." >&2; return 1; }
                                 IG_TARGET="$2"; IG_REQ=1; shift ;;
            no-cleanup)          IG_NOCLEAN=1 ;;
            force-cleanup)       IG_FORCECLEAN=1 ;;
            override-hotfix-cap) IG_OVERRIDE_CAP=1 ;;
            *) echo "❌ [Done Refusal] Unknown token '$1'. Usage: aapp done <id> [integrate [squash|ff|hook] [target <branch>] [no-cleanup] [force-cleanup] [override-hotfix-cap] | no-integrate]" >&2
               return 1 ;;
        esac
        shift
    done
    if [ "$IG_NO" -eq 1 ] && [ "$IG_REQ" -eq 1 ]; then
        echo "❌ [Done Refusal] 'no-integrate' cannot be combined with integration tokens." >&2; return 1
    fi
}

# _ig_decide <plan_file>: whether this `done` integrates, and how (IG_DO, IG_MODE).
# Only a plan with its own worktree integrates: otherwise its commits are on the
# development branch already.
_ig_decide() {
    local pf="$1" cfg
    IG_DO=0; IG_MODE=""
    cfg="$(git config --get aapp.integrate 2>/dev/null)" || cfg=manual
    case "$cfg" in squash|ff|hook|manual) ;; *)
        echo "❌ [Done Refusal] aapp.integrate is '$cfg'; use squash, ff, hook or manual." >&2; return 1 ;;
    esac
    [ "$IG_NO" -eq 1 ] && return 0
    if [ -z "$(parse_plan_worktree "$pf")" ]; then
        if [ "$IG_REQ" -eq 1 ]; then
            echo "❌ [Done Refusal] $(basename "$pf" .md) has no plan worktree: its commits are on the development branch already." >&2
            return 1
        fi
        return 0
    fi
    if [ "$IG_REQ" -eq 1 ]; then
        IG_MODE="${IG_STRATEGY:-$cfg}"; [ "$IG_MODE" = "manual" ] && IG_MODE=squash
        IG_DO=1
    elif [ "$cfg" != "manual" ]; then
        IG_MODE="$cfg"; IG_DO=1
    fi
}

# _ig_hook_registered: an `on-integrate` handler is registered (fail closed when not).
_ig_hook_registered() {
    local reg="$REPO_ROOT/.agents/skills/aapp-hooks/registry.tsv"
    [ -f "$reg" ] && grep -qE "^on-integrate$(printf '\t')" "$reg" && return 0
    [ -n "$(git config --get-all aapp.hook.on-integrate 2>/dev/null)" ]
}

# _ig_preflight <plan_file> <plan_id>: every integration check, before any
# mutation (P-23 invariant). Sets IG_PLAN_BR, IG_TARGET_BR, IG_WT, IG_ALREADY.
_ig_preflight() {
    local pf="$1" pid="$2" rec max count open limit waited step
    rec="$(parse_plan_worktree "$pf")"
    IG_PLAN_BR="${rec#*$'\t'}"; IG_WT="$(aapp_abs_path "${rec%%$'\t'*}" "$PRIMARY_ROOT")"; IG_ALREADY=0
    if ! git show-ref --verify --quiet "refs/heads/$IG_PLAN_BR"; then
        echo "❌ [Done Refusal] Plan branch '$IG_PLAN_BR' not found; integrate it by hand or archive with 'no-integrate'." >&2; return 1
    fi
    if [ -n "$IG_TARGET" ]; then IG_TARGET_BR="$IG_TARGET"
    elif ! IG_TARGET_BR="$(resolve_plan_integrate_target "$pf")"; then
        echo "❌ [Done Refusal] No integration target: the plan's Base names no branch (aapp.integrateTarget)." >&2; return 1
    fi
    if ! git show-ref --verify --quiet "refs/heads/$IG_TARGET_BR"; then
        echo "❌ [Done Refusal] Integration target '$IG_TARGET_BR' is not a local branch; create or fetch it first." >&2; return 1
    fi
    max="$(git config --get aapp.maxEmergencyHotfixes 2>/dev/null)" || max=2
    case "$max" in ''|*[!0-9]*) max=2 ;; esac
    count="$(count_plan_emergency_hotfixes "$pf")"
    if [ "$count" -gt "$max" ] && [ "$IG_OVERRIDE_CAP" -eq 0 ]; then
        echo "❌ [Integration Block] Plan '$pid' accumulated $count emergency fixes (limit $max)." >&2
        echo "   Daisy-chaining hotfixes is prohibited without formal re-scoping." >&2
        echo "   Requires human sign-off: run 'aapp done $pid integrate override-hotfix-cap'." >&2
        return 1
    fi
    if [ -d "$IG_WT" ] && [ -n "$(git -C "$IG_WT" status --porcelain 2>/dev/null)" ]; then
        echo "❌ [Done Refusal] The plan's worktree has uncommitted changes; commit or discard them first." >&2; return 1
    fi
    if [ "$IG_MODE" = "hook" ]; then
        _ig_hook_registered || {
            echo "❌ [Done Refusal] aapp.integrate = hook, but no on-integrate handler is registered." >&2; return 1; }
        return 0
    fi
    # Already integrated (a retry after a refused cleanup): nothing to merge.
    if git merge-base --is-ancestor "$IG_PLAN_BR" "$IG_TARGET_BR" 2>/dev/null || \
       git diff --quiet "$IG_TARGET_BR" "$IG_PLAN_BR" -- 2>/dev/null; then
        IG_ALREADY=1
    elif ! git merge-base --is-ancestor "$IG_TARGET_BR" "$IG_PLAN_BR"; then
        echo "❌ [Done Refusal] '$IG_PLAN_BR' does not contain '$IG_TARGET_BR'; rebase it first:" >&2
        echo "   git -C ${IG_WT} rebase --autostash $IG_TARGET_BR" >&2
        return 1
    fi
    if [ -n "$(git -C "$PRIMARY_ROOT" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
        echo "❌ [Done Refusal] The main checkout has uncommitted changes; integration switches it to '$IG_TARGET_BR'." >&2; return 1
    fi
    # An open mini plan owns the main checkout: wait for it (P-52 roller), under the issue lock.
    _load_issue_module
    limit="$(_issue_wait_limit)"; waited=0; step=2
    while :; do
        if open="$(_issue_open_mini "$PLANS_DIR")"; then
            _issue_roll "#$open is being fixed in the main checkout" && continue
            echo "❌ [Done Refusal] #$open is being fixed in the main checkout; integrate after 'aapp issue close $open'." >&2
            return 1
        fi
        _issue_lock_acquire || return 1
        _issue_open_mini "$PLANS_DIR" >/dev/null && { _issue_lock_release; continue; }
        break
    done
}

# _ig_message <plan_file> <plan_id> <file> <last_commit>: the squash commit
# message, with lineage trailers and the attribution of the plan's last commit.
_ig_message() {
    local pf="$1" pid="$2" out="$3" title decl max subject
    title="$(grep -m 1 -E '^# ' "$pf" | sed -E 's/^#[[:space:]]*(🗺️[[:space:]]*|🧩[[:space:]]*Group[[:space:]]+)?Plan[^:]*:[[:space:]]*//')"
    max="$(git config --int aapp.subjectMaxLen 2>/dev/null)" || max=72
    subject="feat: $title ($pid)"
    if [ "${#subject}" -gt "$max" ]; then subject="feat: ${title:0:$((max - ${#pid} - 13))}... ($pid)"; fi
    decl="$(aapp_plan_changelog_decl "$pf" 2>/dev/null)" || decl=""
    {
        echo "$subject"
        [ -n "$decl" ] && { echo ""; echo "${decl#*|}"; }
        echo ""
        echo "Plan-ID: $pid"
        echo "Plan-Parent: $IG_TARGET_BR"
        echo "Base-Branch: $(aapp_dev_branch)"
    } > "$out"
    # The plan's last commit names who did the work, also when a person archives it.
    git log -1 --format=%B "$4" 2>/dev/null | git interpret-trailers --parse 2>/dev/null | \
        grep -E '^AI-(Agent|Vendor|Model):' >> "$out" || true
}

# ------------------------------------------------------------------------------
# The squash on the plan branch (P-84): the plan's commits become one commit
# before the archive, so the commit that is recorded is the one the parent
# branch is fast-forwarded to.
# ------------------------------------------------------------------------------
# plan_made_for_issue <plan_file>: prints the issue a plan was made for. Both
# sides agree: the plan's Target Issue names it, and its ledger row is Planned
# and links this plan. One side alone is a plan like any other.
plan_made_for_issue() {
    local pf="$1" n link
    n="$(issue_id_at_start "$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$pf" | head -n 1)")" || return 1
    [ -n "$n" ] || return 1
    case "$(ledger_cell "$n" status issues)" in *Planned*) ;; *) return 1 ;; esac
    link="$(ledger_cell "$n" link issues)"
    case "$link" in *"(current/$(basename "$pf"))"*) ;; *) return 1 ;; esac
    echo "$n"
}

# _sq_decide <plan_file> <plan_id> <is_group> <is_issue_plan>: whether this plan
# is squashed now (SQ_DO): every plan where the setup is squash, and a plan made
# for an issue whatever the setup. Sets SQ_BR, SQ_WT, SQ_TARGET, SQ_BASE.
_sq_decide() {
    local pf="$1" pid="$2" rec
    SQ_DO=0; SQ_BR=""; SQ_WT=""; SQ_TARGET=""; SQ_BASE=""; SQ_OLD=""; SQ_NEW=""
    [ "$3" -eq 0 ] || return 0
    rec="$(parse_plan_worktree "$pf")"
    [ -n "$rec" ] || return 0
    SQ_BR="${rec#*$'\t'}"; SQ_WT="$(aapp_abs_path "${rec%%$'\t'*}" "$PRIMARY_ROOT")"
    git show-ref --verify --quiet "refs/heads/$SQ_BR" || return 0
    if [ "$4" -eq 0 ]; then
        [ "$IG_DO" -eq 1 ] && [ "$IG_MODE" = "squash" ] || return 0
    fi
    [ "${IG_ALREADY:-0}" -eq 0 ] || return 0
    SQ_TARGET="${IG_TARGET_BR:-}"
    if [ -z "$SQ_TARGET" ]; then SQ_TARGET="$(resolve_plan_integrate_target "$pf")" || return 0; fi
    git show-ref --verify --quiet "refs/heads/$SQ_TARGET" || return 0
    SQ_BASE="$(git merge-base "$SQ_TARGET" "$SQ_BR" 2>/dev/null)" || return 0
    [ "$(git rev-parse "$SQ_BR")" != "$SQ_BASE" ] || return 0
    # Already one commit of this plan (a retry): nothing to squash.
    if [ "$(git rev-list --count "$SQ_BASE..$SQ_BR")" = "1" ] && \
       git log -1 --format=%B "$SQ_BR" | grep -qx "Plan-ID: $pid"; then
        return 0
    fi
    SQ_DO=1
}

# _sq_move <commit>: the plan branch points at <commit>; its worktree, whose
# files are the same in both, follows without a change.
_sq_move() {
    if [ -d "$SQ_WT" ] && [ "$(git -C "$SQ_WT" symbolic-ref -q --short HEAD 2>/dev/null)" = "$SQ_BR" ]; then
        git -C "$SQ_WT" reset -q --soft "$1"
    else
        git update-ref "refs/heads/$SQ_BR" "$1"
    fi
}

# _sq_run <plan_file> <plan_id>: makes the one commit (the plan's tree on its
# base, the squash message, the last commit's attribution) and moves the branch
# to it. Sets SQ_OLD (the former tip) and SQ_NEW. A commit that cannot be made
# leaves the branch where it was.
_sq_run() {
    local pf="$1" pid="$2" msg new="" sign=""
    SQ_OLD="$(git rev-parse "refs/heads/$SQ_BR")" || return 1
    msg="$(mktemp)" || return 1
    IG_TARGET_BR="$SQ_TARGET"
    _ig_message "$pf" "$pid" "$msg" "$SQ_OLD" || { rm -f "$msg"; return 1; }
    [ "$(git config --type=bool --get commit.gpgsign 2>/dev/null)" = "true" ] && sign="-S"
    new="$(git commit-tree $sign "$SQ_OLD^{tree}" -p "$SQ_BASE" -F "$msg" 2>/dev/null)" || new=""
    rm -f "$msg"
    if [ -z "$new" ] || ! _sq_move "$new"; then
        _sq_move "$SQ_OLD" 2>/dev/null || true
        echo "❌ [Done Refusal] The plan's commits could not be squashed into one on '$SQ_BR'; the branch is as it was and nothing is archived." >&2
        return 1
    fi
    SQ_NEW="$(git rev-parse --short "$new")"
    _sq_carry_notes "$new"
    echo "🗜️  [Squash] $SQ_BR is one commit now ($SQ_NEW, on $(git rev-parse --short "$SQ_BASE"))."
}

# _sq_carry_notes <commit>: the git notes of the replaced commits on the one
# commit: the attribution (`refs/notes/ai`) of the plan's last commit, as with
# the trailers, and every replaced commit's `refs/notes/commits` note, in order.
_sq_carry_notes() {
    local c text
    git notes --ref=refs/notes/ai copy -f "$SQ_OLD" "$1" >/dev/null 2>&1 || true
    for c in $(git rev-list --reverse "$SQ_BASE..$SQ_OLD"); do
        text="$(git notes --ref=refs/notes/commits show "$c" 2>/dev/null)" || continue
        git notes --ref=refs/notes/commits append -m "$text" "$1" >/dev/null 2>&1 || \
            echo "⚠️  [Squash] Could not carry the note of $(git rev-parse --short "$c") onto $SQ_NEW." >&2
    done
}

# _sq_restore: the plan branch back at its former tip (the archive failed).
_sq_restore() {
    [ -n "${SQ_OLD:-}" ] || return 0
    _sq_move "$SQ_OLD" || echo "⚠️  [Done] Could not put '$SQ_BR' back at $SQ_OLD; do it with 'git branch -f $SQ_BR $SQ_OLD'." >&2
}

# _sq_label: the branch the recorded commit is named with: the parent where the
# kit integrates, the plan branch where a person or a handler does.
_sq_label() {
    if [ "$IG_DO" -eq 1 ] && [ "$IG_MODE" != "hook" ]; then echo "$SQ_TARGET"; else echo "$SQ_BR"; fi
}

# _wt_quarantine <worktree> <plan_id> <files>: copies a worktree's sensitive
# ignored files out before it is removed; a failed copy names the file in
# WT_Q_FAILED.
_wt_quarantine() {
    local f qdir
    qdir="$(cd "$(git rev-parse --git-common-dir)" && pwd)/aapp_quarantine/$2"
    while IFS= read -r f; do
        mkdir -p "$qdir/$(dirname "$f")" && cp -p "$1/$f" "$qdir/$f" || { WT_Q_FAILED="$f"; return 1; }
    done <<< "$3"
    echo "📦 [Cleanup] Quarantined ignored files into $qdir: $(echo "$3" | paste -sd' ' -)"
}

# _ig_cleanup <plan_id>: removes the plan worktree and branch; sensitive ignored
# files refuse it (the integration stands) unless quarantined or forced (Q2).
_ig_cleanup() {
    local pid="$1" files q rel
    rel="$(aapp_rel_path "$PRIMARY_ROOT" "$IG_WT")"
    if [ -d "$IG_WT" ]; then
        files="$(check_worktree_ignored_files "$IG_WT")"
        if [ -n "$files" ]; then
            q="$(git config --get aapp.quarantineIgnored 2>/dev/null)" || q=false
            if [ "$q" = "true" ]; then
                _wt_quarantine "$IG_WT" "$pid" "$files" || {
                    echo "⚠️  [Cleanup Refused] Could not quarantine $WT_Q_FAILED; the worktree is kept." >&2; return 0; }
            elif [ "$IG_FORCECLEAN" -eq 0 ]; then
                echo "⚠️  [Cleanup Refused] Removing $rel would delete ignored files: $(echo "$files" | paste -sd' ' -)"
                echo "   The integration stands. Back them up, set aapp.quarantineIgnored true, or run:"
                echo "      aapp done $pid integrate force-cleanup"
                return 0
            fi
        fi
        git worktree remove "$IG_WT" || { echo "⚠️  [Cleanup] 'git worktree remove $rel' failed; the worktree is kept." >&2; return 0; }
    fi
    # `git branch -d` checks against the current HEAD, not the target: check here.
    if ! git merge-base --is-ancestor "$IG_PLAN_BR" "$IG_TARGET_BR"; then
        echo "⚠️  [Cleanup] '$IG_PLAN_BR' is not in '$IG_TARGET_BR'; the branch is kept." >&2; return 0
    fi
    git branch -D "$IG_PLAN_BR" >/dev/null || { echo "⚠️  [Cleanup] Could not delete '$IG_PLAN_BR'." >&2; return 0; }
    echo "🧹 [Cleanup] Removed worktree $rel and branch $IG_PLAN_BR."
    _issues_follow_branch "$IG_PLAN_BR" "$IG_TARGET_BR"
}

# _ig_run <plan_file> <plan_id>: integrates after the archive, then cleans up.
_ig_run() {
    local pf="$1" pid="$2" orig data rc=0
    if [ "$IG_MODE" = "hook" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        data="{\"plan_id\": \"$pid\", \"plan_file\": \"$pf\", \"plan_branch\": \"$IG_PLAN_BR\", \"target_branch\": \"$IG_TARGET_BR\", \"worktree\": \"$IG_WT\"}"
        if ! dispatch_hook "on-integrate" "$data"; then
            echo "❌ [Integrate] The on-integrate handler refused; $pid stays archived. Retry: aapp done $pid integrate" >&2
            return 1
        fi
        echo "🔀 [Integrate] $IG_PLAN_BR handed to the on-integrate handler (target $IG_TARGET_BR); the branch and worktree are its to manage."
        return 0
    fi
    if [ "$IG_ALREADY" -eq 1 ]; then
        echo "🔀 [Integrate] $IG_PLAN_BR is already in $IG_TARGET_BR."
    else
        orig="$(git -C "$PRIMARY_ROOT" rev-parse --abbrev-ref HEAD)"
        if [ "$orig" != "$IG_TARGET_BR" ]; then
            git -C "$PRIMARY_ROOT" checkout -q "$IG_TARGET_BR" || {
                echo "❌ [Integrate] Could not switch the main checkout to '$IG_TARGET_BR'; $pid stays archived. Retry: aapp done $pid integrate" >&2; return 1; }
        fi
        # P-84: a squashed plan is one commit on its branch already, so every
        # mode moves the parent to the plan branch by fast-forward.
        git -C "$PRIMARY_ROOT" merge -q --ff-only "$IG_PLAN_BR" || rc=$?
        if [ "$orig" != "$IG_TARGET_BR" ]; then
            git -C "$PRIMARY_ROOT" checkout -q "$orig" || echo "⚠️  [Integrate] Could not switch the main checkout back to '$orig'." >&2
        fi
        if [ "$rc" -ne 0 ]; then
            echo "❌ [Integrate] The $IG_MODE into '$IG_TARGET_BR' failed; $pid stays archived. Retry: aapp done $pid integrate" >&2
            return 1
        fi
        echo "🔀 [Integrate] $IG_PLAN_BR integrated into $IG_TARGET_BR ($IG_MODE, $(git rev-parse --short "$IG_TARGET_BR"))."
    fi
    # P-102: a group's CODEMAP sections land once its code is in the parent and
    # before the cleanup, which stays last; a failure is reported, `done` exits 1.
    IG_CODEMAP_FAILED=0
    if aapp_is_group_plan "$pf" && ! _group_done_codemap "$pf" "$pid"; then IG_CODEMAP_FAILED=1; fi
    if [ "$IG_NOCLEAN" -eq 1 ] || [ "$(git config --get aapp.integrateCleanup 2>/dev/null)" = "false" ]; then
        [ "${IG_LAND:-0}" -eq 1 ] || echo "   Worktree and branch kept (cleanup off)."
        return 0
    fi
    _ig_cleanup "$pid"
}

# _ig_resolve_done <query>: an archived plan file in done/ (standalone integrate).
_ig_resolve_done() {
    local q="$1" pf pid b
    for pf in "$PLANS_DIR"/done/*.md; do
        [ -f "$pf" ] || continue
        b="$(basename "$pf" .md)"
        case "$b" in 000-*) continue ;; esac
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
        if [ "$q" = "$pid" ] || [ "P-$q" = "$pid" ] || [ "$q" = "$b" ] || [[ "$b" == "$q-"* ]] || [[ "$b" == "P${q#P-}-"* ]]; then
            echo "$pf"; return 0
        fi
    done
    echo "❌ [Done Refusal] Plan '$q' found in neither current/ nor done/." >&2
    return 1
}

# _ig_standalone <done_file>: `aapp done <id> integrate` on an archived plan
# (after `manual`, a refused hook, or a refused cleanup).
_ig_standalone() {
    local pf="$1" pid
    pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
    _ig_decide "$pf" || exit 1
    _ig_preflight "$pf" "$pid" || exit 1
    # P-84: squashed now, on the plan branch; the records follow the new commit.
    local grp=0
    if aapp_is_group_plan "$pf"; then grp=1; fi
    _sq_decide "$pf" "$pid" "$grp" 0
    if [ "$SQ_DO" -eq 1 ]; then _sq_run "$pf" "$pid" || exit 1; fi
    if ! _ig_run "$pf" "$pid"; then
        if [ "$SQ_DO" -eq 1 ]; then _sq_restore; fi
        exit 1
    fi
    if [ "$SQ_DO" -eq 1 ]; then _sq_correct_records "$pf" "$pid" || exit 1; fi
    _load_issue_module
    issue_unblock_landed quiet || echo "⚠️  [Done] Could not check the plans waiting for a fix; 'aapp status' does it." >&2
    if [ "${IG_CODEMAP_FAILED:-0}" -eq 1 ]; then exit 1; fi
}

# _sq_correct_records <done_file> <plan_id>: an archived plan squashed later
# names its new commit: its `Commits:`, its line in the archive ledger and the
# archived row of the issue it closed, in one commit on the plans branch.
_sq_correct_records() {
    local pf="$1" pid="$2" old n bname ledger="$PLANS_DIR/done/000-archive-ledger.md" tmp
    local paths=()
    bname="$(basename "$pf")"
    old="$(parse_plan_commits "$pf" | tail -n 1 | awk '{print $1}')"
    write_plan_commits "$pf" "\`$SQ_NEW\` ($SQ_TARGET)" || return 1
    paths+=("done/$bname")
    if [ -n "$old" ] && [ -f "$ledger" ]; then
        tmp="$ledger.aapp-record.$$"
        AAPP_PID="| \`$pid\` |" AAPP_OLD="\`$old\`" AAPP_NEW="\`$SQ_NEW\`" awk '
            !d && index($0, ENVIRON["AAPP_PID"]) && (i = index($0, ENVIRON["AAPP_OLD"])) {
                $0 = substr($0, 1, i - 1) ENVIRON["AAPP_NEW"] substr($0, i + length(ENVIRON["AAPP_OLD"])); d = 1 }
            { print }' "$ledger" > "$tmp" && mv "$tmp" "$ledger" || { rm -f "$tmp"; return 1; }
        paths+=("done/000-archive-ledger.md")
    fi
    n="$(issue_id_at_start "$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$pf" | head -n 1)")" || n=""
    if [ -n "$n" ] && [ -n "$old" ]; then
        case "$(ledger_cell "$n" commit archive)" in
            *"$old"*) ledger_set_archive_commit "$n" "$SQ_NEW" || return 1
                      paths+=($(ledger_commit_paths archive)) ;;
        esac
    fi
    plans_commit "plan(record): record $SQ_NEW for $pid" "${paths[@]}" || return 1
    echo "   Records      : $pid and its issue name $SQ_NEW."
}

# _draft_template <name>: the path of templates/<name> (AAPP_TEMPLATES, this
# checkout, the primary checkout); refuses when there is none.
_draft_template() {
    local t
    for t in "${AAPP_TEMPLATES:+$AAPP_TEMPLATES/$1}" "$REPO_ROOT/templates/$1" "${PRIMARY_ROOT:+$PRIMARY_ROOT/templates/$1}"; do
        [ -n "$t" ] && [ -f "$t" ] && { echo "$t"; return 0; }
    done
    echo "❌ [Draft Refusal] templates/$1 not found." >&2
    return 1
}

# _draft_render <template> <target> <num> <today> <title> <entry-text>: the plan
# file from its template, with the modes stamped. Placeholder substitution
# (P-34 D1): the title is free text, so it never passes through a pattern
# language: sed treats `/`, `&` and `\` in it as syntax, `awk -v` expands its
# backslash escapes, and gsub's replacement expands `&`. It travels via ENVIRON
# and is spliced with index/substr. The title goes in last, so a title
# containing `P-XX` is not rewritten.
_draft_render() {
    local template_file="$1" target_file="$2" tmp_file="$2.aapp-draft.$$"
    if ! AAPP_DRAFT_NUM="$3" AAPP_DRAFT_TODAY="$4" AAPP_DRAFT_TITLE="$5" AAPP_DRAFT_TEXT="$6" awk '
        function replace_all(s, pat, rep,    out, i) {
            out = ""
            while ((i = index(s, pat)) > 0) {
                out = out substr(s, 1, i - 1) rep
                s = substr(s, i + length(pat))
            }
            return out s
        }
        {
            line = replace_all($0, "[YYYY-MM-DD]", ENVIRON["AAPP_DRAFT_TODAY"])
            line = replace_all(line, "P-XX", "P-" ENVIRON["AAPP_DRAFT_NUM"])
            line = replace_all(line, "Plan P-" ENVIRON["AAPP_DRAFT_NUM"] ": [Feature or Refactor Name]", \
                               "Plan P-" ENVIRON["AAPP_DRAFT_NUM"] ": " ENVIRON["AAPP_DRAFT_TITLE"])
            # P-48: the changelog declaration starts as the title.
            line = replace_all(line, "**Changelog:** Changed: [Feature or Refactor Name]", \
                               "**Changelog:** Changed: " ENVIRON["AAPP_DRAFT_TITLE"])
            line = replace_all(line, "[Group Name]", ENVIRON["AAPP_DRAFT_TITLE"])
            if (ENVIRON["AAPP_DRAFT_TEXT"] != "" && $0 ~ /^\*Provide a concise summary of WHAT is being built/) {
                line = ENVIRON["AAPP_DRAFT_TEXT"]
            }
            print line
        }
    ' "$template_file" > "$tmp_file"; then
        rm -f "$tmp_file"
        echo "❌ [Draft Refusal] Failed to render the plan template." >&2
        return 1
    fi
    mv "$tmp_file" "$target_file"
    # P-51: the modes this plan will be built under, from the current config.
    aapp_plan_stamp_modes "$target_file" || {
        echo "❌ [Draft Refusal] Could not record the commit and changelog modes." >&2
        return 1
    }
}

# _draft_amendments_member <group-plan> <group-id> <slug> <title> <today> <dir>
# (P-101): drafts `<slug>-amendments` from templates/amendments-template.md as
# the group's last member; prints its path relative to the plans worktree.
_draft_amendments_member() {
    local gf="$1" gid="$2" aid anum aslug af tpl
    tpl="$(_draft_template amendments-template.md)" || return 1
    aid="$(allocate_plan_id)" || { echo "❌ [Draft Refusal] Failed to allocate the amendments member's Plan ID." >&2; return 1; }
    anum="${aid#P-}"; aslug="$3-amendments"
    af="$6/current/P${anum}-${aslug}.md"
    _draft_render "$tpl" "$af" "$anum" "$5" "$4 Amendments" "" || return 1
    write_plan_field "$af" Group "$gid" Base && group_set_member "$gf" "$aid" add || {
        echo "❌ [Draft Refusal] Could not record $aid in group $gid." >&2; return 1; }
    echo "current/P${anum}-${aslug}.md"
}

cmd_draft() {
    local raw_slug="$1"
    local slug=""
    local title=""
    local entry_text=""
    local promote_issue=""
    local tpl_name="plan-template.md" join_group="" join_gfile=""

    # P-64: `draft <slug> group` drafts a group plan; `draft <slug> group <id>`
    # a member of that group. Checked before any allocation.
    if [ "${2:-}" = "group" ]; then
        if [ -z "${3:-}" ]; then
            tpl_name="group-template.md"
        else
            join_gfile="$(_group_resolve "$3" "Draft Refusal")" || return 1
            join_group="$(sed -nE 's/^\* \*\*Plan ID:\*\*[[:space:]]*(P-[0-9]+).*/\1/p' "$join_gfile" | head -n 1)"
        fi
    fi

    # P-50: `aapp draft <slug> issue <num>` promotes an active issue. Checked
    # before any allocation, so a refused promotion burns no Plan ID.
    if [ "${2:-}" = "issue" ]; then
        _load_issue_module
        promote_issue="$(issue_id_body "${3:-}")" || exit 1
        if [ "$(ledger_locate "$promote_issue")" != "active" ]; then
            echo "❌ [Draft Refusal] #$promote_issue is not an active issue in ISSUES.md (archived or unknown)." >&2
            return 1
        fi
    fi

    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR" ]; then
        echo "❌ [Plan Switchboard] .plans directory not found." >&2
        return 1
    fi
    mkdir -p "$PLANS_DIR/current"

    if [ -n "$raw_slug" ]; then
        slug="$(echo "$raw_slug" | tr '[:upper:]' '[:lower:]' | sed 's/[ _]/-/g' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
        title="$(echo "$raw_slug" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"
    else
        # No-Dead-End Invariant (Bare Invocations)
        local pickup_items=()
        if [ -f "$PLANS_DIR/pickup.md" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && pickup_items+=("$line")
            done < <(grep -E '^[0-9]+\.|^[\*-] ' "$PLANS_DIR/pickup.md" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '\[x\]|\[X\]' || true)
        fi

        local issue_items=()
        while IFS= read -r line; do
            [ -n "$line" ] && issue_items+=("$line")
        # Issues awaiting a plan: the status cell says Incubated.
        done < <(ledger_row_lines Incubated)

        if [ ${#pickup_items[@]} -gt 0 ]; then
            echo "💡 Unprocessed notes in .plans/pickup.md:"
            local limit=10
            local count=${#pickup_items[@]}
            [ $count -lt $limit ] && limit=$count
            for i in $(seq 1 $limit); do
                local item="${pickup_items[$((i-1))]}"
                local split t_item
                split="$(pickup_entry_split "$item")"
                t_item="${split%%$'\t'*}"
                [ -z "$t_item" ] && t_item="$(echo "$item" | sed -E 's/^[0-9]+\.[[:space:]]*|^[\*-][[:space:]]*(\[[[:space:]]\])?[[:space:]]*//')"
                echo "  $i) $t_item"
            done
            if [ $count -gt 10 ]; then
                echo "  ... and $((count - 10)) more unprocessed notes"
            fi
            echo ""
            local chosen=""
            if [ -t 0 ]; then
                printf "Select a note [1-%s], enter a custom title/slug, or Ctrl+C to abort: " "$limit"
                read -r user_choice
                if [ -n "$user_choice" ]; then
                    if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le $limit ]; then
                        chosen="${pickup_items[$((user_choice-1))]}"
                    else
                        title="$user_choice"
                        slug="$(echo "$user_choice" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
                    fi
                fi
            else
                chosen="${pickup_items[0]}"
            fi

            if [ -n "$chosen" ]; then
                local split
                split="$(pickup_entry_split "$chosen")"
                title="${split%%$'\t'*}"
                entry_text="${split#*$'\t'}"
                if [ -z "$title" ]; then
                    title="$(echo "$chosen" | sed -E 's/^[0-9]+\.[[:space:]]*|^[\*-][[:space:]]*(\[[[:space:]]\])?[[:space:]]*//')"
                    entry_text=""
                fi
                slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
                # P-97 §2.2: Cut slug at its last '-' before 60 characters
                if [ "${#slug}" -gt 60 ]; then
                    slug="${slug:0:60}"
                    case "$slug" in
                        *-*) slug="${slug%-*}" ;;
                    esac
                fi
                if [ -n "$entry_text" ]; then
                    local p_files=""
                    while IFS= read -r pf; do
                        [ -n "$pf" ] && p_files="${p_files}
- \`${pf}\`"
                    done < <(pickup_entry_files "$entry_text")
                    if [ -n "$p_files" ]; then
                        entry_text="${entry_text}

Notes from pickup:${p_files}"
                    fi
                fi
                if [ ! -t 0 ]; then
                    echo "ℹ️  Non-interactive terminal: auto-selected first note: $title"
                fi
            fi
        elif [ ${#issue_items[@]} -gt 0 ]; then
            echo "🐛 Open issues in .plans/ISSUES.md available for promotion:"
            local limit=10
            local count=${#issue_items[@]}
            [ $count -lt $limit ] && limit=$count
            for i in $(seq 1 $limit); do
                local item="${issue_items[$((i-1))]}"
                local issue_id issue_desc
                issue_id="$(echo "$item" | awk -F'|' '{print $2}' | tr -d '[:space:]')"
                issue_desc="$(echo "$item" | awk -F'|' '{print $7}' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
                echo "  $i) $issue_id: $issue_desc"
            done
            if [ $count -gt 10 ]; then
                echo "  ... and $((count - 10)) more open issues"
            fi
            echo ""
            if [ -t 0 ]; then
                printf "Select an issue [1-%s], enter a custom title/slug, or Ctrl+C to abort: " "$limit"
                read -r user_choice
                if [ -n "$user_choice" ]; then
                    if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le $limit ]; then
                        local chosen="${issue_items[$((user_choice-1))]}"
                        local issue_id issue_desc
                        issue_id="$(echo "$chosen" | awk -F'|' '{print $2}' | tr -d '[:space:]')"
                        issue_desc="$(echo "$chosen" | awk -F'|' '{print $7}' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
                        title="$issue_id $issue_desc"
                        slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
                    else
                        title="$user_choice"
                        slug="$(echo "$user_choice" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
                    fi
                fi
            else
                echo "❌ [Draft Refusal] Please specify a plan slug: aapp draft <slug>" >&2
                return 1
            fi
        else
            if [ -t 0 ]; then
                printf "Enter plan title or slug: "
                read -r user_choice
                if [ -n "$user_choice" ]; then
                    title="$user_choice"
                    slug="$(echo "$user_choice" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
                fi
            else
                echo "❌ [Draft Refusal] Please specify a plan slug: aapp draft <slug>" >&2
                return 1
            fi
        fi
    fi

    if [ -z "$slug" ]; then
        echo "❌ [Draft Refusal] Plan slug cannot be empty." >&2
        return 1
    fi

    # Monotonic Plan ID allocation
    local plan_id
    # P-75: with a plan-id provider installed and unreachable (or not to be
    # asked: offline-only), the draft takes a temporary id and is written to
    # `.offline/current/`; `aapp offline sync` gives it its real id.
    local draft_dir="$PLANS_DIR" draft_offline=0 pmode="off"
    if [ -d "$REPO_ROOT/.agents/skills/aapp-planid" ] && resolve_plugin_entrypoint "$REPO_ROOT/.agents/skills/aapp-planid" "aapp-planid" >/dev/null 2>&1; then
        _load_issue_module
        _issue_load_offline || return 1
        pmode="$(offline_mode)"
    fi
    if [ "$pmode" = "only" ]; then
        draft_offline=1
    elif ! plan_id="$(allocate_plan_id 2>/dev/null)"; then
        if [ "$pmode" != "on" ]; then
            allocate_plan_id >/dev/null || true
            echo "❌ [Draft Refusal] Failed to allocate Plan ID." >&2
            return 1
        fi
        draft_offline=1
    fi
    if [ "$draft_offline" -eq 1 ]; then
        if [ -n "$promote_issue" ] || [ -n "$join_group" ]; then
            echo "❌ [Draft Refusal] The plan-id provider is unreachable: a plan drafted offline cannot be linked to an issue or a group until 'aapp offline sync' has published it." >&2
            return 1
        fi
        if [ "$tpl_name" = "group-template.md" ]; then
            echo "❌ [Draft Refusal] The plan-id provider is unreachable: a group drafted offline could not get its amendments member; draft the group once the provider answers." >&2
            return 1
        fi
        offline_mount quiet || return 1
        plan_id="P-$(offline_next_plan_id)"
        draft_dir="$(offline_dir)"
        echo "📡 [Draft] The plan-id provider is unreachable: $plan_id is a temporary id, drafted in .offline/current/; 'aapp offline sync' publishes it."
    fi
    local num="${plan_id#P-}"

    local template_file
    template_file="$(_draft_template "$tpl_name")" || return 1

    local target_file="$draft_dir/current/P${num}-${slug}.md"
    local today
    today="$(date +%Y-%m-%d)"
    [ -z "$title" ] && title="$(echo "$slug" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"

    _draft_render "$template_file" "$target_file" "$num" "$today" "$title" "$entry_text" || return 1

    # P-101: a new group gets its amendments member in the same commit.
    local amend_rel=""
    if [ "$tpl_name" = "group-template.md" ]; then
        amend_rel="$(_draft_amendments_member "$target_file" "P-$num" "$slug" "$title" "$today" "$draft_dir")" || return 1
    fi

    # P-50 promotion: the plan names the issue; the row gets Planned + link.
    if [ -n "$promote_issue" ]; then
        sed -i -E "s|^\* \*\*Target Issue / Milestone:\*\*.*$|* **Target Issue / Milestone:** #$promote_issue|" "$target_file"
        issue_mark_planned "$promote_issue" "[P-${num}](current/P${num}-${slug}.md)" || {
            echo "❌ [Draft Refusal] Could not mark #$promote_issue Planned in ISSUES.md." >&2
            exit 1
        }
    fi

    # P-64: a member names its group, and the group lists it.
    if [ -n "$join_group" ]; then
        write_plan_field "$target_file" Group "$join_group" Base && group_set_member "$join_gfile" "P-$num" add || {
            echo "❌ [Draft Refusal] Could not record P-$num in group $join_group." >&2
            exit 1
        }
    fi

    # P-75: a draft staged offline is committed there, on the `offline` branch;
    # the plans branch and its matrix learn of it at the sync.
    if [ "$draft_offline" -eq 1 ]; then
        offline_commit "plan(draft): P-${num} ${slug} staged offline" >/dev/null
        echo "🚀 Blueprint scaffolded: .offline/current/P${num}-${slug}.md"
        echo "   Plan ID: P-${num} (temporary)"
        echo "   Status : 🟣 Under Review (staged offline)"
        return 0
    fi

    # State matrix registration: derived from the new plan's Status line.
    local sm_file="$PLANS_DIR/state_matrix.md"
    sync_state_matrix

    # Git commit in .plans worktree
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local plan_rel="current/P${num}-${slug}.md"
        local draft_paths=("$plan_rel")
        [ -f "$sm_file" ] && draft_paths+=("state_matrix.md")
        [ -n "$promote_issue" ] && draft_paths+=($(ledger_commit_paths issues))
        [ -n "$join_group" ] && draft_paths+=("current/$(basename "$join_gfile")")
        [ -n "$amend_rel" ] && draft_paths+=("$amend_rel")
        local max_subject_len
        max_subject_len="$(aapp_subject_max_len)"
        local prefix="plan(draft): scaffold P-${num} "
        local subject="${prefix}${slug}"
        if [ "${#subject}" -gt "$max_subject_len" ]; then
            local max_slug_len=$((max_subject_len - ${#prefix}))
            if [ "$max_slug_len" -gt 0 ]; then
                local fitted_slug="${slug:0:$max_slug_len}"
                case "$fitted_slug" in
                    *-*) fitted_slug="${fitted_slug%-*}" ;;
                esac
                subject="${prefix}${fitted_slug}"
            fi
        fi
        plans_commit "$subject" "${draft_paths[@]}" || exit 1
    fi
    # P-74: the provider is told the issue is now planned.
    if [ -n "$promote_issue" ]; then issue_send_refine "$promote_issue"; fi

    # Dispatch post-draft observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local draft_data="{\"command\": \"plan\", \"event\": \"draft\", \"plan_id\": \"P-${num}\", \"slug\": \"$slug\", \"plan_file\": \"$plan_rel\", \"group\": \"${join_group:-none}\"}"
        dispatch_hook "post-draft" "$draft_data" || true
    fi

    echo "🚀 Blueprint scaffolded: .plans/current/P${num}-${slug}.md"
    echo "   Plan ID: P-${num}"
    echo "   Status : 🟣 Under Review (Incubator)"
    if [ -n "$amend_rel" ]; then
        echo "   Amendments member: .plans/$amend_rel (started with the group; takes what development finds)"
    fi

    # Conditional editor launch
    if [ -t 0 ] && [ -n "$EDITOR" ]; then
        printf "Open in \$EDITOR (%s)? [Y/n] " "$EDITOR"
        read -r open_choice
        case "$open_choice" in
            [nN]*) ;;
            *) "$EDITOR" "$target_file" ;;
        esac
    fi
}

cmd_freeze_start() {
    local query="${1:-}"
    [ $# -gt 0 ] && shift
    local plan_file
    plan_file="$(resolve_plan_file "$query" "freeze-start")" || exit 1
    refuse_unless_incubator "$plan_file" "Freeze-Start"
    refuse_uncommitted_plan_edits "$plan_file" "Freeze-Start"
    if aapp_is_group_plan "$plan_file"; then
        cmd_freeze "$query"
        _group_start "$plan_file" "$@"
        return
    fi
    _wt_parse_tokens "Freeze-Start Refusal" "$@" || exit 1

    # Refuse from planning worktrees (.plans, .agents, .githooks)
    local cur_top
    cur_top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    case "$cur_top" in
        */.plans|*/.agents|*/.githooks)
            echo "❌ [Freeze-Start Refusal] Cannot freeze-start plan from planning worktree '$(basename "$cur_top")'." >&2
            echo "   Run freeze-start from a code worktree." >&2
            exit 1
            ;;
    esac

    # Verify Open Questions
    local unresolved_q
    unresolved_q=$(awk '
        /^## ❓ 5\. Open Questions/ { in_q=1; next }
        /^## / && in_q { in_q=0 }
        in_q && /^[[:space:]]*\*[[:space:]]*\[[[:space:]]\]/ { print $0 }
    ' "$plan_file")

    if [ -n "$unresolved_q" ]; then
        echo "❌ [Freeze-Start Refusal] Plan has unresolved open questions in ## ❓ 5. Open Questions:" >&2
        echo "$unresolved_q" | sed 's/^/     /' >&2
        echo "   All open questions must be resolved and checked off ([x]) before freeze-start." >&2
        exit 1
    fi

    # Verify Target Files declared
    local targets
    targets="$(parse_plan_target_paths "$plan_file")"
    if [ -z "$targets" ]; then
        echo "❌ [Freeze-Start Refusal] Plan declares no Target Files under '### 📂 Target Files'." >&2
        exit 1
    fi

    # Disjointness check
    check_disjointness_activation_gate "$plan_file" || exit 1

    # Verify TDD failure tests correspondence if declared (P-35)
    validate_plan_tdd_correspondence "$plan_file" "Freeze-Start Refusal" || exit 1
    validate_plan_changelog_decl "$plan_file" "Freeze-Start Refusal" || exit 1
    _member_group_check "$plan_file" "Freeze-Start Refusal" || exit 1

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Verify plan is not bound in another worktree
    local holding_wt
    holding_wt="$(find_worktree_holding_plan "$plan_id")" || true
    if [ -n "$holding_wt" ]; then
        echo "❌ [Freeze-Start Refusal] Plan '$plan_id' is already bound in worktree '$holding_wt'." >&2
        exit 1
    fi

    # Dispatch pre-freeze and pre-start gating hooks (pre-mutation quality gates)
    local fs_data=""
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local targets_json=""
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            if [ -z "$targets_json" ]; then
                targets_json="\"$t\""
            else
                targets_json="$targets_json, \"$t\""
            fi
        done < <(parse_plan_target_paths "$plan_file")
        fs_data="{\"plan_id\": \"$plan_id\", \"plan_file\": \"$plan_file\", \"target_files\": [$targets_json]}"
        if ! dispatch_hook "pre-freeze" "$fs_data"; then
            echo "❌ [Freeze-Start Refusal] pre-freeze hook vetoed freezing of plan '$plan_id'." >&2
            exit 1
        fi
        if ! dispatch_hook "pre-start" "$fs_data"; then
            echo "❌ [Freeze-Start Refusal] pre-start hook vetoed activation of plan '$plan_id'." >&2
            exit 1
        fi
    fi

    # P-84: a plan made for an issue always has a branch of its own, so it can
    # land as one commit.
    if [ "$WT_MODE" -eq 0 ] && plan_made_for_issue "$plan_file" >/dev/null; then WT_MODE=1; fi
    # P-54: a fresh start may get its own branch and worktree (a re-scoped plan,
    # started before, keeps where it lives).
    if [ "$WT_MODE" -eq 1 ] && [ -n "$(parse_plan_base "$plan_file")" ]; then
        if [ -n "$WT_REQ_PATH" ]; then
            echo "❌ [Freeze-Start Refusal] $plan_id was started before; its worktree is chosen at its first start." >&2
            exit 1
        fi
        WT_MODE=0
    fi
    if [ "$WT_MODE" -eq 1 ]; then
        _wt_start "$plan_file" "$plan_id" "Freeze-Start" "Plan frozen and activated into ⚡ In Development via freeze-start." \
            "plan(start): freeze and activate $plan_id into development" 1
        return 0
    fi

    local plan_snap=""
    plan_snap="$(mktemp)" || exit 1
    cp "$plan_file" "$plan_snap" || exit 1

    # Record Base SHA and branch
    local head_sha head_br
    head_sha="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"
    head_br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
    [ "$head_br" = "HEAD" ] && head_br="detached"
    write_plan_base "$plan_file" "\`$head_sha\` ($head_br)"

    # Update plan header & lock status
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ⚡ In Development/' "$plan_file"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$plan_file"

    local today
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$plan_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan frozen and activated into ⚡ In Development via freeze-start." "$plan_file"
    fi

    # Update state matrix if present
    local sm_file="$PLANS_DIR/state_matrix.md"
    sync_state_matrix

    # Write buffer
    write_active_buffer "$plan_id"

    # Action delegate: on-start (in-transaction)
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        if ! dispatch_hook "on-start" "$fs_data"; then
            echo "❌ [Freeze-Start Refusal] on-start action delegate failed for '$plan_id'." >&2
            cp "$plan_snap" "$plan_file"
            rm -f "$plan_snap"
            rm -f "$ACTIVE_FILE"
            sync_state_matrix
            exit 1
        fi
    fi
    rm -f "$plan_snap"

    # Commit transition in plans worktree if available
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local plan_rel="current/$(basename "$plan_file")"
        if [ -f "$sm_file" ]; then
            plans_commit "plan(start): freeze and activate $plan_id into development" "$plan_rel" "state_matrix.md" || exit 1
        else
            plans_commit "plan(start): freeze and activate $plan_id into development" "$plan_rel" || exit 1
        fi
    fi

    # Dispatch post-freeze and post-start observers
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        local post_freeze_data="{\"command\": \"plan\", \"event\": \"freeze\", \"plan_id\": \"$plan_id\", \"plan_file\": \"current/$(basename "$plan_file")\"}"
        local post_start_data="{\"command\": \"plan\", \"event\": \"start\", \"plan_id\": \"$plan_id\", \"plan_file\": \"current/$(basename "$plan_file")\", \"worktree\": \"none\", \"branch\": \"none\"}"
        dispatch_hook "post-freeze" "$post_freeze_data" || true
        dispatch_hook "post-start" "$post_start_data" || true
    fi

    echo "⚡ [Freeze-Start] Plan '$plan_id' frozen and activated into ⚡ In Development."
    echo "   Blueprint    : $plan_file"
    echo "   Active Buffer: $ACTIVE_FILE"
    _member_guide_line "$plan_file"
}

cmd_tdd() {
    local query="$1"
    local plan_file=""

    if [ -z "$query" ]; then
        echo "❌ [Plan Switchboard] You must specify a target plan for 'tdd'." >&2
        return 1
    fi

    # 1. Attempt to resolve as an existing plan in current/
    if plan_file="$(resolve_plan_file "$query" "tdd" 2>/dev/null)"; then
        :
    else
        # 2. Not found in current/. Check if query looks like a specific plan ID or missing reference
        if [[ "$query" =~ ^[0-9]+$ ]] || [[ "$query" =~ ^P-?[0-9]+$ ]] || [[ "$query" =~ ^P[0-9]+- ]] || [[ "$query" =~ \.md$ ]] || [[ "$query" =~ ^# ]]; then
            echo "❌ [Plan Switchboard] Plan '$query' not found in $PLANS_DIR/current/." >&2
            return 1
        fi

        # 3. Query is a new slug: auto-scaffold first via cmd_draft
        cmd_draft "$query" || return 1
        plan_file="$(resolve_plan_file "$query" "tdd")" || return 1
    fi
    refuse_unless_incubator "$plan_file" "TDD"

    if grep -q -E '###[[:space:]]*🧪[[:space:]]*Required Tests' "$plan_file" || \
       grep -q -E '###[[:space:]]*🧪[[:space:]]*Required Test Files' "$plan_file"; then
        echo "❌ [TDD Refusal] Plan already has TDD failure test sections declared." >&2
        return 1
    fi

    local tmp_file
    tmp_file="$(mktemp 2>/dev/null || echo "${plan_file}.tmp")"
    awk '
    BEGIN { in3=0; in4=0; ins3=0; ins4=0 }
    /^## ([^0-9]*[[:space:]])?3\./ { in3=1; in4=0 }
    /^## ([^0-9]*[[:space:]])?4\./ {
        if (in3 && !ins3) {
            print "### \360\237\247\252 Required Tests (Failure & Boundary Assertions)"
            print "> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`\n"
            ins3=1
        }
        in3=0; in4=1
    }
    /^## ([^0-9]*[[:space:]])?5\./ { in3=0; in4=0 }

    in3 && !ins3 && /^### / {
        print "### \360\237\247\252 Required Tests (Failure & Boundary Assertions)"
        print "> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`\n"
        ins3=1
    }

    in4 && !ins4 && (/^###[[:space:]]*🛑/ || /^---/) {
        print "### \360\237\247\252 Required Test Files"
        print "> Test files that must prove this plan\047s failure cases. Frozen with the blast radius.\n"
        ins4=1
    }

    { print }
    END {
        if (in4 && !ins4) {
            print "\n### \360\237\247\252 Required Test Files"
            print "> Test files that must prove this plan\047s failure cases. Frozen with the blast radius.\n"
        }
    }
    ' "$plan_file" > "$tmp_file"

    mv "$tmp_file" "$plan_file"

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Commit the injection in the plans worktree; a failed commit is fatal (P-47).
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        plans_commit "plan(refine): declare failure tests for $plan_id" "current/$(basename "$plan_file")" || exit 1
    fi

    # Dispatch post-tdd observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local tdd_data="{\"command\": \"plan\", \"event\": \"tdd\", \"plan_id\": \"$plan_id\", \"plan_file\": \"current/$(basename "$plan_file")\"}"
        dispatch_hook "post-tdd" "$tdd_data" || true
    fi

    echo "🧪 [TDD] Declared failure test sections in $(basename "$plan_file")."
    echo "   Next: Enumerate failure assertions in §3 and declared test files in §4 (via '/aapp-tdd' or manual edit)."
}

cmd_freeze() {
    local query="$1"
    local plan_file
    plan_file="$(resolve_plan_file "$query" "freeze")" || exit 1
    refuse_unless_incubator "$plan_file" "Freeze"
    refuse_uncommitted_plan_edits "$plan_file" "Freeze"

    # Verify Open Questions
    local unresolved_q
    unresolved_q=$(awk '
        /^## ❓ 5\. Open Questions/ { in_q=1; next }
        /^## / && in_q { in_q=0 }
        in_q && /^[[:space:]]*\*[[:space:]]*\[[[:space:]]\]/ { print $0 }
    ' "$plan_file")

    if [ -n "$unresolved_q" ]; then
        echo "❌ [Freeze Refusal] Plan has unresolved open questions in ## ❓ 5. Open Questions:" >&2
        echo "$unresolved_q" | sed 's/^/     /' >&2
        echo "   All open questions must be resolved and checked off ([x]) before freeze." >&2
        exit 1
    fi

    # Verify Target Files declared
    local targets
    targets="$(parse_plan_target_paths "$plan_file")"
    if [ -z "$targets" ]; then
        echo "❌ [Freeze Refusal] Plan declares no Target Files under '### 📂 Target Files'." >&2
        exit 1
    fi

    # Verify TDD failure tests correspondence if declared (P-35)
    validate_plan_tdd_correspondence "$plan_file" "Freeze Refusal" || exit 1
    validate_plan_changelog_decl "$plan_file" "Freeze Refusal" || exit 1
    validate_group_plan "$plan_file" "Freeze Refusal" || exit 1

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Dispatch pre-freeze gating hook (pre-mutation quality gate)
    local freeze_data=""
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local targets_json=""
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            if [ -z "$targets_json" ]; then
                targets_json="\"$t\""
            else
                targets_json="$targets_json, \"$t\""
            fi
        done < <(parse_plan_target_paths "$plan_file")
        freeze_data="{\"plan_id\": \"$plan_id\", \"plan_file\": \"$plan_file\", \"target_files\": [$targets_json]}"
        if ! dispatch_hook "pre-freeze" "$freeze_data"; then
            echo "❌ [Freeze Refusal] pre-freeze hook vetoed freezing of plan '$plan_id'." >&2
            exit 1
        fi
    fi

    # Update plan header & lock status
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* 🔷 Frozen/' "$plan_file"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$plan_file"

    local today
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$plan_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan locked and frozen into 🔷 Frozen via freeze." "$plan_file"
    fi

    # Update state matrix if present
    local sm_file="$PLANS_DIR/state_matrix.md"
    sync_state_matrix

    # Commit transition in plans worktree if available
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local plan_rel="current/$(basename "$plan_file")"
        if [ -f "$sm_file" ]; then
            plans_commit "plan(freeze): lock blast radius and greenlight $plan_id" "$plan_rel" "state_matrix.md" || exit 1
        else
            plans_commit "plan(freeze): lock blast radius and greenlight $plan_id" "$plan_rel" || exit 1
        fi
    fi

    # Dispatch post-freeze observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        local post_freeze_data="{\"command\": \"plan\", \"event\": \"freeze\", \"plan_id\": \"$plan_id\", \"plan_file\": \"current/$(basename "$plan_file")\"}"
        dispatch_hook "post-freeze" "$post_freeze_data" || true
    fi

    echo "🔷 [Freeze] Plan '$plan_id' locked and transitioned to 🔷 Frozen."
    echo "   Blueprint    : $plan_file"
}

cmd_start() {
    local query="${1:-}"
    [ $# -gt 0 ] && shift
    local plan_file
    plan_file="$(resolve_plan_file "$query" "start")" || exit 1
    if aapp_is_group_plan "$plan_file"; then
        _group_start "$plan_file" "$@"
        return
    fi
    _wt_parse_tokens "Start Refusal" "$@" || exit 1

    # Refuse from planning worktrees (.plans, .agents, .githooks)
    local cur_top
    cur_top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    case "$cur_top" in
        */.plans|*/.agents|*/.githooks)
            echo "❌ [Start Refusal] Cannot start plan from planning worktree '$(basename "$cur_top")'." >&2
            echo "   Run start from a code worktree." >&2
            exit 1
            ;;
    esac

    # Verify status is 🔷 Frozen or already ⚡ In Development
    local cur_status
    cur_status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$plan_file" | head -n 1 || true)"
    if ! echo "$cur_status" | grep -qE '🔷[[:space:]]*Frozen|⚡[[:space:]]*In Development'; then
        echo "❌ [Start Refusal] Plan is not frozen (current status: $cur_status)." >&2
        echo "   Freeze the plan first with 'aapp freeze $query' or run 'aapp freeze-start $query'." >&2
        exit 1
    fi
    if [ -z "$(parse_plan_base "$plan_file")" ]; then
        _member_group_check "$plan_file" "Start Refusal" || exit 1
    fi

    # Disjointness check
    check_disjointness_activation_gate "$plan_file" || exit 1

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Verify plan is not bound in another worktree
    local holding_wt
    holding_wt="$(find_worktree_holding_plan "$plan_id")" || true
    if [ -n "$holding_wt" ]; then
        echo "❌ [Start Refusal] Plan '$plan_id' is already bound in worktree '$holding_wt'." >&2
        exit 1
    fi

    # Dispatch pre-start gating hook (pre-mutation quality gate)
    local start_data=""
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local targets_json=""
        while IFS= read -r t; do
            [ -z "$t" ] && continue
            if [ -z "$targets_json" ]; then
                targets_json="\"$t\""
            else
                targets_json="$targets_json, \"$t\""
            fi
        done < <(parse_plan_target_paths "$plan_file")
        start_data="{\"plan_id\": \"$plan_id\", \"plan_file\": \"$plan_file\", \"target_files\": [$targets_json]}"
        if ! dispatch_hook "pre-start" "$start_data"; then
            echo "❌ [Start Refusal] pre-start hook vetoed activation of plan '$plan_id'." >&2
            exit 1
        fi
    fi

    # P-84: a plan made for an issue always has a branch of its own, so it can
    # land as one commit.
    if [ "$WT_MODE" -eq 0 ] && plan_made_for_issue "$plan_file" >/dev/null; then WT_MODE=1; fi
    # P-54: a fresh start may get its own branch and worktree. A plan started
    # before keeps where it lives (its Base is recorded).
    if [ "$WT_MODE" -eq 1 ] && [ -n "$(parse_plan_base "$plan_file")" ]; then
        if [ -n "$WT_REQ_PATH" ]; then
            echo "❌ [Start Refusal] $plan_id was started before; its worktree is chosen at its first start." >&2
            exit 1
        fi
        WT_MODE=0
    fi
    if [ "$WT_MODE" -eq 1 ]; then
        _wt_start "$plan_file" "$plan_id" "Start" "Plan activated into ⚡ In Development via start." \
            "plan(start): activate $plan_id into development" 0
        return 0
    fi

    local plan_snap=""
    plan_snap="$(mktemp)" || exit 1
    cp "$plan_file" "$plan_snap" || exit 1

    # Record Base SHA and branch
    local head_sha head_br
    head_sha="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"
    head_br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
    [ "$head_br" = "HEAD" ] && head_br="detached"
    write_plan_base "$plan_file" "\`$head_sha\` ($head_br)"

    # Update status
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ⚡ In Development/' "$plan_file"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$plan_file"

    local today
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$plan_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan activated into ⚡ In Development via start." "$plan_file"
    fi

    local sm_file="$PLANS_DIR/state_matrix.md"
    sync_state_matrix

    write_active_buffer "$plan_id"

    # Action delegate: on-start (in-transaction)
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        if ! dispatch_hook "on-start" "$start_data"; then
            echo "❌ [Start Refusal] on-start action delegate failed for '$plan_id'." >&2
            cp "$plan_snap" "$plan_file"
            rm -f "$plan_snap"
            rm -f "$ACTIVE_FILE"
            sync_state_matrix
            exit 1
        fi
    fi
    rm -f "$plan_snap"

    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local plan_rel="current/$(basename "$plan_file")"
        if [ -f "$sm_file" ]; then
            plans_commit "plan(start): activate $plan_id into development" "$plan_rel" "state_matrix.md" || exit 1
        else
            plans_commit "plan(start): activate $plan_id into development" "$plan_rel" || exit 1
        fi
    fi

    # Dispatch post-start observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        local post_start_data="{\"command\": \"plan\", \"event\": \"start\", \"plan_id\": \"$plan_id\", \"plan_file\": \"current/$(basename "$plan_file")\", \"worktree\": \"none\", \"branch\": \"none\"}"
        dispatch_hook "post-start" "$post_start_data" || true
    fi

    echo "⚡ [Start] Plan '$plan_id' activated into ⚡ In Development."
    echo "   Active Buffer: $ACTIVE_FILE"
    _member_guide_line "$plan_file"
}

cmd_done() {
    local query="${1:-}"
    [ $# -gt 0 ] && shift
    local plan_file
    _ig_parse_tokens "$@" || exit 1
    # P-55: `integrate` on a plan already archived integrates it (no archive).
    if [ "$IG_REQ" -eq 1 ] && [ -n "$query" ] && ! resolve_plan_file "$query" "done" >/dev/null 2>&1; then
        plan_file="$(_ig_resolve_done "$query")" || exit 1
        _ig_standalone "$plan_file"
        return 0
    fi
    plan_file="$(resolve_plan_file "$query" "done")" || exit 1

    # Only an implemented plan is archived (#89).
    if [ "$(plan_status_slug "$plan_file")" != "in-development" ]; then
        echo "❌ [Done Refusal] Plan is not ⚡ In Development (current status: $(grep -m 1 -E '\*\*Status:\*\*' "$plan_file" | sed -E 's/^.*\*\*Status:\*\*[[:space:]]*//'))." >&2
        echo "   Start it with 'aapp start $query' and implement it before archiving." >&2
        exit 1
    fi

    # P-64: a group plan's `done` prepares its feature branch, then follows the
    # normal path: the gate runs on the feature branch, P-55 fast-forwards the parent.
    local is_group=0 is_amend=0
    if aapp_is_group_plan "$plan_file"; then
        is_group=1
        _group_done_prepare "$plan_file" "$(sed -nE 's/^\* \*\*Plan ID:\*\*[[:space:]]*(P-[0-9]+).*/\1/p' "$plan_file" | head -n 1)"
    elif [ "$(parse_plan_field "$plan_file" Kind)" = "amendments" ]; then
        is_amend=1
        _amend_done_check "$plan_file"
    fi

    # P-54: a plan with its own worktree is archived only from a clean worktree.
    local wt_rec wt_rel="" wt_br="" wt_abs=""
    wt_rec="$(parse_plan_worktree "$plan_file")"
    if [ -n "$wt_rec" ]; then
        wt_rel="${wt_rec%%$'\t'*}"; wt_br="${wt_rec#*$'\t'}"
        wt_abs="$(aapp_abs_path "$wt_rel" "$PRIMARY_ROOT")"
        if [ -d "$wt_abs" ] && [ -n "$(git -C "$wt_abs" status --porcelain 2>/dev/null)" ]; then
            echo "❌ [Done Refusal] The plan's worktree $wt_rel has uncommitted changes; commit or discard them first." >&2
            exit 1
        fi
    fi

    # P-35: Mechanical TDD completion gate
    local tdd_badge=""
    if plan_has_required_test_files "$plan_file"; then
        # 1. Completion Check: Every box in ### 🧪 Required Tests must be ticked
        local unticked_tests
        unticked_tests=$(awk '
            /^[[:space:]]*```/ { fence = !fence; next }
            fence { next }
            /^#+[[:space:]]/ {
                region = 0
                if ($0 ~ /^#[[:space:]]/ || $0 ~ /^##[[:space:]]/) {
                    in3 = ($0 ~ /^## ([^0-9]*[[:space:]])?3\./)
                    next
                }
                if (!in3) next
                if ($0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Tests[[:space:]]*(\(.*)?$/) {
                    region = 1
                }
                next
            }
            !region { next }
            /^[[:space:]]*-[[:space:]]*\[[[:space:]]\]/ { print $0 }
        ' "$plan_file")

        if [ -n "$unticked_tests" ]; then
            echo "❌ [Done Refusal] Plan has unticked test assertions under '### 🧪 Required Tests':" >&2
            echo "$unticked_tests" | sed 's/^/     /' >&2
            echo "   All required test assertions must be verified and checked off ([x]) before archiving." >&2
            exit 1
        fi

        local ticked_count
        ticked_count=$(awk '
            /^[[:space:]]*```/ { fence = !fence; next }
            fence { next }
            /^#+[[:space:]]/ {
                region = 0
                if ($0 ~ /^#[[:space:]]/ || $0 ~ /^##[[:space:]]/) {
                    in3 = ($0 ~ /^## ([^0-9]*[[:space:]])?3\./)
                    next
                }
                if (!in3) next
                if ($0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Tests[[:space:]]*(\(.*)?$/) {
                    region = 1
                }
                next
            }
            !region { next }
            /^[[:space:]]*-[[:space:]]*\[[xX]\]/ { count++ }
            END { print count+0 }
        ' "$plan_file")

        if [ "$ticked_count" -eq 0 ]; then
            echo "❌ [Done Refusal] Plan declares '### 🧪 Required Test Files' but has 0 completed test assertions under '### 🧪 Required Tests'." >&2
            exit 1
        fi

        # 2. Existence & Tracked Check, where the plan's code lives (its worktree, #119)
        local tdd_root="$REPO_ROOT"
        [ -n "$wt_abs" ] && [ -d "$wt_abs" ] && tdd_root="$wt_abs"
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            if [ ! -f "$tdd_root/$f" ] && [ ! -f "$PRIMARY_ROOT/$f" ] && [ ! -f "$f" ]; then
                echo "❌ [Done Refusal] Required test file '$f' is missing from disk." >&2
                exit 1
            fi
            if ! ( git -C "$tdd_root" ls-files --error-unmatch "$f" >/dev/null 2>&1 || \
                   git -C "$PRIMARY_ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1 ); then
                echo "❌ [Done Refusal] Required test file '$f' is not tracked in Git." >&2
                exit 1
            fi
        done < <(parse_plan_required_test_files "$plan_file")

        tdd_badge="tdd ($ticked_count/$ticked_count)"
    fi

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # P-39: Recorded commits verification (clean break)
    local recorded_commits=()
    while IFS= read -r c_entry; do
        [ -n "$c_entry" ] && recorded_commits+=("$c_entry")
    done < <(parse_plan_commits "$plan_file")

    # P-102: a group has no commit of its own before the gate; its check is
    # "every member archived" (_group_done_prepare), its docs commit follows the gate.
    # P-101: an amendments member with nothing to land is archived without a commit.
    if [ ${#recorded_commits[@]} -eq 0 ] && [ "$is_group" -eq 0 ] && [ "$is_amend" -eq 0 ]; then
        echo "❌ [Done Refusal] Plan '$plan_id' has no recorded commits under '* **Commits:**'." >&2
        local base_val base_sha=""
        base_val="$(grep -m 1 -E '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Base:\*\*' "$plan_file" 2>/dev/null | sed -E 's/^.*\*\*Base:\*\*[[:space:]]*//' | tr -d '[:space:]')"
        if [[ "$base_val" =~ \`([0-9a-fA-F]+)\` ]]; then
            base_sha="${BASH_REMATCH[1]}"
        fi
        local target_files=()
        while IFS= read -r tf; do
            [ -n "$tf" ] && target_files+=("$tf")
        done < <(parse_plan_target_paths "$plan_file")
        if [ ${#target_files[@]} -gt 0 ]; then
            local log_range="HEAD"
            [ -n "$base_sha" ] && [ "$base_sha" != "none" ] && log_range="$base_sha..HEAD"
            local candidates
            candidates="$(git -C "$REPO_ROOT" log --oneline "$log_range" -- "${target_files[@]}" 2>/dev/null | head -n 5 || true)"
            if [ -n "$candidates" ]; then
                echo "   Candidate implementation commits touching target files:" >&2
                echo "$candidates" | sed 's/^/     • /' >&2
            fi
        fi
        echo "   Record implementation commits with 'aapp commit adopt <sha>' before archiving." >&2
        exit 1
    fi

    # Verify reachability of each recorded commit in repository branch/tag refs
    for c_entry in "${recorded_commits[@]}"; do
        local c_sha=""
        if [[ "$c_entry" =~ \`([0-9a-fA-F]+)\` ]]; then
            c_sha="${BASH_REMATCH[1]}"
        else
            c_sha="$(echo "$c_entry" | awk '{print $1}' | tr -d '\`')"
        fi
        [ -z "$c_sha" ] && continue

        if ! git -C "$REPO_ROOT" rev-parse --verify "$c_sha^{commit}" >/dev/null 2>&1; then
            echo "❌ [Done Refusal] Recorded commit '$c_sha' not found in repository." >&2
            exit 1
        fi

        local containing_refs
        containing_refs="$(git -C "$REPO_ROOT" for-each-ref --contains "$c_sha" refs/heads/ refs/tags/ 2>/dev/null || true)"
        if [ -z "$containing_refs" ]; then
            echo "❌ [Done Refusal] Recorded commit '$c_sha' is not reachable from any branch or tag." >&2
            echo "   Ensure the commit belongs to a branch before archiving." >&2
            exit 1
        fi
    done

    # Dispatch pre-done lifecycle event (veto capability)
    local commits_json=""
    for c_entry in "${recorded_commits[@]}"; do
        local c_sha=""
        if [[ "$c_entry" =~ \`([0-9a-fA-F]+)\` ]]; then
            c_sha="${BASH_REMATCH[1]}"
        else
            c_sha="$(echo "$c_entry" | awk '{print $1}' | tr -d '\`')"
        fi
        if [ -z "$commits_json" ]; then
            commits_json="\"$c_sha\""
        else
            commits_json="$commits_json, \"$c_sha\""
        fi
    done

    local last_commit_entry=""
    [ ${#recorded_commits[@]} -gt 0 ] && last_commit_entry="${recorded_commits[${#recorded_commits[@]}-1]}"
    local commit_sha=""
    if [[ "$last_commit_entry" =~ \`([0-9a-fA-F]+)\` ]]; then
        commit_sha="${BASH_REMATCH[1]}"
    else
        commit_sha="$(echo "$last_commit_entry" | awk '{print $1}' | tr -d '\`')"
    fi
    if [ -z "$commit_sha" ] && [ "$is_amend" -eq 1 ]; then commit_sha="none"; fi
    [ -z "$commit_sha" ] && commit_sha="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD 2>/dev/null || echo "0000000")"
    # P-102: the gate of a group sees the feature branch tip it tests.
    local group_tip=""
    if [ "$is_group" -eq 1 ]; then
        group_tip="$(git -C "$wt_abs" rev-parse --short=7 HEAD)" || exit 1
        commit_sha="$group_tip"; commits_json="\"$group_tip\""
    fi

    # P-55: decide on integration and run every integration check now, before
    # pre-done and the archive commit: a refusal leaves nothing archived.
    _ig_decide "$plan_file" || exit 1
    # A group always fast-forwards its parent: its merge already happened (P-64).
    if [ "$is_group" -eq 1 ]; then IG_DO=1; IG_MODE=ff; fi
    if [ "$IG_DO" -eq 1 ]; then
        _ig_preflight "$plan_file" "$plan_id" || exit 1
    fi

    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local pre_done_data="{\"plan_id\": \"$plan_id\", \"plan_file\": \"$plan_file\", \"commit_hash\": \"$commit_sha\", \"commits\": [$commits_json], \"worktree\": \"$(json_escape "$wt_abs")\"}"
        if ! dispatch_hook "pre-done" "$pre_done_data"; then
            echo "❌ [Done Refusal] pre-done hook vetoed archiving of plan '$plan_id'." >&2
            exit 1
        fi
    fi

    # P-102: only now, with every check passed, the group's docs are committed.
    if [ "$is_group" -eq 1 ]; then
        _group_done_docs "$plan_file" "$plan_id"
        recorded_commits=()
        while IFS= read -r c_entry; do
            [ -n "$c_entry" ] && recorded_commits+=("$c_entry")
        done < <(parse_plan_commits "$plan_file")
        group_tip="$(git -C "$wt_abs" rev-parse --short=7 HEAD)" || exit 1
        commit_sha="$group_tip"; commits_json="\"$group_tip\""
    fi

    local bname
    bname="$(basename "$plan_file")"
    local done_file="$PLANS_DIR/done/$bname"

    # P-32: a plan targeting an issue closes it. Checked before any mutation so a
    # dangling target aborts cleanly; an already-archived issue is left alone.
    local close_issue="" close_where=""
    close_issue="$(issue_id_at_start "$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$plan_file" | head -n 1)" || true)"
    if [ -n "$close_issue" ]; then
        # shellcheck source=lib/cmd_issue.sh
        . "$(dirname "${BASH_SOURCE[0]}")/cmd_issue.sh" || {
            echo "❌ [Done Refusal] Issue module missing: $(dirname "${BASH_SOURCE[0]}")/cmd_issue.sh" >&2
            exit 1
        }
        close_where="$(ledger_locate "$close_issue")" || exit 1
        if [ -z "$close_where" ]; then
            echo "❌ [Done Refusal] Target issue #$close_issue is in neither ISSUES.md nor done/000-issues-archive.md." >&2
            exit 1
        fi
    fi

    # P-84: the checks have passed; the plan's commits become one commit on its
    # branch, and that commit is what the archive records.
    local squashed=0 issue_plan=0
    if plan_made_for_issue "$plan_file" >/dev/null; then issue_plan=1; fi
    _sq_decide "$plan_file" "$plan_id" "$is_group" "$issue_plan"
    if [ "$SQ_DO" -eq 1 ]; then
        _sq_run "$plan_file" "$plan_id" || exit 1
        squashed=1
        recorded_commits=("\`$SQ_NEW\` ($(_sq_label))")
        commit_sha="$SQ_NEW"; commits_json="\"$SQ_NEW\""
    fi

    # #121: what the archive changes, kept until its commit lands; a failed commit puts it back.
    local snap f
    snap="$(mktemp -d)" || exit 1
    cp -a "$PLANS_DIR/current" "$snap/current" || exit 1
    for f in done/000-archive-ledger.md state_matrix.md $(ledger_commit_paths); do
        if [ -f "$PLANS_DIR/$f" ]; then mkdir -p "$(dirname "$snap/$f")" && cp -a "$PLANS_DIR/$f" "$snap/$f" || exit 1; fi
    done

    # Move to done/
    mv "$plan_file" "$done_file"

    # Update plan status to Done
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ✅ Done/' "$done_file"
    # P-84: the one commit replaces the list; the commits it replaces are on no branch.
    if [ "$squashed" -eq 1 ]; then write_plan_commits "$done_file" "${recorded_commits[0]}"; fi

    local today commit_sha
    today="$(date +%Y-%m-%d)"
    # Extract last recorded commit SHA for ledger and reporting
    last_commit_entry=""
    [ ${#recorded_commits[@]} -gt 0 ] && last_commit_entry="${recorded_commits[${#recorded_commits[@]}-1]}"
    if [[ "$last_commit_entry" =~ \`([0-9a-fA-F]+)\` ]]; then
        commit_sha="${BASH_REMATCH[1]}"
    else
        commit_sha="$(echo "$last_commit_entry" | awk '{print $1}' | tr -d '\`')"
    fi
    # A group without a docs commit of its own is recorded with the tip it merged.
    # An amendments member that landed nothing records `none`, never an unrelated HEAD (P-101).
    if [ -z "$commit_sha" ] && [ "$is_amend" -eq 1 ]; then commit_sha="none"; fi
    [ -z "$commit_sha" ] && commit_sha="${group_tip:-$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD 2>/dev/null || echo "0000000")}"

    if grep -q '^## 📦 6\. Change Log' "$done_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan implementation completed and archived to done/." "$done_file"
    fi

    # Append to 000-archive-ledger.md
    local ledger_file="$PLANS_DIR/done/000-archive-ledger.md"
    if [ -f "$ledger_file" ]; then
        local target_issue summary
        target_issue="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$done_file" | head -n 1)"
        target_issue="${target_issue%% \*(*}"
        case "$target_issue" in
            ""|*"[Issue ID or Milestone]"*) target_issue="None" ;;
        esac
        summary="$(grep -m 1 -E '^# ' "$done_file" | sed -E 's/^#[[:space:]]*(🗺️[[:space:]]*|🧩[[:space:]]*Group[[:space:]]+)?Plan[^:]*:[[:space:]]*//')"
        [ -z "$summary" ] && summary="None"
        if [ -n "$tdd_badge" ]; then
            summary="$summary ($tdd_badge)"
        fi
        target_issue="${target_issue//|/\\|}"
        summary="${summary//|/\\|}"
        local ledger_line="| $today | \`$plan_id\` | [\`$bname\`]($bname) | $target_issue | \`$commit_sha\` | $summary |"
        local ledger_tmp="$ledger_file.aapp-done.$$"
        AAPP_LEDGER_LINE="$ledger_line" awk '
            { print }
            !done && /^\| :--- \| :--- \| :--- \|/ { print ENVIRON["AAPP_LEDGER_LINE"]; done = 1 }
        ' "$ledger_file" > "$ledger_tmp" && mv "$ledger_tmp" "$ledger_file"
    fi

    # P-32: relocate the target issue row; committed below with the archive.
    local close_summary="" unblocked_paths="" close_payload=""
    if [ "$close_where" = "active" ]; then
        close_summary="[$plan_id]($bname) - $(grep -m 1 -E '^# ' "$done_file" | sed -E 's/^#[[:space:]]*(🗺️[[:space:]]*|🧩[[:space:]]*Group[[:space:]]+)?Plan[^:]*:[[:space:]]*//')"
        close_payload="$(issue_payload "$close_issue")" || close_payload=""
        ledger_archive_row "$close_issue" "$commit_sha" "$close_summary" || exit 1
        # P-52: a plan blocked on this issue (a hotfix promoted to this plan) resumes.
        # P-78: once this plan's commit is in that plan's parent branch.
        unblocked_paths="$(issue_unblock_plans "$close_issue" "$commit_sha")" || exit 1
    fi

    # P-86: the further issues the plan closes go with the same commit. One
    # already archived is skipped; one whose branch will not hold the commit
    # (neither the plan's parent nor a branch that has it) stays open.
    local also_ids=() also_closed=() also_payloads=() also_notes=() also_summary="" an ab aparent
    while IFS= read -r an; do [ -n "$an" ] && also_ids+=("$an"); done < <(plan_also_closes "$done_file")
    if [ ${#also_ids[@]} -gt 0 ]; then
        _load_issue_module
        aparent="$(plan_base_branch "$done_file")"
        also_summary="[$plan_id]($bname) - $(grep -m 1 -E '^# ' "$done_file" | sed -E 's/^#[[:space:]]*(🗺️[[:space:]]*|🧩[[:space:]]*Group[[:space:]]+)?Plan[^:]*:[[:space:]]*//')"
        for an in "${also_ids[@]}"; do
            if ! ledger_row "$an" >/dev/null 2>&1; then
                also_notes+=("   Also closes : #$an is already archived; skipped."); continue
            fi
            ab="$(issue_branch "$an")"
            if [ -n "$ab" ] && [ "$ab" != "$aparent" ] && ! git merge-base --is-ancestor "$commit_sha" "$ab" 2>/dev/null; then
                also_notes+=("   Also closes : #$an stays open: its branch '$ab' does not hold \`$commit_sha\`; 'aapp issue close $an' once it does.")
                continue
            fi
            also_payloads+=("$(issue_payload "$an" 2>/dev/null || true)")
            ledger_archive_row "$an" "$commit_sha" "$also_summary" || exit 1
            unblocked_paths="$unblocked_paths $(issue_unblock_plans "$an" "$commit_sha")" || exit 1
            also_closed+=("$an")
        done
    fi

    # P-50: other open issues that link this plan now point at done/.
    _load_issue_module
    local relinked
    relinked="$(ledger_relink "current/$bname" "done/$bname")" || exit 1

    # Re-derive state_matrix.md now that the plan has left current/ (#88).
    local sm_file="$PLANS_DIR/state_matrix.md"
    sync_state_matrix

    # Clear active buffer if matching
    if [ -f "$ACTIVE_FILE" ]; then
        local cur_act
        cur_act="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
        if [ "$cur_act" = "$plan_id" ] || [ "$cur_act" = "$bname" ]; then
            rm -f "$ACTIVE_FILE"
        fi
    fi
    # P-54: and in the worktree that holds it, wherever done runs; otherwise that
    # worktree stays bound to an archived plan and its guard refuses every edit.
    local holder holder_buf
    if holder="$(find_worktree_holding_plan "$plan_id")"; then
        holder_buf="$(git -C "$holder" rev-parse --git-path aapp_active_plan)"
        case "$holder_buf" in /*) ;; *) holder_buf="$holder/$holder_buf" ;; esac
        rm -f "$holder_buf"
    fi

    # Commit transition in plans worktree
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local done_targets=("current/$bname" "done/$bname")
        [ -f "$ledger_file" ] && done_targets+=("done/000-archive-ledger.md")
        [ -f "$sm_file" ] && done_targets+=("state_matrix.md")
        if [ "$close_where" = "active" ] || [ ${#also_closed[@]} -gt 0 ]; then
            done_targets+=($(ledger_commit_paths))
            local up
            for up in $unblocked_paths; do done_targets+=("$up"); done
        elif [ "$relinked" -gt 0 ]; then
            done_targets+=($(ledger_commit_paths issues roadmap))
        fi
        if ! plans_commit "plan(done): archive $plan_id to done/ and update state matrix" "${done_targets[@]}"; then
            git -C "$PLANS_DIR" reset -q -- "${done_targets[@]}" || echo "⚠️  [Done] Could not unstage the archive; check 'git -C .plans status'." >&2
            rm -f "$done_file"
            (cd "$snap" && find . -type f) | while IFS= read -r f; do cp -a "$snap/$f" "$PLANS_DIR/$f"; done
            rm -rf "$snap"
            if [ "$squashed" -eq 1 ]; then _sq_restore; fi
            echo "❌ [Done] The archive commit failed; the plan, ledgers and matrix are restored. Run 'aapp done $plan_id' again." >&2
            exit 1
        fi
    fi
    rm -rf "$snap"
    if [ "$close_where" = "active" ]; then
        issue_notify_close "$close_issue" "$commit_sha" "$close_summary" "$plan_id" "$close_payload"
        echo "   Issue closed : #$close_issue -> done/000-issues-archive.md"
    fi
    local ai
    for ai in "${!also_closed[@]}"; do
        issue_notify_close "${also_closed[$ai]}" "$commit_sha" "$also_summary" "$plan_id" "${also_payloads[$ai]}"
        echo "   Also closes : #${also_closed[$ai]} -> done/000-issues-archive.md"
    done
    for ai in "${also_notes[@]}"; do echo "$ai"; done

    # Dispatch post-done observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        local done_data="{\"command\": \"plan\", \"event\": \"done\", \"plan_id\": \"$plan_id\", \"plan_file\": \"done/$bname\", \"commit_hash\": \"$commit_sha\", \"commits\": [$commits_json], \"worktree\": \"${wt_rel:-none}\"}"
        dispatch_hook "post-done" "$done_data" || true
    fi

    echo "🏛️  [Done] Plan '$plan_id' archived to done/$bname."
    echo "   Commit SHA   : $commit_sha"
    echo "   Ledger       : $ledger_file"
    # P-55: integrate and clean up after the archive (the checks ran before it).
    if [ "$IG_DO" -eq 1 ]; then
        _ig_run "$done_file" "$plan_id" || exit 1
        # P-78: the integration moved commits; plans that waited for them resume.
        # P-83: first into a group's feature branch whose member waits for this one.
        _load_issue_module
        if [ "$close_where" = "active" ]; then issue_bring_fix_to_groups "$close_issue" "$commit_sha"; fi
        issue_unblock_landed quiet || echo "⚠️  [Done] Could not check the plans waiting for a fix; 'aapp status' does it." >&2
        if [ "${IG_CODEMAP_FAILED:-0}" -eq 1 ]; then exit 1; fi
    elif [ -n "$wt_rec" ]; then
        # P-54 / aapp.integrate = manual: the developer integrates.
        echo "   Worktree     : $wt_rel ($wt_br) is kept. Integrate with: aapp done $plan_id integrate"
        echo "   Or by hand, after integrating the branch:"
        echo "      git worktree remove $wt_rel   # also deletes ignored files there (local env files, build output)"
        echo "      git branch -D $wt_br   # after a squash merge, where -d refuses"
    fi
}

cmd_active() {
    local sub="$1"
    case "$sub" in
        swap)
            if [ ! -f "$PREV_FILE" ]; then
                echo "ℹ️  No previous active plan found to swap to."
                return 0
            fi

            local prev_val cur_val
            prev_val="$(head -n 1 "$PREV_FILE" 2>/dev/null | tr -d '[:space:]')"
            cur_val="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]' || true)"

            if [ -z "$prev_val" ]; then
                echo "ℹ️  Previous active plan buffer is empty."
                return 0
            fi

            if [ -n "$cur_val" ]; then
                echo "$cur_val" > "$PREV_FILE"
            else
                rm -f "$PREV_FILE"
            fi
            echo "$prev_val" > "$ACTIVE_FILE"
            if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
                # shellcheck source=/dev/null
                source "$AAPP_HOOK_DISPATCHER"
                dispatch_hook "post-active" "{\"command\": \"plan\", \"event\": \"active\", \"action\": \"swap\", \"active_plan\": \"$prev_val\", \"previous_plan\": \"${cur_val:-none}\"}" || true
            fi

            echo "🔄 [Active Buffer] Swapped active execution plan to '$prev_val' (previous: '${cur_val:-none}')."
            ;;
        clear)
            if [ -f "$ACTIVE_FILE" ]; then
                local cur_val
                cur_val="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
                [ -n "$cur_val" ] && echo "$cur_val" > "$PREV_FILE"
                rm -f "$ACTIVE_FILE"
                if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
                    # shellcheck source=/dev/null
                    source "$AAPP_HOOK_DISPATCHER"
                    dispatch_hook "post-active" "{\"command\": \"plan\", \"event\": \"active\", \"action\": \"clear\", \"active_plan\": \"none\", \"previous_plan\": \"${cur_val:-none}\"}" || true
                fi
                echo "🧹 [Active Buffer] Active plan buffer cleared. Reverted to auto-discovery mode."
            else
                echo "ℹ️  Active plan buffer is already empty."
            fi
            ;;
        "")
            # Show current active plan or auto-discovery
            local active_id=""
            if [ -f "$ACTIVE_FILE" ]; then
                active_id="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
            fi

            if [ -n "$active_id" ]; then
                echo "🎯 Active Plan Buffer: '$active_id'"
                echo "   Buffer File       : $ACTIVE_FILE"
                if [ -n "$PLANS_DIR" ] && [ -d "$PLANS_DIR/current" ]; then
                    for pf in "$PLANS_DIR"/current/*.md; do
                        [ ! -f "$pf" ] && continue
                        local pid bname
                        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
                        bname="$(basename "$pf" .md)"
                        if [ "$pid" = "$active_id" ] || [ "$bname" = "$active_id" ] || \
                           [[ "$bname" == "$active_id-"* ]] || [[ "$bname" == "P$active_id-"* ]]; then
                            echo "   Blueprint File    : $pf"
                            local status
                            status="$(grep -E '^\* \*\*Status:\*\*' "$pf" | head -n 1 | sed 's/^\* \*\*Status:\*\*[[:space:]]*//')"
                            echo "   Status            : $status"
                            echo "   Declared Targets  :"
                            parse_plan_target_paths "$pf" | sed 's/^/     • /'
                            break
                        fi
                    done
                fi
                return 0
            fi

            # Auto-discovery inspection (P-52: plans held elsewhere are skipped)
            if [ -n "$PLANS_DIR" ] && [ -d "$PLANS_DIR/current" ]; then
                local dev_plans=() held_plans
                held_plans="$(aapp_held_plans)"
                for pf in "$PLANS_DIR"/current/*.md; do
                    [ ! -f "$pf" ] && continue
                    case "$(basename "$pf")" in 000-*) continue ;; esac
                    if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*⚡[[:space:]]*In Development' "$pf" 2>/dev/null; then
                        aapp_plan_held_by "$pf" "$held_plans" >/dev/null && continue
                        dev_plans+=("$pf")
                    fi
                done

                if [ ${#dev_plans[@]} -eq 1 ]; then
                    local auto_pf="${dev_plans[0]}"
                    local auto_id
                    auto_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$auto_pf" 2>/dev/null || true)"
                    [ -z "$auto_id" ] && auto_id="$(basename "$auto_pf" .md)"
                    echo "🎯 Active Plan Buffer: '$auto_id' (auto-discovered in ⚡ In Development)"
                    echo "   Blueprint File    : $auto_pf"
                    echo "   Declared Targets  :"
                    parse_plan_target_paths "$auto_pf" | sed 's/^/     • /'
                    return 0
                elif [ ${#dev_plans[@]} -gt 1 ]; then
                    echo "⚠️  Multiple plans are currently in development:"
                    for dp in "${dev_plans[@]}"; do
                        echo "     • $(basename "$dp" .md)"
                    done
                    echo "   Run 'aapp active <id>' to designate the active execution plan."
                    return 0
                fi
            fi

            echo "ℹ️  No active plan in buffer or in development. (Auto-discovery / fail-open mode)"
            ;;
        *)
            # Set active plan
            local plan_file
            plan_file="$(resolve_plan_file "$sub" "active")" || exit 1
            local plan_id
            plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
            [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

            # Verify plan is not bound in another worktree (P-39)
            local holding_wt
            holding_wt="$(find_worktree_holding_plan "$plan_id")" || true
            if [ -n "$holding_wt" ]; then
                echo "❌ [Active Refusal] Plan '$plan_id' is already bound in worktree '$holding_wt'." >&2
                return 1
            fi

            write_active_buffer "$plan_id"
            if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
                # shellcheck source=/dev/null
                source "$AAPP_HOOK_DISPATCHER"
                dispatch_hook "post-active" "{\"command\": \"plan\", \"event\": \"active\", \"action\": \"set\", \"active_plan\": \"$plan_id\", \"previous_plan\": \"none\"}" || true
            fi
            echo "🎯 [Active Buffer] Active execution plan set to '$plan_id'."
            echo "   Blueprint: $plan_file"
            echo "   Buffer   : $ACTIVE_FILE"
            echo "   Declared Targets:"
            parse_plan_target_paths "$plan_file" | sed 's/^/     • /'
            ;;
    esac
}

cmd_plan_status() {
    local query="$1"

    if [ -n "$query" ]; then
        local plan_file
        plan_file="$(resolve_plan_file "$query" "plan-status")" || exit 1
        local plan_id status title
        plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
        [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"
        status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$plan_file" | head -n 1 | sed 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*[[:space:]]*//')"
        title="$(grep -E '^# ' "$plan_file" | head -n 1 | sed 's/^# [[:space:]]*//')"

        echo "📄 Plan: $plan_id — $title"
        echo "   Status      : $status"
        echo "   Blueprint   : $plan_file"

        local open_q
        open_q=$(awk '
            /^## ❓ 5\. Open Questions/ { in_q=1; next }
            /^## / && in_q { in_q=0 }
            in_q && /^[[:space:]]*\*[[:space:]]*\[[[:space:]]\]/ { print $0 }
        ' "$plan_file")
        if [ -n "$open_q" ]; then
            echo "   Open Questions: (unresolved)"
            echo "$open_q" | sed 's/^/     • /'
        else
            echo "   Open Questions: All resolved"
        fi

        echo "   Declared Targets:"
        local targets
        targets="$(parse_plan_target_paths "$plan_file")"
        if [ -n "$targets" ]; then
            echo "$targets" | sed 's/^/     • /'
        else
            echo "     (none declared)"
        fi
        # P-101: an amendments member's requests and decisions, as recorded.
        if [ "$(parse_plan_field "$plan_file" Kind)" = "amendments" ]; then
            local reqs decs
            reqs="$(amend_request_lines "$plan_file")"
            decs="$(amend_section_lines "$plan_file" "Decisions" D)"
            echo "   Requests:"
            if [ -n "$reqs" ]; then printf '%s\n' "$reqs" | sed -E 's/^- \*\*(R[0-9]+)\*\* /     • \1 /'; else echo "     (none)"; fi
            if [ -n "$decs" ]; then
                echo "   Decisions:"
                printf '%s\n' "$decs" | sed -E 's/^- \*\*(D[0-9]+)\*\* /     • \1 /'
            fi
        fi
        return 0
    fi

    # Matrix overview
    echo "📊 Plan Lane Matrix (.plans/current/)"
    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
        echo "   (no .plans/current directory found)"
        return 0
    fi

    # Bucketing is registry-driven (P-30 §2.7): a status matching no registry
    # entry is reported as unrecognized rather than folded into the Incubator,
    # where a typo'd status would otherwise hide.
    local states_lib=""
    for cand in "$AAPP_LIB" "$PRIMARY_ROOT/lib" "$REPO_ROOT/lib"; do
        if [ -n "${cand:-}" ] && [ -f "$cand/plan_states.sh" ]; then
            states_lib="$cand/plan_states.sh"
            break
        fi
    done
    if [ -n "$states_lib" ]; then
        # shellcheck source=/dev/null
        . "$states_lib" 2>/dev/null || true
        plan_states_load 2>/dev/null || true
    fi

    local in_dev=()
    local frozen=()
    local incubator=()
    local unrecognized=()

    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        # P-52: mini plans (fix-<num>.md) are not P-xx plans.
        case "$(basename "$pf")" in 000-*|plan-template.md|fix-*) continue ;; esac
        local pid status slug entry
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        [ -z "$pid" ] && pid="$(basename "$pf" .md)"
        status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$pf" | head -n 1 || true)"
        entry="$pid ($(basename "$pf"))"

        slug=""
        if declare -f plan_state_for_status_line >/dev/null 2>&1; then
            slug="$(plan_state_for_status_line "$status" 2>/dev/null || true)"
        fi

        case "$slug" in
            in-development) in_dev+=("$entry") ;;
            frozen)         frozen+=("$entry") ;;
            "")             unrecognized+=("$entry") ;;
            *)              incubator+=("$entry") ;;
        esac
    done

    echo "   ⚡ In Development : ${#in_dev[@]}"
    for item in "${in_dev[@]}"; do echo "      • $item"; done

    echo "   🔷 Frozen Backlog : ${#frozen[@]}"
    for item in "${frozen[@]}"; do echo "      • $item"; done

    echo "   🟣 Incubator      : ${#incubator[@]}"
    for item in "${incubator[@]}"; do echo "      • $item"; done

    if [ ${#unrecognized[@]} -gt 0 ]; then
        echo "   ❓ Unrecognized   : ${#unrecognized[@]}"
        for item in "${unrecognized[@]}"; do echo "      • $item"; done
        echo "      ↳ Status matches no registry entry. Fix the Status line, or declare it"
        echo "        via 'git config aapp.planState.<slug>'."
    fi

    if [ -f "$ACTIVE_FILE" ]; then
        local active_id
        active_id="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
        echo ""
        echo "🎯 Active Execution Buffer: '$active_id'"
    fi
}

# ------------------------------------------------------------------------------
# Plan conflict audit (P-65): which plans can run at the same time. Read-only.
# Targets compare exactly, as the activation gate does; shared docs never collide.
# ------------------------------------------------------------------------------
_pc_id() { parse_plan_field "$1" "Plan ID"; }

# _pc_state <plan>: done (archived or ✅), else the registry slug.
_pc_state() {
    case "$1" in */done/*) echo done; return ;; esac
    if grep -qE '^\* \*\*Status:\*\*.*✅' "$1"; then echo done; else plan_status_slug "$1"; fi
}

# _pc_targets <plan> code|shared: its non-shared (or shared-doc) Target Files.
_pc_targets() {
    local t
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        if aapp_is_shared_doc "$t"; then [ "$2" = shared ] && echo "$t"
        else [ "$2" = code ] && echo "$t"; fi
    done < <(parse_plan_target_paths "$1")
    return 0
}

# plan_compare_targets <plan-a> <plan-b>: prints the colliding non-shared paths;
# returns 1 when there is any.
plan_compare_targets() {
    local out
    out="$(comm -12 <(_pc_targets "$1" code | sort -u) <(_pc_targets "$2" code | sort -u))"
    [ -z "$out" ] && return 0
    printf '%s\n' "$out"
    return 1
}

# _pc_member_files <group-plan>: its members' files in current/ (archived ones skipped).
_pc_member_files() {
    local m f
    for m in $(group_members "$1"); do
        for f in "$PLANS_DIR"/current/P"${m#P-}"-*.md; do [ -f "$f" ] && echo "$f"; done
    done
    return 0
}

# _pc_inflight [except-file]: every ⚡ plan in current/ (mini plans included).
_pc_inflight() {
    local f
    for f in "$PLANS_DIR"/current/*.md; do
        [ -f "$f" ] && [ "$f" != "${1:-}" ] || continue
        case "$(basename "$f")" in 000-*) continue ;; esac
        [ "$(plan_status_slug "$f")" = "in-development" ] && echo "$f"
    done
    return 0
}

# _pc_json_list <item>…: a JSON array of strings.
_pc_json_list() { local s="" i; for i in "$@"; do s="$s${s:+, }\"$(json_escape "$i")\""; done; printf '[%s]' "$s"; }

# cmd_plan_conflict_check <id> [<id>…] [json]: pairwise disjointness of plans
# (a group plan counts its members); exit 1 on any collision.
cmd_plan_conflict_check() {
    local json=0 q f files=() ids=() i j col shared=() cols=() t
    # shellcheck source=/dev/null
    . "$AAPP_HOOK_DISPATCHER"   # json_escape
    for q in "$@"; do
        [ "$q" = json ] && { json=1; continue; }
        f="$(resolve_plan_file "$q" "conflict-check")" || exit 1
        if aapp_is_group_plan "$f"; then
            while IFS= read -r t; do [ -n "$t" ] && files+=("$t"); done < <(_pc_member_files "$f")
        else
            files+=("$f")
        fi
    done
    if [ ${#files[@]} -lt 2 ]; then
        echo "❌ [Plan] conflict-check needs two or more plans (a group counts its members)." >&2
        exit 1
    fi
    for f in "${files[@]}"; do ids+=("$(_pc_id "$f")"); done
    for ((i = 0; i < ${#files[@]}; i++)); do
        for ((j = i + 1; j < ${#files[@]}; j++)); do
            col="$(plan_compare_targets "${files[$i]}" "${files[$j]}")" && continue
            while IFS= read -r t; do cols+=("${ids[$i]}"$'\t'"${ids[$j]}"$'\t'"$t"); done <<< "$col"
        done
    done
    while IFS= read -r t; do [ -n "$t" ] && shared+=("$t"); done < <(
        for f in "${files[@]}"; do _pc_targets "$f" shared | sort -u; done | sort | uniq -d)
    if [ "$json" -eq 1 ]; then
        local cj="" c
        for c in "${cols[@]}"; do
            IFS=$'\t' read -r a b t <<< "$c"
            cj="$cj${cj:+, }{\"plan_a\": \"$a\", \"plan_b\": \"$b\", \"target\": \"$(json_escape "$t")\"}"
        done
        printf '{"clean": %s, "plans": %s, "collisions": [%s], "shared_docs": %s}\n' \
            "$([ ${#cols[@]} -eq 0 ] && echo true || echo false)" "$(_pc_json_list "${ids[@]}")" "$cj" "$(_pc_json_list "${shared[@]}")"
    elif [ ${#cols[@]} -eq 0 ]; then
        echo "✔ Plans ${ids[*]} are disjoint and can run concurrently."
        for t in "${shared[@]}"; do echo "  ℹ️  [Shared Doc] $t (exempt; union merge)"; done
    else
        local c
        for c in "${cols[@]}"; do
            IFS=$'\t' read -r a b t <<< "$c"
            echo "✘ Collision between $a and $b: $t"
        done
        echo "  These plans cannot be in development at the same time."
    fi
    [ ${#cols[@]} -eq 0 ]
}

# cmd_plan_conflict_free [<id> | <group>] [json]: without an id, pending plans
# split by the ⚡ plans; with a plan, the plans compatible with it; with a group,
# its members in waves (see _pc_waves). Informational: exit 0.
cmd_plan_conflict_free() {
    local json=0 q="" a f
    for a in "$@"; do [ "$a" = json ] && json=1 || q="$a"; done
    # shellcheck source=/dev/null
    . "$AAPP_HOOK_DISPATCHER"   # json_escape
    if [ -n "$q" ]; then
        f="$(resolve_plan_file "$q" "conflict-free")" || exit 1
        if aapp_is_group_plan "$f"; then _pc_waves "$f" "$json"; else _pc_against "$f" "$json"; fi
        return 0
    fi
    local inflight=() free=() hit=() p i col
    while IFS= read -r p; do [ -n "$p" ] && inflight+=("$p"); done < <(_pc_inflight)
    for p in "$PLANS_DIR"/current/*.md; do
        [ -f "$p" ] || continue
        case "$(basename "$p")" in 000-*|fix-*) continue ;; esac
        aapp_is_group_plan "$p" && continue
        case "$(_pc_state "$p")" in in-development|done|blocked) continue ;; esac
        col=""
        for i in "${inflight[@]}"; do
            if ! col="$(plan_compare_targets "$p" "$i")"; then
                hit+=("$(_pc_id "$p")"$'\t'"$(_pc_id "$i")"$'\t'"$(head -n 1 <<< "$col")"); break
            fi
            col=""
        done
        [ -z "$col" ] && free+=("$(_pc_id "$p")")
    done
    _pc_report "Conflict-Free (can start now)" "Conflicting (blocked by in-flight work)" "conflict_free" "conflicting" "$json"
}

# _pc_against <plan> <json>: the other plans compatible with <plan>.
_pc_against() {
    local ref="$1" json="$2" free=() hit=() p col
    for p in "$PLANS_DIR"/current/*.md; do
        [ -f "$p" ] && [ "$p" != "$ref" ] || continue
        case "$(basename "$p")" in 000-*|fix-*) continue ;; esac
        aapp_is_group_plan "$p" && continue
        if col="$(plan_compare_targets "$ref" "$p")"; then
            free+=("$(_pc_id "$p")")
        else
            hit+=("$(_pc_id "$p")"$'\t'"$(_pc_id "$ref")"$'\t'"$(head -n 1 <<< "$col")")
        fi
    done
    _pc_report "Compatible with $(_pc_id "$ref")" "Incompatible with $(_pc_id "$ref")" "conflict_free" "conflicting" "$json"
}

# _pc_report <free-title> <hit-title> <free-key> <hit-key> <json>: prints the
# caller's `free` (IDs) and `hit` (plan TAB other TAB target) arrays.
_pc_report() {
    local h p o t
    if [ "$5" -eq 1 ]; then
        local hj=""
        for h in "${hit[@]}"; do
            IFS=$'\t' read -r p o t <<< "$h"
            hj="$hj${hj:+, }{\"plan\": \"$p\", \"collides_with\": \"$o\", \"target\": \"$(json_escape "$t")\"}"
        done
        printf '{"%s": %s, "%s": [%s]}\n' "$3" "$(_pc_json_list "${free[@]}")" "$4" "$hj"
        return 0
    fi
    echo "✔ $1:"
    [ ${#free[@]} -gt 0 ] && printf '    %s\n' "${free[@]}" || echo "    (none)"
    echo "✘ $2:"
    if [ ${#hit[@]} -eq 0 ]; then echo "    (none)"; fi
    for h in "${hit[@]}"; do
        IFS=$'\t' read -r p o t <<< "$h"
        echo "    $p: $t with $o"
    done
}

# _pc_waves <group-plan> <json>: the group's pending members in waves. A wave is
# pairwise disjoint; wave 1 is also disjoint from every ⚡ plan (members or not).
# Members are placed in their listed order, each into the first wave it fits;
# archived (✅) members are left out, ⚡ members are listed as in flight.
_pc_waves() {
    local gf="$1" json="$2" gid m state inflight=() pending=() waves=() held=() w col i placed k
    gid="$(_pc_id "$gf")"
    while IFS= read -r i; do [ -n "$i" ] && inflight+=("$i"); done < <(_pc_inflight "$gf")
    while IFS= read -r m; do
        [ -n "$m" ] || continue
        state="$(_pc_state "$m")"
        case "$state" in done|in-development) continue ;; esac
        pending+=("$m")
    done < <(_pc_member_files "$gf")
    # waves[w] holds space-separated plan files.
    for m in "${pending[@]}"; do
        w=1; placed=0; local why=""
        while [ "$placed" -eq 0 ]; do
            col=""
            if [ "$w" -eq 1 ]; then
                for i in "${inflight[@]}"; do
                    if ! col="$(plan_compare_targets "$m" "$i")"; then
                        [ -n "$why" ] || why="$(head -n 1 <<< "$col") with $(_pc_id "$i")"; break
                    fi
                    col=""
                done
            fi
            if [ -z "$col" ]; then
                for k in ${waves[$w]:-}; do
                    if ! col="$(plan_compare_targets "$m" "$k")"; then
                        [ -n "$why" ] || why="$(head -n 1 <<< "$col") with $(_pc_id "$k")"; break
                    fi
                    col=""
                done
            fi
            if [ -z "$col" ]; then
                waves[$w]="${waves[$w]:-}${waves[$w]:+ }$m"; placed=1
                [ -n "$why" ] && held+=("$(_pc_id "$m")"$'\t'"$w"$'\t'"$why")
            else
                w=$((w + 1))
            fi
        done
    done
    local n=${#waves[@]} ids h p wv r
    if [ "$json" -eq 1 ]; then
        local wj="" hj
        for ((w = 1; w <= n; w++)); do
            ids=(); for k in ${waves[$w]}; do ids+=("$(_pc_id "$k")"); done
            hj=""
            for h in "${held[@]}"; do
                IFS=$'\t' read -r p wv r <<< "$h"
                [ "$wv" = "$w" ] || continue
                hj="$hj${hj:+, }{\"plan\": \"$p\", \"collides_with\": \"${r##* with }\", \"target\": \"$(json_escape "${r% with *}")\"}"
            done
            wj="$wj${wj:+, }{\"wave\": $w, \"plans\": $(_pc_json_list "${ids[@]}")${hj:+, \"held_back\": [$hj]}}"
        done
        ids=(); for k in "${inflight[@]}"; do ids+=("$(_pc_id "$k")"); done
        printf '{"group": "%s", "in_flight": %s, "waves": [%s]}\n' "$gid" "$(_pc_json_list "${ids[@]}")" "$wj"
        return 0
    fi
    echo "🧭 Group $gid: implementation order"
    ids=(); for k in "${inflight[@]}"; do ids+=("$(_pc_id "$k")"); done
    [ ${#ids[@]} -gt 0 ] && echo "  In flight: ${ids[*]}"
    [ "$n" -gt 0 ] || { echo "  (no pending members)"; return 0; }
    for ((w = 1; w <= n; w++)); do
        ids=(); for k in ${waves[$w]}; do ids+=("$(_pc_id "$k")"); done
        local line="  Wave $w: $(printf '%s, ' "${ids[@]}")"; line="${line%, }"
        for h in "${held[@]}"; do
            IFS=$'\t' read -r p wv r <<< "$h"
            [ "$wv" = "$w" ] && line="$line  ($p held back: $r)"
        done
        echo "$line"
    done
}

# ------------------------------------------------------------------------------
# plan abort (P-69): `done` without the code. Every refusal comes before any
# change; the worktree and branch go only after the archive commit has landed.
# ------------------------------------------------------------------------------
AB_USAGE='aapp plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]'

_ab_parse_tokens() {
    AB_REASON="Abandoned"; AB_KEEP=0; AB_FORCE=0; AB_FORCECLEAN=0; AB_CONFIRM=0
    while [ $# -gt 0 ]; do
        case "$1" in
            reason)        if [ $# -lt 2 ] || [ -z "$2" ]; then echo "❌ [Abort Refusal] 'reason' needs a text." >&2; return 1; fi
                           AB_REASON="$2"; shift ;;
            keep-branch)   AB_KEEP=1 ;;
            force)         AB_FORCE=1 ;;
            force-cleanup) AB_FORCECLEAN=1 ;;
            confirm)       AB_CONFIRM=1 ;;
            *) echo "❌ [Abort Refusal] Unknown token '$1'. Usage: $AB_USAGE" >&2; return 1 ;;
        esac
        shift
    done
    case "$AB_REASON" in *$'\n'*) echo "❌ [Abort Refusal] The reason must be a single line." >&2; return 1 ;; esac
}

_ab_plan_id() {
    local id
    id="$(parse_plan_field "$1" "Plan ID")"; id="${id%%[[:space:]]*}"
    echo "${id:-$(basename "$1" .md)}"
}

# _ab_commit_shas <plan>: the recorded SHAs as "`a`, `b`", or nothing.
_ab_commit_shas() { parse_plan_commits "$1" | awk '{ printf "%s`%s`", (NR > 1 ? ", " : ""), $1 }'; }

_ab_target_issue() {
    issue_id_at_start "$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$1" | head -n 1)" || true
}

# _ab_check_worktree <plan_file> <plan_id>: the plan's worktree may be removed.
_ab_check_worktree() {
    local rec wt_rel wt here="" dirty files q
    rec="$(parse_plan_worktree "$1")"
    [ -n "$rec" ] || return 0
    wt_rel="${rec%%$'\t'*}"; wt="$(aapp_abs_path "$wt_rel" "$PRIMARY_ROOT")"
    [ -d "$wt" ] || return 0
    if here="$(git rev-parse --show-toplevel 2>/dev/null)"; then here="$(cd "$here" && pwd -P)"; fi
    if [ -n "$here" ] && [ "$here" = "$(cd "$wt" && pwd -P)" ]; then
        echo "❌ [Abort Refusal] This is $2's own worktree, which the abort removes; run it from the main checkout: cd $PRIMARY_ROOT" >&2
        return 1
    fi
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null)"
    if [ -n "$dirty" ] && [ "$AB_FORCE" -eq 0 ]; then
        echo "❌ [Abort Refusal] $2's worktree $wt_rel has uncommitted changes:" >&2
        printf '%s\n' "$dirty" | sed 's/^/     /' >&2
        echo "   Commit or stash them, or discard them with: aapp plan abort $2 force" >&2
        return 1
    fi
    files="$(check_worktree_ignored_files "$wt")"
    if [ -n "$files" ]; then
        q="$(git config --get aapp.quarantineIgnored 2>/dev/null)" || q=false
        if [ "$q" != "true" ] && [ "$AB_FORCECLEAN" -eq 0 ]; then
            echo "❌ [Abort Refusal] Removing $wt_rel would delete ignored files: $(echo "$files" | paste -sd' ' -)" >&2
            echo "   Back them up, set aapp.quarantineIgnored true, or add: force-cleanup" >&2
            return 1
        fi
    fi
}

# _ab_check_issue <plan_file>: a named Target Issue must exist (as `done` requires).
_ab_check_issue() {
    local n where
    n="$(_ab_target_issue "$1")"
    [ -n "$n" ] || return 0
    where="$(ledger_locate "$n")" || return 1
    if [ -z "$where" ]; then
        echo "❌ [Abort Refusal] Target issue #$n is in neither ISSUES.md nor done/000-issues-archive.md." >&2
        return 1
    fi
}

# _ab_archive_one <plan_file> <reason> <in-group-abort 0|1>: moves one plan to
# aborted/ with its header, ledger row, issue and group edits. No commit: the
# paths go to AB_PATHS, files it created to AB_NEW, reverted issues to AB_ISSUES.
_ab_archive_one() {
    local pf="$1" reason="$2" bname pid dest today led shas target issue grp gf tmp
    bname="$(basename "$pf")"; pid="$(_ab_plan_id "$pf")"; dest="$PLANS_DIR/aborted/$bname"
    today="$(date +%Y-%m-%d)"
    mkdir -p "$PLANS_DIR/aborted" || return 1
    mv "$pf" "$dest" || return 1
    AB_NEW+=("$dest"); AB_PATHS+=("current/$bname" "aborted/$bname"); AB_DONE+=("$dest")

    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/* **Status:** ❌ Aborted/' "$dest" || return 1
    write_plan_field "$dest" Aborted "$today | **Reason:** $reason" || return 1
    tmp="$dest.aapp-abort.$$"
    AAPP_LINE="* **$today:** Plan aborted: $reason" awk '
        { print } !d && /^## 📦 6\. Change Log/ { print ENVIRON["AAPP_LINE"]; d = 1 }' "$dest" > "$tmp" && mv "$tmp" "$dest" || { rm -f "$tmp"; return 1; }

    led="$PLANS_DIR/aborted/000-aborted-ledger.md"
    if [ ! -f "$led" ]; then
        printf '%s\n\n%s\n\n%s\n%s\n' "# 🗑️ Aborted Plans Ledger" \
            "Append-only ledger of plans abandoned with \`aapp plan abort\`." \
            "| Date Aborted | Plan ID | Plan File | Target Issue / Milestone | Reason | Commits |" \
            "| :--- | :--- | :--- | :--- | :--- | :--- |" > "$led" || return 1
        AB_NEW+=("$led")
    fi
    shas="$(_ab_commit_shas "$dest")"
    target="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*//p' "$dest" | head -n 1)"
    target="${target%% \*(*}"
    case "$target" in ""|*"[Issue ID or Milestone]"*) target="None" ;; esac
    target="${target//|/\\|}"
    tmp="$led.aapp-abort.$$"
    AAPP_LEDGER_LINE="| $today | \`$pid\` | [\`$bname\`]($bname) | $target | ${reason//|/\\|} | ${shas:-none} |" awk '
        { print }
        !done && /^\| :--- \| :--- \| :--- \|/ { print ENVIRON["AAPP_LEDGER_LINE"]; done = 1 }
        END { if (!done) exit 3 }' "$led" > "$tmp" && mv "$tmp" "$led" || { rm -f "$tmp"; return 1; }

    # The issue stays open: back to Incubated, linked to the archived plan.
    issue="$(_ab_target_issue "$dest")"
    if [ -n "$issue" ] && ledger_row "$issue" 2>/dev/null | grep -qF "](current/$bname)"; then
        issue_mark_incubated "$issue" "[$pid](aborted/$bname)" || return 1
        AB_ISSUES="$AB_ISSUES #$issue"
    fi
    ledger_relink "current/$bname" "aborted/$bname" >/dev/null || return 1

    grp="$(parse_plan_field "$dest" Group)"
    if [ "$3" -eq 0 ] && [ -n "$grp" ]; then
        gf="$(ls "$PLANS_DIR"/current/P"${grp#P-}"-*.md 2>/dev/null | head -n 1)"
        if [ -n "$gf" ] && aapp_is_group_plan "$gf"; then
            group_set_member "$gf" "$pid" remove || return 1
            AB_PATHS+=("current/$(basename "$gf")")
        fi
    fi
}

# _ab_restore <snapshot>: a failed archive leaves the plans worktree as it was.
_ab_restore() {
    local f
    git -C "$PLANS_DIR" reset -q -- "${AB_PATHS[@]}" 2>/dev/null || echo "⚠️  [Abort] Could not unstage the archive; check 'git -C .plans status'." >&2
    for f in "${AB_NEW[@]}"; do rm -f "$f"; done
    (cd "$1" && find . -type f) | while IFS= read -r f; do cp -a "$1/$f" "$PLANS_DIR/$f"; done
    rm -rf "$1"
}

# _ab_drop_branch <branch> [<note> [<parent>]]: deletes it with a warning naming
# its SHA; `keep-branch` keeps it. Open issues that targeted it move to <parent>
# (P-78).
_ab_drop_branch() {
    local sha
    git show-ref --verify --quiet "refs/heads/$1" || return 0
    if [ "$AB_KEEP" -eq 1 ]; then echo "ℹ️  Branch '$1' preserved."; return 0; fi
    sha="$(git rev-parse --short "$1")"
    if git branch -D "$1" >/dev/null 2>&1; then
        echo "⚠️  [Abort] Deleted branch '$1' (was $sha) with its commits.${2:+ $2}"
        _issues_follow_branch "$1" "${3:-}"
    else
        echo "⚠️  [Abort] Could not delete branch '$1'; delete it with 'git branch -D $1'." >&2
    fi
}

# _ab_teardown <archived_plan_file> <plan_id>: the plan's worktree and branch,
# or a note on what stays. A failure warns; the abort stands.
_ab_teardown() {
    local rec wt_rel wt br files shas
    rec="$(parse_plan_worktree "$1")"
    if [ -z "$rec" ]; then
        shas="$(_ab_commit_shas "$1")"
        if [ -n "$shas" ] && ! aapp_is_group_plan "$1"; then
            echo "ℹ️  [Abort] $2 has no plan worktree: its commits stay on the branch they were made on, nothing is reverted: $shas"
            echo "   Its CHANGELOG.md entry stays too."
        fi
        return 0
    fi
    wt_rel="${rec%%$'\t'*}"; br="${rec#*$'\t'}"; wt="$(aapp_abs_path "$wt_rel" "$PRIMARY_ROOT")"
    if [ -d "$wt" ]; then
        files="$(check_worktree_ignored_files "$wt")"
        if [ -n "$files" ] && [ "$(git config --get aapp.quarantineIgnored 2>/dev/null)" = "true" ]; then
            _wt_quarantine "$wt" "$2" "$files" || {
                echo "⚠️  [Abort] Could not quarantine $WT_Q_FAILED; the worktree $wt_rel is kept. Remove it with 'git worktree remove --force $wt_rel'." >&2
                return 0; }
        fi
        _group_done_drop_wt "$wt"
        if [ ! -d "$wt" ]; then echo "🧹 [Abort] Removed worktree $wt_rel."; fi
    fi
    aapp_is_group_plan "$1" || _ab_drop_branch "$br" "" "$(plan_base_branch "$1")"
}

# _ab_hook <archived_plan_file> <plan_id> <reason>: the post-abort observer.
_ab_hook() {
    local rec wt="" br="" commits data
    [ -f "$AAPP_HOOK_DISPATCHER" ] || return 0
    # shellcheck source=/dev/null
    source "$AAPP_HOOK_DISPATCHER"
    rec="$(parse_plan_worktree "$1")"
    if [ -n "$rec" ]; then wt="$(aapp_abs_path "${rec%%$'\t'*}" "$PRIMARY_ROOT")"; br="${rec#*$'\t'}"; fi
    commits="$(parse_plan_commits "$1" | awk '{ printf "%s\"%s\"", (NR > 1 ? ", " : ""), $1 }')"
    data="{\"command\": \"plan\", \"event\": \"abort\", \"plan_id\": \"$2\", \"plan_file\": \"aborted/$(basename "$1")\", \"reason\": \"$(json_escape "$3")\", \"worktree\": \"$(json_escape "$wt")\", \"branch\": \"$(json_escape "$br")\", \"commits\": [$commits]}"
    dispatch_hook "post-abort" "$data" || echo "⚠️  [Abort] A post-abort hook failed; the abort stands." >&2
}

# cmd_plan_abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]
cmd_plan_abort() {
    local query="${1:-}" plan_file bname pid mf m n
    [ $# -gt 0 ] && shift
    _ab_parse_tokens "$@" || exit 1
    if [ -z "$query" ]; then echo "❌ [Abort Refusal] Usage: $AB_USAGE" >&2; exit 1; fi
    # A mini plan is not a P-xx plan (P-52): its own verb drops it.
    n="${query%.md}"
    case "$n" in fix-*)
        if issue_fix_id "$n" >/dev/null 2>&1; then
            echo "❌ [Abort Refusal] $n is an issue's mini plan; drop it with 'aapp issue fix ${n#fix-} abort'." >&2
            exit 1
        fi ;;
    esac
    plan_file="$(resolve_plan_file "$query" "abort")" || exit 1
    bname="$(basename "$plan_file")"; pid="$(_ab_plan_id "$plan_file")"
    _load_issue_module

    # A group plan takes its open members with it.
    local is_group=0 members_open=() members_done="" fb="" fb_parent="" all=()
    if aapp_is_group_plan "$plan_file"; then
        is_group=1
        for m in $(group_members "$plan_file"); do
            mf="$(ls "$PLANS_DIR"/current/P"${m#P-}"-*.md 2>/dev/null | head -n 1)"
            if [ -n "$mf" ]; then
                members_open+=("$mf")
            elif ls "$PLANS_DIR"/done/P"${m#P-}"-*.md >/dev/null 2>&1; then
                members_done="${members_done:+$members_done, }$m"
            fi
        done
        fb="$(parse_plan_field "$plan_file" "Feature Branch")"
        if [ -n "$fb" ] && ! git show-ref --verify --quiet "refs/heads/$fb"; then fb=""; fi
        fb_parent="$(plan_base_branch "$plan_file")"
    fi
    all=("${members_open[@]}" "$plan_file")
    for mf in "${all[@]}"; do
        _ab_check_worktree "$mf" "$(_ab_plan_id "$mf")" || exit 1
        _ab_check_issue "$mf" || exit 1
    done

    if [ "$is_group" -eq 1 ]; then
        local shas ans
        echo "⚠️  [Abort] Aborting group $pid removes the whole group:"
        for mf in "${members_open[@]}"; do
            shas="$(_ab_commit_shas "$mf")"
            echo "   • member $(_ab_plan_id "$mf") is aborted (commits: ${shas:-none})"
        done
        if [ -n "$fb" ]; then
            if [ "$AB_KEEP" -eq 1 ]; then
                echo "   • feature branch '$fb' ($(git rev-parse --short "$fb")) is kept (keep-branch)"
            else
                echo "   • feature branch '$fb' ($(git rev-parse --short "$fb")) is deleted with every commit on it"
            fi
            if [ -n "$members_done" ]; then echo "   • archived members whose code is on it: $members_done"; fi
        elif [ -n "$members_done" ]; then
            echo "   • archived members: $members_done"
        fi
        if [ "$AB_CONFIRM" -eq 0 ]; then
            if [ -t 0 ]; then
                printf "Abort group %s? [y/N] " "$pid"
                read -r ans || ans=""
                case "$ans" in y|Y) ;; *) echo "Nothing changed."; exit 1 ;; esac
            else
                echo "❌ [Abort Refusal] A group abort needs a confirmation: answer the prompt on a terminal, or add 'confirm'. Nothing changed." >&2
                exit 1
            fi
        fi
    fi

    # What the archive changes, kept until its commit lands (as `done`, #121).
    local snap f led="aborted/000-aborted-ledger.md"
    snap="$(mktemp -d)" || exit 1
    cp -a "$PLANS_DIR/current" "$snap/current" || exit 1
    for f in "$led" state_matrix.md $(ledger_commit_paths issues roadmap); do
        if [ -f "$PLANS_DIR/$f" ]; then mkdir -p "$(dirname "$snap/$f")" && cp -a "$PLANS_DIR/$f" "$snap/$f" || exit 1; fi
    done
    AB_PATHS=(); AB_NEW=(); AB_DONE=(); AB_ISSUES=""
    for mf in "${members_open[@]}"; do
        _ab_archive_one "$mf" "Group $pid aborted: $AB_REASON" 1 || { _ab_restore "$snap"; echo "❌ [Abort] Archiving failed; nothing changed." >&2; exit 1; }
    done
    _ab_archive_one "$plan_file" "$AB_REASON" 0 || { _ab_restore "$snap"; echo "❌ [Abort] Archiving failed; nothing changed." >&2; exit 1; }
    sync_state_matrix
    for f in "$led" $(ledger_commit_paths issues roadmap) state_matrix.md; do
        if [ -n "$(git -C "$PLANS_DIR" status --porcelain -- "$f" 2>/dev/null)" ]; then AB_PATHS+=("$f"); fi
    done
    local subject="plan(abort): archive $pid to aborted/"
    [ "$is_group" -eq 0 ] || subject="plan(abort): archive group $pid to aborted/"
    if ! plans_commit "$subject" "${AB_PATHS[@]}"; then
        _ab_restore "$snap"
        echo "❌ [Abort] The archive commit failed; the plan, ledgers and matrix are restored and no worktree or branch was removed. Run 'aapp plan abort $pid' again." >&2
        exit 1
    fi
    rm -rf "$snap"

    echo "🗑️  [Abort] Plan '$pid' archived to aborted/$bname."
    echo "   Reason       : $AB_REASON"
    echo "   Ledger       : $PLANS_DIR/$led"
    if [ -n "$AB_ISSUES" ]; then
        echo "   Issue        :$AB_ISSUES back to 🟡 Incubated (not closed)"
        # P-74: the provider is told each issue is open and unplanned again.
        local ab_issue
        for ab_issue in $AB_ISSUES; do issue_send_refine "${ab_issue#\#}"; done
    fi

    # Buffers, hotfix records, worktrees and branches: after the commit.
    local dest did cur holder holder_buf line blocked
    for dest in "${AB_DONE[@]}"; do
        did="$(_ab_plan_id "$dest")"
        if [ -f "$ACTIVE_FILE" ]; then
            cur="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
            if [ "$cur" = "$did" ] || [ "$cur" = "$(basename "$dest")" ]; then rm -f "$ACTIVE_FILE"; fi
        fi
        if holder="$(find_worktree_holding_plan "$did")"; then
            holder_buf="$(git -C "$holder" rev-parse --git-path aapp_active_plan)"
            case "$holder_buf" in /*) ;; *) holder_buf="$holder/$holder_buf" ;; esac
            rm -f "$holder_buf"
        fi
        if [ -z "$(parse_plan_worktree "$dest")" ]; then
            line="$(grep -m 1 -E '^\* \*\*Blocked On:\*\*' "$dest" || true)"
            if [ -n "$line" ]; then
                blocked="$(plan_blocked_on_parse "${line#\* \*\*Blocked On:\*\* }" | sed -n 1p | tr -d '# ' | tr ',' ' ')"
                # shellcheck disable=SC2086
                issue_drop_stash_records "$PRIMARY_ROOT" $blocked || echo "⚠️  [Abort] Could not update the hotfix stash record." >&2
            fi
        fi
        _ab_teardown "$dest" "$did"
    done
    if [ -n "$fb" ]; then
        _ab_drop_branch "$fb" "${members_done:+Code of archived members went with it: $members_done.}" "$fb_parent"
    fi
    if [ -n "$members_done" ]; then
        echo "ℹ️  [Abort] Archived members stay in done/ with their ledger rows and closed issues: $members_done."
    fi
    for dest in "${AB_DONE[@]}"; do
        if [ "$dest" = "$PLANS_DIR/aborted/$bname" ]; then
            _ab_hook "$dest" "$(_ab_plan_id "$dest")" "$AB_REASON"
        else
            _ab_hook "$dest" "$(_ab_plan_id "$dest")" "Group $pid aborted: $AB_REASON"
        fi
    done
}

cmd_plan_switchboard() {
    local query="$1"
    case "$query" in
        abort)          shift; cmd_plan_abort "$@"; return ;;
        conflict-check) shift; cmd_plan_conflict_check "$@"; return ;;
        conflict-free)  shift; cmd_plan_conflict_free "$@"; return ;;
    esac

    echo "🗺️  AAPP Planning Switchboard"
    echo "--------------------------------------------------"
    if [ -n "$query" ]; then
        echo "ℹ️  To inspect plan status: aapp plan-status $query"
        echo "ℹ️  To set execution buffer: aapp active $query"
        echo "ℹ️  To draft a blueprint: use '/plan <idea>' in chat"
        echo ""
    fi
    echo "To inspect plans or the active matrix:"
    echo "  aapp plan-status              Inspect plan lane matrix"
    echo "  aapp plan-status <plan-id>    Inspect specific plan details & targets"
    echo ""
    echo "To manage the execution buffer:"
    echo "  aapp active <plan-id>         Set active plan buffer for guard enforcement"
    echo "  aapp active swap              Swap active buffer with previous plan"
    echo "  aapp active clear             Clear buffer (revert to auto-discovery)"
    echo ""
    echo "To plan concurrent work:"
    echo "  aapp plan conflict-check <id> <id>…   Can these plans run at the same time?"
    echo "  aapp plan conflict-free [<id>|<group>] Free to start now, against <id>, or a group's waves"
    echo ""
    echo "To abandon a plan:"
    echo "  aapp plan abort <id> [reason \"<text>\"]  Archive it to aborted/; its worktree and branch go, its issue stays"
    echo ""
    echo "To draft or execute blueprints:"
    echo "  Use '/plan <idea>' or '/aapp-plan <idea>' in your AI agent chat."
}

# plan_blocked_on_parse <text after "* **Blocked On:** "> (P-49, P-52)
# Prints three lines: the issue list ("#41, #42"), the recorded previous status
# (or empty) and the permanent hotfix-limit marker (or empty). Line shapes:
#   #41, #42 (was ⚡ In Development)
#   #41, #42 (was ⚡ In Development); hotfix limit reached (#40, #41, #42)
#   (was ⚡ In Development); hotfix limit reached (…)      (permanent, list empty)
plan_blocked_on_parse() {
    local rest="$1" perm="" was="" list
    case "$rest" in *"hotfix limit reached"*) perm="hotfix limit reached${rest#*hotfix limit reached}"; rest="${rest%%hotfix limit reached*}" ;; esac
    case "$rest" in *"(was "*) was="${rest#*(was }"; was="${was%%)*}"; rest="${rest%%(was *}" ;; esac
    list="$(printf '%s\n' "$rest" | tr ',' '\n' | tr -d ' ;' | grep -E "^${AAPP_ISSUE_REF_RE}\$" | paste -sd, - | sed 's/,/, /g')"
    printf '%s\n%s\n%s\n' "$list" "$was" "$perm"
}

# plan_blocked_on_line <list> <was> <perm>: the `* **Blocked On:**` line for those fields.
plan_blocked_on_line() {
    local out="$1"
    [ -n "$2" ] && out="${out:+$out }(was $2)"
    [ -n "$3" ] && out="${out:+$out; }$3"
    printf '* **Blocked On:** %s\n' "$out"
}

# plan_block_on <plan_file> <num> (P-49)
# Write-only: sets the Status line to 🟥 BLOCKED and appends #<num> to the
# `* **Blocked On:**` list, recording the status the plan had before on the
# first block. No commit and no matrix: callers commit (`refine … blocked`
# alone, `issue hotfix` with its other files).
# Returns 0 when written, 3 when #<num> is already listed (nothing written).
plan_block_on() {
    local pf="$1" num="${2#\#}" status_line prev line list was perm fields tmp
    [ -f "$pf" ] || return 1
    issue_id_valid "$num" || return 1
    status_line="$(grep -m 1 -E '^\* \*\*Status:\*\*' "$pf" || true)"
    [ -n "$status_line" ] || return 1
    prev="${status_line#\* \*\*Status:\*\* }"
    line="$(grep -m 1 -E '^\* \*\*Blocked On:\*\*' "$pf" || true)"
    if [ -n "$line" ]; then
        fields="$(plan_blocked_on_parse "${line#\* \*\*Blocked On:\*\* }")"
        list="$(sed -n 1p <<< "$fields")"; was="$(sed -n 2p <<< "$fields")"; perm="$(sed -n 3p <<< "$fields")"
        if printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -qxF "#$num"; then
            return 3
        fi
        line="$(plan_blocked_on_line "${list:+$list, }#$num" "$was" "$perm")"
    elif printf '%s' "$prev" | grep -qE '🟥|BLOCKED'; then
        line="$(plan_blocked_on_line "#$num" "" "")"
    else
        line="$(plan_blocked_on_line "#$num" "$prev" "")"
    fi
    tmp="$(mktemp)" || return 1
    AAPP_BLOCKED_LINE="$line" awk '
        /^\* \*\*Status:\*\*/ && !s { print "* **Status:** 🟥 BLOCKED"; s = 1; if (!b) { print ENVIRON["AAPP_BLOCKED_LINE"]; b = 1 } ; next }
        /^\* \*\*Blocked On:\*\*/ { if (!b) { print ENVIRON["AAPP_BLOCKED_LINE"]; b = 1 } ; next }
        { print }
    ' "$pf" > "$tmp" && mv "$tmp" "$pf" || { rm -f "$tmp"; return 1; }
}

# plan_unblock <plan_file> <num> (P-52, P-78)
# Write-only: removes #<num> from the `* **Blocked On:**` list; when the list
# empties and the block is not permanent, restores the recorded previous
# status. No commit and no matrix: callers commit.
# Returns 0 when written, 3 when #<num> is not listed (nothing written).
plan_unblock() {
    local pf="$1" n="${2#\#}" line fields list was perm newlist tmp
    [ -f "$pf" ] || return 1
    line="$(grep -m 1 -E '^\* \*\*Blocked On:\*\*' "$pf" || true)"
    [ -n "$line" ] || return 3
    fields="$(plan_blocked_on_parse "${line#\* \*\*Blocked On:\*\* }")"
    list="$(sed -n 1p <<< "$fields")"; was="$(sed -n 2p <<< "$fields")"; perm="$(sed -n 3p <<< "$fields")"
    printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -qxF "#$n" || return 3
    newlist="$(printf '%s\n' "$list" | tr ',' '\n' | tr -d ' ' | grep -E "^${AAPP_ISSUE_REF_RE}\$" | grep -vxF "#$n" | paste -sd, - | sed 's/,/, /g')"
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
}

# _issues_follow_branch <removed-branch> <parent> (P-78): the open issues that
# targeted a branch the kit has just removed target its parent, in one commit.
_issues_follow_branch() {
    local moved
    [ -n "$1" ] && [ -n "$2" ] || return 0
    _load_issue_module
    moved="$(issue_move_branch "$1" "$2")" || { echo "⚠️  [Issues] Could not retarget the issues of '$1'; set them with 'aapp refine issues \"<msg>\" branch <num> $2'." >&2; return 0; }
    [ -n "$moved" ] || return 0
    # Where a tracker keeps the record the ledger is not tracked: nothing to commit.
    [ -n "$(ledger_commit_paths issues)" ] || { echo "🐛 [Issues] $moved targeted '$1', which is removed; now '$2'."; return 0; }
    plans_commit "issue(branch): retarget issues of a removed branch" $(ledger_commit_paths issues) || {
        echo "⚠️  [Issues] $moved now target '$2' in ISSUES.md, uncommitted; commit with 'aapp refine issues \"<msg>\"'." >&2; return 0; }
    echo "🐛 [Issues] $moved targeted '$1', which is removed; now '$2'."
}

# _refine_check_subject <subject> <msg>: refuse before any git work when the
# message is not one line or the subject exceeds the commit-msg gate's limit.
_refine_check_subject() {
    local subject="$1" msg="$2" max len
    case "$msg" in
        *$'\n'*|*$'\r'*)
            echo "❌ [Refine] The message must be a single line (it becomes the commit subject)." >&2
            exit 1
            ;;
    esac
    max="$(git config --int aapp.subjectMaxLen 2>/dev/null || echo 72)"
    len="${#subject}"
    if [ "$len" -gt "$max" ]; then
        echo "❌ [Refine] Commit subject is $len characters; the limit is $max (aapp.subjectMaxLen)." >&2
        echo "   Shorten the message by $((len - max)) characters: \"$msg\"" >&2
        exit 1
    fi
}

# _load_issue_module: cmd_issue.sh (issue_mark_planned, issue_queued_blockers, issue_unblock_plans).
_load_issue_module() {
    declare -f issue_mark_planned >/dev/null && return 0
    # shellcheck source=lib/cmd_issue.sh
    . "$(dirname "${BASH_SOURCE[0]}")/cmd_issue.sh" || {
        echo "❌ [AAPP] Issue module missing: $(dirname "${BASH_SOURCE[0]}")/cmd_issue.sh" >&2
        exit 1
    }
}

# _refine_ledger pickup|issues "<msg>" (P-50): commit a hand-made ledger edit,
# validated first; nothing is committed on failure.
_refine_ledger() {
    local target="$1" msg="$2" subject files=() f changed="" sha health
    health="$(dirname "${BASH_SOURCE[0]}")/planning_health.sh"
    if [ "$target" = "issues" ]; then
        shift
        _refine_issues "$@"
        return
    fi
    subject="pickup: $msg"; files=("pickup.md")
    if [ $# -gt 2 ]; then
        echo "❌ [Refine] Usage: aapp refine pickup \"<msg>\"" >&2
        exit 1
    fi
    _refine_check_subject "$subject" "$msg"
    for f in "${files[@]}"; do
        [ -n "$(git -C "$PLANS_DIR" status --porcelain -- "$f")" ] && changed=1
    done
    if [ -z "$changed" ]; then
        echo "❌ [Refine] Nothing to commit: ${files[*]} unchanged." >&2
        exit 1
    fi
    # shellcheck source=lib/planning_health.sh
    . "$health" || { echo "❌ [Refine] Cannot load $health" >&2; exit 1; }
    check_pickup_entries "$PLANS_DIR/pickup.md" >&2 || {
        echo "   Nothing committed: fix pickup.md and run 'aapp refine pickup' again." >&2; exit 1; }
    _refine_commit "$subject" "${files[@]}"
    sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
    echo "📝 [Refine] $target committed ($sha): $msg"
}

# _refine_issues "<msg>" [branch <num> <name>] [note <num> "<text>"]… (P-50, P-78, P-74)
# A change to existing rows, validated and committed; `branch` names the branch
# an issue's fix lands on; `note` adds a note to an issue (kept outside Git,
# never in the ledger). A row is never added here: `aapp issue log` is the one
# writer of new rows. Where a tracker keeps the record the ledgers are not
# tracked: nothing is committed, the change is sent to the provider.
_refine_issues() {
    local usage='aapp refine issues "<msg>" [branch <num> <name>] [note <num> "<text>"]…'
    local msg="$1" subject files=() f changed="" sha="" health external=0 n old="" ids="" i
    local bn="" bname="" bcur bwant notes_n=() notes_t=() said=0
    health="$(dirname "${BASH_SOURCE[0]}")/planning_health.sh"
    shift
    subject="issue(triage): $msg"
    while [ $# -gt 0 ]; do
        case "$1" in
            branch) if [ $# -lt 3 ] || [ -n "$bn" ]; then echo "❌ [Refine] Usage: $usage" >&2; exit 1; fi
                    bn="$(issue_id_body "$2")" || exit 1; bname="$3"; shift 3 ;;
            note)   if [ $# -lt 3 ] || [ -z "$3" ]; then echo "❌ [Refine] Usage: $usage" >&2; exit 1; fi
                    n="$(issue_id_body "$2")" || exit 1
                    notes_n+=("$n"); notes_t+=("$3"); shift 3 ;;
            *)      echo "❌ [Refine] Usage: $usage" >&2; exit 1 ;;
        esac
    done
    _refine_check_subject "$subject" "$msg"
    _load_issue_module
    ledger_record_external && external=1
    files=($(ledger_commit_paths issues roadmap))
    # Everything is checked before anything is written or sent.
    for n in ${bn:+"$bn"} "${notes_n[@]}"; do
        if ! ledger_row "$n" >/dev/null 2>&1; then
            echo "❌ [Refine] #$n is not an active issue in ISSUES.md." >&2
            exit 1
        fi
    done
    if [ -n "$bn" ] && ! aapp_branch_ref "$bname" >/dev/null; then
        echo "❌ [Refine] Branch '$bname' does not exist, here or on a remote; #$bn is unchanged." >&2
        exit 1
    fi
    # shellcheck source=lib/planning_health.sh
    . "$health" || { echo "❌ [Refine] Cannot load $health" >&2; exit 1; }
    if [ "$external" -eq 0 ]; then
        old="$(mktemp)" || exit 1
        if git -C "$PLANS_DIR" show "HEAD:$(ledger_rel issues)" > "$old" 2>/dev/null; then
            check_issues_added_rows "$(ledger_path issues)" "$old" >&2 || {
                rm -f "$old"; echo "   Nothing committed." >&2; exit 1; }
        else
            rm -f "$old"; old=""
        fi
    fi
    if [ -n "$bn" ]; then
        bcur="$(ledger_cell "$bn" branch)"; bwant="$(issue_branch_cell "$bname")"
        if [ "$bcur" = "$bwant" ]; then
            if [ ${#notes_n[@]} -eq 0 ] && { [ ${#files[@]} -eq 0 ] || [ -z "$(git -C "$PLANS_DIR" status --porcelain -- "${files[@]}")" ]; }; then
                [ -z "$old" ] || rm -f "$old"
                echo "ℹ️  [Refine] #$bn already targets '$bname'; nothing changed."
                return 0
            fi
        else
            ledger_set_cell "$bn" branch "$bwant" || exit 1
            ids="$bn"
        fi
    fi
    for f in "${files[@]}"; do
        [ -n "$(git -C "$PLANS_DIR" status --porcelain -- "$f")" ] && changed=1
    done
    if [ -z "$changed" ] && [ -z "$ids" ] && [ ${#notes_n[@]} -eq 0 ]; then
        [ -z "$old" ] || rm -f "$old"
        if [ "$external" -eq 1 ]; then
            echo "❌ [Refine] The tracker keeps the issues: change them there, or here with 'branch <num> <name>' or 'note <num> \"<text>\"'." >&2
        else
            echo "❌ [Refine] Nothing to commit: ${files[*]} unchanged." >&2
        fi
        exit 1
    fi
    if [ -n "$changed" ] || [ -n "$ids" ]; then
        check_ledger_issues "$(ledger_path issues)" "$(ledger_path archive)" "$(ledger_path roadmap)" >&2 || {
            [ -z "$old" ] || rm -f "$old"
            echo "   Nothing committed: fix the lines above and run 'aapp refine issues' again." >&2; exit 1; }
    fi
    # The rows that changed: each is a `refine` step for the provider.
    if [ -n "$old" ]; then
        for n in $(ledger_ids active); do
            [ "$(ledger_row "$n")" = "$(AAPP_LEDGER_ISSUES="$old" ledger_row "$n")" ] || ids="$ids $n"
        done
        rm -f "$old"
    fi
    if [ -n "$changed" ]; then
        _refine_commit "$subject" "${files[@]}"
        sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
        echo "📝 [Refine] issues committed ($sha): $msg"
        said=1
    fi
    # Sent after the local write: a refused change never reaches the provider.
    for n in $(printf '%s\n' $ids "${notes_n[@]}" | awk 'NF && !seen[$0]++'); do
        local own=()
        for i in "${!notes_n[@]}"; do
            [ "${notes_n[$i]}" = "$n" ] && own+=("${notes_t[$i]}")
        done
        issue_refine_step "$n" "${own[@]}"
        if [ ${#own[@]} -gt 0 ]; then echo "📝 [Refine] #$n: ${#own[@]} note(s) added: $msg"; said=1; fi
    done
    [ "$said" -eq 1 ] || echo "📝 [Refine] issues: $msg"
}

# _refine_slug <plan-id> <new-slug> (P-50): rename a plan file, repair the
# issue links that point at it, re-derive the matrix, one commit.
_refine_slug() {
    local query="$1" raw="$2" plan_file old new slug prefix plan_id subject count act sha today links
    plan_file="$(resolve_plan_file "$query" "refine")" || exit 1
    old="$(basename "$plan_file")"
    slug="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[ _]/-/g' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
    if [ -z "$slug" ]; then
        echo "❌ [Refine] The new slug is empty after normalisation: '$raw'." >&2
        exit 1
    fi
    prefix="${old%%-*}"
    new="${prefix}-${slug}.md"
    if [ "$new" = "$old" ]; then
        echo "❌ [Refine] $old already has that name." >&2
        exit 1
    fi
    if [ -e "$PLANS_DIR/current/$new" ]; then
        echo "❌ [Refine] current/$new already exists." >&2
        exit 1
    fi
    if [ -n "$(git -C "$PLANS_DIR" status --porcelain -- "current/$old")" ]; then
        echo "❌ [Refine] current/$old has uncommitted edits; commit them with 'aapp refine $query \"<what changed>\"' first." >&2
        exit 1
    fi
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" | head -n 1)"
    [ -n "$plan_id" ] || plan_id="$query"
    subject="plan(refine): $plan_id renamed to $new"
    _refine_check_subject "$subject" "renamed to $new"

    mv "$PLANS_DIR/current/$old" "$PLANS_DIR/current/$new" || exit 1
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$PLANS_DIR/current/$new"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* File renamed from $old to $new." "$PLANS_DIR/current/$new"
    fi
    _load_issue_module
    count="$(ledger_relink "current/$old" "current/$new")" || exit 1
    if [ -f "$ACTIVE_FILE" ]; then
        act="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
        if [ "$act" = "$old" ] || [ "$act" = "${old%.md}" ]; then
            echo "${new%.md}" > "$ACTIVE_FILE"
        fi
    fi
    sync_state_matrix
    local paths=("current/$old" "current/$new")
    [ -f "$PLANS_DIR/state_matrix.md" ] && paths+=("state_matrix.md")
    if [ "$count" -gt 0 ]; then
        paths+=($(ledger_commit_paths issues roadmap))
    fi
    _refine_commit "$subject" "${paths[@]}"
    sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
    links="links"; [ "$count" -eq 1 ] && links="link"
    echo "📝 [Refine] $plan_id renamed to $new ($sha); $count issue $links repaired"
}

# cmd_refine <plan-id> "<what changed>" | <plan-id> blocked <num> (P-47, P-49)
# Commits an edit to an active plan's content through the lifecycle commit
# engine, so agents never run raw git on the plans worktree. Only the plan file
# is committed; the pre-commit design lock still guards frozen sections.
# `blocked <num>` writes the BLOCKED status itself (plan_block_on); the state
# matrix stays `aapp matrix`'s job.
# _refine_group <plan> <group-id|none> (P-64): a plan joins or leaves a group
# until it is started; plan and group(s) change in one commit.
_refine_group() {
    local pf pid cur gf="" gid="" paths=() subject
    pf="$(resolve_plan_file "$1" "refine")" || exit 1
    pid="$(sed -nE 's/^\* \*\*Plan ID:\*\*[[:space:]]*(P-[0-9]+).*/\1/p' "$pf" | head -n 1)"
    if aapp_is_group_plan "$pf"; then
        echo "❌ [Refine] $pid is a group plan; groups do not nest." >&2
        exit 1
    fi
    case "$(plan_status_slug "$pf")" in
        in-development|blocked)
            echo "❌ [Refine] $pid is already started; its group can no longer change." >&2
            exit 1 ;;
    esac
    cur="$(parse_plan_field "$pf" Group)"
    if [ "$2" != "none" ]; then
        gf="$(_group_resolve "$2" "Refine")" || exit 1
        gid="$(sed -nE 's/^\* \*\*Plan ID:\*\*[[:space:]]*(P-[0-9]+).*/\1/p' "$gf" | head -n 1)"
    fi
    if [ "$cur" = "$gid" ] || { [ -z "$cur" ] && [ "$2" = "none" ]; }; then
        echo "ℹ️  [Refine] $pid is already ${gid:+in }${gid:-in no group}; nothing changed."
        return 0
    fi
    paths=("current/$(basename "$pf")")
    if [ -n "$cur" ]; then
        local old
        old="$(resolve_plan_file "$cur" "refine")" || exit 1
        group_set_member "$old" "$pid" remove || exit 1
        paths+=("current/$(basename "$old")")
    fi
    write_plan_field "$pf" Group "$gid" Base || exit 1
    if [ -n "$gf" ]; then
        group_set_member "$gf" "$pid" add || exit 1
        paths+=("current/$(basename "$gf")")
        subject="plan(refine): $pid joins group $gid"
    else
        subject="plan(refine): $pid leaves group $cur"
    fi
    _refine_commit "$subject" "${paths[@]}"
    echo "📝 [Refine] ${subject#plan(refine): }."
}

# _refine_unblocked <plan-id> <num> (P-78): the manual unblock, for a fix that
# reached the plan's parent branch as another commit (a squash, a cherry-pick,
# a rebase), which the kit does not recognise. Refuses an issue still open.
_refine_unblocked() {
    local pf rel pid num rc=0 sha
    num="$(issue_id_body "$2" 2>/dev/null)" || {
        echo "❌ [Refine] Usage: aapp refine <plan-id> unblocked <num> (an issue's id without the '#': a number or a tracker's key, e.g. 101 or PROJ-101)" >&2
        exit 1
    }
    pf="$(resolve_plan_file "$1" "refine")" || exit 1
    rel="current/$(basename "$pf")"
    pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" | head -n 1)"
    [ -n "$pid" ] || pid="$1"
    if ledger_row "$num" >/dev/null 2>&1; then
        echo "❌ [Refine] #$num is still open; a plan is unblocked once its issue is closed ('aapp issue close $num')." >&2
        exit 1
    fi
    plan_unblock "$pf" "$num" || rc=$?
    if [ "$rc" -eq 3 ]; then
        echo "❌ [Refine] $pid is not blocked on #$num." >&2
        exit 1
    elif [ "$rc" -ne 0 ]; then
        echo "❌ [Refine] Could not update $rel." >&2
        exit 1
    fi
    _refine_commit "plan(refine): $pid unblocked from #$num" "$rel"
    sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
    echo "📝 [Refine] $pid committed ($sha): unblocked from #$num"
    if grep -q '^\* \*\*Blocked On:\*\*' "$pf"; then
        echo "   Still blocked: $(sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$pf" | head -n 1)"
    fi
}

# plan_also_closes <plan_file> (P-86): the further issues a plan closes, from
# its `* **Also Closes:**` line, one id (without `#`) per line.
plan_also_closes() {
    parse_plan_field "$1" "Also Closes" | issue_id_refs | sed 's/^#//'
}

# _refine_closes <plan> <num> [remove] (P-86): adds an active issue to the
# plan's `Also Closes` list, or takes it off; the issue's row is not touched.
_refine_closes() {
    local usage="aapp refine <plan-id> closes <num> [remove] (an issue's id without the '#')"
    local pf rel pid num list new sha t what
    num="$(issue_id_body "$2" 2>/dev/null)" || { echo "❌ [Refine] Usage: $usage" >&2; exit 1; }
    case "${3:-}" in ''|remove) ;; *) echo "❌ [Refine] Unknown token '$3'. Usage: $usage" >&2; exit 1 ;; esac
    pf="$(resolve_plan_file "$1" "refine")" || exit 1
    rel="current/$(basename "$pf")"
    pid="$(parse_plan_field "$pf" "Plan ID")"; [ -n "$pid" ] || pid="$1"
    list="$(plan_also_closes "$pf")"
    if [ "${3:-}" = "remove" ]; then
        if ! printf '%s\n' "$list" | grep -qxF -- "$num"; then
            echo "❌ [Refine] $pid does not list #$num in its Also Closes." >&2; exit 1
        fi
        list="$(printf '%s\n' "$list" | grep -vxF -- "$num" || true)"
        what="no longer closes #$num"
    else
        if printf '%s\n' "$list" | grep -qxF -- "$num"; then
            echo "ℹ️  [Refine] $pid already closes #$num; nothing changed."
            return 0
        fi
        if ! ledger_row "$num" >/dev/null 2>&1; then
            echo "❌ [Refine] #$num is not an active issue in ISSUES.md." >&2; exit 1
        fi
        t="$(issue_id_at_start "$(parse_plan_field "$pf" "Target Issue / Milestone")" 2>/dev/null)" || t=""
        if [ "$t" = "$num" ]; then
            echo "❌ [Refine] #$num is $pid's own Target Issue: 'aapp done' closes it already." >&2; exit 1
        fi
        list="$(printf '%s\n%s\n' "$list" "$num" | awk 'NF')"
        what="closes #$num"
    fi
    new="$(printf '%s\n' "$list" | awk 'NF { printf "%s#%s", (n++ ? ", " : ""), $0 }')"
    write_plan_field "$pf" "Also Closes" "$new" "Target Issue / Milestone" || exit 1
    _refine_commit "plan(refine): $pid $what" "$rel"
    sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
    echo "📝 [Refine] $pid committed ($sha): $what"
}

# ------------------------------------------------------------------------------
# The amendments member (P-101): the refine kinds that write request lines. The
# line format and its readers are in lib/aapp-lib.sh (amend_*); these are the writers.
# ------------------------------------------------------------------------------

# amend_request_set_state <plan_file> <n> <state>: rewrites R<n>'s state.
amend_request_set_state() {
    local tmp="$1.aapp-req.$$"
    AAPP_RN="$2" AAPP_RS="$3" awk '
        /^## Scope Requests$/ { f = 1 } /^## / && !/^## Scope Requests$/ { f = 0 }
        f && index($0, "- **R" ENVIRON["AAPP_RN"] "** ") == 1 { sub(/ — .*$/, ""); $0 = $0 " — " ENVIRON["AAPP_RS"] }
        { print }' "$1" > "$tmp" && mv "$tmp" "$1"
}

# _amend_append <plan_file> <section> <line>: the line at the end of `## <section>`.
_amend_append() {
    local tmp="$1.aapp-req.$$"
    AAPP_SEC="## $2" AAPP_LINE="$3" awk '
        function flush() { print ENVIRON["AAPP_LINE"]; for (i = 0; i < nb; i++) print ""; nb = 0; done = 1 }
        $0 == ENVIRON["AAPP_SEC"] { print; f = 1; next }
        f && /^## / { flush(); f = 0; print; next }
        f && $0 == "" { nb++; next }
        f { for (i = 0; i < nb; i++) print ""; nb = 0; print; next }
        { print }
        END { if (f && !done) flush() }' "$1" > "$tmp" && mv "$tmp" "$1"
}

# _amend_next <plan_file> <section> <letter>: the next number of R or D lines.
_amend_next() {
    local n
    n="$(amend_section_lines "$1" "$2" | sed -nE "s/^- \*\*$3([0-9]+)\*\* .*/\1/p" | sort -n | tail -n 1)"
    echo $(( ${n:-0} + 1 ))
}

# _amend_add_target <plan_file> <path> <note>: one Target Files line, after the
# file is checked against every other plan in development.
_amend_add_target() {
    local pf="$1" p="$2" note="$3" other
    if parse_plan_target_paths "$pf" | grep -qxF -- "$p"; then
        echo "❌ [Refine] \`$p\` is already in $(basename "$pf" .md)'s Target Files." >&2; return 1
    fi
    for other in "$PLANS_DIR"/current/*.md; do
        [ "$other" = "$pf" ] && continue
        [ "$(plan_status_slug "$other")" = "in-development" ] || continue
        if parse_plan_target_paths "$other" | grep -qxF -- "$p"; then
            echo "❌ [Refine] \`$p\` is a Target File of $(parse_plan_field "$other" "Plan ID"), which is in development; it cannot be added." >&2
            return 1
        fi
    done
    plan_add_target_line "$pf" "- [ ] \`$p\` -> $note"
}

# _amend_outside_group_section: a group plan on stdin without its
# `## Architecture & Codemap` (fenced headings inside it do not end it).
_amend_outside_group_section() {
    awk '
        /^````/ && sec { infence = !infence; next }
        infence { next }
        /^## Architecture & Codemap/ { sec = 1; next }
        /^## / { sec = 0 }
        !sec'
}

# _amend_approver: who approves: the agent identity when given, else git's user.
_amend_approver() {
    if [ -n "${AAPP_AGENT_NAME:-}" ]; then echo "$AAPP_AGENT_NAME"; else git config --get user.name 2>/dev/null || echo "unknown"; fi
}

# _refine_amend <kind> <query> <args…>: request | approve | refuse | file | decision
# on a group's amendments member (P-101). Each is one plans commit.
_refine_amend() {
    local kind="$1" query="$2" pf aid gid gf rel n l req bound target summary p reason heading k today af_rel gf_rel
    shift 2
    pf="$(resolve_plan_file "$query" "refine")" || exit 1
    aid="$(parse_plan_field "$pf" "Plan ID")"; rel="current/$(basename "$pf")"
    if [ "$(parse_plan_field "$pf" Kind)" != "amendments" ]; then
        echo "❌ [Refine] '$kind' is for a group's amendments member; $aid is not one." >&2; exit 1
    fi
    if [ "$(plan_status_slug "$pf")" != "in-development" ]; then
        echo "❌ [Refine] $aid is not ⚡ In Development; its group's 'aapp start' starts it." >&2; exit 1
    fi
    gid="$(parse_plan_field "$pf" Group)"; gf="$(resolve_plan_file "$gid" "refine")" || exit 1
    today="$(date +%Y-%m-%d)"
    case "$kind" in
        request)
            summary="${1:-}"; shift || true
            [ -n "$summary" ] || { echo "❌ [Refine] Usage: aapp refine <amend-id> request \"<summary>\" [file <path> | heading \"<heading>\"]" >&2; exit 1; }
            case "${1:-}" in
                file)    [ -n "${2:-}" ] || { echo "❌ [Refine] 'file' needs a path." >&2; exit 1; }; target="\`$2\`" ;;
                heading) [ -n "${2:-}" ] || { echo "❌ [Refine] 'heading' needs the heading's text." >&2; exit 1; }; target="§ $2" ;;
                "")      target="—" ;;
                *)       echo "❌ [Refine] Unknown token '$1'; use file <path> or heading \"<heading>\"." >&2; exit 1 ;;
            esac
            bound="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
            if [ -z "$bound" ] || [ "$bound" = "$aid" ] || ! group_members "$gf" | grep -qxF "$bound"; then
                echo "❌ [Refine] A request comes from the checkout of a member of group $gid, for itself; this checkout is bound to ${bound:-no plan}." >&2; exit 1
            fi
            aapp_amendment_approval_required >/dev/null || exit 1
            n="$(_amend_next "$pf" "Scope Requests" R)"
            _amend_append "$pf" "Scope Requests" "- **R$n** $today · $bound · $target · $summary — pending"
            _refine_commit "plan(refine): $aid request R$n from $bound" "$rel"
            if [ "$(aapp_amendment_approval_required)" = "true" ] && [ "$target" != "—" ]; then
                echo "📝 [Refine] R$n recorded in $aid, waiting for approval. Do not implement ${target#§ }; continue with your own Target Files, or stop. Check: aapp plan-status $aid"
            else
                echo "📝 [Refine] R$n recorded in $aid."
            fi
            ;;
        approve|refuse)
            n="${1:-}"; reason="${2:-}"
            [[ "$n" =~ ^[0-9]+$ ]] || { echo "❌ [Refine] Usage: aapp refine <amend-id> $kind <n>$([ "$kind" = refuse ] && echo ' "<reason>"')" >&2; exit 1; }
            l="$(amend_request_line "$pf" "$n")" || { echo "❌ [Refine] $aid has no request R$n." >&2; exit 1; }
            [ "$(amend_request_state "$l")" = "pending" ] || { echo "❌ [Refine] R$n is not pending ($(amend_request_state "$l"))." >&2; exit 1; }
            if [ "$kind" = refuse ]; then
                [ -n "$reason" ] || { echo "❌ [Refine] Usage: aapp refine <amend-id> refuse <n> \"<reason>\"" >&2; exit 1; }
                amend_request_set_state "$pf" "$n" "refused: $reason"
                _refine_commit "plan(refine): $aid refuse R$n" "$rel"
                echo "📝 [Refine] R$n refused: $reason"
                return 0
            fi
            if [ "$(aapp_amendment_approval_required)" != "true" ]; then
                echo "❌ [Refine] aapp.amendmentApprovalRequired is false: $aid's owner adds a file with 'aapp refine $aid file <path> \"<reason>\"'." >&2; exit 1
            fi
            p="$(amend_request_path "$l")"
            if [ -n "$p" ]; then
                _amend_add_target "$pf" "$p" "R$n $(printf '%s\n' "$l" | sed -E 's/^.* · //; s/ — .*$//')" || exit 1
            fi
            amend_request_set_state "$pf" "$n" "approved ($(_amend_approver))"
            _refine_commit "plan(refine): $aid approve R$n" "$rel"
            if [ -n "$p" ]; then
                echo "📝 [Refine] R$n approved: \`$p\` added to $aid's Target Files; implement it in $(parse_plan_worktree "$pf" | cut -f1)."
            else
                echo "📝 [Refine] R$n approved; $aid's owner applies it ('decision $n')."
            fi
            ;;
        file)
            p="${1:-}"; reason="${2:-}"
            [ -n "$p" ] && [ -n "$reason" ] || { echo "❌ [Refine] Usage: aapp refine <amend-id> file <path> \"<reason>\"" >&2; exit 1; }
            if [ "$(aapp_amendment_approval_required)" != "false" ]; then
                echo "❌ [Refine] Approval is required (aapp.amendmentApprovalRequired): a file comes in by 'request', then 'aapp refine $aid approve <n>'." >&2; exit 1
            fi
            _refine_owner_check "$pf" "$aid"
            _amend_add_target "$pf" "$p" "$reason" || exit 1
            _refine_commit "plan(refine): $aid file $(basename "$p")" "$rel"
            echo "📝 [Refine] \`$p\` added to $aid's Target Files."
            ;;
        decision)
            _refine_owner_check "$pf" "$aid"
            if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
                n="$1"; reason="${2:-}"
                l="$(amend_request_line "$pf" "$n")" || { echo "❌ [Refine] $aid has no request R$n." >&2; exit 1; }
                heading="$(amend_request_heading "$l")"
                [ -n "$heading" ] || { echo "❌ [Refine] R$n names no heading of the group's text." >&2; exit 1; }
                case "$(amend_request_state "$l")" in approved*) ;; *)
                    echo "❌ [Refine] R$n is not approved ($(amend_request_state "$l"))." >&2; exit 1 ;; esac
            else
                heading="${1:-}"; reason="${2:-}"; n=""
                if [ "$(aapp_amendment_approval_required)" = "true" ]; then
                    echo "❌ [Refine] Approval is required: request it with 'heading', approve it, then 'aapp refine $aid decision <n> \"<reason>\"'." >&2; exit 1
                fi
            fi
            [ -n "$heading" ] && [ -n "$reason" ] || { echo "❌ [Refine] Usage: aapp refine <amend-id> decision <n> \"<reason>\" | decision \"<heading>\" \"<reason>\"" >&2; exit 1; }
            gf_rel="current/$(basename "$gf")"; af_rel="$rel"
            if [ -z "$(git -C "$PLANS_DIR" status --porcelain -- "$gf_rel")" ]; then
                echo "❌ [Refine] Write the corrected section into $gf_rel first; it has no changes." >&2; exit 1
            fi
            # Only the group's `## Architecture & Codemap` may change; the pre-commit
            # lock checks that each changed section is the one named (P-99).
            if ! diff -q <(git -C "$PLANS_DIR" show "HEAD:$gf_rel" | _amend_outside_group_section) \
                         <(_amend_outside_group_section < "$gf") >/dev/null; then
                echo "❌ [Refine] $gf_rel changed outside its ## Architecture & Codemap; a decision changes that section only." >&2; exit 1
            fi
            k="$(_amend_next "$pf" "Decisions" D)"
            _amend_append "$pf" "Decisions" "- **D$k** $today · § $heading · ${n:+R$n · }$reason"
            [ -n "$n" ] && amend_request_set_state "$pf" "$n" "applied"
            if ! ( _refine_commit "plan(refine): $aid decision D$k on group $gid" "$gf_rel" "$af_rel" ); then
                git -C "$PLANS_DIR" reset -q -- "$gf_rel" "$af_rel" 2>/dev/null
                git -C "$PLANS_DIR" checkout -q -- "$af_rel" 2>/dev/null
                echo "❌ [Refine] Nothing committed; the group plan keeps your edit. The lock accepts a change to the section named '$heading' only." >&2
                exit 1
            fi
            echo "📝 [Refine] D$k: group $gid's section '$heading' corrected; members re-read it at their next start or session start."
            ;;
    esac
}

# _amend_done_check <plan_file>: an amendments member is archived last, with no
# request left pending or approved and not landed (P-101).
_amend_done_check() {
    local pf="$1" gid gf m open="" req
    gid="$(parse_plan_field "$pf" Group)"
    if gf="$(resolve_plan_file "$gid" "done" 2>/dev/null)"; then
        for m in $(group_members "$gf"); do
            [ "$m" = "$(parse_plan_field "$pf" "Plan ID")" ] && continue
            [ -n "$(ls "$PLANS_DIR"/current/P"${m#P-}"-*.md 2>/dev/null)" ] && open="$open $m"
        done
    fi
    if [ -n "$open" ]; then
        echo "❌ [Done Refusal] The amendments member is archived last; group $gid has members not archived:$open." >&2; exit 1
    fi
    req="$(amend_open_requests "$pf")"
    if [ -n "$req" ]; then
        echo "❌ [Done Refusal] Requests still open; approve or refuse each, and land what was approved:" >&2
        printf '%s\n' "$req" | sed 's/^/   /' >&2
        exit 1
    fi
}

# _refine_owner_check <plan_file> <plan_id>: a plan in development, and every
# plan of a group in development, started or not, is refined only from its
# owning checkout (P-99): the plan's recorded worktree, else the checkout whose
# active-plan buffer holds it; for a group, a checkout bound to one of its plans.
# The refusal says what to do instead. Verb-written fields do not come here.
_refine_owner_check() {
    local pf="$1" pid="$2" here bound grp="" gf="" wt_rec wt_abs owner
    here="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)"
    bound="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
    if aapp_is_group_plan "$pf"; then
        gf="$pf"; grp="$pid"
    else
        grp="$(parse_plan_field "$pf" Group)"
        if [ -n "$grp" ]; then gf="$(resolve_plan_file "$grp" "refine" 2>/dev/null)" || gf=""; fi
    fi
    if [ "$(plan_status_slug "$pf")" = "in-development" ] && [ "$gf" != "$pf" ]; then
        wt_rec="$(parse_plan_worktree "$pf")"
        if [ -n "$wt_rec" ]; then
            wt_abs="$(cd "$(aapp_abs_path "${wt_rec%%$'\t'*}" "$PRIMARY_ROOT")" 2>/dev/null && pwd -P)"
            [ -n "$wt_abs" ] && [ "$here" = "$wt_abs" ] && return 0
            owner="its worktree ${wt_rec%%$'\t'*}"
        else
            [ "$bound" = "$pid" ] && return 0
            owner="the checkout whose active plan is $pid"
        fi
    elif [ -n "$gf" ] && [ "$(plan_status_slug "$gf")" = "in-development" ]; then
        if [ -n "$bound" ] && { [ "$bound" = "$grp" ] || group_members "$gf" | grep -qxF "$bound"; }; then return 0; fi
        owner="a checkout bound to a plan of group $grp (a member's worktree, or 'aapp active $grp')"
    else
        return 0
    fi
    echo "❌ [Refine] $pid is in development; only $owner amends it." >&2
    echo "   Do not change it from here: tell the developer, log what you found ('aapp issue log'), or add a line to pickup.md ('aapp refine pickup')." >&2
    exit 1
}

# _refine_event <event> <kind> <plan_id> <files> [commit] [args…]: `pre-refine`
# (gate), `on-refine` (in the transaction) or `post-refine` (observer) for every
# refine (P-99). A gate or an in-transaction failure refuses the refine.
_refine_event() {
    local ev="$1" rc=0
    [ -f "$AAPP_HOOK_DISPATCHER" ] || return 0
    # A subshell: the dispatcher sets errexit, which must not reach the rest of refine.
    (
        local kind="$2" pid="$3" files="$4" commit="${5:-}" a args="" fl="" f data
        shift 5 2>/dev/null || shift $#
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        for a in "$@"; do args="${args:+$args, }\"$(json_escape "$a")\""; done
        for f in $files; do fl="${fl:+$fl, }\"$(json_escape "$f")\""; done
        data="{\"command\": \"plan\", \"event\": \"refine\", \"plan_id\": \"$(json_escape "$pid")\", \"kind\": \"$kind\", \"args\": [$args], \"files\": [$fl]"
        if [ "$ev" = "post-refine" ]; then data="$data, \"commit\": \"$commit\""; fi
        dispatch_hook "$ev" "$data}"
    ) || rc=$?
    [ "$ev" = "post-refine" ] && return 0
    if [ "$rc" -ne 0 ]; then
        echo "❌ [Refine] The $ev hook refused; nothing committed." >&2
        exit 1
    fi
}

# _refine_commit <subject> <path>…: the plans commit of every refine, between
# `on-refine` and `post-refine` (P-99); REFINE_KIND, REFINE_PID, REFINE_ARGS
# are set by cmd_refine.
_refine_commit() {
    local subject="$1"; shift
    _refine_event on-refine "$REFINE_KIND" "$REFINE_PID" "$*" "" "${REFINE_ARGS[@]}"
    plans_commit "$subject" "$@" || exit 1
    _refine_event post-refine "$REFINE_KIND" "$REFINE_PID" "$*" "$(git -C "$PLANS_DIR" rev-parse --short HEAD)" "${REFINE_ARGS[@]}"
}

cmd_refine() {
    local query="${1:-}" msg="${2:-}" plan_file rel plan_id sha num="" subject rc
    if [ -z "$query" ] || [ -z "$msg" ]; then
        echo "❌ [Refine] Usage: aapp refine <plan-id> \"<what changed>\" | <plan-id> blocked <num> | <plan-id> unblocked <num> | <plan-id> slug <new-slug> | <plan-id> closes <num> [remove] | pickup \"<msg>\" | issues \"<msg>\" [branch <num> <name>]" >&2
        exit 1
    fi
    # P-99: the kind of refine, for the owner check and the `refine` events.
    REFINE_ARGS=("${@:2}"); REFINE_PID=""
    case "$query" in
        pickup|issues) REFINE_KIND="$query" ;;
        *)
            REFINE_KIND=message
            case "$msg" in unblocked|closes|slug|group|blocked|request|approve|refuse|file|decision) [ $# -ge 3 ] && REFINE_KIND="$msg" ;; esac
            plan_file="$(resolve_plan_file "$query" "refine")" || exit 1
            REFINE_PID="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" | head -n 1)"
            [ -n "$REFINE_PID" ] || REFINE_PID="$query"
            case "$REFINE_KIND" in message|slug) _refine_owner_check "$plan_file" "$REFINE_PID" ;; esac
            ;;
    esac
    _refine_event pre-refine "$REFINE_KIND" "$REFINE_PID" "" "" "${REFINE_ARGS[@]}"
    # P-50: ledger targets are reserved words, checked before plan resolution
    # (the resolver's file-name match would send `pickup` to a plan named *pickup*).
    case "$query" in
        pickup|issues) _refine_ledger "$query" "$msg" "${@:3}"; return ;;
    esac
    case "$msg" in request|approve|refuse|file|decision)
        if [ $# -ge 3 ]; then _refine_amend "$msg" "$query" "${@:3}"; return; fi ;;
    esac
    if [ "$msg" = "unblocked" ] && [ $# -ge 3 ]; then
        _refine_unblocked "$query" "$3"
        return
    fi
    if [ "$msg" = "closes" ] && [ $# -ge 3 ]; then
        _refine_closes "$query" "$3" "${4:-}"
        return
    fi
    if [ "$msg" = "slug" ] && [ $# -ge 3 ]; then
        _refine_slug "$query" "$3"
        return
    fi
    if [ "$msg" = "group" ] && [ $# -ge 3 ]; then
        _refine_group "$query" "$3"
        return
    fi
    if [ "$msg" = "blocked" ] && [ $# -ge 3 ]; then
        num="$(issue_id_body "$3" 2>/dev/null)" || {
            echo "❌ [Refine] Usage: aapp refine <plan-id> blocked <num> (an issue's id without the '#': a number or a tracker's key, e.g. 101 or PROJ-101)" >&2
            exit 1
        }
        msg="blocked on #$num"
    fi
    plan_file="$(resolve_plan_file "$query" "refine")" || exit 1
    rel="current/$(basename "$plan_file")"
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" | head -n 1)"
    [ -n "$plan_id" ] || plan_id="$query"
    subject="plan(refine): $plan_id $msg"
    _refine_check_subject "$subject" "$msg"
    if [ -n "$num" ]; then
        if ! ledger_row "$num" >/dev/null 2>&1; then
            echo "❌ [Refine] #$num is not an active issue in ISSUES.md." >&2
            exit 1
        fi
        rc=0
        plan_block_on "$plan_file" "$num" || rc=$?
        if [ "$rc" -eq 3 ]; then
            echo "ℹ️  [Refine] $plan_id is already blocked on #$num; nothing changed."
            return 0
        elif [ "$rc" -ne 0 ]; then
            echo "❌ [Refine] Could not write the BLOCKED status into $rel." >&2
            exit 1
        fi
    elif [ -z "$(git -C "$PLANS_DIR" status --porcelain -- "$rel")" ]; then
        echo "❌ [Refine] Nothing to commit: $rel has no changes." >&2
        exit 1
    fi
    if aapp_is_group_plan "$plan_file"; then
        _group_stamp_sections "$plan_file" || exit 1
    fi
    _refine_commit "$subject" "$rel"
    sha="$(git -C "$PLANS_DIR" rev-parse --short HEAD)" || exit 1
    echo "📝 [Refine] $plan_id committed ($sha): $msg"
}

# Sourcing with AAPP_PLAN_LIB_ONLY=1 loads the functions (e.g. plan_block_on
# for `aapp issue hotfix`, P-52) without running a command, as cmd_matrix.sh
# does with AAPP_MATRIX_LIB_ONLY.
if [ "${AAPP_PLAN_LIB_ONLY:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# Dispatcher
ACTION="${1:-plan}"
shift || true

case "$ACTION" in
    draft)
        cmd_draft "$@"
        ;;
    refine)
        cmd_refine "$@"
        ;;
    freeze-start)
        cmd_freeze_start "$@"
        ;;
    freeze)
        cmd_freeze "$@"
        ;;
    start)
        cmd_start "$@"
        ;;
    done)
        cmd_done "$@"
        ;;
    active)
        cmd_active "$@"
        ;;
    plan-status)
        cmd_plan_status "$@"
        ;;
    plan)
        cmd_plan_switchboard "$@"
        ;;
    tdd)
        cmd_tdd "$@"
        ;;
    help|-h|--help)
        cat <<EOF
Usage: aapp <command> [args]

Multi-Agent Planning & Execution Commands:
  draft [slug]       Scaffold blueprint from template, stamp ID & date, register in matrix
  refine <id> "<msg>" Commit an edit to an active plan's content (plans worktree)
  tdd <id>          Declare failure-first test sections in an incubator plan before freeze
  freeze-start <id>  Atomically freeze blueprint, transition to ⚡ In Development, and bind buffer
  freeze <id>        Lock blueprint into 🔷 Frozen backlog specification
  start <id>         Transition 🔷 Frozen blueprint to ⚡ In Development and bind buffer
  done <id>          Archive implemented blueprint to done/ and update ledger
  active [id]        Display or set active execution plan buffer (.git/aapp_active_plan)
  active swap        Swap between current and previous active plan
  active clear       Clear active plan buffer (revert to auto-discovery)
  plan-status [id]   Inspect plan matrix or specific blueprint (read-only)
  plan [query]       Display educational planning switchboard
  plan conflict-check <id> <id>… [json]   Can these plans run at the same time? (exit 1 on collision)
  plan conflict-free [<id>|<group>] [json] Plans free to start now, against <id>, or a group's waves
EOF
        ;;
    *)
        echo "❌ Unknown plan command: '$ACTION'" >&2
        echo "   Available: draft, refine, tdd, freeze-start, freeze, start, done, active, plan-status, plan" >&2
        exit 1
        ;;
esac
