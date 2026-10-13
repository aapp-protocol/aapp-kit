# 🗺️ Plan P-84: Squash On The Plan Branch
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-13
* **Target Issue / Milestone:** none
* **Plan ID:** P-84
* **Changelog:** Changed: `done` squashes on the plan branch before the archive (squash setup, and any plan made for an issue), so recorded commits are on the parent (P-84)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `13f174f` (develop)
* **Worktree:** .workspace/P84 (plan/P84-squash-on-the-plan-branch)
* **Commits:** `51cf739` (plan/P84-squash-on-the-plan-branch), `78b3616` (plan/P84-squash-on-the-plan-branch)
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->

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
With `aapp.integrate squash`, `aapp done` writes the archive first and squashes afterwards. The plan's ledger line and the row of the issue it closes get the plan's last commit, which is on the plan branch; the squash then makes a new commit on the parent branch, and the plan branch is deleted. Nothing goes back to the records: they name a commit that is on no branch any more, and the commit that holds the work on the parent is recorded nowhere. A plan blocked on the closed issue never sees that commit arrive, and stays blocked until someone unblocks it by hand.

This plan makes the squash happen on the plan branch, before the archive. The one commit it produces is what gets recorded and what the parent is fast-forwarded to: every recorded SHA exists on the parent branch.

It builds on group P-72 (the unblocking rule of P-78, the provider step of P-74) and is done after that group lands.

---

## 2. Technical Blueprint
- **Which plans are squashed.** Two kinds, both needing a branch of their own:
  1. every plan, where the setup is squash (`aapp.integrate squash`, or `done <id> integrate squash`);
  2. **a plan made for an issue, whatever the setup** (`ff` included): one issue, one commit, one SHA in the archive.
