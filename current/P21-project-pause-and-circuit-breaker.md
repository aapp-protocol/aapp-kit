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

During modern agentic pair programming, developers frequently operate across multiple mediums simultaneously: multiple IDE windows, parallel terminal tabs, background subagents, or mobile companion chats. When no blueprint is actively in development (`🟠 In Development`), the AAPP governance engine operates in fail-open mode for repository files to preserve rapid developer velocity for quick scripts, tests, and typo fixes.

However, this fail-open window creates a severe vulnerability: **the un-planned multi-window collision**. An agent instructed in another window or chat can misunderstand homonymous file structures (such as modifying `templates/AGENTS.md` instead of `.agents/AGENTS.md`, or touching production models instead of test fixtures) and silently alter or corrupt the codebase without an active plan.

Rather than imposing heavy ceremony on everyday single-line fixes, this plan introduces the **Master Emergency Brake / Project Circuit Breaker** (`aapp pause [reason]` and `aapp resume`):
1. **Zero Daily Friction**: When inactive (normal mode), developers and agents work at full velocity with zero overhead.
2. **Total Intentional Freeze**: When paused, Layer 1 (`blast-radius-guard`) and Layer 2 (`pre-commit`) lock all repository code, configurations, and templates against modifications by any agent in any window.
3. **Preserved Cognitive Functions**: Reading code, conversational Q&A, logging defects in `.plans/ISSUES.md`, drafting blueprints in `.plans/current/`, and jotting thoughts in `.plans/pickup.md` remain 100% functional.

---

## 2. Technical Blueprint

### A. State Storage & Scoping
The pause state is recorded in a lightweight, atomic state buffer:
- **Local Worktree Scope (Default)**: `$(git rev-parse --git-path aapp_paused)`. Contains a single JSON or delimited record:
  ```json
  {"paused": true, "reason": "Reviewing multi-window architecture updates", "timestamp": "2026-09-19T01:50:00Z", "user": "lorand"}
  ```
  Local scoping ensures zero git noise, instant activation, and immunity to git conflicts across branch switches.
- **Shared Scope (Optional `--shared`)**: If invoked with `--shared`, creates or updates `.plans/PAUSED.md`, committing the freeze across worktrees and remote clones.

### B. Layer 1: Write-Time Interception (`templates/blast-radius-guard.sh`)
Add an early Circuit Breaker check in `templates/blast-radius-guard.sh` before Section 3:
1. Check if the paused buffer exists and is active.
2. If paused:
   - Allow external scratchpads and authorized agent memory paths (Section 2c).
   - Allow `.plans/*` paths (blueprints, issues, pickup queue).
   - Deny all other file writes inside the repository:
     ```text
     🛑 [Project Circuit Breaker] The project is currently PAUSED.
        Reason: <reason>
        All code and template modifications are strictly refused.
        To resume modifications, run 'aapp resume'.
     ```

### C. Layer 2: Commit-Time Gate (`templates/aapp-pre-commit`)
Add a Circuit Breaker check in `templates/aapp-pre-commit`:
1. Check if the project is paused.
2. If paused:
   - If staged files are strictly confined to `.plans/*` or `.agents/*`, allow the commit (documenting the pause or recording planning thoughts).
   - If any staged file touches tracked code, templates, libraries, or hooks, refuse the commit with exit code 1.

### D. CLI Ergonomics & Switchboard (`lib/cmd_pause.sh` & `aapp`)
Provide intuitive, memorable verbs:
- `aapp pause [reason]`: Engage the emergency brake with an optional descriptive reason.
- `aapp resume` (or `aapp unpause`): Disengage the emergency brake and restore normal operation.
- `aapp status`: Display prominent warning banner when paused:
  ```text
  🛑 PROJECT STATUS: PAUSED
     Reason: Reviewing multi-window architecture updates
  ```

### E. Universal Skills Bridging
Author `templates/skills/aapp-pause/SKILL.md` (exposing `/aapp-pause` and `/aapp-resume`), bridged to `.agents/skills/` and `.claude/skills/`, and protected under Guard Section 2 self-protection.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core CLI & State Engine
- [ ] Task 1.1: Author `lib/cmd_pause.sh` implementing `cmd_pause`, `cmd_resume`, and status helpers.
- [ ] Task 1.2: Integrate `pause`, `resume`, and `unpause` into `aapp` command router.
- [ ] Task 1.3: Update `lib/cmd_status.sh` to surface project pause status in the header of Context Recovery.
- [ ] Task 1.4: Update `lib/cmd_help.sh` documenting `aapp pause` and `aapp resume`.

### Phase 2: Guard & Hook Enforcement
- [ ] Task 2.1: Add Circuit Breaker check to `templates/blast-radius-guard.sh` denying code writes while paused.
- [ ] Task 2.2: Add Circuit Breaker check to `templates/aapp-pre-commit` refusing code commits while paused.
- [ ] Task 2.3: Add `.agents/skills/aapp-pause` and `.claude/skills/aapp-pause` to Guard Section 2 self-protection.

### Phase 3: Universal Skill & Adoption Sync
- [ ] Task 3.1: Author `templates/skills/aapp-pause/SKILL.md` for agent chat interaction.
- [ ] Task 3.2: Update `lib/cmd_init.sh` to synchronize `aapp-pause` skill and mount hooks.

### Phase 4: Governance & Documentation
- [ ] Task 4.1: Document the Emergency Brake & Circuit Breaker in `templates/AGENTS.md`.
- [ ] Task 4.2: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with pause state contracts.
- [ ] Task 4.3: Update `README.md`, `MANUAL.md`, and `CHEATSHEET.md`.

### Phase 5: Automated Verification & Regression Suite
- [ ] Task 5.1: Add test cases in `tests/write-guard_test.sh` asserting write refusal on code while paused, and allowing `.plans/*`.
- [ ] Task 5.2: Add test cases in `tests/pre-commit_test.sh` asserting commit refusal on code while paused.
- [ ] Task 5.3: Add test cases in `tests/install_test.sh` validating `aapp-pause` skill sync and drift control.
- [ ] Task 5.4: Run full test suite across all suites (target: 270+ passing tests).
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

* [ ] **Question 1: Default Scope: Local Worktree vs. Shared `.plans/`**
  - *Option A (Local First):* By default, `aapp pause` sets `.git/aapp_paused`. It affects all processes on the local machine without creating git commit noise. A `--shared` flag optionally creates `.plans/PAUSED.md`.
  - *Option B (Shared First):* `aapp pause` commits `.plans/PAUSED.md` immediately so all clones/branches inherit the pause.
  - *Recommendation:* Option A (Local First) keeps the brake instantaneous and zero-noise for multi-window local work, while `--shared` handles team coordination.
* [ ] **Question 2: Complementary `aapp.planRequired` Globs**
  - *Question:* Should this plan also implement targeted `aapp.planRequired` configuration (e.g. `templates/*` always requiring a plan even when unpaused), or keep P-21 strictly dedicated to the Emergency Brake switch?
  - *Recommendation:* Keep P-21 focused on the Emergency Brake; evaluate `aapp.planRequired` as a separate follow-up if fine-grained path gating is needed.

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Plan initialized from user request for project-level blockage and multi-window pause mechanism.
