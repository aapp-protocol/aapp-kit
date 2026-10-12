#!/usr/bin/env bash
# ==============================================================================
# AAPP Adoption Advisories & Setup Checklist (Plan P-63)
#
# Rules catalogue, synchronization engine, and open-task counter for
# .plans/adoption.md (local, untracked per-clone setup guide).
# ==============================================================================

# Returns all unique manual headings referenced in the adoption rules catalogue.
get_all_adoption_manual_headings() {
    cat <<'EOF'
Adaptive Branch Protection & Repository Topologies
Remote Sync & Worktree Transport
Plan IDs & Sequence Counters
Repository Settings Matrix
Project Files & Protocol Upgrade
Project Rules & Customizations
Codebase Mapping & Architecture
Template Synchronization & Drift
Issue IDs & Lifecycle
Delimited Template Synchronization
Claude Code Write-Time Interception (Layer 1)
Foreign Hook Managers & Framework Integration
Test Gates & Pre-Done Verification
Monorepo & Build Tool Isolation
EOF
}

# Returns the number of open (- [ ]) tasks in .plans/adoption.md.
adoption_open_count() {
    local target="${1:-}"
    local f
    if [ -z "$target" ]; then
        f="${PLANS_DIR:-.plans}/adoption.md"
        [ -f "$f" ] || f=".plans/adoption.md"
    elif [ -d "$target" ]; then
        f="$target/adoption.md"
    else
        f="$target"
    fi

    [ -f "$f" ] || { echo 0; return 0; }
    local count
    count="$(grep -cE '^- \[ \] `\[' "$f" 2>/dev/null || true)"
    echo "${count:-0}"
}

