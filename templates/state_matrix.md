# 📊 State Matrix (Plan Lane / The Planning Brain)

This document is the central dashboard for all active ideas, drafts, ready plans, and completed architectures.

> **Role:** This is the ordering lane for **future implementations** — features, refactors, new capabilities. Every entry links a blueprint in `.plans/current/`, and every blueprint carries a Blast Radius.
>
> **Not for raw issues.** Bugs, regressions, and edge-case gaps are recorded in root `ISSUES.md` and sequenced in `.plans/issues_road_map.md` — never dropped here as bare entries. What *may* appear here is a **fix plan promoted from an issue**: a blueprint for a fix too large to simply make. Such an entry carries its issue ID, and the issue itself stays open on the issue board until the fix ships.
>
> **Rule for Agents:** The Roadmap order below is set by the human. Follow it. Do **not** re-sequence it to match your own estimate of effort, risk, or severity.

---

## 🚦 Recommended Implementation Roadmap

1. 🔷 **P-1: [Core Foundation Blueprint](current/P1-approved-feature.md)**
2. 📝 **P-2: [Secondary Feature](current/P2-feature-name.md)**

---

## 🧠 1. Human Thought & Refinement (The Incubator)
*Ideas that are unpolished, missing edge cases, or require user clarification. The execution agent must not write code for items in this section.*

* **P-2: [Idea: Feature Name](current/P2-feature-name.md)**
  * *Status:* Drafted. Needs edge-case handling for timeout conditions.
  * *Open Questions:* See Section 5 of plan file.

---

## ⚡ 2a. In Development (Active Implementation Context)
*Blueprints actively being coded in the working tree. Governed by the local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).*

* [ ] **P-1: [Feature: Implementation Blueprint](current/P1-approved-feature.md)**
  * *Target Files:* `src/path/to/file.ext`
  * *Status:* ⚡ In Development. Active execution buffer set.

---

## 🔷 2b. Frozen Backlog (Approved Specifications)
*Blueprints where architecture, blast radius, and interfaces are locked down. Approved for implementation, but not yet active in development.*

* [ ] **P-3: [Approved Feature](current/P3-approved-feature.md)**
  * *Target Files:* `src/path/to/other.ext`
  * *Status:* 🔷 Frozen. Ready to activate via `aapp start P-3`.

---

## 🚫 2c. Blocked (Halted on an Issue)
*Plans that were in flight and hit a blocking bug too substantial to hotfix. **Not executable** — an execution session must not pick these up, even though their Blast Radius is still locked. They return to the Greenlight Zone only when the human unblocks them.*

* [ ] **[Feature: Implementation Blueprint](current/approved-feature.md)**
  * *Blocked On:* `ISSUE-002` -> [`current/parser-refactor.md`](current/parser-refactor.md)
  * *Halted:* YYYY-MM-DD — awaiting the human's decision on how to resolve the blocker.

---

## 🏛️ 3. Archival Ledger (Completed Plans DB)
Completed blueprints are permanently archived in [`done/000-archive-ledger.md`](done/000-archive-ledger.md).
