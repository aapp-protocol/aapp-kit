# 🗺️ Plan P-62: Guard Buffer And Workspace Fixtures
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-09
* **Target Issue / Milestone:** #114
* **Plan ID:** P-62
* **Changelog:** Fixed: write guard reads the active plan for files in subdirectories again; worktree tests follow `.workspace/{id}`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

`develop` fails 22 tests in 6 suites (#114). Two causes:
1. **Guard buffer path.** `templates/blast-radius-guard.sh:399-400` asks git for the buffer from the file's directory (`git -C "$TARGET_DIR" rev-parse --git-path aapp_active_plan`). From a subdirectory git answers relative to it (`../.git/aapp_active_plan`), but the result is prefixed with the worktree root. The buffer is never found; with two plans in development the guard refuses every file below the top level (`write-guard_test.sh`, 6 cases). `MINI_BUF` (`:404`) reuses the same path.
2. **Worktree fixtures.** The default worktree path is `.workspace/{id}`; five suites still expect `../{repo}-{id}`.

**Goal:** the suite is green again; the guard reads the right buffer for any file in any worktree.

---

## 2. Technical Blueprint

### 2.1 Guard
Resolve the buffer from the worktree root, not the file's directory: `git -C "$TARGET_WT_ROOT" rev-parse --git-path aapp_active_plan`, prefixed with `$TARGET_WT_ROOT` when relative.

### 2.2 Fixtures
`tests/integrate_test.sh`, `tests/verbs/done.sh`, `freeze-start.sh`, `issue.sh`, `status.sh`: worktree paths and recorded `Worktree:` lines follow `.workspace/P<n>` inside the sandbox project.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/write-guard_test.sh`: two plans in development, buffer set, a target in a subdirectory of the primary and of a `.workspace/` worktree: allowed; the other plan's target: denied.

### Phase 2: Implementation
- [ ] Task 2.1: Guard buffer resolution (2.1).
- [ ] Task 2.2: Fixtures (2.2).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `templates/blast-radius-guard.sh` -> Buffer path from the worktree root.
- [ ] `tests/write-guard_test.sh` -> Subdirectory targets with two plans and a buffer.
- [ ] `tests/integrate_test.sh` -> `.workspace/` paths.
- [ ] `tests/verbs/done.sh` -> `.workspace/` paths.
- [ ] `tests/verbs/freeze-start.sh` -> `.workspace/` paths.
- [ ] `tests/verbs/issue.sh` -> `.workspace/` paths.
- [ ] `tests/verbs/status.sh` -> `.workspace/` paths.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Worktree creation is P-61's and correct.
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init` after this plan.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Overlap with P-60 on `tests/verbs/done.sh`.** P-60 (⚡) lists it for its payload test, so `start` refuses P-62, while P-60 cannot finish on a red suite. (a) Move P-60's payload test to `tests/hooks_test.sh` (already a P-60 target) and drop `done.sh` from P-60 through a Refining round trip. (b) Leave `done.sh`'s fixture to P-60. Recommendation: (a).

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-09:** Drafted from #114 with the guard's root cause (relative `--git-path` from a subdirectory).
