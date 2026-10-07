#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `init`
#
# Sets up or syncs isolated Git worktrees mounted on orphan branches:
# 1. 'plans'    --> mounted at ./.plans/ (Blueprints, State Matrix, Release Runbooks)
# 2. 'agents'   --> mounted at ./.agents/ (Agent Behavioral Rules, Project Context)
# 3. 'githooks' --> mounted at ./.githooks/ (Version-Controlled Git Hooks)
# ==============================================================================
set -e

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: aapp init"
            echo ""
            echo "Initializes or updates AAPP worktrees in the target git repository."
            echo ""
            return 0 2>/dev/null || exit 0
            ;;
        *)
            echo "❌ Error: Unknown option '$arg'."
            echo "Usage: aapp init"
            return 1 2>/dev/null || exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Target Repository Resolution & Canonical Fast-Fail Check (F14)
# ------------------------------------------------------------------------------
AAPP_BASE_PHYSICAL="$(cd "$AAPP_BASE" 2>/dev/null && pwd -P)" || {
    echo "❌ Error: Could not resolve physical path for AAPP_BASE: $AAPP_BASE" >&2
    exit 1
}
REPO_ROOT_PHYSICAL="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
    echo "❌ Error: Could not resolve physical path for REPO_ROOT: $REPO_ROOT" >&2
    exit 1
}

if [ "$AAPP_RUNTIME" != "installed" ] && [ "$AAPP_BASE_PHYSICAL" != "$REPO_ROOT_PHYSICAL" ]; then
    echo "❌ Error: AAPP must be installed globally before initializing projects." >&2
    echo "   Run: ./aapp install" >&2
    exit 1
fi

cd "$REPO_ROOT"

# Target Repository Validation
GIT_DIR_ABS="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo .)"
GIT_COMMON_ABS="$(cd "$GIT_COMMON_DIR" 2>/dev/null && pwd || true)"
if [ -n "$GIT_DIR_ABS" ] && [ -n "$GIT_COMMON_ABS" ] && [ "$GIT_DIR_ABS" != "$GIT_COMMON_ABS" ]; then
    echo "❌ Error: '$REPO_ROOT' is a linked worktree, not the main working tree."
    echo "   Run this script from the main working tree root."
    exit 1
fi

MAIN_BRANCH="$(git branch --show-current 2>/dev/null || true)"
if [ -z "$MAIN_BRANCH" ]; then
    echo "❌ Error: HEAD is detached. Check out a branch before initializing AAPP."
    exit 1
fi

echo "🚀 Initializing / Syncing Asymmetric Agent Planning Protocol (AAPP v$AAPP_VERSION)..."
echo "📍 Repository root: $REPO_ROOT"

# Configure .gitignore on Main Branch
for IGNORE_ENTRY in ".plans/" ".agents/" ".githooks/" ".claude/"; do
    if ! grep -qxF "${IGNORE_ENTRY}" .gitignore 2>/dev/null; then
        if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then
            echo "" >> .gitignore
        fi
        echo "${IGNORE_ENTRY}" >> .gitignore
        echo "📝 Added '${IGNORE_ENTRY}' to .gitignore on active code branch."
    fi
done

# Worktree Mounting Helper
mount_or_create_worktree() {
    local branch="$1"
    local dir="$2"

    if [ -d "$dir" ] && [ -e "$dir/.git" ]; then
        echo "ℹ️  Worktree '$dir' already mounted."
        return 0
    fi

    if [ -d "$dir" ] && [ ! -e "$dir/.git" ]; then
        echo "❌ Error: '$dir' exists as a normal directory, not an AAPP worktree."
        echo "   Move or remove '$dir' before running aapp init."
        exit 1
    fi

    # 1. Local branch exists
    if git show-ref --quiet "refs/heads/$branch"; then
        echo "ℹ️  Local branch '$branch' exists. Mounting worktree at '$dir'..."
        git worktree add "$dir" "$branch" --quiet
    # 2. Remote tracking branch exists
    elif git show-ref --quiet "refs/remotes/origin/$branch"; then
        echo "🌐 Remote branch 'origin/$branch' detected. Mounting and tracking at '$dir'..."
        git worktree add --track -b "$branch" "$dir" "origin/$branch" --quiet
    # 3. Create brand-new orphan branch (safe plumbing fallback without wiping working tree)
    else
        echo "📦 Creating isolated '$branch' orphan branch..."
        if git worktree add -h 2>&1 | grep -q -- "--orphan"; then
            git worktree add --orphan -b "$branch" "$dir" --quiet
        else
            local empty_tree commit
            empty_tree="$(git hash-object -t tree /dev/null)"
            commit="$(git commit-tree "$empty_tree" -m "chore: initialize orphan $branch branch")"
            git branch "$branch" "$commit"
            git worktree add "$dir" "$branch" --quiet
        fi
    fi
}

