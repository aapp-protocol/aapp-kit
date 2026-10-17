# 🗺️ Issue Work Queue

> **Role:** The issues that may be worked on, and nothing else. Every issue is recorded in `ISSUES.md` and listed by `aapp issue list`; this file holds only the two kinds of work an agent may take.
>
> **Written by verbs only.** `aapp issue hotfix` adds a line to 🧱 Plan Blockers; `aapp issue queue <num> [urgent | low]` (a person's decision) adds one to a level of 📋 Queued, Normal by default, and `aapp issue queue <num> remove` takes it off. Inside a level the oldest comes first, so a waiting issue rises. `aapp issue close` and `aapp done` remove the line of an issue they close.
>
> **Rule for Agents:** `aapp issue fix` opens only an issue listed here. Never queue an issue yourself: queueing is the person's call.

---

## 🧱 Plan Blockers

## 📋 Queued
### 🔺 Urgent
### Normal
- [ ] #162 -> `aapp start <id>` and `freeze-start` for a plan re-frozen while its worktree still holds it refuse from the main checkout ("already bound in worktree") without saying that `aapp start` run in that worktree resumes it. (queued 2026-10-17)
- [ ] #110 -> A hook registration example still uses `on-done`, which P-23 renamed to `post-done` with no alias: a handler registered as shown never fires. Seen while drafting P-60. (queued 2026-10-17)
- [ ] #108 -> ARCHITECTURE.md prematurely lists unbuilt features (P-38, P-59, non-existent `archive-plan.sh`) and cites 30s watchdog default where code uses 10s. (queued 2026-10-17)
- [ ] #124 -> `done` clears the active plan buffers before its archive commit; when that commit fails the plan is restored but the buffers stay cleared. (queued 2026-10-17)
### Low