- **Telling a plan made for an issue apart.** Both sides must agree: the plan's `Target Issue` names `#<n>`, and the ledger's row of `#<n>` is `Planned` and links this plan (`[P-<id>](current/<file>)`, the same plan id). When only one side says so, the plan is not a plan for the issue: it happens to supersede the issue, or to sort it out with its own work. It is treated as any other plan, and the setup decides.
- **A plan made for an issue always has a branch of its own.** `aapp start` (and `freeze-start`) gives it its own branch and worktree whatever `aapp.planWorktrees` says, and prints where to work, so it can be squashed to one commit. On a repository with one branch too: the history stays smooth and each issue traceable to one commit. Other plans follow `aapp.planWorktrees` as before.
- **How the squash is made:** at `done`, once the checks have passed and before anything is archived, the plan's commits are turned into one commit on the plan branch. The plan branch already contains its parent (`done` refuses otherwise), so this is the same tree as today's squash merge, with the same message (`feat: <title> (<plan>)`, the changelog line, `Plan-ID`, `Plan-Parent`, `Base-Branch`).
- **That commit is what is recorded:** the plan's `* **Commits:**` (the one commit replaces the list; the commits it replaces no longer exist on any branch), the plan's line in the archive ledger, the row of the issue the plan closes, and the `commit` the provider is told (`issue.close`).
- **Integration is then a fast-forward** wherever the kit integrates (squash and `ff` setups): the parent moves to the recorded commit. The plan branch is merged, so it is deleted without force. Under `manual` and `hook` a plan made for an issue is squashed all the same; its one commit stays on the plan branch for the person or the handler to integrate.
- **An archived plan integrated later** (`aapp done <id> integrate squash` after `manual`, or after a refused integration) is squashed then, and its records are corrected to the new commit (the plan's ledger line, the issue's archive row) in one commit on the plans branch.
- **Attribution: the plan's last commit before the squash.** The squashed commit carries the `AI-Agent`, `AI-Vendor` and `AI-Model` trailers of the plan's last commit, not the identity of whoever runs `done`: the work was done by the agents that committed it, also when a person archives it. One set of trailers, never a list. A last commit without trailers gives a squashed commit without them.
- **A plan waiting on the closed issue** is unblocked by the rule that already exists: the recorded commit is in its parent branch once the fast-forward is done. `aapp refine <plan> unblocked <num>` stays for a squash made by hand.
- **Failure:** when the squashed commit cannot be made, the plan branch is put back exactly as it was and `done` refuses; nothing is archived.
- **Unchanged:** a plan that closes no issue under `ff`, `hook` or `manual` (every commit and its SHA are kept), and a plan that closes no issue and has no branch of its own (its commits are on the shared branch).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: `None`. Plans archived before this keep the records they have.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/done.squash.sh::test_recorded_commit_is_on_parent` -> asserts after `done` in squash mode the plan's ledger line and its `Commits:` name the commit at the tip of the parent branch
- [ ] `tests/verbs/done.squash.sh::test_one_commit_fast_forwarded` -> asserts the parent gains exactly one commit, with the squash message, and the plan branch is deleted
- [ ] `tests/verbs/done.squash.sh::test_issue_row_names_parent_commit` -> asserts the archive row of the issue the plan closes names a commit reachable from the parent branch
- [ ] `tests/verbs/done.squash.sh::test_provider_gets_parent_commit` -> asserts `issue.close` carries that same commit
- [ ] `tests/verbs/done.squash.sh::test_waiting_plan_is_unblocked` -> asserts a plan blocked on the closed issue, whose parent is that branch, is unblocked by the `done`, with no manual step
- [ ] `tests/verbs/done.squash.sh::test_attribution_is_the_last_commit` -> asserts the squashed commit carries the trailers of the plan's last commit and not those of the identity running `done`; none when that commit has none
- [ ] `tests/verbs/done.squash.sh::test_failed_squash_restores_branch` -> asserts when the squashed commit cannot be made the plan branch is at its former tip, `done` refuses and nothing is archived
- [ ] `tests/verbs/done.squash.sh::test_ff_mode_keeps_every_commit` -> asserts in `ff` mode a plan that closes no issue reaches the parent with every commit and its SHA, as before
- [ ] `tests/verbs/done.squash.sh::test_issue_plan_squashed_in_ff_mode` -> asserts in `ff` mode a plan made for an issue lands as one commit, which the issue's archive row names
- [ ] `tests/verbs/done.squash.sh::test_issue_plan_needs_both_sides` -> asserts a plan whose `Target Issue` names an issue the ledger does not link to it (not `Planned`, or linked to another plan) is not squashed in `ff` mode: it is a plan like any other
- [ ] `tests/verbs/done.squash.sh::test_issue_plan_squashed_under_manual` -> asserts under `manual` a plan made for an issue is archived with one commit on its kept branch, which the records name
- [ ] `tests/verbs/done.squash.sh::test_issue_plan_gets_its_own_branch` -> asserts with `aapp.planWorktrees off` `start` of a plan made for an issue creates its branch and worktree and names the path, and `start` of another plan does not
- [ ] `tests/verbs/done.squash.sh::test_later_integration_corrects_records` -> asserts `done <id> integrate squash` on an archived plan squashes, fast-forwards, and corrects the plan's ledger line and the issue's archive row in one commit on the plans branch

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- `tests/integrate_test.sh::test_squash_integrates_with_trailers_and_cleans_up`: rewritten where it reads the trailers (now the last commit's) and where it expects a forced branch deletion.
- `tests/verbs/issue.branch.sh::test_cherry_picked_fix_stays_blocked`: unchanged; a commit carried by hand is still not recognised.

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/done.squash.sh`; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: The squash on the plan branch before the archive, with the last commit's trailers; the former tip kept until the commit exists.
- [ ] Task 2.2: The one commit recorded (plan file, archive ledger, issue row, provider); integration by fast-forward.
- [ ] Task 2.3: A plan made for an issue is recognised (plan and ledger agree) and squashed whatever the setup.
- [ ] Task 2.4: Later integration of an archived plan corrects the records.
- [ ] Task 2.5: `start` gives a plan made for an issue its own branch and worktree whatever the setting.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md`, the `done` and `issue` contracts.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue; none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> The squash on the plan branch before the archive; the recorded commit; fast-forward in squash mode.
- [ ] `lib/docs/verbs/done.md` -> Contract.
- [ ] `lib/docs/verbs/start.md` -> Contract: a plan made for an issue gets its own branch.
- [ ] `templates/AGENTS.md` -> Agent rules: a plan made for an issue is worked in its own worktree and lands as one commit.
- [ ] `lib/docs/verbs/issue.md` -> Contract: the kit's own squash is recognised.
- [ ] `MANUAL.md` -> Squash integration; what the records name; attribution of the squashed commit.
- [ ] `tests/integrate_test.sh` -> Existing test changed (§3).

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/verbs/done.squash.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> No hook rule changes.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Whose attribution does the squashed commit carry? → RESOLVED (developer, 2026-10-13):** the plan's last commit before the squash. The work was done by agents, also when a person runs `done`; nobody stops an agent mid-work to let another make the last commit; and one set of trailers keeps the commit short.
* [x] **Question 2 — `aapp done <id> integrate squash` on a plan archived earlier? → RESOLVED (developer, 2026-10-13):** the squash is made then, and the plan's ledger line and the issue's archive row are corrected to the new commit in one commit on the plans branch.
* [x] **Question 4 — A plan made for an issue that has no branch of its own? → RESOLVED (developer, 2026-10-13):** `start` gives every plan made for an issue its own branch and worktree, whatever `aapp.planWorktrees` says: one unified system for issues. On a one-branch repository it may look odd, but the history stays smooth and traceable. Small fixes (`aapp issue fix`) follow the same rule in P-85.
* [x] **Question 3 — Is a plan made for an issue squashed only in squash mode? → RESOLVED (developer, 2026-10-13):** no: any plan made for an issue is a squashed plan. It is recognised by both sides agreeing: the issue declared in the plan, and the ledger's row of that issue being planned and naming the same plan.

---

## 📦 6. Change Log & Refinement History
* **2026-10-13:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Drafted. Follows group P-72.
* **2026-10-13:** A plan made for an issue is always squashed; later integration corrects the records.
* **2026-10-13:** A plan that names an issue the ledger does not link to it is a plan like any other; Question 4 opened.
* **2026-10-13:** Question 4 resolved: a plan made for an issue always has its own branch.
