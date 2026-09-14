# 🗺️ Issue Priority Board

> **Role:** This file does one thing — it puts the issues recorded in root `ISSUES.md` into the order you intend to fix them. It is an **active view**, not a historical record. `ISSUES.md` holds the detail; this holds the sequence.
>
> **Active-Only Queue Invariant:** This board only tracks active, unresolved issues. When an issue is resolved, it is pruned from this board (the pre-commit hook automatically purges any marked ✅ or Resolved). Historical records belong exclusively in `ISSUES.md`.
>
> **Not for future implementations.** Raw feature requests and new capabilities never appear here — they belong in `.plans/state_matrix.md`.
>
> **But an issue may have a plan.** If a fix is large enough to need a blueprint and a locked Blast Radius, promote it (`digest ISSUE-00X`) — and it **stays on this board**, marked 🔵 `Planned` with a link to its blueprint, until the fix ships. Promotion changes how it gets fixed, not which lane it lives in.
>
> **Rule for Agents:** This ordering is a human judgement call — appetite, dependency, and context, not a severity calculation. Read it as given and report it as given. Do **not** re-sort, re-rank, or "correct" these priorities unless explicitly asked.

---

## 🔴 High Priority (Immediate Focus)
1. `ISSUE-049` -> `aapp upgrade` clones default branch, but `main` is 13 commits behind `develop` and carries pre-fix guard; upgrades downgrade Layer 1.
2. `ISSUE-052` -> Deny payload omits `hookEventName` and `permissionDecisionReason`; agent blocked with no reason to self-correct.
3. `ISSUE-064` -> Status enum is not enforced in write-guard/pre-commit (`🚫|BLOCKED` check only; `🔴` and `🟡` fall through to unblocked).

## 🟡 Medium Priority (Upcoming Iteration)
- [ ] `ISSUE-050` -> Drop-in mode on `agent-planning-kit` or `aapp-develop-kit` resolves root to kit itself rather than cwd.
- [ ] `ISSUE-051` -> Self-consumption `rm -rf` gated on basename allowlist rather than directory contents/signatures.
- [ ] `ISSUE-053` -> Matcher uses `Write|Edit|NotebookEdit`; `MultiEdit` writes bypass Layer 1 write guard.

## 🟢 Low Priority (Test Infrastructure & Verification)
- [ ] `ISSUE-062` -> Deny-schema assertion checks only `decision == 'deny'`, not that denial reason reaches caller.
- [ ] `ISSUE-063` -> No CI runs the three test suites and no release gate blocks publishing `main` that trails `develop`.
