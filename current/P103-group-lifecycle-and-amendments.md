# 🧩 Group Plan P-103: Group Lifecycle And Amendments
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Plan ID:** P-103
* **Changelog:** Added: Group Plan P-103 coordinating in-flight group amendments and clean completion lifecycle (P-103)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Feature Branch:** none
* **Members:** P-101, P-102
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-103` (or `aapp refine <id> group P-103`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
Provide end-to-end resilience and rigorous lifecycle governance for Group Plans across both execution phases:
1. **In-Flight Phase (P-101)**: Provide a dedicated amendments member for the group to safely accommodate missing files, unexpected cross-cutting dependencies, and small adjustments discovered during member implementation, without breaking frozen Blast Radii or requiring manual unfreezes.
2. **Completion & Finalization Phase (P-102)**: Reorder `aapp done` for group plans so that pre-done test gates execute *first* against clean committed code before any umbrella doc commits are made, with `.agents/CODEMAP.md` committed atomically and worktree cleanup executed strictly as the final operation.

---

## 2. Shared Decisions
- **Feature Branch**: All members collaborate on `feature/group-lifecycle-and-amendments` cut from `develop`.
- **Member Synergy**:
  - P-101 introduces the protocol and mechanisms for in-flight requests, preventing agents from getting trapped by locked member boundaries.
  - P-102 guarantees that when all members finish, the group's integration into `develop` leaves no premature doc commits if tests fail, and preserves logical terminal output order.
- **Fail-Closed Contract**: Both members preserve fail-closed invariants: zero un-named fallbacks, strict validation before mutations, and clean breaks.

---

## 3. Members & Order
- **Member 1: P-102 (`P102-group-done-lifecycle-order.md`)**:
  - Reorders `cmd_done`, `_group_done_prepare`, and `_group_done_codemap`.
  - Can be implemented first or in parallel, ensuring the group itself benefits from the clean `done` lifecycle when landing.
- **Member 2: P-101 (`P101-group-amendments-member.md`)**:
  - Specifies and implements the Group Amendments Member workflow, allowing in-flight accommodations and missing file requests.

---

## Architecture & Codemap

### ARCHITECTURE.md
No changes.

### .agents/CODEMAP.md
No changes.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** Settle during RFC review: Should P-102 land first so that P-101's landing on the group feature branch exercises the reordered done lifecycle?

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Group drafted. Added member P-101 and P-102. Authored group goals, shared decisions, and execution order.
