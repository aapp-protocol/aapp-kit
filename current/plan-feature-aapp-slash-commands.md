# 🗺️ Plan: Universal AAPP Skills & Slash Commands (`.agents/skills/` & `.claude/skills/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-13
* **Target Issue / Milestone:** `ISSUE-061`
* **Status:** 🟢 Ready for Execution

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### 🔒 Execution Note: `.githooks/` is write-protected
> `blast-radius-guard` hard-blocks every write to `.githooks/*` (self-protection). The engine copy is therefore **never edited directly**. Edit `templates/blast-radius-guard.sh` and run `aapp init` to propagate it into `.githooks/blast-radius-guard`. The same applies to `.agents/AGENTS.md`, which is regenerated from `templates/AGENTS.md` by the delimited-block sync.

---

## 1. Context & Architectural Goal

`README.md:241-245` presents `/status`, `/digest`, `/freeze`, `/done` and `/release` as slash commands, but they previously existed **only as prose** inside `templates/AGENTS.md`. In active agent sessions (Claude Code, Antigravity, Cursor) they resolve to unknown commands or require reading a ~20 KB `AGENTS.md` into full conversational context — which does *not* happen on a cold start, in subagents, or upon fresh repository adoption.

**Goal:** Ship the five lifecycle verbs as **Universal AAPP Skills** (`skills/<name>/SKILL.md`) natively housed within the orphan `agents` worktree (`.agents/skills/`) and bridged to Claude Code (`.claude/skills/`). This ensures cross-agent interoperability (Antigravity, Claude Code, Cursor), eliminates prompt context pollution through progressive disclosure, and enables isolated subagent execution.

### Architectural Advantages of Universal Skills over Flat Commands:
1. **Multi-Agent Interoperability**:
   - **Google Antigravity** natively discovers workspace skills in `.agents/skills/<name>/SKILL.md` via progressive disclosure.
   - **Claude Code** natively discovers `.claude/skills/<name>/SKILL.md` and exposes them as slash commands (e.g. `/aapp-status`, `/aapp-digest`).
   - Standardizes on the open `SKILL.md` format with YAML frontmatter across AI pair-programming tools.
2. **Decoupled Worktree Alignment**:
   - Canonical skill files live in the orphan `agents` worktree (`.agents/skills/`), never polluting the application code branch or commit history.
   - `aapp init` wires Claude Code compatibility via `.claude/skills` (symlink or directory mirror).
3. **Progressive Disclosure & Token Economics**:
   - Instead of injecting 20 KB of `AGENTS.md` on every turn, agents only register ~100 tokens of skill names and 1-line descriptions. Full procedure text is loaded on-demand *only* when the skill or slash command is triggered.
4. **Execution Isolation (`context: fork` vs Inline)**:
   - Heavy automated verification workflows like `/aapp-release` (running full test suites and linters) run in an isolated fork/subagent context (`context: fork`), reporting only clean summaries back to the primary chat. Conversational workflows like `/aapp-digest` run inline to preserve full chat context and access user interaction.
5. **Deterministic Tool Execution**:
   - Eliminates brittle pre-render `` !`aapp status` `` macro injections that crash Claude sessions on missing binaries or permission checks. The agent inspects `aapp status` via standard tool execution or falls back gracefully to reading the four pillar markdown files directly.

---

## 2. Technical Blueprint

### 2.1 Skill Hierarchy, Naming & Path Depth Invariant

Each lifecycle verb is authored as an isolated skill directory:
```text
templates/skills/
├── aapp-status/
│   └── SKILL.md
├── aapp-digest/
│   └── SKILL.md
├── aapp-freeze/
│   └── SKILL.md
├── aapp-done/
│   └── SKILL.md
└── aapp-release/
    └── SKILL.md
```