# Helper: resolve the first path segment of aapp.planWorktreePath
# Returns empty string if path leaves repository or is absolute.
_adoption_wt_dir() {
    local wt_cfg
    wt_cfg="$(git config --get aapp.planWorktreePath 2>/dev/null || echo ".workspace")"
    [ -z "$wt_cfg" ] && wt_cfg=".workspace"
    if [[ "$wt_cfg" = /* ]] || [[ "$wt_cfg" == ../* ]] || [[ "$wt_cfg" == ".." ]]; then
        echo ""
        return 0
    fi
    local first_seg="${wt_cfg%%/*}"
    echo "$first_seg"
}

# Appends or inserts a task line under the appropriate markdown section.
_adoption_insert_task() {
    local file="$1"
    local sec_title="$2"
    local task_line="$3"

    local tmp
    tmp="$(mktemp)"

    awk -v sec="$sec_title" -v task="$task_line" '
        BEGIN {
            in_target = 0
            inserted = 0
            found_target = 0
        }
        /^## / {
            if (in_target && !inserted) {
                print task
                inserted = 1
                in_target = 0
            }
            if ($0 ~ ("^##[[:space:]]+" sec "$")) {
                found_target = 1
                in_target = 1
            }
        }
        {
            print
        }
        END {
            if (in_target && !inserted) {
                print task
                inserted = 1
            }
            if (!found_target && !inserted) {
                print ""
                print "## " sec
                print task
            }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

# Synchronize the adoption checklist in .plans/adoption.md
sync_adoption_checklist() {
    local root="${1:-${REPO_ROOT:-$(pwd)}}"
    local plans_dir="${2:-$root/.plans}"
    local adoption_file="$plans_dir/adoption.md"

    # Ensure adoption.md exists
    if [ ! -f "$adoption_file" ]; then
        local starter="${AAPP_TEMPLATES:-$root/templates}/adoption.md"
        if [ -f "$starter" ]; then
            cp "$starter" "$adoption_file"
        else
            cat > "$adoption_file" <<'EOF'
# 📋 Adoption Checklist

> Your setup guide. `aapp init` adds tasks and ticks the ones it can verify; tick a task yourself when it is done or does not apply.

## 🌿 Branches & Remote

## 👥 Team

## 📁 Project Files

## 🛡️ Hooks & Gates

## 🛠️ Build Tools

## ⚙️ Settings to Review
EOF
        fi
    fi

    local wt_dir
    wt_dir="$(_adoption_wt_dir)"

    # Rule definitions: tag | section | manual_heading | trigger_fn | check_fn | text
    # Checks returning 0 pass. Trigger returning 0 means triggered.
    # Review tasks have check_fn="none".

    local tmp_file
    tmp_file="$(mktemp)"
    cp "$adoption_file" "$tmp_file"

    local -a RULES=(
        # 🌿 Branches & Remote
        "DEV-BRANCH|🌿 Branches & Remote|Adaptive Branch Protection & Repository Topologies|_trig_dev_branch|_chk_dev_branch|Name your development branch: \`git config aapp.devBranch <name>\`. Tick it when the kit's defaults (develop dev development) are yours or you work on one branch."
        "STABLE-BRANCH|🌿 Branches & Remote|Adaptive Branch Protection & Repository Topologies|_trig_stable_branch|_chk_stable_branch|Name your protected branches: \`git config aapp.protectedBranches <names>\`."
        "REMOTE|🌿 Branches & Remote|Remote Sync & Worktree Transport|_trig_remote|_chk_remote|Add a remote or set \`aapp.remote\`: \`git remote add <name> <url>\` or \`git config aapp.remote <name>\`."
        "FIRST-PUSH|🌿 Branches & Remote|Remote Sync & Worktree Transport|_trig_first_push|_chk_first_push|Run \`aapp push\`, so teammates can get the plans, rules and hooks."

        # 👥 Team
        "PLAN-ID-PROVIDER|👥 Team|Plan IDs & Sequence Counters|_trig_always|_chk_plan_id_provider|More than one contributor needs an aapp-planid provider, or two people allocate the same Plan ID; tick it when you work alone."
        "TEAM-SETTINGS|👥 Team|Repository Settings Matrix|_trig_always|none|Settings are local to this clone: agree the project's values and set them on every clone (#126)."

        # 📁 Project Files
        "INIT-FILES|📁 Project Files|Project Files & Protocol Upgrade|_trig_init_files|_chk_init_files|Commit the files init wrote on the code branch; plan worktrees are cut from it."
        "PROJECT-RULES|📁 Project Files|Project Rules & Customizations|_trig_project_rules|_chk_project_rules|Fill the project rules, or run \`/aapp-digest Onboarding\`."
        "PROJECT-MAP|📁 Project Files|Codebase Mapping & Architecture|_trig_project_map|_chk_project_map|Map the codebase, or run \`/aapp-digest Onboarding\`."
        "TEMPLATE-DRIFT|📁 Project Files|Template Synchronization & Drift|_trig_template_drift|_chk_template_drift|Merge each *.new file into its original and delete it."
        "ISSUES-SCHEMA|📁 Project Files|Issue IDs & Lifecycle|_trig_issues_schema|_chk_issues_schema|Adapt the file to the flat issue ledger."
        "PROTOCOL-BLOCK|📁 Project Files|Delimited Template Synchronization|_trig_protocol_block|_chk_protocol_block|Close the marker so the block syncs again."

        # 🛡️ Hooks & Gates
        "WRITE-GUARD|🛡️ Hooks & Gates|Claude Code Write-Time Interception (Layer 1)|_trig_write_guard|_chk_write_guard|Install python3 and re-run aapp init, or add the guard hook by hand."
        "HOOK-WIRING|🛡️ Hooks & Gates|Foreign Hook Managers & Framework Integration|_trig_hook_wiring|_chk_hook_wiring|Call \`.githooks/aapp-pre-commit\` from your pre-commit hook."
        "GATE-TEST|🛡️ Hooks & Gates|Test Gates & Pre-Done Verification|_trig_always|_chk_gate_test|Register a pre-done test gate from examples/hooks/test-gate.sh.sample with aapp hook-hash; tick it when you do not want one."

        # 🛠️ Build Tools
        "MONO-NX|🛠️ Build Tools|Monorepo & Build Tool Isolation|_trig_mono_nx|_chk_mono_nx|Add /${wt_dir:-.workspace} to .nxignore."
        "MONO-BAZEL|🛠️ Build Tools|Monorepo & Build Tool Isolation|_trig_mono_bazel|_chk_mono_bazel|Add ${wt_dir:-.workspace} to .bazelignore."

        # ⚙️ Settings to Review
        "SET-WORKTREES|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|One worktree and branch per plan? Group plans need on: \`git config aapp.planWorktrees <on|off>\`."
        "SET-INTEGRATE|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|How done integrates a plan branch: \`git config aapp.integrate <manual|squash|ff|hook>\`."
        "SET-COMMIT-MODE|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|One commit per plan or many: \`git config aapp.commitMode <atomic|microcommits>\`, \`git config aapp.changelogMode <plan|commit>\`."
        "SET-ATTRIBUTION|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|Record which agent wrote a commit: \`git config aapp.aiAttribution <none|lax|strict|notes>\`."
    )

    # --------------------------------------------------------------------------
    # Trigger and Check Helper Implementations
    # --------------------------------------------------------------------------
    _trig_always() { return 0; }

    _trig_dev_branch() {
        [ -z "$(git config --get aapp.devBranch 2>/dev/null || true)" ]
    }
    _chk_dev_branch() {
        [ -n "$(git config --get aapp.devBranch 2>/dev/null || true)" ]
    }

    _trig_stable_branch() {
        local prot
        prot="$(git config --get aapp.protectedBranches 2>/dev/null || true)"
        if [ -z "$prot" ]; then
            local def_br
            def_br="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
            def_br="${def_br#origin/}"
            [ -z "$def_br" ] && def_br="$(git branch --show-current 2>/dev/null || true)"
            [ -z "$def_br" ] && def_br="main"
            case "$def_br" in
                main|master|production) return 1 ;;
                *) return 0 ;;
            esac
        fi
        return 1
    }
    _chk_stable_branch() {
        [ -n "$(git config --get aapp.protectedBranches 2>/dev/null || true)" ]
    }

    _trig_remote() {
        local rmt
        rmt="$(git config --get aapp.remote 2>/dev/null || echo "origin")"
        if ! git remote 2>/dev/null | grep -qxF "$rmt"; then
            return 0
        fi
        return 1
    }
    _chk_remote() {
        local rmt
        rmt="$(git config --get aapp.remote 2>/dev/null || echo "origin")"
        git remote 2>/dev/null | grep -qxF "$rmt"
    }

    _trig_first_push() {
        # Remote must exist
        _chk_remote || return 1
        # Trigger holds if any branch in aapp.syncWorktrees is not on remote
        local rmt
        rmt="$(git config --get aapp.remote 2>/dev/null || echo "origin")"
        local sync_wts
        sync_wts="$(git config --get aapp.syncWorktrees 2>/dev/null || echo "plans agents githooks")"
        for br in $sync_wts; do
            if ! git rev-parse --verify --quiet "refs/remotes/$rmt/$br" >/dev/null 2>&1; then
                return 0
            fi
        done
        return 1
    }
    _chk_first_push() {
        _chk_remote || return 1
        local rmt
        rmt="$(git config --get aapp.remote 2>/dev/null || echo "origin")"
        local sync_wts
        sync_wts="$(git config --get aapp.syncWorktrees 2>/dev/null || echo "plans agents githooks")"
        for br in $sync_wts; do
            if ! git rev-parse --verify --quiet "refs/remotes/$rmt/$br" >/dev/null 2>&1; then
                return 1
            fi
        done
        return 0
    }

    _chk_plan_id_provider() {
        [ -d "$root/.agents/skills/aapp-planid" ]
    }

    _trig_init_files() {
        for f in .gitignore .gitattributes CHANGELOG.md ARCHITECTURE.md; do
            if [ -e "$root/$f" ]; then
                if git -C "$root" status --porcelain -- "$f" 2>/dev/null | grep -q .; then
                    return 0
                fi
            fi
        done
        return 1
    }
    _chk_init_files() {
        for f in .gitignore .gitattributes CHANGELOG.md ARCHITECTURE.md; do
            if [ -e "$root/$f" ]; then
                if git -C "$root" status --porcelain -- "$f" 2>/dev/null | grep -q .; then
                    return 1
                fi
            fi
        done
        return 0
    }

    _trig_project_rules() {
        if [ -f "$root/.agents/PROJECT.MD" ]; then
            if grep -qE '\[Project Name\]|\[one or two sentences\]|\[languages' "$root/.agents/PROJECT.MD" 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    }
    _chk_project_rules() {
        if [ -f "$root/.agents/PROJECT.MD" ]; then
            if ! grep -qE '\[Project Name\]|\[one or two sentences\]|\[languages' "$root/.agents/PROJECT.MD" 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    }

    _trig_project_map() {
        local templ_dir="$root/templates"
        [ -d "$templ_dir" ] || templ_dir="${AAPP_TEMPLATES:-}"
        if [ -f "$root/.agents/CODEMAP.md" ] && [ -f "$templ_dir/codemap.md" ]; then
            cmp -s "$root/.agents/CODEMAP.md" "$templ_dir/codemap.md" && return 0
        fi
        if [ -f "$root/ARCHITECTURE.md" ] && [ -f "$templ_dir/architecture.md" ]; then
            cmp -s "$root/ARCHITECTURE.md" "$templ_dir/architecture.md" && return 0
        fi
        return 1
    }
    _chk_project_map() {
        local templ_dir="$root/templates"
        [ -d "$templ_dir" ] || templ_dir="${AAPP_TEMPLATES:-}"
        if [ -f "$root/.agents/CODEMAP.md" ] && [ -f "$templ_dir/codemap.md" ]; then
            cmp -s "$root/.agents/CODEMAP.md" "$templ_dir/codemap.md" && return 1
        fi
        if [ -f "$root/ARCHITECTURE.md" ] && [ -f "$templ_dir/architecture.md" ]; then
            cmp -s "$root/ARCHITECTURE.md" "$templ_dir/architecture.md" && return 1
        fi
        return 0
    }

    _trig_template_drift() {
        find "$root" -maxdepth 3 -name "*.new" 2>/dev/null | grep -q .
    }
    _chk_template_drift() {
        ! find "$root" -maxdepth 3 -name "*.new" 2>/dev/null | grep -q .
    }

    _trig_issues_schema() {
        if [ -f "$root/.plans/ISSUES.md" ]; then
            if ! grep -qE '\|[[:space:]]*(#|Issue ID)[[:space:]]*\|' "$root/.plans/ISSUES.md" 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    }
    _chk_issues_schema() {
        [ -f "$root/.plans/ISSUES.md" ] && grep -qE '\|[[:space:]]*(#|Issue ID)[[:space:]]*\|' "$root/.plans/ISSUES.md" 2>/dev/null
    }

    _trig_protocol_block() {
        for f in "$root/.agents/AGENTS.md" "$root/.agents/PROJECT.MD" "$root/.plans/pickup.md"; do
            if [ -f "$f" ]; then
                if grep -q -E "^[[:space:]]*<!-- AAPP-PROTOCOL:START" "$f" 2>/dev/null && \
                   ! grep -q -E "^[[:space:]]*<!-- AAPP-PROTOCOL:END -->" "$f" 2>/dev/null; then
                    return 0
                fi
            fi
        done
        return 1
    }
    _chk_protocol_block() {
        ! _trig_protocol_block
    }

    _trig_write_guard() {
        local found=0
        for cf in "$root/.claude/settings.json" "$root/.claude/settings.local.json" "$root/.agents/.claude/settings.json"; do
            if [ -s "$cf" ] && grep -q 'blast-radius-guard' "$cf" 2>/dev/null; then
                found=1; break
            fi
        done
        [ "$found" -eq 0 ]
    }
    _chk_write_guard() {
        ! _trig_write_guard
    }

    _trig_hook_wiring() {
        if [ "${HOOK_MANAGER_NOTICE:-0}" -eq 1 ]; then
            return 0
        fi
        local chp
        chp="$(git config --get core.hooksPath 2>/dev/null || true)"
        if [ -n "$chp" ] && [ "$chp" != ".githooks" ]; then
            return 0
        fi
        if [ -x "$root/.git/hooks/pre-commit" ]; then
            return 0
        fi
        if [ -f "$root/.githooks/pre-commit" ]; then
            local first_line
            first_line="$(head -n 1 "$root/.githooks/pre-commit" 2>/dev/null || true)"
            if ! [[ "$first_line" =~ ^#!.*(sh|bash) ]]; then
                return 0
            fi
        fi
        return 1
    }
    _chk_hook_wiring() {
        local chp
        chp="$(git config --get core.hooksPath 2>/dev/null || true)"
        local candidate_files=()
        if [ -n "$chp" ]; then
            if [[ "$chp" = /* ]]; then
                candidate_files+=("$chp/pre-commit")
            else
                candidate_files+=("$root/$chp/pre-commit")
            fi
        fi
        if [ -x "$root/.git/hooks/pre-commit" ]; then
            candidate_files+=("$root/.git/hooks/pre-commit")
        fi
        if [ -f "$root/.githooks/pre-commit" ]; then
            local first_line
            first_line="$(head -n 1 "$root/.githooks/pre-commit" 2>/dev/null || true)"
            if ! [[ "$first_line" =~ ^#!.*(sh|bash) ]]; then
                candidate_files+=("$root/.githooks/pre-commit")
            fi
        fi
        candidate_files+=(
            "$root/.husky/pre-commit"
            "$root/lefthook.yml"
            "$root/.lefthook.yml"
            "$root/.pre-commit-config.yaml"
        )
        for hf in "${candidate_files[@]}"; do
            if [ -f "$hf" ] && grep -qF "aapp-pre-commit" "$hf" 2>/dev/null; then
                return 0
            fi
        done
        return 1
    }

    _chk_gate_test() {
        local reg="$root/.agents/skills/aapp-hooks/registry.tsv"
        [ -f "$reg" ] && grep -qE '^pre-done[[:space:]]' "$reg" 2>/dev/null
    }

    _trig_mono_nx() {
        [ -n "$wt_dir" ] && [ -f "$root/nx.json" ]
    }
    _chk_mono_nx() {
        [ -n "$wt_dir" ] && [ -f "$root/.nxignore" ] && grep -qE "^(/)?${wt_dir}(\$|/)" "$root/.nxignore" 2>/dev/null
    }

    _trig_mono_bazel() {
        [ -n "$wt_dir" ] && { [ -f "$root/WORKSPACE" ] || [ -f "$root/WORKSPACE.bazel" ] || [ -f "$root/MODULE.bazel" ]; }
    }
    _chk_mono_bazel() {
        [ -n "$wt_dir" ] && [ -f "$root/.bazelignore" ] && grep -qE "^(/)?${wt_dir}(\$|/)" "$root/.bazelignore" 2>/dev/null
    }

    # --------------------------------------------------------------------------
    # Process Each Rule
    # --------------------------------------------------------------------------
    for rule in "${RULES[@]}"; do
        IFS='|' read -r tag sec mhead trig_fn chk_fn text <<< "$rule"
        local tag_pattern="\`\\[${tag}\\]\`"

        if grep -qF "\`[${tag}]\`" "$tmp_file"; then
            # Line already exists in file
            if grep -qE "^- \\[x\\] .*\`\\[${tag}\\]\`" "$tmp_file"; then
                # Already checked: never untick
                :
            elif grep -qE "^- \\[ \\] .*\`\\[${tag}\\]\`" "$tmp_file"; then
                # Unticked: check if check_fn passes
                if [ "$chk_fn" != "none" ]; then
                    if "$chk_fn"; then
                        # Tick the line, preserving user text
                        sed -i -E "s/^- \\[ \\] (.*\`\\[${tag}\\]\`.*)/- [x] \\1/" "$tmp_file"
                    fi
                fi
            fi
        else
            # Line does not exist in file
            if "$trig_fn"; then
                local passes=0
                if [ "$chk_fn" != "none" ]; then
                    if "$chk_fn"; then
                        passes=1
                    fi
                fi
                if [ "$passes" -eq 0 ]; then
                    local new_task_line="- [ ] \`[${tag}]\` ${text} → MANUAL: ${mhead}"
                    _adoption_insert_task "$tmp_file" "$sec" "$new_task_line"
                fi
            fi
        fi
    done

    # Only touch adoption_file if bytes changed (preserves mtime and hash on no-op)
    if ! cmp -s "$tmp_file" "$adoption_file"; then
        cp "$tmp_file" "$adoption_file"
    fi
    rm -f "$tmp_file"
}
