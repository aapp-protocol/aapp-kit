# 🗺️ Plan P-XX: [Feature or Refactor Name]
* **Created:** [YYYY-MM-DD] | **Last Refined:** [YYYY-MM-DD]
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-XX
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED
     The pre-commit hook reads this line. A plan whose Status says BLOCKED grants no
     commit rights at all — its Blast Radius stops admitting files until you clear it. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (e.g., `Co-authored-by: Antigravity <antigravity@google.com>` or `Claude <noreply@anthropic.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
*Provide a concise summary of WHAT is being built, WHY it is being designed this way, and key technical constraints.*

---

## 2. Technical Blueprint
*Detailed technical architecture, interfaces, data models, or algorithms written for both human and agent understanding.*

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: ...
- [ ] Task 1.2: ...

### Phase 2: Core Implementation
- [ ] Task 2.1: ...
- [ ] Task 2.2: ...

### Phase 3: Verification & Edge Cases
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Verify changelog updates and documentation synchronization.

---

## 💥 4. Blast Radius & System Boundaries
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

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** [Describe genuine ambiguity or fork in the road requiring human decision]

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **[YYYY-MM-DD]:** Plan initialized from `pickup.md`.
* **[YYYY-MM-DD]:** Refined blast radius and locked module boundaries.