#### Naming Convention: `aapp-<verb>` vs `aapp:<verb>`
* **Cross-Platform Filesystem Safety (Windows NTFS)**: Colons (`:`) are strictly forbidden in directory and file names on Windows (`NTFS` / `FAT32`). Naming directories `aapp:status` breaks Windows checkouts, git clones, and WSL shared mounts. Therefore, the canonical skill directory and identifier is **`aapp-<verb>`** (e.g. `aapp-status`, `aapp-digest`).
* **Slash Command Registration**:
  * In Claude Code, a skill directory named `aapp-status` registers the slash command **`/aapp-status`**.
  * Prose triggers (`/aapp status`, `aapp status`, `status`) remain supported as natural language aliases in `templates/AGENTS.md`.
* **Zero Collision**: Prefixing with `aapp-` guarantees zero collisions with built-ins (`/status`, `/init`, `/compact`) across all agent tools.

#### Path Depth Invariant for Cursor, Codex & Antigravity Compatibility
* **The Depth Rule**: Agent skill discovery engines in Google Antigravity, Cursor, and OpenAI Codex look for skills matching the exact glob `skills/*/SKILL.md` (depth = 1 directory level below `skills/`).
* **Why Subdirectories Break**: If skills were organized into nested subtrees like `skills/aapp/status/SKILL.md`, the discovery engines in Antigravity, Cursor, and Codex would silently ignore them due to fixed-depth directory traversal.
* **Universal Discovery**: By placing each verb at `.agents/skills/aapp-<verb>/SKILL.md`, the depth requirement is satisfied across all major agent environments:
  1. **Google Antigravity**: Discovers `.agents/skills/aapp-*/SKILL.md` natively in workspace root.
  2. **Cursor & Codex**: Automatically index `.agents/skills/aapp-*/SKILL.md` as workspace skills.
  3. **Claude Code**: Discovers bridged skills in `.claude/skills/aapp-*/SKILL.md`.

When `aapp init` executes:
1. Installs canonical skills into `.agents/skills/aapp-*/SKILL.md`.
2. First checks if `.claude/skills/` exists; creates the directory if absent (`[ ! -d .claude/skills ] && mkdir -p .claude/skills`).
3. For each `aapp-*` skill, establishes a granular relative symlink `.claude/skills/aapp-<verb> -> ../../.agents/skills/aapp-<verb>`, with graceful POSIX directory copy fallback where symlinks fail (e.g. on Windows without elevated privileges or developer mode).
4. Adds `.claude/` to `.gitignore` on the active code branch alongside `.plans/`, `.agents/`, and `.githooks/` so `.claude/settings.json` and `.claude/skills/` never pollute the application repository.
5. In Claude Code, this generates slash commands `/aapp-status`, `/aapp-digest`, `/aapp-freeze`, `/aapp-done`, and `/aapp-release`.
6. In Antigravity, Cursor, and Codex, the skills are immediately indexed and available via progressive disclosure.

### 2.2 Clean Codebase Invariant: `.claude/` in `.gitignore`

When `aapp init` runs, it configures `.gitignore` on the user's active code branch to ignore the decoupled worktree mounts:
```bash
for IGNORE_ENTRY in ".plans/" ".agents/" ".githooks/" ".claude/"; do
    if ! grep -qxF "${IGNORE_ENTRY}" .gitignore 2>/dev/null; then
        echo "${IGNORE_ENTRY}" >> .gitignore
    fi
done
```
Previously, `.claude/` was omitted from this loop. As a result, `.claude/settings.json` (and the newly created `.claude/skills/` bridge) would appear as untracked files in `git status`, risking accidental commits to application code branches. Including `.claude/` in the initial `.gitignore` setup ensures zero repository pollution while keeping agent configuration fully functional.

### 2.3 Granular Per-Skill Symlinks & Non-Destructive Invariant

| Class | Existing example | Sync verb | Applies here |
| :--- | :--- | :--- | :--- |
| User-owned scaffold | `pickup.md`, `ISSUES.md` | `copy_guarded` (create if absent) | ✗ |
| AAPP-owned engine | `aapp-pre-commit`, `blast-radius-guard` | `cp` / granular symlink every init | ✓ |

