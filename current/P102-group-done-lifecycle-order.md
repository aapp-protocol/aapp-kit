# 🗺️ Plan P-102: Group Done Lifecycle Order
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** #165
* **Plan ID:** P-102
* **Changelog:** Fixed: group done verifies tests before committing docs and commits codemap before worktree cleanup (P-102)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-103
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
In the current implementation of group plan completion (`cmd_done` in `lib/cmd_plan.sh` under Plan P-64), `_group_done_prepare` mutates `ARCHITECTURE.md` and immediately creates a commit (`docs: group <gid> architecture and changelog`) on the group's feature branch **before** the test gate runs.

This causes severe lifecycle defects:
1. **Premature Commit**: If tests fail (or pre-commit hooks fail), the feature branch is permanently polluted with a documentation commit claiming that the feature is delivered. Fixing tests afterward inverts git history, putting bug fixes *after* the delivery documentation commit.
2. **Inconsistent Documentation Split**: `ARCHITECTURE.md` is committed on the feature branch *before* tests run, while `.agents/CODEMAP.md` is committed on `.agents` *after* integration.
3. **Out-of-Order Terminal Output**: In `cmd_done`, `_group_done_codemap` runs *after* `_ig_run`, emitting `.agents/CODEMAP.md` replacement lines *after* the `🧹 [Cleanup] Removed worktree...` message. In any clean CLI tool, worktree cleanup must be the final operation.

The goal of P-102 is to rationalize the group plan `done` lifecycle into a clean, test-first, properly ordered execution pipeline.

---

## 2. Technical Blueprint

### 2.1 Reordered Lifecycle Sequence for Group Plans
The group plan `aapp done <group-id>` pipeline is restructured into four distinct phases:

1. **Pre-Flight Validation (Read-Only & Dry-Runs)**:
   - Verify all group members are archived (`group_members`).
   - Merge parent branch into feature branch (`_group_merge_parent_in`).
   - Run dry-run checks for both `ARCHITECTURE.md` and `.agents/CODEMAP.md` (`group_docs_apply ... >/dev/null`). If either fails to apply cleanly, abort with 0 commits made.
2. **Test Gate First**:
   - Run the pre-done test gate on the clean, merged feature branch *before* generating doc commits.
   - If tests fail, abort immediately: the branch remains clean, with no premature doc commits.
3. **Atomic Documentation Generation**:
   - Once tests are proven green, apply `ARCHITECTURE.md` and umbrella changelog entry and commit them to the feature branch.
   - Archive the group plan to `.plans/done/` and record in archive ledger.
4. **Integration & Codemap Application Before Cleanup**:
   - Fast-forward integrate the feature branch into the parent branch (`develop`).
   - Apply and commit `.agents/CODEMAP.md` on the `.agents` worktree.
   - **Cleanup Last**: Delete the group worktree and delete the feature branch as the final step.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Lifecycle Analysis & Refactoring
- [ ] Task 1.1: Refactor `_group_done_prepare` in `lib/cmd_plan.sh` so that it handles dry-run validation and parent merging, without committing docs before test gates.
- [ ] Task 1.2: Move the `ARCHITECTURE.md` application and commit step to execute only after the pre-done test gate succeeds.
- [ ] Task 1.3: Reorder `_group_done_codemap` and worktree cleanup in `_ig_run` so that all document commits land before `🧹 [Cleanup]` is printed.

### Phase 2: Verification & Test Suites
- [ ] Task 2.1: Run `tests/group_docs_test.sh` to ensure all group doc transformations remain compliant.
- [ ] Task 2.2: Add regression test verifying that a failing test gate in a group plan leaves the feature branch free of premature doc commits.
- [ ] Task 2.3: Verify terminal output order matches: `Test Gate` -> `Docs Commit` -> `Archive` -> `Integrate` -> `Codemap` -> `Cleanup`.

### Phase 3: Documentation & Polish
- [ ] Task 3.1: Update `ARCHITECTURE.md` and `MANUAL.md` section on Group Plans to reflect the verified lifecycle order.
- [ ] Task 3.2: Verify full test suite passes (`./aapp test quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> Reorder group plan done preparation, test gate, codemap commit, and cleanup.
- [ ] `lib/group_docs.sh` -> Helper adjustments for pre-test dry-run and post-gate application if needed.
- [ ] `tests/group_docs_test.sh` -> Regression tests for group done lifecycle order.
- [ ] `tests/verbs/done.sh` -> Add test assertions verifying output ordering and cleanup sequence.
- [ ] `MANUAL.md` -> Update Group Plan completion lifecycle documentation.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/aapp-lib.sh` -> Core ledger and resolution logic is out of scope.
- [ ] `templates/blast-radius-guard.sh` -> Guard engine is untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** Should the `ARCHITECTURE.md` doc commit be folded directly into the group integration commit (making group integration a single commit containing code + docs), or kept as a distinct commit on the feature branch before fast-forward?

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan initialized from issue #165. Authored technical blueprint, reordered lifecycle sequence, and defined target files.