copy_guarded() {
    local src="$1"
    local dest="$2"
    local desc="$3"

    if [ -f "$dest" ]; then
        return 0
    elif [ -f "$src" ]; then
        cp "$src" "$dest"
        if [ -n "$desc" ]; then
            echo "$desc"
        fi
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Three-Tier Document Governance & Delimited Template Sync Engine (P-25)
# ------------------------------------------------------------------------------

resolve_template_sync_mode() {
    local mode
    mode="$(git config --get aapp.templateSync 2>/dev/null || echo "safe")"
    case "$mode" in
        safe|strict|manual) echo "$mode" ;;
        *) echo "safe" ;;
    esac
}

sync_delimited_block() {
    local src="$1"
    local dest="$2"
    local desc="$3"

    if [ ! -f "$src" ] || [ ! -f "$dest" ]; then
        return 0
    fi

    if cmp -s "$src" "$dest"; then
        return 0
    fi

    local block_tmp
    block_tmp="$(mktemp)"
    awk -v ver="$AAPP_VERSION" '
        /<!-- AAPP-PROTOCOL:START/ {
            inside=1
            print "<!-- AAPP-PROTOCOL:START v" ver " -->"
            next
        }
        inside { print }
        /<!-- AAPP-PROTOCOL:END -->/ { inside=0 }
    ' "$src" > "$block_tmp"

    if [ ! -s "$block_tmp" ]; then
        rm -f "$block_tmp"
        return 0
    fi

    if grep -q "<!-- AAPP-PROTOCOL:START" "$dest" && grep -q "<!-- AAPP-PROTOCOL:END -->" "$dest"; then
        local dest_tmp
        dest_tmp="$(mktemp)"
        awk -v block_file="$block_tmp" '
            BEGIN {
                while ((getline line < block_file) > 0) {
                    new_block = (new_block == "" ? "" : new_block "\n") line
                }
                close(block_file)
            }
            /<!-- AAPP-PROTOCOL:START/ {
                in_block=1
                print new_block
                next
            }
            /<!-- AAPP-PROTOCOL:END -->/ {
                in_block=0
                next
            }
            !in_block {
                print
            }
        ' "$dest" > "$dest_tmp" && mv "$dest_tmp" "$dest"
        rm -f "$block_tmp"
        if [ -n "$desc" ]; then
            echo "$desc"
        fi
        return 0
    elif grep -q "<!-- AAPP-PROTOCOL:START" "$dest" && ! grep -q "<!-- AAPP-PROTOCOL:END -->" "$dest"; then
        rm -f "$block_tmp"
        echo "⚠️  Warning: Found unclosed <!-- AAPP-PROTOCOL:START --> marker without matching END marker in $dest."
        echo "   Skipping protocol block replacement to prevent data loss. Please repair markers manually."
        return 1
    else
        # No markers in dest: append protocol block
        if [ -s "$dest" ] && [ -n "$(tail -c 1 "$dest")" ]; then
            echo "" >> "$dest"
        fi
        echo "" >> "$dest"
        cat "$block_tmp" >> "$dest"
        echo "" >> "$dest"
        rm -f "$block_tmp"
        echo "➕ Appended AAPP protocol block to existing $dest (custom rules/content preserved)."
        return 0
    fi
}

sync_tier1_template() {
    local src="$1"
    local dest="$2"
    local mode
    mode="$(resolve_template_sync_mode)"

    if [ ! -f "$dest" ]; then
        if [ -f "$src" ]; then
            cp "$src" "$dest"
            echo "📄 Initialized $dest from template."
        fi
        return 0
    fi

    # In manual mode, preserve existing file untouched
    if [ "$mode" = "manual" ]; then
        return 0
    fi

    # Fast skip if identical
    if cmp -s "$src" "$dest"; then
        return 0
    fi

    # If both src and dest carry delimiter markers, update the delimited block
    if grep -q "<!-- AAPP-PROTOCOL:START" "$dest" && grep -q "<!-- AAPP-PROTOCOL:END -->" "$dest" && \
       grep -q "<!-- AAPP-PROTOCOL:START" "$src" && grep -q "<!-- AAPP-PROTOCOL:END -->" "$src"; then
        sync_delimited_block "$src" "$dest" "🔄 Updated protocol block in $dest to v$AAPP_VERSION (custom template sections preserved)."
        return 0
    fi

    # Unclosed delimiter safety
    if grep -q "<!-- AAPP-PROTOCOL:START" "$dest" && ! grep -q "<!-- AAPP-PROTOCOL:END -->" "$dest"; then
        echo "⚠️  Warning: Found unclosed <!-- AAPP-PROTOCOL:START --> marker without matching END marker in $dest."
        echo "   Skipping protocol update to prevent data loss. Please repair markers manually."
        return 1
    fi

    if [ "$mode" = "strict" ]; then
        cp "$src" "$dest"
        echo "🔄 [strict] Overwrote diverged template $dest with upstream template."
    else
        # safe mode: produce .new buffer
        cp "$src" "$dest.new"
        echo "⚠️  Template drift in $dest: preserved existing file; wrote updated template to $dest.new."
    fi
}

