# 🗺️ Plan P-102: Group Done Lifecycle Order
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** #165
* **Plan ID:** P-102
* **Changelog:** Fixed: a group's `done` runs the gate before committing its docs, restores them when a hook refuses that commit, and cleans up last (P-102)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `4a7da2f` (feature/group-lifecycle-and-amendments)
* **Worktree:** .workspace/P102 (plan/P102-group-done-lifecycle-order)
* **Group:** P-103
* **Commits:** `6849fe5` (plan/P102-group-done-lifecycle-order)
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
A group's `done` (`cmd_done` → `_group_done_prepare` in `lib/cmd_plan.sh`) commits the group's `ARCHITECTURE.md` sections and umbrella changelog entry on the feature branch before `pre-done` runs. When the gate or a project's pre-commit then refuses, the feature branch keeps a commit stating that work is delivered which has not passed its checks, and in an adopter's project the integration may follow days later. The `.agents/CODEMAP.md` sections are applied after the worktree cleanup, so cleanup is not the last step.

Goal: nothing that claims delivery is committed until every check has passed; cleanup is the last step. Review: `.plans/pickup/p103-group-lifecycle-rfc.md` (C1–C4, C10, C15, A1, A2; settled 2026-10-17).

---

## 2. Technical Blueprint

### 2.1 The order of a group's `done`
1. **Checks, no delivery claim.** Members archived; feature branch and parent found; dry runs of both section sets; the worktree `.workspace/P<n>` on the feature branch; a moved parent merged in (mechanical, as today); the worktree clean (the P-54 check, moved before any section is applied); `_ig_preflight`.
2. **The gate.** `pre-done` runs in the group's worktree. A group's recorded-commits check is "every member archived" (already enforced) instead of "the plan has recorded commits": at the gate the group has none yet. The `pre-done` payload's `commit_hash` and `commits` carry the feature branch tip. A veto exits 1; the feature branch holds no docs commit.
3. **The docs commit.** The `ARCHITECTURE.md` sections and the umbrella changelog entry are applied and committed with `aapp commit`, a distinct commit, recorded as the group's. When a hook refuses it, `git -C <worktree> reset -q --hard HEAD` restores both files (a newly created `ARCHITECTURE.md` included), and `done` exits 1 with nothing archived. The reset is safe because step 1 checked the worktree clean. A retry re-applies everything: sections apply unchanged on a retry, the changelog sync is idempotent.
4. **Archive, integrate, CODEMAP, cleanup.** The group is archived; P-55 fast-forwards the parent; for a group, `_ig_run` applies and commits the `.agents/CODEMAP.md` sections between the integration and `_ig_cleanup`. A CODEMAP failure is reported as today (the integration stands; "update .agents/CODEMAP.md by hand"); cleanup still runs, and `done` exits 1.

Printed order: gate → docs commit → archive → integrate → CODEMAP → cleanup.

### 2.2 Distinct docs commit
The docs commit stays its own commit on the feature branch: a group integrates by fast-forward and is never squashed (`_sq_decide`), so the members' recorded SHAs stay reachable.

### 2.3 Contract and tests
`lib/docs/verbs/done.md` (the group line and its tests) describes the order of 2.1. `tests/integrate_test.sh::test_group_done_commits_architecture_before_gate_codemap_after_merge` asserts the old order and is replaced by the tests in §3.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Failing tests
- [ ] Task 1.1: In `tests/integrate_test.sh`, replace `test_group_done_commits_architecture_before_gate_codemap_after_merge` with:
  - `test_group_done_gate_veto_leaves_no_docs_commit` -> a `pre-done` veto: exit 1, the feature branch tip unchanged, nothing archived.
  - `test_group_done_commits_docs_after_gate` -> the `ARCHITECTURE.md` sections and umbrella entry are absent at `pre-done` and committed after it; `pre-done`'s `commit_hash` is the feature branch tip.
  - `test_group_done_precommit_refusal_restores_worktree` -> a pre-commit refusing the docs commit: exit 1, the worktree clean (a new `ARCHITECTURE.md` removed), nothing archived; a retry succeeds.
  - `test_group_done_codemap_before_cleanup` -> the CODEMAP lines are printed before `🧹 [Cleanup]`, and the `.agents` commit exists when cleanup runs.

### Phase 2: Implementation
- [ ] Task 2.1: `_group_done_prepare` keeps the checks and the parent merge; the section application and docs commit move to a step after `pre-done` (2.1.3), with the restore.
- [ ] Task 2.2: The recorded-commits check and the `pre-done` payload for a group (2.1.2); the P-54 clean check before any section is applied.
- [ ] Task 2.3: `_ig_run` applies CODEMAP for a group between the integration and `_ig_cleanup` (2.1.4).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `lib/docs/verbs/done.md`: the group line, the replaced test names.
- [ ] Task 3.2: `MANUAL.md`: the group's `done` order.
- [ ] Task 3.3: `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> the order of a group's `done`, the restore, the recorded-commits check and payload for a group, CODEMAP inside `_ig_run`.
- [ ] `tests/integrate_test.sh` -> the replaced group `done` test and the new ones.
- [ ] `lib/docs/verbs/done.md` -> the group line and its tests.
- [ ] `MANUAL.md` -> the group's `done` order.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/group_docs.sh` -> the section transformations stay as they are.
- [ ] `templates/blast-radius-guard.sh` -> the write guard stays as it is.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-17:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-16:** Plan initialized from issue #165.
* **2026-10-17:** Refined from the settled review (`.plans/pickup/p103-group-lifecycle-rfc.md`): gate first, the docs commit after it with a restore, recorded commits and payload for a group, CODEMAP before cleanup, a distinct docs commit; Target Files corrected.