#### Why Monolithic Symlinking is Prohibited:
A monolithic symlink `.claude/skills -> ../.agents/skills` would fail if `.claude/skills` already existed as a directory and would destroy or shadow pre-existing user skills (e.g. `.claude/skills/deploy-aws/`).

#### The Granular Bridge Pattern:
`lib/cmd_init.sh` executes a granular per-skill sync:
```bash
sync_skills() {
    local templates_skills="$AAPP_TEMPLATES/skills"
    [ ! -d "$templates_skills" ] && return 0

    [ ! -d .agents/skills ] && mkdir -p .agents/skills
    [ ! -d .claude/skills ] && mkdir -p .claude/skills

    for skill_dir in "$templates_skills"/aapp-*; do
        [ ! -d "$skill_dir" ] && continue
        local skill_name
        skill_name="$(basename "$skill_dir")"

        # 1. Sync canonical engine skill into .agents/skills/ (clean overwrite)
        rm -rf ".agents/skills/$skill_name"
        mkdir -p ".agents/skills/$skill_name"
        cp -R "$skill_dir/." ".agents/skills/$skill_name/"

        # 2. Granular Claude Code symlink bridge with verified resolution
        rm -rf ".claude/skills/$skill_name"
        ln -s "../../.agents/skills/$skill_name" ".claude/skills/$skill_name" 2>/dev/null || true
        if [ -e ".claude/skills/$skill_name/SKILL.md" ]; then
            : # Relative symlink established and verified
        else
            rm -rf ".claude/skills/$skill_name"
            cp -R ".agents/skills/$skill_name" ".claude/skills/" # Cross-platform fallback copy
        fi
    done
}
```
* **User Skill Preservation**: Any custom skills in `.claude/skills/` or `.agents/skills/` that do not begin with `aapp-` remain 100% untouched.
* **Clean Upgrade Guarantee**: Removing destination directories prior to copying ensures that files dropped or renamed across AAPP releases never persist as stale artifacts.
* **Cross-Platform Resilience**: On systems where unprivileged symlinks fail or produce broken link stubs (Windows NTFS, certain Docker volumes), directory copying seamlessly succeeds.

### 2.4 Anatomy of an AAPP `SKILL.md` File

```markdown
---
name: aapp-status
description: Act as a Context Recovery agent upon desk return. Scan the four pillars (Shipped, Issues, Plans, Pickup) and report a concise structured briefing.
disable-model-invocation: false
argument-hint: ""
---

# AAPP Status (Context Recovery)

Execute the 5-step four-pillar context recovery procedure...
```

* **Frontmatter Contract**:
  - `name`: `aapp-status`, `aapp-digest`, `aapp-freeze`, `aapp-done`, `aapp-release`.
  - `description`: Crisp 1-sentence explanation used by agent skill catalogs for progressive disclosure.
  - `disable-model-invocation: true` on `freeze`, `done`, and `release`: Critical state transitions (granting commit rights, archiving plans, running releases) must be human-initiated. `status` and `digest` remain model-invocable.
  - `context: fork` strictly on `release`: Heavy preflight test runs and linters execute in an isolated subagent/fork context, preventing noisy test logs from cluttering primary chat.
  - **Inline Execution (Default)**: `status`, `digest`, `freeze`, and `done` omit the `context` field (the standard Claude Code default for running inline in the active conversation). In particular, `digest` requires conversational context and recent chat notes to scaffold blueprints.
* **Zero-Crash Execution Logic (No Brittle Macros)**:
  - `status` instructs the agent to run `./aapp status` if available. If absent or unpermitted, the agent directly inspects the four pillar files (`CHANGELOG.md`, `ISSUES.md` / `issues_road_map.md`, `state_matrix.md`, `pickup.md`) without ever failing or aborting the session.
* **Canonical Pointer**:
  - Each skill references the canonical specification in `.agents/AGENTS.md` for deep edge-case resolution.

### 2.5 Drift Control