sync_tier2_hybrid() {
    local src="$1"
    local dest="$2"
    local mode
    mode="$(resolve_template_sync_mode)"

    if [ ! -f "$dest" ]; then
        if [ -f "$src" ]; then
            cp "$src" "$dest"
            echo "📄 Initialized $dest from template."
        fi
        return 0
    fi

    # In manual mode, preserve existing file untouched
    if [ "$mode" = "manual" ]; then
        return 0
    fi

    if cmp -s "$src" "$dest"; then
        return 0
    fi

    sync_delimited_block "$src" "$dest" "🔄 Updated AAPP protocol block in $dest to v$AAPP_VERSION (custom rules preserved)."
}

sync_tier3_data() {
    # Tier 3 (Pure Project Domain Data) seeded on install only, never overwritten.
    copy_guarded "$@"
}

# ------------------------------------------------------------------------------
# PHASE 1: 'plans' Worktree
# ------------------------------------------------------------------------------
mount_or_create_worktree "plans" ".plans"
mkdir -p .plans/current .plans/release .plans/done .plans/aborted

# Legacy project-root ISSUES.md migration
if [ -f "ISSUES.md" ] && [ ! -f ".plans/ISSUES.md" ]; then
    mv "ISSUES.md" ".plans/ISSUES.md"
    echo "📦 Migrated legacy project-root ISSUES.md to .plans/ISSUES.md."
fi

sync_tier2_hybrid "$AAPP_TEMPLATES/pickup.md" ".plans/pickup.md"
sync_tier3_data "$AAPP_TEMPLATES/state_matrix.md" ".plans/state_matrix.md" ""
sync_tier3_data "$AAPP_TEMPLATES/issues_road_map.md" ".plans/issues_road_map.md" ""
sync_tier1_template "$AAPP_TEMPLATES/plan-template.md" ".plans/plan-template.md"
sync_tier1_template "$AAPP_TEMPLATES/release_checklist.md" ".plans/release/release_checklist.md"
sync_tier3_data "$AAPP_TEMPLATES/issues.md" ".plans/ISSUES.md" ""
sync_tier3_data "$AAPP_TEMPLATES/done-issues-archive.md" ".plans/done/000-issues-archive.md" ""
sync_tier1_template "$AAPP_TEMPLATES/000-archive-ledger.md" ".plans/done/000-archive-ledger.md"

if [ ! -f ".plans/.gitignore" ]; then
    cat > .plans/.gitignore <<'EOF'
