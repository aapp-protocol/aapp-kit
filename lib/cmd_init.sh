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

# Target Repository Resolution
IS_INSIDE_PROJECT=0
if [ "$AAPP_IS_DROP_IN" -eq 1 ]; then
    KIT_DIR_GIT_ROOT="$(cd "$AAPP_SCRIPT_DIR" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
    PARENT_DIR="$(cd "$AAPP_SCRIPT_DIR/.." 2>/dev/null && pwd || true)"
    PARENT_GIT_ROOT="$(cd "$PARENT_DIR" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"

    case "$(basename "$AAPP_SCRIPT_DIR")" in
        aapp-develop-kit|agent-planning-kit)
            if [ -n "$KIT_DIR_GIT_ROOT" ] && [ "$KIT_DIR_GIT_ROOT" = "$AAPP_SCRIPT_DIR" ]; then
                REPO_ROOT="$KIT_DIR_GIT_ROOT"
                IS_INSIDE_PROJECT=0
            elif [ -n "$PARENT_GIT_ROOT" ]; then
                REPO_ROOT="$PARENT_GIT_ROOT"
                IS_INSIDE_PROJECT=1
            else
                echo "❌ No git repository here. Did you mean ./aapp-kit/aapp install ?"
                exit 1
            fi
            ;;
        *)
            if [ -n "$PARENT_GIT_ROOT" ]; then
                REPO_ROOT="$PARENT_GIT_ROOT"
                IS_INSIDE_PROJECT=1
            else
                echo "❌ No git repository here. Did you mean ./aapp-kit/aapp install ?"
                exit 1
            fi
            ;;
    esac
else
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$REPO_ROOT" ]; then
        echo "❌ Error: Not a git repository. Run 'git init' first."
        exit 1
    fi
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
for IGNORE_ENTRY in ".plans/" ".agents/" ".githooks/"; do
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
# PHASE 1: 'plans' Worktree
# ------------------------------------------------------------------------------
mount_or_create_worktree "plans" ".plans"
mkdir -p .plans/current .plans/release .plans/done .plans/aborted

# Legacy project-root ISSUES.md migration
if [ -f "ISSUES.md" ] && [ ! -f ".plans/ISSUES.md" ]; then
    mv "ISSUES.md" ".plans/ISSUES.md"
    echo "📦 Migrated legacy project-root ISSUES.md to .plans/ISSUES.md."
fi

copy_guarded "$AAPP_TEMPLATES/pickup.md" ".plans/pickup.md" ""
copy_guarded "$AAPP_TEMPLATES/state_matrix.md" ".plans/state_matrix.md" ""
copy_guarded "$AAPP_TEMPLATES/issues_road_map.md" ".plans/issues_road_map.md" ""
copy_guarded "$AAPP_TEMPLATES/plan-template.md" ".plans/plan-template.md" ""
copy_guarded "$AAPP_TEMPLATES/release_checklist.md" ".plans/release/release_checklist.md" ""
copy_guarded "$AAPP_TEMPLATES/issues.md" ".plans/ISSUES.md" ""
copy_guarded "$AAPP_TEMPLATES/000-archive-ledger.md" ".plans/done/000-archive-ledger.md" ""