`templates/AGENTS.md` remains canonical protocol prose; the skill files are the executable procedures. A new assertion block in `tests/install_test.sh` verifies, for each of the five verbs, that:
1. `SKILL.md` exists and contains valid YAML frontmatter (`name`, `description`).
2. Mandatory invariant markers (`state_matrix.md`, `000-archive-ledger.md`, `release_checklist.md`) are present.
3. Frontmatter fields match expected safety flags (`disable-model-invocation: true` for freeze/done/release).

### 2.6 Self-Protection Precedence & Closing the Inode Aliasing Bypass

`templates/blast-radius-guard.sh` matches paths using string patterns on `$TARGET_FILE`, not filesystem inodes. When configuration or skills inside `.claude/` are symlinked to canonical targets inside `.agents/`, this introduces a dual-path aliasing attack vector:
* **The Vulnerability**: If an agent is blocked from writing to `.claude/settings.json`, but targets `.agents/claude/settings.json` directly, Section 3's always-allowed rule (`.agents/*`) would unconditionally permit the write. Because `.claude/settings.json` is a symlink to that file, the agent would successfully overwrite Claude Code's hook configuration and disarm its own write guard!
* **The Solution**: Section 2 (Self-Protection) evaluates **before** Section 3 (Always-Allowed Rules), and **must explicitly cover both sides of every symlink**:
```bash
# Section 2: Self-Protection (EVALUATED FIRST)
case "$TARGET_FILE" in
    .claude/settings.json|.claude/settings.local.json|*/.claude/settings.json|*/.claude/settings.local.json|\
    .agents/claude/*|*/.agents/claude/*|\
    .agents/skills/aapp-*|*/.agents/skills/aapp-*|\
    .claude/skills/aapp-*|*/.claude/skills/aapp-*)
        deny_action "Tampering with AAPP core configuration or governance skills is strictly prohibited."
        ;;
    .githooks/*|*/.githooks/*|.git/hooks/*|*/.git/hooks/*)
        deny_action "Tampering with AAPP git hooks engine is strictly prohibited."
        ;;
    .cursor/rules/*|*/.cursor/rules/*)
        deny_action "Tampering with agent rule files (.cursor/rules/) is strictly prohibited."
        ;;
esac

# Section 3: Always-Allowed Invariants (EVALUATED SECOND)
case "$TARGET_FILE" in
    .plans/*|.agents/*)
        exit 0
        ;;
    CHANGELOG.md|README.md|MANUAL.md|CODEMAP.md|ARCHITECTURE.md|ISSUES.md|.gitignore)
        exit 0
        ;;
    package.json|package-lock.json|composer.json|composer.lock|go.mod|go.sum|Cargo.toml|Cargo.lock|pyproject.toml|requirements.txt)
        exit 0
        ;;
esac
```
Because Section 2 takes precedence:
* Attempts by an agent to modify `.claude/settings.json` or `.agents/claude/*` are **hard-blocked**.
* Attempts by an agent to modify `.agents/skills/aapp-*` or `.claude/skills/aapp-*` are **hard-blocked**.
* Edits to custom user skills in `.agents/skills/` (e.g. `.agents/skills/my-deploy/`) fall through to Section 3 and remain freely writable.

#### Asymmetry Rule: Where to Author Custom Skills
* Notice that `.agents/skills/my-deploy/` is always-allowed (matching Section 3 `.agents/*`), but a write directed to `.claude/skills/my-deploy/` falls through to blast radius validation.
* **The Rule**: Custom skills must always be authored in `.agents/skills/<name>/SKILL.md` (the canonical workspace root). The `.claude/skills/` directory is an AAPP-managed bridge. Skills authored in `.agents/skills/` are universally discovered across Antigravity, Cursor, and Codex, and bridged to Claude Code during `aapp init`.

### 2.7 Granular Claude Configuration Bridge & Architectural Caveats

To enforce the core AAPP invariant that application code branches (`main`/`develop`) remain 100% clean of tool-specific configuration, `.claude/settings.json` is decoupled into the orphan `agents` worktree:
```text
.agents/claude/settings.json          ← canonical, versioned on the orphan 'agents' branch
.agents/skills/aapp-*/                ← canonical, versioned on the orphan 'agents' branch

.claude/                              ← real directory, gitignored on code branch
├── settings.json  -> ../.agents/claude/settings.json
├── skills/aapp-*  -> ../../.agents/skills/aapp-*
└── settings.local.json               ← uncommitted local machine state
```

