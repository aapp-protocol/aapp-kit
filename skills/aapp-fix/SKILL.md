---
name: aapp-fix
description: Fix a queued issue in the main checkout through a temporary mini plan. Claims the issue (or the next plan blocker), commits the fix, and closes it, unblocking the plans that waited on it.
disable-model-invocation: false
argument-hint: "[#<num>]"
---

# AAPP Fix (Issue Fix via Mini Plan)

Fix one logged issue in the main checkout via the authoritative CLI engine. The fixer is a role of its own (often an automated runner): it fixes the issue and nothing else.

## Execution Procedure

### Step 1: Claim
- `/aapp-fix #<num>` runs:
  ```bash
  aapp issue fix <num>
  ```
- `/aapp-fix` alone takes the top of the 🧱 Plan Blockers queue:
  ```bash
  aapp issue fix next-blocker
  ```

**The files come from the issue log** (the row's Location). Add `file <path>` only for a file the log does not name.

Run the command with a tool timeout longer than `aapp.issueFixWait` (default 5 minutes). It waits, printing each step, while another fix is open or one of its files has uncommitted changes.

On exit 0, the mini plan `current/fix-<num>.md` is open and bound to this checkout.

### Step 2: Fix
Edit only the mini plan's files; the write guard enforces this. Then commit:
```bash
aapp commit "fix: <what> (#<num>)"
```

### Step 3: Close
```bash
aapp issue close <num>
```
Read its output and report it:
- which plans are unblocked;
- whether stashed plan work was re-applied, or is in conflict;
- `P-xx also lists <file>`: another active plan lists a fixed file. That plan picks the fix up at its next rebase.

### Rules
- Never commit or stash another plan's work. `fix` waits for that work to be committed.
- After a timeout, leave that issue. `aapp issue fix next-blocker` takes another one; retry this one later.
- If the fix is more than small, drop it and promote the issue to a plan:
  ```bash
  aapp issue fix <num> abort
  aapp draft <slug> issue <num>
  ```

### Fail Closed
If any command exits non-zero, **STOP** and explain its diagnostic. **Do NOT edit the mini plan, `ISSUES.md`, `issues_road_map.md` or the state matrix by hand**, and do not commit on the plans worktree.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
