# 🗺️ Plan: [Feature or Refactor Name]
* **Created:** [YYYY-MM-DD] | **Last Refined:** [YYYY-MM-DD]
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED
     The pre-commit hook reads this line. A plan whose Status says BLOCKED grants no
     commit rights at all — its Blast Radius stops admitting files until you clear it. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

---

## 1. Context & Architectural Goal
*Provide a concise summary of WHAT is being built, WHY it is being designed this way, and key technical constraints.*

## 2. Technical Blueprint
*Detailed checklist, data structures, flow, or pseudo-code written for both human and agent understanding.*
- [ ] Step 1: ...
- [ ] Step 2: ...

---

## 💥 3. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `src/path/to/file.ext` -> Description of specific modification.
- [ ] `NEW FILE` -> `src/path/to/new_file.ext` -> Purpose of the new component.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/core/critical_module.ext` -> Core module is frozen; do not refactor.
- [ ] `src/auth/` -> Authentication flow must remain completely isolated.

---

## ❓ 4. Open Questions & Decision Matrix
*If this section contains open items, the plan is blocked and cannot be marked as [READY] in the State Matrix.*
* [ ] **Question 1:** [e.g., Which error response format should we standardize on?]
* [ ] **Question 2:** [e.g., Do we need retry logic here or fail-fast?]

---

## 📦 5. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **[YYYY-MM-DD]:** Plan initialized from `pickup.md`.
* **[YYYY-MM-DD]:** Refined blast radius and locked module boundaries.