#### Why Monolithic Symlinking `.claude -> .agents/claude` is Prohibited:
Claude Code generates local, machine-specific state into `.claude/` (e.g., `settings.local.json`, telemetry, session caches). If `.claude` were a wholesale symlink to `.agents/claude`, this local churn would land directly inside the orphan `agents` git worktree, creating untracked noise in `git -C .agents status` and standing accidental-commit risks. The granular bridge pattern ensures that only AAPP-governed configuration is versioned.

#### Non-Destructive Adopter Migration Pattern:
`lib/cmd_init.sh` executes a migration algorithm that preserves existing user settings and hook configurations (satisfying `tests/install_test.sh:290, 300` / `ISSUE-007` & `ISSUE-010`):
```bash
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
        fi
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
```

#### Path-Parameterized Settings Merge Helper:
The inline Python merge in `lib/cmd_init.sh` (which previously hardcoded `.claude/settings.json`) is extracted into a path-parameterized helper `merge_blast_radius_guard "$target" ["$source"]`:
```bash
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
                break

if not has_hook:
    target_data["hooks"]["PreToolUse"].append({
        "matcher": "Write|Edit|NotebookEdit",
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
    fi
}
```

#### The Two Architectural Caveats:
1. **The Activation Pre-requisite (Fresh Clones)**:
   On a fresh repository clone, `.claude/` is gitignored and the orphan worktrees (`.plans/`, `.agents/`, `.githooks/`) do not yet exist. Running `./aapp init` is the required activation step that mounts worktrees, generates the `.claude/` directory, untracks legacy code-branch `.claude/settings.json` if present, and establishes the symlinks. (Note: write protection via `.githooks/blast-radius-guard` already required `aapp init` to mount `.githooks/`, so this preserves existing workflow expectations).
2. **Windows Asymmetry & Copy-Fallback**:
   On systems where unprivileged symlink creation is disallowed (e.g., Windows without Developer Mode or restricted container volumes), `settings.json` falls back to a file copy. When `.claude/settings.json` diverges from `.agents/claude/settings.json` (e.g. if Claude Code writes new permissions or configs into `.claude/settings.json`), `sync_claude_settings()` automatically creates a `.bak` backup and merges divergent keys into the canonical file upon `aapp init`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: Pre-Freeze Empirical Verification Spike
- [ ] Task 0.1: Empirically verify that Claude Code runtime traverses relative symlinks for `.claude/settings.json` (triggering `PreToolUse` on denied paths) and `.claude/skills/*/SKILL.md` (registering `/aapp-*` slash commands).

### Phase 1: Author the Universal Skill Templates
- [ ] Task 1.1: Create `templates/skills/aapp-status/SKILL.md` — frontmatter (`name: aapp-status`, `description`, omitted `context` executes inline), 5-step four-pillar briefing contract with deterministic fallback file reading.
- [ ] Task 1.2: Create `templates/skills/aapp-digest/SKILL.md` — frontmatter (`name: aapp-digest`, `argument-hint: [idea or ISSUE-ID]`, omitted `context` executes inline to access chat conversation context), 6-step routing procedure (resolve → route to lane → NEW/AMEND → scaffold → clean pickup → report).
- [ ] Task 1.3: Create `templates/skills/aapp-freeze/SKILL.md` — frontmatter (`name: aapp-freeze`, `disable-model-invocation: true`, `argument-hint: [plan-name]`), 3-step boundary verification and greenlight lock procedure.
- [ ] Task 1.4: Create `templates/skills/aapp-done/SKILL.md` — frontmatter (`name: aapp-done`, `disable-model-invocation: true`, `argument-hint: [plan-name]`), 4-step archive procedure (move → ledger append → state matrix prune → worktree commit).
- [ ] Task 1.5: Create `templates/skills/aapp-release/SKILL.md` — frontmatter (`name: aapp-release`, `disable-model-invocation: true`, `context: fork`, `argument-hint: [version]`), 5-step preflight verification runbook against `.plans/release/release_checklist.md`.

