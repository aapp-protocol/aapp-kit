# 🗺️ Plan P-29: Universal Skills Pruning, Fallback Invariants & Antigravity Autocomplete Parity
* **Created:** 2026-09-21 | **Last Refined:** 2026-09-21
* **Target Issue / Milestone:** #70, #72 *(supersedes #70 and #72 upon completion)*
* **Plan ID:** P-29
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement
An audit of AAPP's Universal Skills layer revealed three structural usability and integration defects across developer environments:

1. **Skill Bloat & Prompt Token Tax**: `templates/skills/` currently defines 12 distinct skill directories. Several of these (`aapp-hooks`, `aapp-freeze-start`, `aapp-active`) are not high-level cognitive agent workflows; they are low-level CLI commands or static documentation. Because AI coding agents ingest skill names and descriptions into system prompts on every session turn, shipping non-skills pollutes agent context and burns prompt tokens.
2. **Antigravity IDE Autocomplete Suppression (#70)**: In `templates/skills/*/SKILL.md`, `disable-model-invocation: true` suppresses skills in the Antigravity IDE UI, hiding slash commands from chat autocomplete and preventing natural invocation.
3. **Parameter-less Dead-Ends & Recommendation Loops (#72)**: Skills currently fail or dead-end when invoked without arguments (e.g., bare `/aapp-digest` fails over an empty pickup queue; `/aapp-start` without arguments halts). Simultaneously, `lib/cmd_status.sh` blindly prints *"Run 'aapp init' to sync worktrees, or use /aapp-digest <idea> in chat"* even when the pickup queue is empty and worktrees are already initialized, locking the user into a dead-end recommendation cycle.
4. **CLI vs. Agent Skill Boundary**: One-time administrative or configuration commands (such as the `ai-*` attribution family) properly belong strictly in the terminal CLI, not in agent skills. Universal skills should be reserved strictly for core interactive agent workflows.

### Architectural Goal
1. **Prune the Universal Skills Inventory**: Retire `aapp-hooks`, `aapp-freeze-start`, and `aapp-active` from `templates/skills/`, retaining them strictly as terminal CLI verbs. Focus the skills catalog on true cognitive workflows (`aapp-status`, `aapp-plan` / `plan`, `aapp-digest`, `aapp-freeze`, `aapp-start`, `aapp-done`, `aapp-pause`, `aapp-release`).
2. **Implement the No-Dead-End Invariant**: Enhance remaining skills so bare invocations never fail:
   - Bare `aapp-digest`: If `pickup.md` is empty, query `.plans/ISSUES.md` and offer top open issues as promotion candidates; if both are empty, prompt for an inline idea.
   - Bare `aapp-start`: Auto-select if exactly 1 frozen plan exists; list candidates if multiple; guide the user to freeze an incubator plan if 0 are ready.
   - Bare `aapp-done`: Resolve active plan from `$(git rev-parse --git-path aapp_active_plan)` or list in-development plans.
   - Bare `aapp-freeze`: List ready incubator plans for locking.
3. **Restore Antigravity Autocomplete Parity**: Set `disable-model-invocation: false` across all retained skills so they register cleanly in Antigravity chat autocomplete.
4. **Dynamic Context Recovery Footer**: Update `lib/cmd_status.sh` to dynamically evaluate repo state—suggesting digest only when pickup has items, issue promotion when issues exist, or plan freezing when plans are ready, while omitting `aapp init` once worktrees are active.
5. **Test & Documentation Synchronization**: Update `tests/install_test.sh` drift control assertions, resync `.claude/skills/` and `.agents/skills/`, and update `CHEATSHEET.md` and `MANUAL.md`.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Skill Inventory & Boundary Matrix (CLI vs. Agent Skill)

| Component | Target Location | Disposition | Rationale |
| :--- | :--- | :--- | :--- |
| **`aapp-status`** | `.agents/skills/aapp-status/` | **Retained** | Core desk context recovery workflow (always parameter-less). |
| **`aapp-plan` / `plan`** | `.agents/skills/aapp-plan/` | **Retained** | Canonical architectural blueprint scaffolding. |
| **`aapp-digest`** | `.agents/skills/aapp-digest/` | **Retained** | High-level idea/issue digestion and promotion workflow. |
| **`aapp-freeze`** | `.agents/skills/aapp-freeze/` | **Retained** | Blast radius verification and plan design locking. |
| **`aapp-start`** | `.agents/skills/aapp-start/` | **Retained** | Worktree binding and active plan execution transition. |
| **`aapp-done`** | `.agents/skills/aapp-done/` | **Retained** | Implementation verification and plan archival. |
| **`aapp-pause`** | `.agents/skills/aapp-pause/` | **Retained** | Worktree context suspension and state matrix update. |
| **`aapp-release`** | `.agents/skills/aapp-release/` | **Retained** | Release runbook execution and changelog stamp. |
| **`aapp-hooks`** | *CLI Only* (`aapp hooks`) | **Retired from Skills** | Documentation/admin schema reference; not an agent workflow. |
| **`aapp-freeze-start`** | *CLI Only* (`aapp freeze-start`) | **Retired from Skills** | Redundant compound shortcut of `freeze` + `start`. |
| **`aapp-active`** | *CLI Only* (`aapp active`) | **Retired from Skills** | Low-level git path buffer inspector/setter; not a skill. |
| **`ai-*` family** | *CLI Only* (`aapp ai-*`) | **CLI Only (Invariant)** | One-time workstation/repo setup; zero reason for skill presence. |

### 2.2 The No-Dead-End Invariant & Fallback Specifications

Every retained skill must adhere to the **No-Dead-End Invariant**: an invocation without arguments must never abort with an unhelpful error or blank output. It must actively inspect local workspace state, infer the target, or present a numbered candidate menu.

```
Bare Skill Invocation
   │
   ├── /aapp-digest (bare)
   │     ├── pickup.md has entries? ──────> List entries & ask user to select
   │     ├── ISSUES.md has open items? ───> List top open issues & offer promotion
   │     └── both empty? ─────────────────> Prompt: "What idea or feature would you like to plan?"
   │
   ├── /aapp-start (bare)
   │     ├── exactly 1 frozen plan? ──────> Auto-select & confirm start: "Starting P-XX..."
   │     ├── multiple frozen plans? ──────> List frozen candidates & ask user to select
   │     └── 0 frozen plans? ─────────────> Report: "No frozen plans in state_matrix.md. Ready in Incubator: P-YY. Freeze first?"
   │
   ├── /aapp-done (bare)
   │     ├── active plan buffer set? ─────> Confirm archival: "Archive active plan P-XX to .plans/done/?"
   │     ├── 1 plan in development? ──────> Auto-target active plan
   │     └── multiple in development? ────> List in-development plans & ask user to select
   │
   └── /aapp-freeze (bare)
         ├── incubator plans ready? ──────> List incubator candidates & ask user which to freeze
         └── 0 incubator plans? ──────────> Report: "No incubator plans found in .plans/current/."
```

### 2.3 Dynamic Context Recovery Footer (`lib/cmd_status.sh`)

Replace the static, hardcoded footer in `lib/cmd_status.sh` with a dynamic context evaluator:

```bash
# Evaluate Next Action Dynamically
local next_action=""
local pickup_count=0
if [ -f "$PLANS_DIR/pickup.md" ]; then
    pickup_count=$(grep -c '^[[:space:]]*[-*][[:space:]]\+\[[[:space:]]\]' "$PLANS_DIR/pickup.md" 2>/dev/null || true)
    [ "$pickup_count" -eq 0 ] && pickup_count=$(grep -c '^[[:space:]]*[-*][[:space:]]' "$PLANS_DIR/pickup.md" 2>/dev/null || true)
fi

if [ "$pickup_count" -gt 0 ]; then
    next_action="Run '/aapp-digest <idea>' (or 'aapp digest <idea>') to work a queued pickup idea."
elif [ -f "$PLANS_DIR/ISSUES.md" ] && [ -n "$FIRST_ISSUE_NUM" ]; then
    next_action="Run '/aapp-digest #$FIRST_ISSUE_NUM' to promote open issue #$FIRST_ISSUE_NUM, or inspect issues_road_map.md."
elif [ -n "$FIRST_READY_PLAN" ]; then
    next_action="Run '/aapp-freeze $FIRST_READY_PLAN' to review and lock incubator blueprint $FIRST_READY_PLAN."
elif [ -n "$FIRST_FROZEN_PLAN" ]; then
    next_action="Run '/aapp-start $FIRST_FROZEN_PLAN' to activate frozen plan $FIRST_FROZEN_PLAN into development."
else
    next_action="Run '/aapp-plan' to draft a new blueprint, or 'aapp help' to browse available commands."
fi

# Do not recommend 'aapp init' if worktrees are already properly mounted
if [ "$WORKTREES_SYNCED" -ne 1 ]; then
    next_action="Run 'aapp init' to complete worktree setup. $next_action"
fi

echo "➡️  Next Action: $next_action"
```

### 2.4 Antigravity IDE Autocomplete Parity (`disable-model-invocation`)

Update frontmatter across all retained skills:
```yaml
---
name: aapp-<verb>
description: <Concise, actionable description of the workflow>
disable-model-invocation: false
argument-hint: "<optional or required parameters>"
---
```
- `disable-model-invocation: false` ensures the Antigravity IDE indexes the skill and presents it in the chat `/` slash command popup.
- Claude Code bridging continues to function identically via `.claude/skills/` symlinks.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Retired skills (`aapp-hooks`, `aapp-freeze-start`, `aapp-active`) continue to exist as first-class CLI verbs in `aapp` (`aapp hooks`, `aapp freeze-start`, `aapp active`). No CLI functionality is removed or degraded.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Test Setup & Drift Assertions
- [ ] Task 1.1: Update `tests/install_test.sh` (Test 42 / skill drift control) to expect the pruned list of 8 retained skills instead of 12.
- [ ] Task 1.2: Add assertions in `tests/install_test.sh` verifying all retained skills have `disable-model-invocation: false`.

### Phase 2: Skill Inventory Pruning
- [ ] Task 2.1: Remove retired skill directories from `templates/skills/`:
  - Delete `templates/skills/aapp-hooks/`
  - Delete `templates/skills/aapp-freeze-start/`
  - Delete `templates/skills/aapp-active/`
- [ ] Task 2.2: Update `sync_skills()` in `lib/cmd_init.sh` to remove obsolete skill symlinks or directories in `.agents/skills/` and `.claude/skills/`.

### Phase 3: No-Dead-End Fallback Implementations
- [ ] Task 3.1: Update `templates/skills/aapp-digest/SKILL.md` with the 3-tier fallback procedure (pickup entries -> open issues -> inline prompt) and `disable-model-invocation: false`.
- [ ] Task 3.2: Update `templates/skills/aapp-start/SKILL.md` with candidate auto-selection / menu fallback and `disable-model-invocation: false`.
- [ ] Task 3.3: Update `templates/skills/aapp-done/SKILL.md` with active buffer inference and candidate list fallback and `disable-model-invocation: false`.
- [ ] Task 3.4: Update `templates/skills/aapp-freeze/SKILL.md`, `templates/skills/aapp-pause/SKILL.md`, `templates/skills/aapp-release/SKILL.md`, and `templates/skills/aapp-plan/SKILL.md` to ensure `disable-model-invocation: false` and actionable instructions.

### Phase 4: Dynamic Status Footer
- [ ] Task 4.1: Update `lib/cmd_status.sh` to compute `next_action` dynamically based on pickup items, open issues, and plan matrix states.
- [ ] Task 4.2: Suppress the `"Run 'aapp init'"` advice in `lib/cmd_status.sh` when worktrees are already mounted and synced.

### Phase 5: Verification, Worktree Sync & Documentation
- [ ] Task 5.1: Run `tests/install_test.sh` and verify all tests pass without drift errors.
- [ ] Task 5.2: Resync local `.agents/skills/` and `.claude/skills/` to reflect the pruned, updated skills.
- [ ] Task 5.3: Update `CHEATSHEET.md` and `MANUAL.md` to document the streamlined slash commands and fallback behaviors.
- [ ] Task 5.4: Relocate resolved issues #70 and #72 in `.plans/ISSUES.md` upon completion.
- [ ] Task 5.5: Update `CHANGELOG.md` and run syntax checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Add 3-tier fallback logic and set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Add candidate selection fallback and set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Add active buffer inference and set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> Update fallback instructions and set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-release/SKILL.md` -> Set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Set `disable-model-invocation: false`.
- [ ] `templates/skills/plan/SKILL.md` -> Set `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-status/SKILL.md` -> Ensure `disable-model-invocation: false`.
- [ ] `templates/skills/aapp-hooks/` -> [DELETE] Retired from skills (retained in CLI).
- [ ] `templates/skills/aapp-freeze-start/` -> [DELETE] Retired from skills (retained in CLI).
- [ ] `templates/skills/aapp-active/` -> [DELETE] Retired from skills (retained in CLI).
- [ ] `lib/cmd_status.sh` -> Implement dynamic `Next Action` footer.
- [ ] `lib/cmd_init.sh` -> Prune deleted skills during `sync_skills()`.
- [ ] `tests/install_test.sh` -> Update Test 42 skill drift assertions and add fallback tests.
- [ ] `CHEATSHEET.md` -> Update slash commands table.
- [ ] `MANUAL.md` -> Document trimmed skills and fallback behaviors.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Plan ID resolution logic is stable and out of scope.
- [ ] `lib/cmd_hook.sh` -> Hook engine remains intact.
- [ ] `lib/cmd_upgrade.sh` -> Upgrade mechanics are out of scope.
- [ ] `.githooks/*` -> Git hooks engine is out of scope.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected (synced via `aapp init`).
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected (synced via `aapp init`).

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — CLI vs. Skill Boundary for `aapp-pause`. → RESOLVED (developer, 2026-09-21): Retain `aapp-pause` as a skill.** Pausing a plan involves capturing remaining tasks, adding a dated refinement note, and updating `state_matrix.md` to `⏸️ Paused`, making it a valid cognitive agent workflow.
* [x] **Question 2 — Skill Deletion Sync in Existing Repositories. → RESOLVED (developer, 2026-09-21): Explicit pruning in `sync_skills()`.** When `aapp init` runs, `sync_skills()` will clean up obsolete skill directories in `.agents/skills/` and symlinks in `.claude/skills/` that no longer exist in `templates/skills/`.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-21:** Blueprint scaffolded on developer direction. Formulates Universal Skills pruning (retiring `aapp-hooks`, `aapp-freeze-start`, `aapp-active`), the No-Dead-End Invariant across retained skills, Antigravity IDE autocomplete parity (`disable-model-invocation: false`), and dynamic context recovery footer in `lib/cmd_status.sh`. Supersedes issues #70 and #72.