# AAPP .plans Worktree Git Ignore
# Air-gapped local reference store (transcripts, chat dumps, private notes)
pickup/*
!pickup/.gitkeep
!pickup/.gitignore

# Local worktree hook dispatcher symlink
.githooks

# Template drift buffers (safe sync)
*.new
EOF
else
    if ! grep -qxF "*.new" .plans/.gitignore 2>/dev/null; then
        echo "" >> .plans/.gitignore
        echo "# Template drift buffers (safe sync)" >> .plans/.gitignore
        echo "*.new" >> .plans/.gitignore
    fi
    if ! grep -qxF ".githooks" .plans/.gitignore 2>/dev/null; then
        echo "" >> .plans/.gitignore
        echo "# Local worktree hook dispatcher symlink" >> .plans/.gitignore
        echo ".githooks" >> .plans/.gitignore
    fi
fi

# Non-destructive advisory for existing custom ISSUES.md
if [ -f ".plans/ISSUES.md" ] && ! grep -qE '\|[[:space:]]*(#|Issue ID)[[:space:]]*\|' ".plans/ISSUES.md" 2>/dev/null; then
    echo "ℹ️  Found existing custom .plans/ISSUES.md. Leaving untouched."
    echo "   To adapt to the AAPP Flat Issue Ledger schema, see MANUAL.md and templates/issues.md."
fi

(
    cd .plans
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: initialize planning state machine structures" --no-verify --quiet 2>/dev/null || true
    fi
)

# ------------------------------------------------------------------------------
# PHASE 2: 'agents' Worktree & Deterministic Protocol Sync
# ------------------------------------------------------------------------------
mount_or_create_worktree "agents" ".agents"

# Legacy flat AGENTS.md migration
if [ -f "AGENTS.md" ] && [ ! -f ".agents/AGENTS.md" ]; then
    mv "AGENTS.md" ".agents/AGENTS.md"
    echo "📦 Migrated legacy project-root AGENTS.md to .agents/AGENTS.md."
fi

# Legacy project-root CODEMAP.md migration
if [ -f "CODEMAP.md" ] && [ ! -f ".agents/CODEMAP.md" ]; then
    mv "CODEMAP.md" ".agents/CODEMAP.md"
    echo "📦 Migrated legacy project-root CODEMAP.md to .agents/CODEMAP.md."
fi

sync_tier2_hybrid "$AAPP_TEMPLATES/AGENTS.md" ".agents/AGENTS.md"
sync_tier3_data "$AAPP_TEMPLATES/PROJECT.MD" ".agents/PROJECT.MD" ""
sync_tier3_data "$AAPP_TEMPLATES/codemap.md" ".agents/CODEMAP.md" ""

if [ ! -f ".agents/.gitignore" ]; then
    cat > .agents/.gitignore <<'EOF'
# Local worktree hook dispatcher symlink
.githooks
EOF
elif ! grep -qxF ".githooks" .agents/.gitignore 2>/dev/null; then
    echo "" >> .agents/.gitignore
    echo "# Local worktree hook dispatcher symlink" >> .agents/.gitignore
    echo ".githooks" >> .agents/.gitignore
fi

(
    cd .agents
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: sync agent behavioral rules and project context" --no-verify --quiet 2>/dev/null || true
    fi
)

# ------------------------------------------------------------------------------
# PHASE 3: 'githooks' Worktree (Namespaced Infrastructure Sync)
# ------------------------------------------------------------------------------
mount_or_create_worktree "githooks" ".githooks"

# 0. Shared library beside the hook engines (P-37). Copied from $AAPP_LIB, never
#    from templates/aapp-lib.sh: on a `core.symlinks=false` checkout that symlink
#    is a one-line text stub. The hooks refuse to run without the library, so a
#    missing source is fatal here rather than deferred to the first commit.
AAPP_LIB_SRC="$AAPP_LIB/aapp-lib.sh"
if [ ! -f "$AAPP_LIB_SRC" ] || [ ! -r "$AAPP_LIB_SRC" ]; then
    echo "❌ [Init Error] Shared library missing or unreadable: $AAPP_LIB_SRC" >&2
    echo "   Detected OS : $(uname -s 2>/dev/null || echo unknown)" >&2
    echo "   The hook engines cannot run without it. Reinstall the kit:" >&2
    echo "     git clone https://github.com/aapp-protocol/aapp-kit.git && ./aapp-kit/aapp install" >&2
    exit 1
fi
cp "$AAPP_LIB_SRC" .githooks/aapp-lib.sh

# 1. Always update AAPP core engine files byte-for-byte
if [ -f "$AAPP_TEMPLATES/aapp-pre-commit" ]; then
    cp "$AAPP_TEMPLATES/aapp-pre-commit" .githooks/aapp-pre-commit
    chmod +x .githooks/aapp-pre-commit
fi

if [ -f "$AAPP_TEMPLATES/blast-radius-guard.sh" ]; then
    cp "$AAPP_TEMPLATES/blast-radius-guard.sh" .githooks/blast-radius-guard
    chmod +x .githooks/blast-radius-guard
fi

if [ -f "$AAPP_TEMPLATES/aapp-commit-msg" ]; then
    cp "$AAPP_TEMPLATES/aapp-commit-msg" .githooks/aapp-commit-msg
    chmod +x .githooks/aapp-commit-msg
fi

if [ -f "$AAPP_TEMPLATES/aapp-post-commit" ]; then
    cp "$AAPP_TEMPLATES/aapp-post-commit" .githooks/aapp-post-commit
    chmod +x .githooks/aapp-post-commit
fi

NON_SHELL_HOOK_EXISTS=0
# 2. Master pre-commit hook (project entrypoint) - never overwrite custom user hook
if [ ! -f .githooks/pre-commit ]; then
    if [ -f "$AAPP_TEMPLATES/pre-commit" ]; then
        cp "$AAPP_TEMPLATES/pre-commit" .githooks/pre-commit
        chmod +x .githooks/pre-commit
    fi
else
    # Existing hook found: ensure aapp-pre-commit is wired if shell script
    if ! grep -qs "aapp-pre-commit" .githooks/pre-commit; then
        if grep -qs '^#!/.*sh' .githooks/pre-commit; then
            echo "" >> .githooks/pre-commit
            echo '# Wire AAPP Blast Radius Engine' >> .githooks/pre-commit
            echo '"$(cd "$(git rev-parse --git-common-dir 2>/dev/null || echo .git)/.." && pwd)/.githooks/aapp-pre-commit" || exit 1' >> .githooks/pre-commit
            chmod +x .githooks/pre-commit
            echo "🛡️  Wired .githooks/aapp-pre-commit into existing .githooks/pre-commit."
        else
            NON_SHELL_HOOK_EXISTS=1
        fi
    fi
fi

# 3. Master commit-msg hook
if [ ! -f .githooks/commit-msg ]; then
    if [ -f "$AAPP_TEMPLATES/commit-msg" ]; then
        cp "$AAPP_TEMPLATES/commit-msg" .githooks/commit-msg
        chmod +x .githooks/commit-msg
    fi
else
    if ! grep -qs "aapp-commit-msg" .githooks/commit-msg; then
        if grep -qs '^#!/.*sh' .githooks/commit-msg; then
            echo "" >> .githooks/commit-msg
            echo '# Wire AAPP Commit-Msg Engine' >> .githooks/commit-msg
            echo '"$(cd "$(git rev-parse --git-common-dir 2>/dev/null || echo .git)/.." && pwd)/.githooks/aapp-commit-msg" "$@" || exit 1' >> .githooks/commit-msg
            chmod +x .githooks/commit-msg
            echo "🛡️  Wired .githooks/aapp-commit-msg into existing .githooks/commit-msg."
        else
            NON_SHELL_HOOK_EXISTS=1
        fi
    fi
fi

# 4. Master post-commit hook
if [ ! -f .githooks/post-commit ]; then
    if [ -f "$AAPP_TEMPLATES/post-commit" ]; then
        cp "$AAPP_TEMPLATES/post-commit" .githooks/post-commit
        chmod +x .githooks/post-commit
    fi
else
    if ! grep -qs "aapp-post-commit" .githooks/post-commit; then
        if grep -qs '^#!/.*sh' .githooks/post-commit; then
            echo "" >> .githooks/post-commit
            echo '# Wire AAPP Post-Commit Engine' >> .githooks/post-commit
            echo '"$(cd "$(git rev-parse --git-common-dir 2>/dev/null || echo .git)/.." && pwd)/.githooks/aapp-post-commit" "$@"' >> .githooks/post-commit
            chmod +x .githooks/post-commit
            echo "🛡️  Wired .githooks/aapp-post-commit into existing .githooks/post-commit."
        fi
    fi
fi

(
    cd .githooks
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: sync version-controlled git hooks" --no-verify --quiet 2>/dev/null || true
    fi
)

# Safe Hook Manager Wiring
HOOK_MANAGER_NOTICE=0
CURRENT_HOOKS_PATH="$(git config --get core.hooksPath 2>/dev/null || true)"
NATIVE_HOOK_EXISTS=0
[ -x .git/hooks/pre-commit ] && NATIVE_HOOK_EXISTS=1

if [ -z "$CURRENT_HOOKS_PATH" ] && [ "$NATIVE_HOOK_EXISTS" -eq 0 ]; then
    git config core.hooksPath .githooks
    if [ "$NON_SHELL_HOOK_EXISTS" -eq 1 ]; then
        HOOK_MANAGER_NOTICE=1
    fi
elif [ "$CURRENT_HOOKS_PATH" = ".githooks" ]; then
    if [ "$NON_SHELL_HOOK_EXISTS" -eq 1 ]; then
        HOOK_MANAGER_NOTICE=1
    fi
else
    HOOK_MANAGER_NOTICE=1
fi

# Wire worktree hook symlinks for linked worktrees (.plans, .agents)
for wt_dir in .plans .agents; do
    if [ -d "$wt_dir" ] && [ ! -e "$wt_dir/.githooks" ]; then
        ln -sfn ../.githooks "$wt_dir/.githooks" 2>/dev/null || true
    fi
done

# ------------------------------------------------------------------------------
# Plan ID Counter Bootstrap
# ------------------------------------------------------------------------------
# Returns the NEXT free Plan ID by scanning blueprint filenames across all three
# lanes plus the archive ledger (which retains ids whose files were pruned).
#
# Pure POSIX by design: no `ls`, no `grep -o`, no `sort`, and no arithmetic on
# parsed text -- only glob expansion, parameter expansion and `test`. This keeps
# it portable and immune to filenames containing newlines.
#
# MAX starts at 0 and the function returns MAX + 1, so a project with no plans
# at all seeds to exactly 1 without any special-casing.
seed_plan_id() {
    local PLANS="$1"
    local LEDGER="$1/done/000-archive-ledger.md"
    local DIR F BNAME LINE N MAX=0

    for DIR in current done aborted; do
        [ -d "$PLANS/$DIR" ] || continue
        for F in "$PLANS/$DIR"/[Pp][0-9]*.md; do
            [ -e "$F" ] || continue          # literal-glob guard when nothing matches
            BNAME=${F##*/}
            N=${BNAME#[Pp]}                  # strip the leading P
            N=${N%%[!0-9]*}                  # keep the leading digit run
            [ -n "$N" ] || continue
            # `test -gt` parses decimally, so a legacy P-007 compares as 7.
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done
    done

    # Ledger rows cover archived plans whose blueprint files were removed.
    if [ -f "$LEDGER" ]; then
        while IFS= read -r LINE; do
            case $LINE in
                *'`P-'*) N=${LINE#*\`P-}; N=${N%%[!0-9]*} ;;
                *) continue ;;
            esac
            [ -n "$N" ] || continue
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done < "$LEDGER"
    fi

    printf '%s\n' "$((MAX + 1))"
}