### Phase 2: Wire Settings Decoupling, Skill Sync, Gitignore & Claude Bridge into `aapp init`
- [ ] Task 2.1: Add `.claude/` to the `.gitignore` setup loop in `lib/cmd_init.sh` and transparently untrack `.claude/settings.json` from git index on code branch with notice (`git rm --cached .claude/settings.json` if tracked).
- [ ] Task 2.2: Author canonical `templates/claude/settings.json`, extract inline Python merge into path-parameterized `merge_blast_radius_guard "$target" ["$source"]`, and implement non-destructive `sync_claude_settings()` in `lib/cmd_init.sh`: migrates existing real settings if present, merges diverged settings with backup (`${canonical_settings}.bak`) on Windows/Claude UI changes, ensures `blast-radius-guard` is merged preserving custom keys (`tests/install_test.sh:290, 300`), and establishes verified symlink with content check (`[ -s ] && grep`) and copy fallback.
- [ ] Task 2.3: Implement clean `sync_skills()` in `lib/cmd_init.sh`: removes destination dir prior to copy to eliminate stale dropped files, checks if `.claude/skills/` (and `.agents/skills/`) exist (creates if not), installs canonical skills to `.agents/skills/aapp-*`, and creates verified relative symlinks in `.claude/skills/aapp-*` with directory-copy fallback.
- [ ] Task 2.4: Call `sync_claude_settings()` and `sync_skills()` during `aapp init` (Phase 5) and update the completion banner with `➡️  Universal Skills: .agents/skills/ (bridged to .claude/skills/)`.
- [ ] Task 2.5: Add `.agents/claude/*`, `.claude/settings.local.json`, `.agents/skills/aapp-*`, and `.claude/skills/aapp-*` to Section 2 self-protection in `templates/blast-radius-guard.sh` and sync to `.githooks/blast-radius-guard`.
- [ ] Task 2.6: Update `templates/AGENTS.md` to document the Universal Skills, `/aapp-<verb>` slash command triggers, and `/aapp <verb>` aliases.
- [ ] Task 2.7: Update next-action advice footer in `lib/cmd_status.sh` from `/digest <idea>` to `/aapp-digest <idea>`.

