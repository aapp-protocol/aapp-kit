# 🗺️ Plan P-21: Project Pause & Circuit Breaker Architecture
* **Created:** 2026-09-19 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** None
* **Plan ID:** P-21
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 🟠 Refining | 🔷 Frozen | 🟠 In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. An 🟠 In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 6. **Portability Invariant**: Never write machine-specific absolute paths or `file:///` URIs into tracked files. Use repo-relative paths or backticked basenames only.

---

## 1. Context & Architectural Goal

During modern agentic pair programming, developers frequently operate across multiple mediums simultaneously: multiple IDE windows, parallel terminal tabs, background subagents, or companion chats across different repositories. When no blueprint is actively in development (`🟠 In Development`), the AAPP governance engine operates in fail-open mode for repository files to preserve rapid developer velocity for quick scripts, tests, and typo fixes.

However, this creates a distinct operational vulnerability: **the un-planned cross-window and cross-project collision**. When a developer shifts attention to work on another project ("Project 2"), a loosely framed instruction in that secondary window or terminal can inadvertently find homonymous files (e.g. `templates/AGENTS.md` vs `.agents/AGENTS.md`, or matching filenames across repos) and alter or commit code in this repository without an active plan.

Rather than imposing bureaucratic ceremony on everyday single-line fixes, this plan introduces the **Master Emergency Brake / Project Circuit Breaker** (`aapp pause [reason]` and `aapp resume`):
1. **Zero Daily Friction**: When inactive (normal mode), developers and agents work at full velocity with zero overhead.
2. **Intentional Project Freeze**: When paused, the project is placed into a locked, read-only mode for codebase modifications.
3. **Cross-Medium Hook Realism ("Uncommittable, Not Untouchable")**:
   - **Local Session Writes (Layer 1)**: For sessions rooted in this repository, `blast-radius-guard` intercepts and blocks write tools at execution time.
   - **External & Cross-Repo Sessions (Layer 2)**: For sessions rooted in other directories or plain terminals (where Project 1's PreToolUse hook is not in the call stack), Layer 2 (`pre-commit`) serves as the strict, inescapable gate that executes inside this repository and rejects any code commit attempt.
4. **Preserved Cognitive Functions**: Reading code, codebase analysis, conversational Q&A, logging defects in `.plans/ISSUES.md`, drafting blueprints in `.plans/current/`, recording behavioral notes in `.agents/`, and capturing ideas in `.plans/pickup.md` remain 100% functional.

---

## 2. Technical Blueprint

### A. State Storage & Scoping (`--git-common-dir`)
The pause state is recorded in a lightweight, atomic state buffer:
- **Repo-Wide Scope (Default)**: `$(git rev-parse --git-common-dir)/aapp_paused`. Contains a single JSON or delimited record:
  ```json
  {"paused": true, "reason": "Switching focus to project-2", "timestamp": "2026-09-19T02:15:00Z", "user": "lorand"}
  ```
  *Scoping Invariant:* Using `--git-common-dir` rather than `--git-path` ensures the pause buffer is physically shared across all linked worktrees (`develop`, `.plans`, `.agents`) without isolation splits, while remaining uncommitted with zero git history noise.
- **Team-Wide Shared Scope (Optional `--shared`)**: If invoked with `--shared`, creates or updates `.plans/PAUSED.md`, committing the freeze to the `plans` branch so remote clones, team members, and CI pipelines inherit the project pause.

### B. Layer 1: Write-Time Interception (`templates/blast-radius-guard.sh`)
Add an early Circuit Breaker check in `templates/blast-radius-guard.sh` before Section 3:
1. Probe for pause state in `$(git rev-parse --git-common-dir 2>/dev/null)/aapp_paused` or `.plans/PAUSED.md`.
2. If paused:
   - Allow external scratchpads and authorized agent memory paths (Section 2c allowlist).
   - Allow `.plans/*` paths (blueprints, issues, pickup queue) and `.agents/*` paths (codemap, agent rules, project notes).
   - Deny all other file writes inside the repository:
     ```text
     🛑 [Project Circuit Breaker] The project is currently PAUSED.
        Reason: <reason>
        All code and template modifications are strictly refused.
        To resume modifications, run 'aapp resume'.
     ```

### C. Layer 2: Commit-Time Gate (`templates/aapp-pre-commit`)
Add a Circuit Breaker check in `templates/aapp-pre-commit`:
1. Probe for pause state in `$(git rev-parse --git-common-dir 2>/dev/null)/aapp_paused` or `.plans/PAUSED.md`.
2. If paused:
   - If staged files are strictly confined to `.plans/*` or `.agents/*`, allow the commit (documenting the pause, filing issues, or refining plans).
   - If any staged file touches tracked code, templates, libraries, or hooks, refuse the commit with exit code 1:
     ```text
     ❌ [Project Circuit Breaker] Commits to codebase are refused while the project is PAUSED.
        Reason: <reason>
        To resume commits, run 'aapp resume'.
     ```

### D. Emergency Escape Hatches
The circuit breaker provides explicit, standard escape hatches for emergency overrides:
- Write-time bypass: `SKIP_BLAST_RADIUS=1` bypasses Layer 1.
- Commit-time bypass: `git commit --no-verify` or `SKIP_BLAST_RADIUS=1` bypasses Layer 2.
These mechanisms are documented as deliberate emergency overrides for developer agency.

### E. CLI Ergonomics & Switchboard (`lib/cmd_pause.sh` & `aapp`)
Provide intuitive, memorable verbs:
- `aapp pause [reason]`: Engage the emergency brake with an optional descriptive reason.
- `aapp pause --shared [reason]`: Engage team-wide freeze via `.plans/PAUSED.md`.
- `aapp resume` (or `aapp unpause`): Disengage the emergency brake and restore normal operation.
- `aapp status`: Display prominent warning banner when paused in Context Recovery briefing:
  ```text
  🛑 PROJECT STATUS: PAUSED
     Reason: Switching focus to project-2
  ```

### F. Universal Skills Bridging
Author `templates/skills/aapp-pause/SKILL.md` (exposing `/aapp-pause` and `/aapp-resume`), bridged to `.agents/skills/` and `.claude/skills/`, and protected under Guard Section 2 self-protection.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core CLI & State Engine
- [ ] Task 1.1: Author `lib/cmd_pause.sh` implementing `cmd_pause` (using `--git-common-dir`), `cmd_resume`, and shared `.plans/PAUSED.md` support.
- [ ] Task 1.2: Integrate `pause`, `resume`, and `unpause` into `aapp` command router.
- [ ] Task 1.3: Update `lib/cmd_status.sh` to surface project pause status in the header of Context Recovery.
- [ ] Task 1.4: Update `lib/cmd_help.sh` documenting `aapp pause` and `aapp resume`.

### Phase 2: Guard & Hook Enforcement
- [ ] Task 2.1: Add Circuit Breaker check to `templates/blast-radius-guard.sh` using `--git-common-dir`, allowing `.plans/*` and `.agents/*`.
- [ ] Task 2.2: Add Circuit Breaker check to `templates/aapp-pre-commit` refusing code commits while paused.
- [ ] Task 2.3: Add `.agents/skills/aapp-pause` and `.claude/skills/aapp-pause` to Guard Section 2 self-protection.

### Phase 3: Universal Skill & Adoption Sync
- [ ] Task 3.1: Author `templates/skills/aapp-pause/SKILL.md` for agent chat interaction.
- [ ] Task 3.2: Update `lib/cmd_init.sh` to synchronize `aapp-pause` skill and mount hooks.

### Phase 4: Governance & Documentation
- [ ] Task 4.1: Document the Emergency Brake & Circuit Breaker protocol and escape hatches in `templates/AGENTS.md`.
- [ ] Task 4.2: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with pause state contracts.
- [ ] Task 4.3: Update `README.md`, `MANUAL.md`, and `CHEATSHEET.md`.

### Phase 5: Automated Verification & Regression Suite
- [ ] Task 5.1: Add test cases in `tests/write-guard_test.sh` asserting write refusal on code while paused, and allowing `.plans/*` and `.agents/*`.
- [ ] Task 5.2: Add test cases in `tests/pre-commit_test.sh` asserting commit refusal on code while paused across linked worktrees (`--git-common-dir`).
- [ ] Task 5.3: Add test cases in `tests/install_test.sh` validating `aapp-pause` skill sync and drift control.
- [ ] Task 5.4: Run full regression suite across all suites against 262-test baseline (target: 270+ passing tests).
- [ ] Task 5.5: Update `CHANGELOG.md` with release notes.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_pause.sh` -> NEW FILE: Implementation of pause and resume commands.
- [ ] `aapp` -> Add router cases for pause, resume, and unpause.
- [ ] `lib/cmd_status.sh` -> Display pause state in briefing banner.
- [ ] `lib/cmd_help.sh` -> Catalog and usage examples for pause/resume.
- [ ] `lib/cmd_init.sh` -> Sync aapp-pause skill and self-protection.
- [ ] `templates/blast-radius-guard.sh` -> Write-time interception on paused state.
- [ ] `templates/aapp-pre-commit` -> Pre-commit interception on paused state.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> NEW FILE: Slash command for pause/resume.
- [ ] `templates/AGENTS.md` -> Document Project Circuit Breaker protocol.
- [ ] `ARCHITECTURE.md` -> Architectural boundary documentation for pause buffer.
- [ ] `.agents/CODEMAP.md` -> Callable contracts for cmd_pause.sh.
- [ ] `README.md` -> User documentation for emergency brake.
- [ ] `MANUAL.md` -> Comprehensive operational guide in Chapter 5.
- [ ] `CHEATSHEET.md` -> Command cheat sheet updates.
- [ ] `tests/write-guard_test.sh` -> Automated tests for write-guard circuit breaker.
- [ ] `tests/pre-commit_test.sh` -> Automated tests for pre-commit circuit breaker.
- [ ] `tests/install_test.sh` -> Skill synchronization test coverage.
- [ ] `CHANGELOG.md` -> Feature entry under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Plan ID shorthand resolver engine is untouched.
- [ ] `lib/planning_health.sh` -> Planning health integrity engine is untouched.
- [ ] `.githooks/*` -> Hook dispatcher entrypoints are untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1: State Buffer Scoping Architecture**
  - *Resolution:* Default scope strictly uses `$(git rev-parse --git-common-dir)/aapp_paused` (repo-wide uncommitted, shared across all linked worktrees `.plans`, `.agents`, and code worktrees without git commit noise). An optional `--shared` flag creates or updates `.plans/PAUSED.md` (committed to `plans` branch for team-wide/remote synchronization). Per-worktree scoping (`--git-path`) is rejected as an architectural bug.
* [x] **Question 2: Complementary `aapp.planRequired` Globs**
  - *Resolution:* P-21 remains strictly focused on the Master Emergency Brake switch (`aapp pause` / `aapp resume`). Fine-grained permanent path gating (`aapp.planRequired`) is tracked as an orthogonal follow-up issue.
* [x] **Question 3: Permitted Path Boundaries During Pause**
  - *Resolution:* Both Layer 1 and Layer 2 permit writes and commits exclusively confined to `.plans/*` (planning, issues, pickup) and `.agents/*` (codemap, agent behavioral rules, project notes), enabling reflection and triage while blocking all code, templates, libraries, and tests.

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Plan refined from Red Team insights: corrected state buffer scoping from per-worktree (`--git-path`) to repo-wide (`--git-common-dir`); aligned `.agents/*` and `.plans/*` permission across both Layer 1 and Layer 2; documented cross-repo hook execution reality ("uncommittable, not untouchable"); added explicit documentation for `SKIP_BLAST_RADIUS=1` and `--no-verify` emergency escapes; calibrated test baselines against 262 passing tests; and resolved Open Questions 1, 2, and 3.
* **2026-09-19:** Plan initialized from user request for project-level blockage and multi-window pause mechanism.