# Safe-by-default AI Attribution configuration (none default; pure human authoring until opted in)
if [ -z "$(git config --get aapp.aiAttribution 2>/dev/null || true)" ]; then
    git config aapp.aiAttribution none
fi
if [ -z "$(git config --get aapp.aiCredits 2>/dev/null || true)" ]; then
    git config aapp.aiCredits false
fi

# Safe-by-default Remote Sync configuration (A/C Hybrid)
if [ -z "$(git config --get aapp.remote 2>/dev/null || true)" ]; then
    DEFAULT_REMOTE="$(git remote 2>/dev/null | head -n 1 || true)"
    [ -z "$DEFAULT_REMOTE" ] && DEFAULT_REMOTE="origin"
    git config aapp.remote "$DEFAULT_REMOTE"
fi
if [ -z "$(git config --get aapp.syncWorktrees 2>/dev/null || true)" ]; then
    git config aapp.syncWorktrees "plans agents githooks"
fi
if [ -z "$(git config --get aapp.pullStrategy 2>/dev/null || true)" ]; then
    git config aapp.pullStrategy "ff-only"
fi
if [ -z "$(git config --get aapp.syncStrategy 2>/dev/null || true)" ]; then
    REG_FILE=".agents/skills/aapp-hooks/registry.tsv"
    if [ -f "$REG_FILE" ] && grep -qE '^[[:space:]]*on-sync([[:space:]]|$)' "$REG_FILE"; then
        git config aapp.syncStrategy "hook"
    else
        git config aapp.syncStrategy "builtin"
    fi