### Phase 3: Automated Verification & Documentation
- [ ] Task 3.1: Extend `tests/install_test.sh` — verify `.claude/` added to `.gitignore`, canonical settings installation in `.agents/claude/settings.json`, `.claude/settings.json` symlink, skill installation in `.agents/skills/`, `.claude/skills/` bridge creation, preservation of non-AAPP custom skills and `settings.local.json`, and byte-for-byte upgrade overwrites without stale files.
- [ ] Task 3.2: Extend `tests/write-guard_test.sh` — verify Section 2 self-protection denies edits to `.agents/claude/settings.json` (closing the inode aliasing bypass), `.claude/settings.json`, `.claude/settings.local.json`, `.agents/skills/aapp-freeze/SKILL.md`, and `.claude/skills/aapp-freeze/SKILL.md` while permitting user skills.
- [ ] Task 3.3: Add drift assertions in `tests/install_test.sh` verifying all five skills declare valid frontmatter and match `AGENTS.md` invariants.
- [ ] Task 3.4: Update `README.md` and `MANUAL.md` documentation covering Universal Skills, `aapp-<verb>` naming, the depth-1 path invariant (`skills/*/SKILL.md`), the decoupled `.agents/claude/settings.json` configuration, and out-of-the-box compatibility across Cursor, OpenAI Codex, Google Antigravity, and Claude Code.
- [ ] Task 3.5: Run full test suite (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`) to ensure 100% pass rate.
- [ ] Task 3.6: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **LOCKED** — greenlit for execution)*

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/skills/aapp-status/SKILL.md` -> Four-pillar context recovery skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-digest/SKILL.md` -> Idea/issue routing and blueprint scaffolding skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-freeze/SKILL.md` -> Blast Radius lock and greenlight skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-done/SKILL.md` -> Archival lifecycle and ledger append skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-release/SKILL.md` -> Release preflight runbook skill.
- [ ] `NEW FILE` -> `templates/claude/settings.json` -> Canonical Claude Code settings template.
- [ ] `lib/cmd_init.sh` -> Add `sync_skills()`, `sync_claude_settings()`, untrack `.claude/settings.json`, wire into initialization flow, update completion banner.
- [ ] `lib/cmd_status.sh` -> Update next-action advice footer to recommend `/aapp-digest <idea>`.
- [ ] `templates/blast-radius-guard.sh` -> Add `.agents/claude/*`, `.claude/settings.local.json`, `.agents/skills/aapp-*`, and `.claude/skills/aapp-*` to self-protection.
- [ ] `templates/AGENTS.md` -> Document Universal Skills, `aapp-<verb>` naming, and slash command triggers.
- [ ] `tests/install_test.sh` -> Skill sync, symlink bridge, settings decoupling, upgrade, and drift assertions.
- [ ] `tests/write-guard_test.sh` -> Self-protection assertions for `.agents/claude/*` and AAPP skill namespace.
- [ ] `README.md` -> Document Universal Skills, Cursor/Codex depth compatibility, slash command table, and updated test counts.
- [ ] `MANUAL.md` -> Multi-agent skills reference section, path depth invariant, and Claude configuration decoupling.
- [ ] `templates/architecture.md` -> Add `.agents/skills/` and `.agents/claude/` to the structural architecture tree.
- [ ] `ARCHITECTURE.md` -> Mirror structural tree update.
- [ ] `CHANGELOG.md` -> Unreleased entry citing ISSUE-061.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/` -> Write-protected engine copies; regenerate via `aapp init`, never edit.
- [ ] `.agents/AGENTS.md` -> Generated from `templates/AGENTS.md` by delimited-block sync.
- [ ] `lib/cmd_upgrade.sh` -> Distribution fixes belong to ISSUE-049, not this plan.
- [ ] `lib/cmd_install.sh` -> Self-consumption fixes belong to ISSUE-051, not this plan.
- [ ] `templates/aapp-pre-commit` -> Commit-time enforcement is unchanged by this work.
- [ ] `aapp` -> No dispatcher verb is added; these are agent skills, not CLI subcommands.

> **Concurrent Incubator Plan Alignment**: Note that [`plan-feature-aapp-lifecycle-hooks.md`](plan-feature-aapp-lifecycle-hooks.md) is also in the Incubator and touches `lib/cmd_init.sh` and documentation. Skill synchronization (`sync_skills()`) and Claude settings management (`sync_claude_settings()`) are modularized as isolated helper functions in `lib/cmd_init.sh` to prevent git conflicts.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Namespace & Naming Convention (Resolved 2026-09-13):** **Adopt canonical `aapp-<verb>` naming.** Formally name skills and slash commands as `aapp-<verb>` (e.g. `/aapp-status`, `/aapp-digest`, `/aapp-freeze`, `/aapp-done`, `/aapp-release`) to guarantee 100% cross-platform Windows NTFS filesystem safety (colons `:` are forbidden characters on Windows). Retain `/aapp <verb>` and bare words as natural-language aliases in `AGENTS.md`.
* [x] **Question 2 — Commands vs. Skills (Resolved 2026-09-13):** **Adopt Universal AAPP Skills (`.agents/skills/`).** Pivoted from Claude-only flat commands (`.claude/commands/`) to cross-agent `SKILL.md` files housed in `.agents/skills/` and bridged to Claude Code (`.claude/skills/`). Provides native discovery in Google Antigravity, Cursor, Codex, and Claude Code, progressive disclosure, and context forking.
* [x] **Question 3 — Tool & Status Coupling (Resolved 2026-09-13):** **Standard Tool Execution with Direct Markdown Fallback.** Replaced brittle pre-render `` !`aapp status` `` macro with normal agent execution (`./aapp status`) and direct fallback to reading the 4 pillar files (`CHANGELOG.md`, `ISSUES.md` + `issues_road_map.md`, `state_matrix.md`, `pickup.md`). Guarantees the session never aborts on missing binaries or strict tool permissions.
* [x] **Question 4 — Canonical Claude Configuration & Inode Aliasing Bypass (Resolved 2026-09-14):** **Adopt Granular Configuration Bridge (`.agents/claude/settings.json`).** Untrack `.claude/settings.json` from the code branch and manage canonical configuration inside the orphan `agents` worktree. Protect both ends of the symlink in `templates/blast-radius-guard.sh` Section 2 (`.agents/claude/*` and `.claude/settings.json`) to completely close the path-string inode aliasing bypass. Documented non-destructive adopter settings migration (preserving tests 13 & 14), fresh-clone activation requirement, and Windows copy-fallback caveat.

---

## 📦 6. Change Log & Refinement History
* **2026-09-14:** Plan frozen and greenlit for execution (all open questions resolved, blast radius locked).
* **2026-09-14:** Eliminated settings deletion bug on divergence: added auto-backup and key-merging for diverged `.claude/settings.json`, extracted path-parameterized `merge_blast_radius_guard()` helper, and strengthened symlink verification (`[ -s ] && grep 'blast-radius-guard'`).
* **2026-09-14:** Hardened blueprint against regressions: added non-destructive settings migration algorithm preserving pre-existing user configurations (tests/install_test.sh:290, 300), resolved stale files on upgrade via clean destination directory recreation (`rm -rf` before `cp`), verified symlink resolution via target file check (`[ -e ... ]`), removed `context: fork` from digest to preserve chat history, and documented skill authoring asymmetry.
* **2026-09-14:** Upgraded blueprint with canonical Claude configuration decoupling (`.agents/claude/settings.json` -> `.claude/settings.json`), closed the inode aliasing bypass in `blast-radius-guard.sh` Section 2 (`.agents/claude/*`), added empirical pre-freeze verification task (Task 0.1), and documented fresh-clone activation and Windows fallback caveats.
* **2026-09-13:** Integrated granular per-skill symlinking with directory existence check, cross-platform Windows symlink fallback, self-protection precedence rules, and `cmd_status.sh` next-action footer alignment to `/aapp-digest`.
* **2026-09-13:** Added `.claude/` to the `.gitignore` configuration loop in `aapp init` (Phase 2 Task 2.1) to guarantee `.claude/settings.json` and `.claude/skills/` never pollute application code branches or git logs.
* **2026-09-13:** Standardized canonical skill directory and slash command naming to `aapp-<verb>` for cross-platform Windows NTFS safety (`:` forbidden on Windows). Defined depth-1 path invariant (`skills/*/SKILL.md`) ensuring out-of-the-box discovery across Cursor, Codex, Antigravity, and Claude Code; added README compatibility documentation requirement.
* **2026-09-13:** Pivoted from Claude-only flat commands (`.claude/commands/`) to Universal AAPP Skills (`.agents/skills/` with `.claude/skills/` bridge) per human decision (Option 1). Resolved Open Questions 2 and 3; updated blueprint, sync architecture, and execution tasks.
* **2026-09-10:** User confirmed `aapp` command family namespace (`/aapp:<verb>` and `/aapp <verb>`) to eliminate cross-environment collisions across Antigravity CLI and Claude Code; marked Open Question 1 resolved.
* **2026-09-10:** Verified `!` injection semantics: execution is pre-render and non-discretionary, a non-zero exit aborts the whole invocation, and a non-`allow` permission check does the same. Hardened §2.3, Task 3.4 and Open Question 3 accordingly.
* **2026-09-10:** Verified against the slash-command spec that no command-to-command delegation exists and that shadowing a built-in is total; recorded in Open Question 1.
* **2026-09-10:** Plan initialized from `ISSUE-061` (2026-09-10 audit sweep). Namespace, engine-sync semantics, self-protection scope and drift-test strategy specified; three open questions raised for human decision.
