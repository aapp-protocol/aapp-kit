# 🗺️ Plan P-49: Refine Subject Precheck & Blocked Token
* **Created:** 2026-10-03 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** None (follow-up to P-47 and P-28)
* **Plan ID:** P-49
* **Changelog:** Fixed: `aapp refine` checks the commit subject length and shape before committing, and blocks a plan on an issue with `aapp refine <id> blocked <num>`
* **Status:** ⚡ In Development
* **Base:** `1bb9d4e` (develop)
* **Commits:** `9fc51ee` (develop)
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 1. Context & Architectural Goal

`aapp refine <id> "<what changed>"` (P-47) commits a plan edit as `plan(refine): <id> <what changed>`. It hands that subject straight to git, so P-28's `commit-msg` gate is the first thing that measures it. A message that pushes the subject past `aapp.subjectMaxLen` (default 72) is refused only after the commit attempt, with the gate's generic advice and no hint of how much to cut. This happened in practice: `aapp refine P-48 "rework: drop lock, shared docs, changelog token, union merge"` was refused, and the retry needed a second guess at the length.

A message containing a newline would also put text on line 2 of the commit message, which the same gate refuses (blank-line invariant).

**Goal:** `aapp refine` validates the subject it is about to write, with the same limit the gate uses, and refuses before any git work with an exact instruction. Same pattern as P-48's changelog check: catch it at the CLI, keep the gate as the backstop.


**Also: blocking a plan has no command.** Setting a plan `🟥 BLOCKED` means hand-editing its Status line and adding `* **Blocked On:**`, then committing with `aapp refine`. The P-52/P-54 review (RFC C71) makes this the hotfix step for blocking bugs found in a plan worktree, so it should be one command. **Added goal:** a `blocked` token on `refine` (no new verb) sets both lines and commits them. The state matrix stays `aapp matrix`'s job: `aapp refine <id> blocked <num> && aapp matrix`.
---

## 2. Technical Blueprint

### 2.1 Subject pre-check in `cmd_refine` (`lib/cmd_plan.sh`)
After resolving the plan and before `plans_commit`:
- **Shape:** the message must be one line. A message containing a newline → exit 1: `❌ [Refine] The message must be a single line (it becomes the commit subject).`
- **Length:** build the subject exactly as committed (`plan(refine): <plan-id> <msg>`), read the limit the gate uses (`git config --int aapp.subjectMaxLen`, default 72), and when the subject is longer → exit 1:
  ```text
  ❌ [Refine] Commit subject is 81 characters; the limit is 72 (aapp.subjectMaxLen).
     Shorten the message by 9 characters: "rework: drop lock, shared docs, changelog token, union merge"
  ```
- Both checks run before staging, so a refused call leaves the plan worktree unchanged; the plan file stays modified and the author retries with a shorter message.
- The `commit-msg` gate is unchanged and still the final authority.

### 2.2 `aapp refine <id> blocked <num>` (`lib/cmd_plan.sh`)
- **Write function.** A write-only function in `lib/cmd_plan.sh`, `plan_block_on <plan_file> <num>`, sets `* **Status:** 🟥 BLOCKED` and appends `#<num>` to `* **Blocked On:**`, a comma-separated list (no duplicates). On the first block, it records the status the plan had before (`* **Blocked On:** #41 (was ⚡ In Development)`); later entries keep that record. It writes the file only: no commit, no matrix.
- **`refine … blocked <num>`** checks that `#<num>` is an active row in `ISSUES.md`, calls `plan_block_on`, then commits the plan file alone as `plan(refine): <id> blocked on #<num>`. No message argument and no prior hand edit needed. A plan that is already BLOCKED gets the issue appended, not refused; an issue already listed changes nothing (`ℹ️ … already blocked on #<num>`).
- **Second caller.** `aapp issue hotfix` (P-52) calls `plan_block_on` in-process, then writes its other files and makes one commit. For that, `lib/cmd_plan.sh` gains a load-functions-only guard (`AAPP_PLAN_LIB_ONLY=1`: source the functions, skip the command dispatch), mirroring `cmd_matrix.sh`'s `AAPP_MATRIX_LIB_ONLY`.
- Does not touch `state_matrix.md`: `aapp matrix` re-derives it (chain `&& aapp matrix`). Unblocking is P-52's `issue close` path, which restores the recorded previous status.

