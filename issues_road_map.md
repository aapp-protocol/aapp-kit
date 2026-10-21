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
- [ ] #186 -> Design lock reads a fenced '## … 2.' heading inside a group plan's Architecture & Codemap as the plan's own §2, so an approved codemap decision is refused as a §2 edit (queued 2026-10-21)
### Low
