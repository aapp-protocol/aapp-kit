#!/usr/bin/env bash
# lib/cmd_commit.sh - Plan-bound commit helper CLI verb (P-39)
# Enforces trailer compliance, records commits in active plan, and commits plan alone.

# Sourced dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$_LIB_DIR/aapp-lib.sh" ] && . "$_LIB_DIR/aapp-lib.sh"
# shellcheck source=/dev/null
[ -f "$_LIB_DIR/attribution.sh" ] && . "$_LIB_DIR/attribution.sh"
# shellcheck source=/dev/null
[ -f "$_LIB_DIR/commit_engine.sh" ] && . "$_LIB_DIR/commit_engine.sh"

# changelog_sync_plan_entry <plan-file> <plan-id> (P-48)
# In `plan` mode (aapp.changelogMode, default) makes CHANGELOG.md carry the plan's
# declared entry exactly once under ## [Unreleased], and stages it with the commit:
# absent -> inserted as the first bullet of its section; worded differently ->
# that one line replaced; current -> untouched. `commit` mode does nothing.
changelog_sync_plan_entry() {
    local plan_file="$1" plan_id="$2" mode decl section text bullet current cl max tmp
    mode="$(git config --get aapp.changelogMode 2>/dev/null)" || mode="plan"
    [ "$mode" = "plan" ] || return 0

    cl="$(git rev-parse --show-toplevel)/CHANGELOG.md"
    if ! decl="$(aapp_plan_changelog_decl "$plan_file")"; then
        echo "ℹ️  [Commit] $plan_id declares no '**Changelog:**' entry; CHANGELOG.md is left to you (declare it with 'aapp refine')."
        return 0
    fi
    if [ ! -f "$cl" ]; then
        echo "ℹ️  [Commit] No CHANGELOG.md at the repository root; $plan_id's entry was not written."
        return 0
    fi
    section="${decl%%|*}"; text="${decl#*|}"
    bullet="$(aapp_render_changelog_bullet "$text" "$plan_id")"
    max="$(git config --int aapp.changelogMaxLen 2>/dev/null)" || max=300
    if [ "${#bullet}" -gt "$max" ]; then
        echo "❌ [Commit Refusal] $plan_id's changelog entry is ${#bullet} characters; the limit is $max." >&2
        return 1
    fi
    if ! grep -q '^## \[Unreleased\]' "$cl"; then
        echo "❌ [Commit Refusal] CHANGELOG.md has no '## [Unreleased]' heading for $plan_id's entry." >&2
        return 1
    fi
    if ! git diff --quiet -- "$cl"; then
        echo "❌ [Commit Refusal] CHANGELOG.md has unstaged edits; stage or discard them first." >&2
        return 1
    fi

    current="$(aapp_changelog_plan_line "$plan_id" < "$cl")" || current=""
    [ "$current" = "$bullet" ] && return 0

    tmp="$cl.aapp-commit.$$"
    AAPP_CL_BULLET="$bullet" AAPP_CL_CURRENT="$current" AAPP_CL_SECTION="### $section" awk '
        BEGIN { bullet = ENVIRON["AAPP_CL_BULLET"]; current = ENVIRON["AAPP_CL_CURRENT"]; heading = ENVIRON["AAPP_CL_SECTION"] }
        /^## / {
            if (in_unrel && !done && current == "") { print heading; print bullet; print ""; done = 1 }
            in_unrel = ($0 ~ /^## \[Unreleased\]/)
            print; next
        }
        in_unrel && !done && current != "" && $0 == current { print bullet; done = 1; next }
        in_unrel && !done && current == "" && $0 == heading { print; print bullet; done = 1; next }
        { print }
        END { if (in_unrel && !done && current == "") { print heading; print bullet } }
    ' "$cl" > "$tmp" || { rm -f "$tmp"; echo "❌ [Commit Refusal] Could not update CHANGELOG.md." >&2; return 1; }
    mv "$tmp" "$cl"
    git add -- "$cl" || return 1
    if [ -n "$current" ]; then
        echo "📜 [Commit] Updated $plan_id's CHANGELOG.md entry to the plan's declaration."
    else
        echo "📜 [Commit] Wrote $plan_id's declared entry to CHANGELOG.md."
    fi
}

