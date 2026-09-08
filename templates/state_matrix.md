# 📊 State Matrix (Plan Lane / The Planning Brain)

This document is the central dashboard for all active ideas, drafts, ready plans, and completed architectures.

> **Role:** This is the ordering lane for **future implementations** — features, refactors, new capabilities. Every entry links a blueprint in `.plans/current/`, and every blueprint carries a Blast Radius.
>
> **Not for raw issues.** Bugs, regressions, and edge-case gaps are recorded in root `ISSUES.md` and sequenced in `.plans/issues_road_map.md` — never dropped here as bare entries. What *may* appear here is a **fix plan promoted from an issue**: a blueprint for a fix too large to simply make. Such an entry carries its issue ID, and the issue itself stays open on the issue board until the fix ships.
>
> **Rule for Agents:** The Roadmap order below is set by the human. Follow it. Do **not** re-sequence it to match your own estimate of effort, risk, or severity.

---

## 🚦 Recommended Implementation Roadmap

1. 🟢 **[Step 1: Core Foundation Blueprint](current/approved-feature.md)**
2. 🟡 **[Step 2: Secondary Feature](current/feature-name.md)**

---

## 🧠 1. Human Thought & Refinement (The Incubator)
*Ideas that are unpolished, missing edge cases, or require user clarification. The execution agent must not write code for items in this section.*

* **[Idea: Feature Name](current/feature-name.md)**
  * *Status:* Drafted. Needs edge-case handling for timeout conditions.
  * *Open Questions:* See Section 4 of plan file.

---

## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)
*Blueprints where architecture, blast radius, and interfaces are locked down. Execution sessions safely build off these.*

* [ ] **[Feature: Implementation Blueprint](current/approved-feature.md)**
  * *Target Files:* `src/path/to/file.ext`
  * *Status:* Approved. Blast radius locked. Ready to code.

---

## 🚫 2b. Blocked (Halted on an Issue)
*Plans that were in flight and hit a blocking bug too substantial to hotfix. **Not executable** — an execution session must not pick these up, even though their Blast Radius is still locked. They return to the Greenlight Zone only when the human unblocks them.*

* [ ] **[Feature: Implementation Blueprint](current/approved-feature.md)**
  * *Blocked On:* `ISSUE-002` -> [`current/parser-refactor.md`](current/parser-refactor.md)
  * *Halted:* YYYY-MM-DD — awaiting the human's decision on how to resolve the blocker.

---

## 📦 3. Archival Ledger (Recently Completed)
*When verified in code, completed plans are logged here.*

* [x] **[Core System Initialization](done/)** | Verified: [Commit / Date]

---

## 🗄️ 4. Historical Milestone Archives
<!-- Execution agents: Ignore collapsed blocks below during standard planning sessions -->
<details>
<summary>📦 Completed Milestone: v1.0.0 (Click to expand history)</summary>

| Plan File | Date Shipped | Primary Impact |
| :--- | :--- | :--- |
| `done/foundation-setup.md` | YYYY-MM-DD | Initial workspace & architecture scaffold |

</details>