### 2.3 Scope
- Only `aapp refine`. Lifecycle verbs build fixed, short subjects and need no check.
- Length is measured in characters as the gate measures them (`${#subject}`), so both always agree.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/refine.sh`: a message making the subject exceed `aapp.subjectMaxLen` exits 1 before any commit, naming the length, the limit and how many characters to cut; a lowered `aapp.subjectMaxLen` is honoured; a multi-line message exits 1; the plans worktree HEAD is unchanged after both refusals.
- [ ] Task 1.2: `tests/verbs/refine.sh`: `blocked <num>` sets Status and `Blocked On:` (with the previous status) and commits only the plan; a second `blocked` on another issue appends it and keeps the recorded previous status; the same issue again changes nothing; refuses an unknown or closed issue; the matrix is untouched until `aapp matrix`; sourcing `lib/cmd_plan.sh` with `AAPP_PLAN_LIB_ONLY=1` defines `plan_block_on` without running a command, and calling it writes the file without committing.

### Phase 2: Implementation
- [ ] Task 2.1: Single-line and length checks in `cmd_refine` (`lib/cmd_plan.sh`).
- [ ] Task 2.2: `lib/docs/verbs/refine.md`: two new failure modes, the `blocked` token, and their tests.
- [ ] Task 2.3: `plan_block_on` write function, the `blocked <num>` token in `cmd_refine`, and the `AAPP_PLAN_LIB_ONLY` guard in `lib/cmd_plan.sh`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `MANUAL.md` (Committing Plan Edits): the message is one line and must keep the subject within `aapp.subjectMaxLen`; blocking a plan with `aapp refine <id> blocked <num> && aapp matrix`.
- [ ] Task 3.2: Run `./aapp test strict quiet`.
- [ ] Task 3.3: AGENTS.md (both) Issue Escape Triage and `CHEATSHEET.md`: the `blocked` token replaces hand-editing the Status line.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> Subject shape and length checks, `plan_block_on`, the `blocked` token in `cmd_refine`, the `AAPP_PLAN_LIB_ONLY` guard.
- [ ] `lib/docs/verbs/refine.md` -> Contract: new failure modes and tests.
- [ ] `tests/verbs/refine.sh` -> Refusal and `blocked` token tests.
- [ ] `MANUAL.md` -> Message rules and `blocked` token for `aapp refine`.
- [ ] `CHEATSHEET.md` -> `aapp refine <id> blocked <num>`.
- [ ] `templates/AGENTS.md` -> Issue Escape Triage uses the `blocked` token.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-commit-msg` -> The gate stays the final authority, unchanged.
- [ ] `lib/commit_engine.sh` -> `plans_commit` is shared by every lifecycle verb; the check belongs in `cmd_refine`.
- [ ] `lib/cmd_matrix.sh` -> The matrix stays `aapp matrix`'s job; `refine` does not call it.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Also give pickup and issue-triage commits a verb? → RESOLVED (developer, 2026-10-03): (a), in a separate plan.** P-49 stays the subject check. Pickup and issue-triage commits move onto existing verbs (no new verb) in the plan that also covers plan rename (`aapp refine <id> slug <new>`), link repair on `aapp done`, and promotion (`aapp draft <slug> issue <num>`).

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Plan activated into ⚡ In Development via start.
* **2026-10-07:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-07:** Renamed `aapp issue handoff` to `aapp issue hotfix` (developer): vendor-neutral, and one word with `Emergency Hotfixes:` and `aapp.maxEmergencyHotfixes`; misuse is caught both ways (`hotfix` needs a bound plan, `fix` is refused in a plan worktree).
* **2026-10-05:** Aligned with the P-52/P-54 review RFC (settled design; C96, C99): `blocked` appends to a `Blocked On:` list instead of refusing an already blocked plan; the writing is a write-only function (`plan_block_on`) that `refine` commits and P-52's `issue handoff` calls in-process through an `AAPP_PLAN_LIB_ONLY` guard.
* **2026-10-05:** Added the `blocked <num>` token to `aapp refine` (developer, from the P-52/P-54 review, RFC C71): sets BLOCKED and `Blocked On:` in one command; `refine` and `aapp matrix` stay separate verbs, chained by the caller.
* **2026-10-03:** Plan drafted after a P-48 refine commit was refused by the `commit-msg` gate for subject length, with no hint of how much to cut.
