# 🐛 Issues: Audit Trail & Technical Backlog

This document is the canonical issue record for the project — bugs, regressions, and missing edge-case coverage.

---

## 🚦 1. Issue Triage & Escape Protocol (AAPP)
When a bug or a missing edge case is discovered during an active coding session:
* **Non-blocking Bug:** Do NOT stop or fix immediately. Log it in the **Active Issues Backlog** below and continue the current plan.
* **Blocking Bug:** If the bug halts the current plan, pause execution, document an `### 🚨 Emergency Hotfix Extensions` subsection in the active plan's Blast Radius, fix the blocker, log the resolution here, and resume.

---

## 🔍 2. Active Issues Backlog

| Issue ID | Severity | Component | Summary & Impact | Proposed Fix / Target Plan | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ISSUE-001** | `Medium` | `core` | Example issue description. | Fix in place — no plan needed. | 🟡 `Incubated` |
| **ISSUE-002** | `High` | `parser` | Example issue whose fix spans several modules. | [`.plans/current/parser-refactor.md`](../.plans/current/parser-refactor.md) | 🔵 `Planned` |

**Status values:** 🟡 `Incubated` (recorded, unscheduled) · 🔵 `Planned` (promoted to a blueprint — see below) · 🟠 `In Progress` · ✅ `Resolved`

> **An issue may be promoted to a plan.** When a fix is too large to simply make — several modules, real design decisions, or a refactor — scaffold a blueprint with `digest ISSUE-00X` and link it in the **Proposed Fix / Target Plan** column above. The issue **stays here** and stays open: this file records *what is wrong*, the plan records *how it will be fixed*. Close it only when the fix ships. Small fixes need no plan.

---

## 📦 3. Resolved Issues & Fix History

| Issue ID | Component | Summary & Resolution | Resolved In | Date |
| :--- | :--- | :--- | :--- | :--- |
| **FIX-001** | `core` | Initial setup validation. | `commit-hash` | YYYY-MM-DD |