(
    cd .plans
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: initialize planning state machine structures" --quiet 2>/dev/null || true
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

sync_agent_rules() {
    local target=".agents/AGENTS.md"
    local template="$AAPP_TEMPLATES/AGENTS.md"

    if [ ! -f "$template" ]; then
        return 0
    fi

    if [ ! -f "$target" ]; then
        cp "$template" "$target"
        echo "🤖 Initialized .agents/AGENTS.md with AAPP protocol rules."
        return 0
    fi

    local block_tmp
    block_tmp="$(mktemp)"
    awk '
        /<!-- AAPP-PROTOCOL:START/ { inside=1 }
        inside { print }
        /<!-- AAPP-PROTOCOL:END -->/ { inside=0 }
    ' "$template" > "$block_tmp"

    if [ ! -s "$block_tmp" ]; then
        rm -f "$block_tmp"
        return 0
    fi

    # Dynamically stamp current AAPP_VERSION
    if command -v sed >/dev/null 2>&1; then
        sed -i "s/<!-- AAPP-PROTOCOL:START.*/<!-- AAPP-PROTOCOL:START v${AAPP_VERSION} -->/" "$block_tmp" 2>/dev/null || true
    fi

    if grep -q "<!-- AAPP-PROTOCOL:START" "$target" && grep -q "<!-- AAPP-PROTOCOL:END -->" "$target"; then
        local target_tmp
        target_tmp="$(mktemp)"
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
        ' "$target" > "$target_tmp" && mv "$target_tmp" "$target"
        echo "🔄 Updated AAPP protocol block in .agents/AGENTS.md to v$AAPP_VERSION (custom rules preserved)."
    elif grep -q "<!-- AAPP-PROTOCOL:START" "$target" && ! grep -q "<!-- AAPP-PROTOCOL:END -->" "$target"; then
        echo "⚠️  Warning: Found unclosed <!-- AAPP-PROTOCOL:START --> marker without matching END marker in $target."
        echo "   Skipping protocol block replacement to prevent data loss. Please repair markers manually."
    else
        if [ -s "$target" ] && [ -n "$(tail -c 1 "$target")" ]; then
            echo "" >> "$target"
        fi
        echo "" >> "$target"
        cat "$block_tmp" >> "$target"
        echo "" >> "$target"
        echo "➕ Appended AAPP protocol block to existing .agents/AGENTS.md (custom rules preserved)."
    fi
    rm -f "$block_tmp"
}

# Legacy project-root CODEMAP.md migration
if [ -f "CODEMAP.md" ] && [ ! -f ".agents/CODEMAP.md" ]; then
    mv "CODEMAP.md" ".agents/CODEMAP.md"
    echo "📦 Migrated legacy project-root CODEMAP.md to .agents/CODEMAP.md."
fi

sync_agent_rules
copy_guarded "$AAPP_TEMPLATES/PROJECT.MD" ".agents/PROJECT.MD" ""
copy_guarded "$AAPP_TEMPLATES/codemap.md" ".agents/CODEMAP.md" ""

(
    cd .agents
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: sync agent behavioral rules and project context" --quiet 2>/dev/null || true
    fi
)

# ------------------------------------------------------------------------------
# PHASE 3: 'githooks' Worktree (Namespaced Infrastructure Sync)
# ------------------------------------------------------------------------------
mount_or_create_worktree "githooks" ".githooks"

# 1. Always update AAPP core engine files byte-for-byte
if [ -f "$AAPP_TEMPLATES/aapp-pre-commit" ]; then
    cp "$AAPP_TEMPLATES/aapp-pre-commit" .githooks/aapp-pre-commit
    chmod +x .githooks/aapp-pre-commit
fi

if [ -f "$AAPP_TEMPLATES/blast-radius-guard.sh" ]; then
    cp "$AAPP_TEMPLATES/blast-radius-guard.sh" .githooks/blast-radius-guard
    chmod +x .githooks/blast-radius-guard
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
            echo '"$(git rev-parse --show-toplevel)/.githooks/aapp-pre-commit" || exit 1' >> .githooks/pre-commit
            chmod +x .githooks/pre-commit
            echo "🛡️  Wired .githooks/aapp-pre-commit into existing .githooks/pre-commit."
        else
            NON_SHELL_HOOK_EXISTS=1
        fi
    fi
fi

(
    cd .githooks
    git add .
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git commit -m "chore: sync version-controlled git hooks" --quiet 2>/dev/null || true
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

# ------------------------------------------------------------------------------
# PHASE 4: Public Project Root Anchors
# ------------------------------------------------------------------------------
copy_guarded "$AAPP_TEMPLATES/architecture.md" "ARCHITECTURE.md" "🏛️  Created starter ARCHITECTURE.md at project root."
copy_guarded "$AAPP_TEMPLATES/changelog.md" "CHANGELOG.md" "📜 Created starter CHANGELOG.md at project root."

# ------------------------------------------------------------------------------
# PHASE 5: Write-Time Enforcement Hook (.claude/settings.json)
# ------------------------------------------------------------------------------
if [ -f .githooks/blast-radius-guard ]; then
    if [ ! -f .claude/settings.json ]; then
        mkdir -p .claude
        cat > .claude/settings.json <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|NotebookEdit",
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
        echo "🛡️  Wrote .claude/settings.json - writes outside the Blast Radius are now refused."
    else
        if ! grep -qs "blast-radius-guard" .claude/settings.json; then
            if command -v python3 >/dev/null 2>&1; then
                python3 - <<'PYEOF'
import json, sys

settings_path = ".claude/settings.json"
try:
    with open(settings_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

if not isinstance(data, dict):
    data = {}

if "hooks" not in data or not isinstance(data["hooks"], dict):
    data["hooks"] = {}

if "PreToolUse" not in data["hooks"] or not isinstance(data["hooks"]["PreToolUse"], list):
    data["hooks"]["PreToolUse"] = []

hook_cmd = "${CLAUDE_PROJECT_DIR}/.githooks/blast-radius-guard"
has_hook = False
for entry in data["hooks"]["PreToolUse"]:
    if isinstance(entry, dict) and "hooks" in entry and isinstance(entry["hooks"], list):
        for h in entry["hooks"]:
            if isinstance(h, dict) and h.get("command") == hook_cmd:
                has_hook = True
                break

if not has_hook:
    data["hooks"]["PreToolUse"].append({
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
            {
                "type": "command",
                "command": hook_cmd
            }
        ]
    })
    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("🛡️  Merged blast-radius-guard into existing .claude/settings.json.")
PYEOF
            else
                echo "⚠️  Warning: python3 not found. Could not automatically merge blast-radius-guard into .claude/settings.json."
            fi
        fi
    fi
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
    echo "     \"\$(git rev-parse --show-toplevel)/.githooks/aapp-pre-commit\" || exit 1"
    echo ""
fi

# ------------------------------------------------------------------------------
# PHASE 7: Drop-in Folder Consumption
# ------------------------------------------------------------------------------
if [ "$AAPP_IS_DROP_IN" -eq 1 ] && [ "$IS_INSIDE_PROJECT" -eq 1 ]; then
    case "$(basename "$AAPP_SCRIPT_DIR")" in
        aapp-develop-kit|agent-planning-kit)
            # Development workspace: do not self-consume
            ;;
        *)
            rm -rf "$AAPP_SCRIPT_DIR"
            echo ""
            echo "🧹 Consumed kit folder '$AAPP_SCRIPT_DIR'."
            ;;
    esac
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