cmd_commit() {
    local is_amend=0
    local is_adopt=0
    local commit_msg=""
    local adopt_shas=()
    local agent_override=""
    local vendor_override=""
    local model_override=""
    local note_text=""
    local changelog_text=""
    local amendment_n=""

    while [ $# -gt 0 ]; do
        case "$1" in
            amend)
                is_amend=1
                shift
                ;;
            amendment)
                shift
                amendment_n="${1:-}"
                [ $# -gt 0 ] && shift
                [[ "$amendment_n" =~ ^[0-9]+$ ]] || { echo "❌ [Commit Refusal] 'amendment' needs a request number: aapp commit \"<msg>\" amendment <n>." >&2; return 1; }
                ;;
            adopt)
                is_adopt=1
                shift
                while [ $# -gt 0 ]; do
                    case "$1" in
                        agent|vendor|model|note|changelog) break ;;
                        *) adopt_shas+=("$1"); shift ;;
                    esac
                done
                ;;
            agent)
                shift
                agent_override="${1:-}"
                [ $# -gt 0 ] && shift
                ;;
            vendor)
                shift
                vendor_override="${1:-}"
                [ $# -gt 0 ] && shift
                ;;
            model)
                shift
                model_override="${1:-}"
                [ $# -gt 0 ] && shift
                ;;
            note)
                shift
                note_text="${1:-}"
                [ $# -gt 0 ] && shift
                ;;
            changelog)
                shift
                changelog_text="${1:-}"
                [ $# -gt 0 ] && shift
                ;;
            *)
                if [ "$is_adopt" -eq 1 ]; then
                    adopt_shas+=("$1")
                elif [ -z "$commit_msg" ]; then
                    commit_msg="$1"
                else
                    commit_msg="$commit_msg $1"
                fi
                shift
                ;;
        esac
    done

    # 1. Resolve .plans directory
    local plans_dir=""
    if [ -n "${PLANS_DIR:-}" ] && [ -d "$PLANS_DIR" ]; then
        plans_dir="$PLANS_DIR"
    else
        local git_common primary_root repo_root
        repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
        git_common="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
        if [ -d "$git_common" ]; then
            primary_root="$(cd "$git_common/.." 2>/dev/null && pwd)"
        else
            primary_root="$repo_root"
        fi

        if [ -d "$repo_root/.plans" ]; then
            plans_dir="$repo_root/.plans"
        elif [ -n "$primary_root" ] && [ -d "$primary_root/.plans" ]; then
            plans_dir="$primary_root/.plans"
        elif [ -d ".plans" ]; then
            plans_dir=".plans"
        elif [ -d "../.plans" ]; then
            plans_dir="../.plans"
        fi
    fi

    if [ ! -d "$plans_dir/current" ]; then
        echo "❌ [Commit Refusal] .plans/current directory not found." >&2
        return 1
    fi

    # 2. Plan Resolution
    local plan_file=""
    local plan_id=""
    local buf_path
    buf_path="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || true)"

    if [ -n "$buf_path" ] && [ -f "$buf_path" ]; then
        local bound_id
        bound_id="$(tr -d '[:space:]' < "$buf_path" 2>/dev/null || true)"
        if [ -n "$bound_id" ]; then
            for pf in "$plans_dir"/current/*.md; do
                [ ! -f "$pf" ] && continue
                case "$(basename "$pf")" in 000-*) continue ;; esac
                local pf_id pf_base
                pf_id="$(grep -m 1 -E '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Plan ID:\*\*' "$pf" 2>/dev/null | sed -E 's/^.*\*\*Plan ID:\*\*[[:space:]]*//' | tr -d '[:space:]')"
                pf_base="$(basename "$pf" .md)"
                if [ "$pf_id" = "$bound_id" ] || [ "P-$pf_id" = "$bound_id" ] || \
                   [ "$pf_base" = "$bound_id" ] || [[ "$pf_base" == "$bound_id-"* ]] || \
                   [[ "$pf_base" == "P$bound_id-"* ]] || [[ "$pf_base" == "P-$bound_id-"* ]]; then
                    plan_file="$pf"
                    plan_id="${pf_id:-$bound_id}"
                    break
                fi
            done
        fi
    fi

    # Auto-discover if no buffer
    if [ -z "$plan_file" ]; then
        local dev_plans=() held_plans
        # P-52: a plan held by another worktree's buffer is not adopted here.
        held_plans="$(aapp_held_plans)"
        for pf in "$plans_dir"/current/*.md; do
            [ ! -f "$pf" ] && continue
            case "$(basename "$pf")" in 000-*) continue ;; esac
            if plan_status_is "$pf" in-development; then
                aapp_plan_held_by "$pf" "$held_plans" >/dev/null && continue
                dev_plans+=("$pf")
            fi
        done

        if [ ${#dev_plans[@]} -eq 1 ]; then
            plan_file="${dev_plans[0]}"
            plan_id="$(grep -m 1 -E '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Plan ID:\*\*' "$plan_file" 2>/dev/null | sed -E 's/^.*\*\*Plan ID:\*\*[[:space:]]*//' | tr -d '[:space:]')"
            [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md | cut -d'-' -f1)"
        elif [ ${#dev_plans[@]} -eq 0 ]; then
            echo "❌ [Commit Refusal] No plan is currently ⚡ In Development." >&2
            echo "   Run 'aapp start <id>' or 'aapp active <id>' to begin." >&2
            return 1
        else
            echo "❌ [Commit Refusal] Multiple plans are currently ⚡ In Development:" >&2
            for dp in "${dev_plans[@]}"; do
                echo "   • $(basename "$dp" .md)" >&2
            done
            echo "   Run 'aapp active <id>' to designate the active commit context." >&2
            return 1
        fi
    fi

    # Verify plan status is ⚡ In Development
    if ! plan_status_is "$plan_file" in-development; then
        echo "❌ [Commit Refusal] Plan '$(basename "$plan_file")' is not $(plan_status_render in-development)." >&2
        return 1
    fi

    # Verify plan is not bound in another worktree
    local holding_wt
    holding_wt="$(find_worktree_holding_plan "$plan_id")" || true
    if [ -n "$holding_wt" ]; then
        echo "❌ [Commit Refusal] Plan '$plan_id' is already bound in worktree '$holding_wt'." >&2
        return 1
    fi

    # P-129: an approved amendment request's one commit, by its requester.
    if [ -n "$amendment_n" ]; then
        if [ "$is_amend" -eq 1 ] || [ "$is_adopt" -eq 1 ] || [ -n "$changelog_text" ]; then
            echo "❌ [Commit Refusal] 'amendment' takes a message and the attribution tokens only; not 'amend', 'adopt' or 'changelog'." >&2
            return 1
        fi
        _commit_amendment "$plan_file" "$plan_id" "$amendment_n" "$commit_msg" "$agent_override" "$vendor_override" "$model_override" "$note_text"
        return
    fi

    # P-51: in atomic mode a plan is one commit; further changes fold in with
    # `aapp commit amend`.
    if [ "$is_amend" -eq 0 ] && [ "$is_adopt" -eq 0 ] && [ "$(aapp_plan_commit_mode "$plan_file")" = "atomic" ]; then
        local first_recorded
        first_recorded="$(parse_plan_commits "$plan_file" | head -n 1 | awk '{print $1}')"
        if [ -n "$first_recorded" ]; then
            echo "❌ [Commit Refusal] aapp.commitMode=atomic: $plan_id already has commit $first_recorded. Fold changes in with 'aapp commit amend', or set aapp.commitMode=microcommits." >&2
            return 1
        fi
    fi

    # P-66: an issue fix (`#<n>`) writes its own changelog entry at its first
    # commit, once the change is known; a plan declares its entry in its header.
    if [ "${plan_id#\#}" = "$plan_id" ]; then
        if [ -n "$changelog_text" ]; then
            echo "❌ [Commit Refusal] 'changelog' is for issue fixes; $plan_id declares its entry in its '* **Changelog:**' line ('aapp refine')." >&2
            return 1
        fi
    elif aapp_plan_changelog_decl "$plan_file" >/dev/null; then
        # A fix with no commit yet takes the token again: its first commit was refused.
        if [ -n "$changelog_text" ] && [ -z "$(parse_plan_commits "$plan_file")" ]; then
            write_plan_field "$plan_file" Changelog "Fixed: $changelog_text" || return 1
        elif [ -n "$changelog_text" ]; then
            echo "❌ [Commit Refusal] $plan_id already has its changelog entry; reword its '* **Changelog:**' line with 'aapp refine'." >&2
            return 1
        fi
    elif [ -n "$changelog_text" ]; then
        write_plan_field "$plan_file" Changelog "Fixed: $changelog_text" || return 1
    elif [ "$is_adopt" -eq 0 ]; then
        echo "❌ [Commit Refusal] $plan_id has no changelog entry yet; say what the fix changed:" >&2
        echo "   aapp commit \"${commit_msg:-<msg>}\" changelog \"<what the fix changed>\"" >&2
        return 1
    fi

    # 3. Attribution Identity Resolution
    local identity="" agent_name="" agent_vendor="" agent_model=""
    if declare -f resolve_ai_identity >/dev/null; then
        identity="$(resolve_ai_identity "$agent_override" "$vendor_override" "$model_override")"
        if [ -n "$identity" ]; then
            agent_name="$(echo "$identity" | grep -m1 '^AI-Agent:' | sed 's/^AI-Agent:[[:space:]]*//')"
            agent_vendor="$(echo "$identity" | grep -m1 '^AI-Vendor:' | sed 's/^AI-Vendor:[[:space:]]*//')"
            agent_model="$(echo "$identity" | grep -m1 '^AI-Model:' | sed 's/^AI-Model:[[:space:]]*//')"
        fi
    fi

    local attr_mode
    attr_mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"
    if [ "$attr_mode" = "strict" ] && [ -z "$identity" ]; then
        echo "❌ [Commit Refusal] Strict attribution mode requires valid AI identity." >&2
        echo "   Pass 'agent <A> vendor <V> model <M>' or set AAPP_AGENT_* environment variables." >&2
        return 1
    fi

    # 4. Handle adopt mode
    if [ "$is_adopt" -eq 1 ]; then
        if [ ${#adopt_shas[@]} -eq 0 ]; then
            echo "❌ [Adopt Refusal] Please specify at least one commit SHA to adopt." >&2
            return 1
        fi

        echo "⚠️  [Adopt Warning] Adopted commits did not pass through aapp commit helper; attribution was not completed." >&2

        local current_br
        current_br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
        [ "$current_br" = "HEAD" ] && current_br="detached"

        local existing_commits
        existing_commits="$(parse_plan_commits "$plan_file")"

        local added_any=0
        for s in "${adopt_shas[@]}"; do
            # Verify SHA exists
            if ! git cat-file -e "$s^{commit}" 2>/dev/null; then
                echo "❌ [Adopt Refusal] Unknown or invalid commit object: '$s'." >&2
                return 1
            fi

            # Find containing branch
            local containing_branches
            containing_branches="$(git for-each-ref --format='%(refname:short)' --contains "$s" refs/heads refs/remotes 2>/dev/null)"
            if [ -z "$containing_branches" ]; then
                echo "❌ [Adopt Refusal] Commit '$s' is not contained in any branch or ref." >&2
                return 1
            fi

            local target_br="$current_br"
            if ! echo "$containing_branches" | grep -qFx "$current_br"; then
                target_br="$(echo "$containing_branches" | head -1)"
            fi

            local short_s
            short_s="$(git rev-parse --short "$s")"

            # Check if already recorded
            if echo "$existing_commits" | grep -q "^$short_s "; then
                continue
            fi

            # Append to plan header
            local curr_line
            curr_line="$(grep -m 1 -E '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Commits:\*\*' "$plan_file" 2>/dev/null | sed -E 's/^.*\*\*Commits:\*\*[[:space:]]*//' || true)"
            local new_token="\`$short_s\` ($target_br)"
            if [ -z "$curr_line" ] || [ "$curr_line" = "none" ]; then
                write_plan_commits "$plan_file" "$new_token"
            else
                write_plan_commits "$plan_file" "$curr_line, $new_token"
            fi
            existing_commits="$(parse_plan_commits "$plan_file")"
            added_any=$((added_any + 1))
        done

        if [ "$added_any" -gt 0 ]; then
            local plan_rel="current/$(basename "$plan_file")"
            AAPP_AGENT_NAME="$agent_name" AAPP_AGENT_VENDOR="$agent_vendor" AAPP_AGENT_MODEL="$agent_model" \
            plans_commit "plan(record): adopt $added_any commit(s) for $plan_id" "$plan_rel" || {
                local p_rc=$?
                echo "❌ [Plan Commit Failure] Failed to commit plan record in .plans worktree." >&2
                return "$p_rc"
            }
        fi
        return 0
    fi

    # 5. Handle amend mode vs standard commit
    local old_head_sha=""

    if [ "$is_amend" -eq 1 ]; then
        old_head_sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
        if [ -z "$commit_msg" ]; then
            # Read existing commit message
            commit_msg="$(git log -1 --format=%B 2>/dev/null || true)"
        fi
    else
        # Standard commit requires staged changes
        if git diff --cached --quiet; then
            echo "❌ [Commit Refusal] Nothing staged to commit." >&2
            return 1
        fi
        if [ -z "$commit_msg" ]; then
            echo "❌ [Commit Refusal] Commit message cannot be empty." >&2
            return 1
        fi
    fi

    # P-48: the plan's declared CHANGELOG.md entry rides along with the commit.
    changelog_sync_plan_entry "$plan_file" "$plan_id" || return 1

    # Decorate commit message per attribution mode using temp file
    local tmp_msg
    tmp_msg="$(mktemp)"
    printf "%s\n" "$commit_msg" > "$tmp_msg"

    if declare -f attribution_decorate >/dev/null; then
        attribution_decorate "$tmp_msg" "$identity" || {
            local dec_rc=$?
            rm -f "$tmp_msg"
            echo "❌ [Commit Refusal] Attribution decoration failed." >&2
            return "$dec_rc"
        }
    fi

    # P-101: an amendments member's commits land on the feature branch one by
    # one; each carries its plan, as a squashed plan's commit does.
    if [ "$(parse_plan_field "$plan_file" Kind)" = "amendments" ] && ! grep -qx "Plan-ID: $plan_id" "$tmp_msg"; then
        git interpret-trailers --in-place --trailer "Plan-ID: $plan_id" "$tmp_msg" || {
            rm -f "$tmp_msg"; echo "❌ [Commit Refusal] Could not add the Plan-ID trailer." >&2; return 1; }
    fi

    # 6. Execute Code Commit
    local code_rc=0
    if [ "$is_amend" -eq 1 ]; then
        AAPP_COMMIT_HELPER=1 git commit --amend -F "$tmp_msg"
        code_rc=$?
    else
        AAPP_COMMIT_HELPER=1 git commit -F "$tmp_msg"
        code_rc=$?
    fi
    rm -f "$tmp_msg"

    if [ "$code_rc" -ne 0 ]; then
        return "$code_rc"
    fi

    local new_sha
    new_sha="$(git rev-parse --short HEAD)"
    local curr_br
    curr_br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
    [ "$curr_br" = "HEAD" ] && curr_br="detached"

    # Attach note if note_text is provided, or if AI notes are enabled with an identity
    local ai_notes_enabled
    ai_notes_enabled="$(git config aapp.aiNotes 2>/dev/null || echo "false")"
    if [ -n "$note_text" ] || { [ -n "$identity" ] && { [ "$attr_mode" = "notes" ] || [ "$ai_notes_enabled" = "true" ]; }; }; then
        if declare -f attribution_note >/dev/null; then
            attribution_note "$new_sha" "$identity" "$note_text" || {
                local note_rc=$?
                echo "❌ [Commit Refusal] Note attachment failed." >&2
                return "$note_rc"
            }
        fi
    fi

    # 7. Record in Plan Header
    local curr_line
    curr_line="$(grep -m 1 -E '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Commits:\*\*' "$plan_file" 2>/dev/null | sed -E 's/^.*\*\*Commits:\*\*[[:space:]]*//' || true)"

    if [ "$is_amend" -eq 1 ] && [ -n "$old_head_sha" ] && [ -n "$curr_line" ] && [ "$curr_line" != "none" ]; then
        # Replace old SHA with new SHA in header
        local updated_line
        updated_line="$(echo "$curr_line" | sed -E "s|\`$old_head_sha\`[[:space:]]*\([^)]+\)|\`$new_sha\` ($curr_br)|g")"
        if [ "$updated_line" = "$curr_line" ]; then
            # Old SHA wasn't recorded, append new SHA
            updated_line="$curr_line, \`$new_sha\` ($curr_br)"
        fi
        write_plan_commits "$plan_file" "$updated_line"
    else
        local new_token="\`$new_sha\` ($curr_br)"
        if [ -z "$curr_line" ] || [ "$curr_line" = "none" ]; then
            write_plan_commits "$plan_file" "$new_token"
        else
            write_plan_commits "$plan_file" "$curr_line, $new_token"
        fi
    fi

    # P-51: record the modes this commit was made under.
    aapp_plan_stamp_modes "$plan_file" "$new_sha" || echo "⚠️  [Commit] Could not record the commit and changelog modes in $plan_id." >&2

    # 8. Commit Plan File Alone via plans_commit
    local plan_rel="current/$(basename "$plan_file")"
    AAPP_AGENT_NAME="$agent_name" AAPP_AGENT_VENDOR="$agent_vendor" AAPP_AGENT_MODEL="$agent_model" \
    plans_commit "plan(record): record $new_sha for $plan_id" "$plan_rel"
    local plan_commit_rc=$?

    if [ "$plan_commit_rc" -ne 0 ]; then
        echo "" >&2
        echo "❌ [Plan Commit Failure] Code commit $new_sha succeeded, but plan recording failed." >&2
        echo "   Repair with: aapp commit adopt $new_sha" >&2
        return "$plan_commit_rc"
    fi

    # Dispatch post-commit observer lifecycle event
    local hook_lib="$_LIB_DIR/hook_dispatcher.sh"
    if [ -f "$hook_lib" ]; then
        # shellcheck source=/dev/null
        source "$hook_lib"
        local wt_p
        wt_p="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
        local commit_data="{\"command\": \"commit\", \"event\": \"record\", \"plan_id\": \"$plan_id\", \"commit_sha\": \"$new_sha\", \"subject\": \"$(json_escape "$commit_msg")\", \"worktree\": \"$(json_escape "$wt_p")\", \"agent\": \"$(json_escape "$agent_name")\", \"vendor\": \"$(json_escape "$agent_vendor")\", \"model\": \"$(json_escape "$agent_model")\"}"
        dispatch_hook "post-commit" "$commit_data" || true
    fi
    return 0
}

# _commit_amendment <plan_file> <plan_id> <n> <msg> <agent> <vendor> <model> <note>
# (P-129): the one commit of approved request R<n>, made by its requester (the
# active plan), holding R<n>'s file only (and CHANGELOG.md when the requester owns
# it), with the trailer `Amendment: R<n>`; not recorded in the plan's Commits. A
# request the requester owns becomes `committed`; one another plan owns lands at
# once on the requester's parent branch (_commit_amendment_land).
_commit_amendment() {
    local pf="$1" pid="$2" n="$3" msg="$4" ao="$5" vo="$6" mo="$7" note="$8"
    local af l p owner state f extra="" parent="" tip="" identity="" attr_mode tmp_msg sha
    # shellcheck source=/dev/null
    AAPP_PLAN_LIB_ONLY=1 . "$_LIB_DIR/cmd_plan.sh" || return 1
    if [ -z "$msg" ]; then
        echo "❌ [Commit Refusal] Commit message cannot be empty." >&2; return 1
    fi
    if ! af="$(amend_member_of "$pf")"; then
        echo "❌ [Commit Refusal] $pid is in no group with an amendments member; there is no request R$n." >&2; return 1
    fi
    if ! l="$(amend_request_line "$af" "$n")"; then
        echo "❌ [Commit Refusal] $(parse_plan_field "$af" "Plan ID") has no request R$n." >&2; return 1
    fi
    p="$(amend_request_path "$l")"; state="$(amend_request_state "$l")"; owner="$(amend_request_owner "$l")"
    if [ -z "$p" ]; then
        echo "❌ [Commit Refusal] R$n names no file; a correction of the group's text is applied with 'decision'." >&2; return 1
    fi
    if [ "$(amend_request_requester "$l")" != "$pid" ]; then
        echo "❌ [Commit Refusal] R$n was requested by $(amend_request_requester "$l"); only its requester makes its commit." >&2; return 1
    fi
    case "$state" in
        approved*) ;;
        committed|"landed "*|closed*) echo "❌ [Commit Refusal] R$n already has its commit ($state); a further change to \`$p\` is a new request." >&2; return 1 ;;
        *) echo "❌ [Commit Refusal] R$n is not approved ($state)." >&2; return 1 ;;
    esac
    if git diff --cached --quiet -- "$p"; then
        echo "❌ [Commit Refusal] Stage R$n's file first: git add $p" >&2; return 1
    fi
    while IFS= read -r f; do
        [ "$f" = "$p" ] && continue
        [ "$owner" = "$pid" ] && [ "$f" = "CHANGELOG.md" ] && continue
        extra="$extra $f"
    done < <(git diff --cached --name-only)
    if [ -n "$extra" ]; then
        echo "❌ [Commit Refusal] R$n's commit holds \`$p\` only; also staged:$extra" >&2; return 1
    fi
    if [ "$owner" != "$pid" ]; then
        parent="$(plan_base_branch "$pf")"
        if [ -z "$parent" ] || ! git show-ref --verify --quiet "refs/heads/$parent"; then
            echo "❌ [Commit Refusal] $pid has no parent branch to land R$n on (its * **Base:**)." >&2; return 1
        fi
        tip="$(git rev-parse "refs/heads/$parent")"
        if [ "$(git rev-parse -q --verify "$tip:$p" 2>/dev/null)" != "$(git rev-parse -q --verify "HEAD:$p" 2>/dev/null)" ]; then
            echo "❌ [Commit Refusal] \`$p\` changed on $parent since this branch took it; rebase onto $parent first: git rebase --autostash $parent" >&2
            return 1
        fi
    else
        changelog_sync_plan_entry "$pf" "$pid" || return 1
    fi

    if declare -f resolve_ai_identity >/dev/null; then identity="$(resolve_ai_identity "$ao" "$vo" "$mo")"; fi
    attr_mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"
    if [ "$attr_mode" = "strict" ] && [ -z "$identity" ]; then
        echo "❌ [Commit Refusal] Strict attribution mode requires valid AI identity." >&2; return 1
    fi
    tmp_msg="$(mktemp)" || return 1
    printf '%s\n' "$msg" > "$tmp_msg"
    if declare -f attribution_decorate >/dev/null && ! attribution_decorate "$tmp_msg" "$identity"; then
        rm -f "$tmp_msg"; echo "❌ [Commit Refusal] Attribution decoration failed." >&2; return 1
    fi
    if ! git interpret-trailers --in-place --trailer "Amendment: R$n" "$tmp_msg"; then
        rm -f "$tmp_msg"; echo "❌ [Commit Refusal] Could not add the Amendment trailer." >&2; return 1
    fi
    if ! AAPP_COMMIT_HELPER=1 AAPP_AMENDMENT_OWNER="$owner" git commit -F "$tmp_msg"; then
        rm -f "$tmp_msg"; return 1
    fi
    rm -f "$tmp_msg"
    sha="$(git rev-parse --short HEAD)"
    if [ -n "$note" ] || { [ -n "$identity" ] && { [ "$attr_mode" = "notes" ] || [ "$(git config aapp.aiNotes 2>/dev/null)" = "true" ]; }; }; then
        if declare -f attribution_note >/dev/null && ! attribution_note "$sha" "$identity" "$note"; then
            echo "❌ [Commit Refusal] Note attachment failed for $sha." >&2; return 1
        fi
    fi

    if [ "$owner" = "$pid" ]; then
        amend_request_set_state "$af" "$n" "committed"
        plans_commit "plan(record): R$n committed for $pid" "current/$(basename "$af")" || {
            echo "❌ [Plan Commit Failure] R$n's commit $sha is made, but the request was not marked; its 'done' still finds it by the trailer." >&2; return 1; }
        echo "🧩 [Amendment] R$n committed ($sha) on $(git rev-parse --abbrev-ref HEAD); $pid's 'done' records it in its plan."
        return 0
    fi
    _commit_amendment_land "$pf" "$pid" "$af" "$l" "$n" "$p" "$owner" "$parent"
}

# _commit_amendment_land <plan_file> <plan_id> <amend_file> <line> <n> <path> <owner>
# <parent>: lands R<n>'s commit (HEAD) on the parent branch under the lock
# `integrate/<parent>`: the same change (<path> only, same message and author) on
# the parent's tip, which moves to it (a worktree holding the parent fast-forwards;
# otherwise the ref moves only from the tip it was read at). Then the request and
# the owner's record in one plans commit, and the requester's rebase onto the
# parent, which drops its own copy. A failed landing undoes the local commit (the
# change stays staged) and lands nothing.
_commit_amendment_land() {
    local pf="$1" pid="$2" af="$3" l="$4" n="$5" p="$6" owner="$7" parent="$8"
    local tip idx entry tree new short sign="" holder of today ref old wt
    old="$(git rev-parse HEAD)"
    _amend_undo() { git reset -q --soft HEAD~1; echo "   Nothing landed; R$n's change is staged again." >&2; }
    aapp_lock_acquire "integrate/$parent" "" "Parent branch '$parent'" || { _amend_undo; return 1; }
    tip="$(git rev-parse "refs/heads/$parent")"
    if [ "$(git rev-parse -q --verify "$tip:$p" 2>/dev/null)" != "$(git rev-parse -q --verify "HEAD~1:$p" 2>/dev/null)" ]; then
        aapp_lock_release "integrate/$parent"
        echo "❌ [Commit Refusal] \`$p\` changed on $parent meanwhile; rebase onto $parent first: git rebase --autostash $parent" >&2
        _amend_undo; return 1
    fi
    idx="$(mktemp)" || { aapp_lock_release "integrate/$parent"; _amend_undo; return 1; }
    entry="$(git ls-tree HEAD -- "$p")"
    if ! GIT_INDEX_FILE="$idx" git read-tree "$tip" || \
       { [ -n "$entry" ] && ! GIT_INDEX_FILE="$idx" git update-index --add --cacheinfo "$(printf '%s' "$entry" | awk '{ print $1 "," $3 }'),$p"; } || \
       { [ -z "$entry" ] && ! GIT_INDEX_FILE="$idx" git update-index --force-remove -- "$p"; } || \
       ! tree="$(GIT_INDEX_FILE="$idx" git write-tree)"; then
        rm -f "$idx"; aapp_lock_release "integrate/$parent"
        echo "❌ [Commit Refusal] Could not build R$n's commit on $parent." >&2; _amend_undo; return 1
    fi
    rm -f "$idx"
    [ "$(git config --type=bool --get commit.gpgsign 2>/dev/null)" = "true" ] && sign="-S"
    if ! new="$(git log -1 --format=%B HEAD | GIT_AUTHOR_NAME="$(git log -1 --format=%an HEAD)" \
        GIT_AUTHOR_EMAIL="$(git log -1 --format=%ae HEAD)" GIT_AUTHOR_DATE="$(git log -1 --format=%aD HEAD)" \
        git commit-tree $sign "$tree" -p "$tip")"; then
        aapp_lock_release "integrate/$parent"
        echo "❌ [Commit Refusal] Could not make R$n's commit on $parent." >&2; _amend_undo; return 1
    fi
    holder="$(git worktree list --porcelain | awk -v b="refs/heads/$parent" '/^worktree / { w = substr($0, 10) } $1 == "branch" && $2 == b { print w; exit }')"
    if [ -n "$holder" ]; then
        if [ "$(git -C "$holder" rev-parse HEAD)" != "$tip" ] || ! git -C "$holder" merge -q --ff-only "$new" >/dev/null 2>&1; then
            aapp_lock_release "integrate/$parent"
            echo "❌ [Commit Refusal] $parent could not be fast-forwarded in $holder (moved, or changed there)." >&2; _amend_undo; return 1
        fi
    elif ! git update-ref "refs/heads/$parent" "$new" "$tip" 2>/dev/null; then
        aapp_lock_release "integrate/$parent"
        echo "❌ [Commit Refusal] $parent moved during the landing; nothing landed." >&2; _amend_undo; return 1
    fi
    aapp_lock_release "integrate/$parent"
    short="$(git rev-parse --short "$new")"
    for ref in ai commits; do
        if git notes --ref="$ref" show "$old" >/dev/null 2>&1; then git notes --ref="$ref" copy "$old" "$new" >/dev/null 2>&1 || echo "⚠️  [Amendment] Could not copy the refs/notes/$ref note to $short." >&2; fi
    done
    echo "🔀 [Amendment] R$n landed on $parent ($short)."

    # The request and the owner's record, in one plans commit.
    of="$(ls "$PLANS_DIR"/current/P"${owner#P-}"-*.md 2>/dev/null | head -n 1)"
    [ -n "$of" ] || of="$(ls "$PLANS_DIR"/done/P"${owner#P-}"-*.md 2>/dev/null | head -n 1)"
    today="$(date +%Y-%m-%d)"
    amend_request_set_state "$af" "$n" "landed \`$short\`"
    if [ -z "$of" ] || ! amend_record_in_owner "$of" "$n" "$p" "$(amend_request_summary "$l")" "$pid" "$short" "$today" || \
       ! plans_commit "plan(record): land R$n $short for $owner" "current/$(basename "$af")" "${of#"$PLANS_DIR"/}"; then
        echo "❌ [Plan Commit Failure] R$n landed ($short) on $parent, but its record in $(parse_plan_field "$af" "Plan ID") and $owner was not committed; check 'git -C .plans status'." >&2
        return 1
    fi

    # The requester takes the parent: its own copy of the change is dropped.
    wt="$(git rev-parse --show-toplevel)"
    if ! git -C "$wt" rebase -q --autostash "$parent" >/dev/null 2>&1; then
        echo "❌ [Amendment] R$n landed, but the rebase of $pid onto $parent stopped; resolve it in $wt and 'git rebase --continue'." >&2
        return 1
    fi
    _land_name_members "$af" "$parent"
    if [ -f "$_LIB_DIR/hook_dispatcher.sh" ]; then
        # shellcheck source=/dev/null
        source "$_LIB_DIR/hook_dispatcher.sh"
        local land_data="{\"command\": \"commit\", \"event\": \"land\", \"group_id\": \"$(parse_plan_field "$af" Group)\", \"amendment_id\": \"$(parse_plan_field "$af" "Plan ID")\", \"feature_branch\": \"$parent\", \"commit_sha\": \"$short\"}"
        dispatch_hook "post-land" "$land_data" || true
    fi
    echo "   $pid is rebased onto $parent; $owner records R$n."
}

# _land_name_members <plan_file> <feature-branch>: the members in development
# whose branch lacks the new tip; they rebase.
_land_name_members() {
    local m mf
    for m in $(amend_must_rebase "$1"); do
        mf="$(resolve_plan_file "$m" "commit" 2>/dev/null)" || continue
        echo "   $m must rebase: git -C $(parse_plan_worktree "$mf" | cut -f1) rebase --autostash $2"
    done
}
