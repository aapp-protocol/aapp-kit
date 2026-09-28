---
name: aapp-done
description: Complete lifecycle and archive an implemented blueprint. Moves plan to done/, appends to archive ledger, and cleans active state matrix.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP Done (Plan Completion & Archival)

Complete the implementation lifecycle and archive a finished blueprint via the authoritative CLI engine.

## Execution Procedure

### Step 1: Execute Authoritative CLI Verb
Invoke the deterministic archival verb:
```bash
aapp done [target]
```
*(If `<target>` is omitted, `aapp done` automatically inspects the active execution buffer `$(git rev-parse --git-path aapp_active_plan)`).*

### Step 2: Deterministic Failure Branch (Fail Closed)
If `aapp done` exits non-zero, **STOP immediately**.
**Do NOT attempt manual file moves, manual header regex substitutions, archive ledger edits, or raw git commits on the plans worktree.** Manual bypasses corrupt the ledger, skip TDD assertions, and bypass pre-done verification gates.

Parse and explain the exact CLI diagnostic:
- **Missing Recorded Commits**: If the plan has unrecorded commits, run `aapp commit adopt <sha>...` to associate the implementation commits with the plan.
- **Unticked TDD Assertions**: If TDD assertions remain unchecked, verify that all declared failure tests pass and check them off.
- **Worktree Collision**: If another worktree holds the plan, resolve the conflict before archiving.
- **Hook Veto**: If a `pre-done` hook vetoed completion, address the specific condition reported by the hook.

### Step 3: Success Confirmation
On exit 0, `aapp done` has moved the plan to `.plans/done/`, updated the plan header status, appended to `.plans/done/000-archive-ledger.md`, and updated `.plans/state_matrix.md`.

Report the structured completion record (Plan ID, verification SHA, and archive summary) to the user.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