fi

# Changelog policy (P-48): one plan-declared entry per plan unless the project
# opted into a bullet per commit. An existing value is never overwritten.
if ! git config --get aapp.changelogMode >/dev/null 2>&1; then
    git config aapp.changelogMode plan
fi

# Union merge for CHANGELOG.md (P-48): bullets added on two branches are both
# kept at merge time. Appended once; other .gitattributes lines are untouched.
if [ ! -f .gitattributes ] || ! grep -qxF 'CHANGELOG.md merge=union' .gitattributes; then
    if [ -s .gitattributes ] && [ -n "$(tail -c 1 .gitattributes)" ]; then
        printf '\n' >> .gitattributes
    fi
    printf 'CHANGELOG.md merge=union\n' >> .gitattributes
    echo "ℹ️  Added 'CHANGELOG.md merge=union' to .gitattributes (keeps both sides of changelog merges)."
fi

# Plan ID counter (next id to hand out). A numeric value is LEFT ALONE, so
# repeat `aapp init` -- including the init that follows `aapp upgrade` -- never
# disturbs a live counter. Seeding happens only when the key is absent or
# unusable; `seed_plan_id` returns 1 for a project with no plans.
PLAN_ID_CURRENT="$(git config --get aapp.planId 2>/dev/null || true)"
case "$PLAN_ID_CURRENT" in
    ''|*[!0-9]*) git config aapp.planId "$(seed_plan_id ".plans")" ;;
esac

# ------------------------------------------------------------------------------
# PHASE 4: Public Project Root Anchors
# ------------------------------------------------------------------------------
sync_tier3_data "$AAPP_TEMPLATES/architecture.md" "ARCHITECTURE.md" "🏛️  Created starter ARCHITECTURE.md at project root."
sync_tier3_data "$AAPP_TEMPLATES/changelog.md" "CHANGELOG.md" "📜 Created starter CHANGELOG.md at project root."

# ------------------------------------------------------------------------------
# PHASE 5: Write-Time Enforcement Hook & Universal Skills Synchronization
# ------------------------------------------------------------------------------
merge_blast_radius_guard() {
    local target_file="$1"
    local source_file="${2:-}"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$target_file" "$source_file" <<'PYEOF'
import json, sys, os

target_path = sys.argv[1]
source_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None

def load_json(p):
    if not p or not os.path.isfile(p):
        return {}
    try:
        with open(p, "r", encoding="utf-8") as f:
            d = json.load(f)
            return d if isinstance(d, dict) else {}
    except Exception:
        return {}

target_data = load_json(target_path)

# If source file provided (e.g. migrating existing or diverged .claude/settings.json),
# merge all top-level keys and union nested permissions/lists
if source_path and os.path.isfile(source_path):
    source_data = load_json(source_path)
    for k, v in source_data.items():
        if k not in target_data:
            target_data[k] = v
        elif isinstance(v, dict) and isinstance(target_data[k], dict):
            for sub_k, sub_v in v.items():
                if sub_k not in target_data[k]:
                    target_data[k][sub_k] = sub_v
                elif isinstance(sub_v, list) and isinstance(target_data[k][sub_k], list):
                    for item in sub_v:
                        if item not in target_data[k][sub_k]:
                            target_data[k][sub_k].append(item)

# Ensure blast-radius-guard hook is present in PreToolUse
if "hooks" not in target_data or not isinstance(target_data["hooks"], dict):
    target_data["hooks"] = {}
if "PreToolUse" not in target_data["hooks"] or not isinstance(target_data["hooks"]["PreToolUse"], list):
    target_data["hooks"]["PreToolUse"] = []

hook_cmd = "${CLAUDE_PROJECT_DIR}/.githooks/blast-radius-guard"
has_hook = False
for entry in target_data["hooks"]["PreToolUse"]:
    if isinstance(entry, dict) and "hooks" in entry and isinstance(entry["hooks"], list):
        for h in entry["hooks"]:
            if isinstance(h, dict) and h.get("command") == hook_cmd:
                has_hook = True
                if "matcher" in entry and isinstance(entry["matcher"], str) and "MultiEdit" not in entry["matcher"]:
                    entry["matcher"] = "Write|Edit|MultiEdit|NotebookEdit"
                break

if not has_hook:
    target_data["hooks"]["PreToolUse"].append({
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [
            {
                "type": "command",
                "command": hook_cmd
            }
        ]
    })

os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
with open(target_path, "w", encoding="utf-8") as f:
    json.dump(target_data, f, indent=2)
    f.write("\n")
PYEOF
    else
        echo "⚠️  Warning: python3 not found. Could not automatically merge blast-radius-guard into $target_file."
    fi
}

