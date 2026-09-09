# 🗺️ Issue Priority Board

> **Role:** This file does one thing — it puts the issues recorded in root `ISSUES.md` into the order you intend to fix them. It is a *view*, not a record. `ISSUES.md` holds the detail; this holds the sequence.
>
> **Not for future implementations.** Raw feature requests and new capabilities never appear here — they belong in `.plans/state_matrix.md`.
>
> **But an issue may have a plan.** If a fix is large enough to need a blueprint and a locked Blast Radius, promote it (`digest ISSUE-00X`) — and it **stays on this board**, marked 🔵 `Planned` with a link to its blueprint, until the fix ships. Promotion changes how it gets fixed, not which lane it lives in.
>
> **Rule for Agents:** This ordering is a human judgement call — appetite, dependency, and context, not a severity calculation. Read it as given and report it as given. Do **not** re-sort, re-rank, or "correct" these priorities unless explicitly asked.

---

## 🔴 High Priority (Immediate Focus)
1. `ISSUE-001` -> One-line restatement of the issue.
2. `ISSUE-002` -> Larger fix. 🔵 `Planned` -> [`current/parser-refactor.md`](current/parser-refactor.md)

## 🟡 Medium Priority (Upcoming Iteration)
- [ ] `ISSUE-00X` -> One-line restatement of the issue.

## 🟢 Low Priority (Accepted Edge Cases / Deferred)
- [ ] `ISSUE-00X` -> Known gap, tolerated for now. Revisit when it bites.
