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
**Plan in a worktree?** Rebase it onto the development branch first: `git rebase --autostash <devBranch>`. Fixes to its files may have landed since it started; resolve any conflict in its own lines, re-run its tests, then archive.

Invoke the deterministic archival verb:
```bash
aapp done [target]
```
*(If `<target>` is omitted, `aapp done` automatically inspects the active execution buffer `$(git rev-parse --git-path aapp_active_plan)`).*

**Plan with its own worktree:** `aapp done` refuses while that worktree has uncommitted changes.
- With `aapp.integrate` = `squash`, `ff` or `hook`, the same command also integrates the plan branch into its parent branch (the one in `* **Base:**`) after archiving, and removes the worktree and branch. Every integration check runs first: a refusal (branch not rebased, dirty main checkout, an open issue fix, too many emergency hotfixes) archives nothing. Fix the cause and run `aapp done` again; never merge by hand to get around it.
- With `aapp.integrate = manual` (the default), it archives only and prints `aapp done <id> integrate` plus the manual commands (`git worktree remove <path>` also **deletes ignored files**; `git branch -D <branch>` after a squash). Report them; do not run them unless asked.
- **Cleanup refused for ignored files** (`.env`, keys): the integration stands. Report the files; never pass `force-cleanup` on your own. The developer backs them up, sets `aapp.quarantineIgnored true`, or decides on `force-cleanup`.
- `override-hotfix-cap` is a human sign-off: never add it yourself.

```bash
aapp done <id> integrate [squash | ff | hook] [target <branch>] [no-cleanup]   # integrate (again) after manual, a refused hook or cleanup
aapp done <id> no-integrate                                                   # archive only
```

### Step 2: Deterministic Failure Branch (Fail Closed)
If `aapp done` exits non-zero, **STOP immediately**.
**Do NOT attempt manual file moves, manual header regex substitutions, archive ledger edits, or raw git commits on the plans worktree.** Manual bypasses corrupt the ledger, skip TDD assertions, and bypass pre-done verification gates.

Parse and explain the exact CLI diagnostic:
- **Missing Recorded Commits**: If the plan has unrecorded commits, run `aapp commit adopt <sha>...` to associate the implementation commits with the plan.
- **Unticked TDD Assertions**: If TDD assertions remain unchecked, verify that all declared failure tests pass and check them off.
- **Worktree Collision**: If another worktree holds the plan, resolve the conflict before archiving.
- **Hook Veto**: If a `pre-done` hook vetoed completion, address the specific condition reported by the hook.
- **Dangling Target Issue**: `Target issue #N is in neither ISSUES.md nor done/000-issues-archive.md` means the plan header names an issue that does not exist. Report it to the user; do not invent a ledger row.

### Step 3: Success Confirmation
On exit 0, `aapp done` has moved the plan to `.plans/done/`, updated the plan header status, appended to `.plans/done/000-archive-ledger.md`, and updated `.plans/state_matrix.md`. If the plan's Target Issue was still open, the same commit moved its row to `.plans/done/000-issues-archive.md` and pruned `issues_road_map.md`: never relocate it again by hand.

Report the structured completion record (Plan ID, verification SHA, and archive summary) to the user.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