sync_claude_settings() {
    mkdir -p .agents/claude
    [ ! -d .claude ] && mkdir -p .claude

    local canonical_settings=".agents/claude/settings.json"
    local bridge_settings=".claude/settings.json"

    # Step 1: Non-destructive migration & divergence reconciliation
    # Handles initial adopter migration, Windows copy-fallback, and Claude UI permission updates
    if [ -f "$bridge_settings" ] && [ ! -L "$bridge_settings" ]; then
        if [ ! -f "$canonical_settings" ]; then
            # Initial migration for fresh AAPP adopter
            mv "$bridge_settings" "$canonical_settings"
        elif ! cmp -s "$bridge_settings" "$canonical_settings"; then
            # File diverged (e.g. Windows copy-fallback or Claude UI added permissions/config)
            cp "$bridge_settings" "${canonical_settings}.bak"
            echo "ℹ️  Merging diverged .claude/settings.json into canonical (backup: ${canonical_settings}.bak)."
            merge_blast_radius_guard "$canonical_settings" "$bridge_settings"
            rm -f "$bridge_settings"
        else
            # Identical to canonical (clean copy from previous init)
            rm -f "$bridge_settings"
        fi
    fi

    # Step 2: Ensure canonical template settings exist
    if [ ! -f "$canonical_settings" ]; then
        if [ -f "$AAPP_TEMPLATES/claude/settings.json" ]; then
            cp "$AAPP_TEMPLATES/claude/settings.json" "$canonical_settings"
        else
            cat > "$canonical_settings" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.githooks/blast-radius-guard"
          }
        ]
      }
    ]
  }
}
JSON
        fi
        echo "🛡️  Wrote $canonical_settings (bridged to $bridge_settings) - writes outside the Blast Radius are now refused."
    fi

    # Step 3: Run path-parameterized Python merge against canonical settings
    # Guarantees blast-radius-guard hook is present without disturbing custom user keys
    merge_blast_radius_guard "$canonical_settings"

    # Step 4: Transparent git index untracking for code branch hygiene
    if git ls-files --error-unmatch "$bridge_settings" >/dev/null 2>&1; then
        git rm --cached "$bridge_settings" >/dev/null 2>&1 || true
        echo "ℹ️  Untracked $bridge_settings from git index (migrated to $canonical_settings; ignored via .gitignore)."
    fi

    # Step 5: Establish granular symlink with verified resolution and content check
    rm -rf "$bridge_settings"
    ln -s "../$canonical_settings" "$bridge_settings" 2>/dev/null || true
    if [ -s "$bridge_settings" ] && grep -q 'blast-radius-guard' "$bridge_settings" 2>/dev/null; then
        : # Symlink verified and readable
    else
        rm -rf "$bridge_settings"
        cp "$canonical_settings" "$bridge_settings" # Cross-platform copy fallback
    fi
}

sync_skills() {
    local templates_skills="$AAPP_TEMPLATES/skills"
    [ ! -d "$templates_skills" ] && return 0

    [ ! -d .agents/skills ] && mkdir -p .agents/skills
    [ ! -d .claude/skills ] && mkdir -p .claude/skills

    # 1. Prune retired skills from worktree and Claude bridge
    for retired in aapp-freeze-start aapp-active; do
        rm -rf ".agents/skills/$retired"
        rm -rf ".claude/skills/$retired"
    done
    rm -f ".agents/skills/aapp-hooks/SKILL.md"
    rm -rf ".claude/skills/aapp-hooks"

    for skill_dir in "$templates_skills"/aapp-* "$templates_skills"/plan; do
        [ ! -d "$skill_dir" ] && continue
        local skill_name
        skill_name="$(basename "$skill_dir")"

        # 2. Sync canonical engine skill/assets into .agents/skills/ (preserving user registry.tsv)
        local saved_reg=""
        if [ "$skill_name" = "aapp-hooks" ] && [ -f ".agents/skills/aapp-hooks/registry.tsv" ]; then
            saved_reg="$(mktemp)"
            cp ".agents/skills/aapp-hooks/registry.tsv" "$saved_reg"
        fi

        rm -rf ".agents/skills/$skill_name"
        mkdir -p ".agents/skills/$skill_name"
        cp -R "$skill_dir/." ".agents/skills/$skill_name/"

        if [ -n "$saved_reg" ] && [ -f "$saved_reg" ]; then
            mv "$saved_reg" ".agents/skills/aapp-hooks/registry.tsv"
        fi

        # 3. Granular Claude Code symlink bridge with verified resolution (only for skills declaring SKILL.md)
        rm -rf ".claude/skills/$skill_name"
        if [ -f "$skill_dir/SKILL.md" ]; then
            ln -s "../../.agents/skills/$skill_name" ".claude/skills/$skill_name" 2>/dev/null || true
            if [ -e ".claude/skills/$skill_name/SKILL.md" ]; then
                : # Relative symlink established and verified
            else
                rm -rf ".claude/skills/$skill_name"
                cp -R ".agents/skills/$skill_name" ".claude/skills/" # Cross-platform fallback copy
            fi
        fi
    done
}

if [ -f .githooks/blast-radius-guard ]; then
    sync_claude_settings
fi
sync_skills

if [ -d .agents ] && [ -e .agents/.git ]; then
    (
        cd .agents
        git add .
        if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
            git commit -m "chore: sync universal skills and claude configuration" --no-verify --quiet 2>/dev/null || true
        fi
    )
fi

# ------------------------------------------------------------------------------
# PHASE 6: Reporting & Warnings
# ------------------------------------------------------------------------------
if [ "$HOOK_MANAGER_NOTICE" -eq 1 ]; then
    echo ""
    echo "ℹ️  An existing hook configuration was detected:"
    if [ -n "$CURRENT_HOOKS_PATH" ]; then
        echo "     core.hooksPath is currently set to: '$CURRENT_HOOKS_PATH'"
    elif [ -f .githooks/pre-commit ] && [ "$NON_SHELL_HOOK_EXISTS" -eq 1 ]; then
        echo "     Custom non-shell hook detected at '.githooks/pre-commit'"
    else
        echo "     Executable hook found at '.git/hooks/pre-commit'"
    fi
    echo "   Git config was left untouched. To wire AAPP blast-radius checks into your existing hook,"
    echo "   add this subprocess call to your pre-commit script:"
    echo ""
    echo "     \"\$(cd \"\$(git rev-parse --git-common-dir 2>/dev/null || echo .git)/..\" && pwd)/.githooks/aapp-pre-commit\" || exit 1"
    echo ""
fi



echo ""
echo "✨ Multi-Orphan Worktree Setup Complete!"
echo "➡️  Planning workspace:   .plans/    (branch: 'plans')"
echo "➡️  Agent rules & ctx:    .agents/   (branch: 'agents')"
echo "➡️  Git hooks engine:     .githooks/ (branch: 'githooks')"
echo "➡️  Active scratchpad:    .plans/pickup.md"
echo "➡️  State Matrix Brain:   .plans/state_matrix.md"
echo "➡️  Release Runbooks:     .plans/release/"
echo "➡️  Write-time guard:    .githooks/blast-radius-guard"
echo "➡️  Universal Skills:     .agents/skills/ (bridged to .claude/skills/)"
CUSTOM_ALLOW_COUNT=$(git config --get-all aapp.allowPath 2>/dev/null | grep -c . || true)
echo "➡️  Guard allowlist:      7 built-in + ${CUSTOM_ALLOW_COUNT} from git config (aapp.allowPath)"
ATTR_CURRENT="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"
echo "➡️  AI Attribution:     $ATTR_CURRENT (switch via 'aapp ai lax', 'aapp ai strict', 'aapp ai notes', or 'aapp ai none')"
SYNC_REMOTE="$(git config aapp.remote 2>/dev/null || echo "origin")"
SYNC_STRAT="$(git config aapp.syncStrategy 2>/dev/null || echo "builtin")"
SYNC_WTS="$(git config aapp.syncWorktrees 2>/dev/null || echo "plans agents githooks")"
PLAN_ID_NEXT="$(git config aapp.planId 2>/dev/null || echo "1")"
echo "➡️  Remote sync:        remote=$SYNC_REMOTE, strategy=$SYNC_STRAT, worktrees=$SYNC_WTS"
echo "➡️  Next plan ID:       P-$PLAN_ID_NEXT (aapp.planId)"
if ISSUE_ID_NEXT="$(git config --get aapp.issueId 2>/dev/null)"; then
    echo "➡️  Next issue ID:      #$ISSUE_ID_NEXT (aapp.issueId)"
else
    echo "➡️  Next issue ID:      seeded from the ledgers on first 'aapp issue allocate'"
fi

# Detect Branching Topology
DEV_EXISTS=0
for DB in develop dev development; do
    if git show-ref --verify --quiet "refs/heads/$DB" 2>/dev/null || \
       git show-ref --verify --quiet "refs/remotes/origin/$DB" 2>/dev/null; then
        DEV_EXISTS=1
        break
    fi
done

if [ "$DEV_EXISTS" -eq 1 ]; then
    echo "➡️  Branch topology:     Dual-Branch (Stable/Edge guard active)"
else
    echo "➡️  Branch topology:     Trunk-based ($MAIN_BRANCH)"
fi

echo ""
echo "🚀 Next Steps — Experience Your First AAPP Loop:"
echo "   1. Open your AI agent (Claude Code, Antigravity, Cursor)."
echo "   2. Run '/aapp-status' (or 'aapp status') to inspect the 4 pillars."
echo "   3. Run '/aapp-digest Onboarding' to map your codebase into"
echo "      .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD!"

