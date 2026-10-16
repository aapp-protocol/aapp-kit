# 🗺️ Plan P-101: Group Amendments Member
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-101
* **Changelog:** Added: every group has an amendments member that takes the changes found during development, so the other members stay as frozen (P-101)
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
> **Early draft, for review between agents.** §2 holds findings and options as starting points, not decisions. The aim of the review is the safest design that changes the least of the kit; anything here may be replaced.

Groups P-72 and P-91 showed that a group's members meet unknowns during development that their frozen plans did not foresee:
- **A file outside the member.** P-93 broke `tests/verbs/issue.provider.sh`, P-100 broke `tests/verbs/status.sh`: tests outside the member's Target Files that assert behaviour the member changes. Each time the member went back to Refining, the file was added, the member was frozen and started again, with the developer's OK.
- **Decisions that replace the group's text.** The group's §2 is design-locked while it is in development, and a started group cannot be restarted (`start` refuses to reuse the feature branch). P-100's change of the JSON stream rule was recorded in the group's §6 instead of §2.
- **Late scope.** P-100 itself: work that became visible only once P-94 existed.

Today each of these reaches into a plan in development. That is the risk P-99 addresses from the other side: a plan in development belongs to its owner, and other sessions must not change it.

Goal: every group has one more member, its **amendments member**, which takes what development finds: files outside a member, decisions that replace group text, late follow-ups. The other members are never amended after freeze. The amendments member is the one place a scope change is asked for, approved by the developer, recorded and made.

---

## 2. Technical Blueprint

### 2.1 Findings (starting points)
- **A1 — The member.** A group's amendments member is an ordinary member plan (`* **Group:** <id>`), marked `* **Kind:** amendments` in its header. It starts with no Target Files and these sections, kept apart from the plan template's: `Scope requests` (one line per request: date, the member that needs it, the file, why, the developer's OK), `Decisions` (what replaces group text, naming the group section), `Follow-ups` (work found late that no member needs to land). The rest is the plan template.
- **A2 — Created with the group.** `aapp draft <slug> group` drafts the group and its amendments member (`<slug>-amendments`) in one commit. The group's `Members:` lists it last. Whether this is automatic or asked for with a token is Question 1.
- **A3 — Runs beside the members.** It starts after the group, on the feature branch, like a member, and stays ⚡ In Development until the last other member is archived. The existing disjointness gate keeps it apart: a file it takes on cannot be one an active member lists, since a request is by definition for a file outside the member.
- **A4 — A file is added only by request.** An agent that needs a file outside its member writes the request in the amendments member's `Scope requests` and asks the developer. With the OK the file is added to the amendments member's Target Files, never to the member's. The add is P-99's narrow, owner-only step (`refine <id> file <path> "<reason>"`, F1/F2), from the amendments member's own checkout. Without P-99 it is the unfreeze route; see Question 7.
- **A5 — The change lands before the member needs it.** The amendments member commits the change and lands it where the member picks it up; then the member's suite passes and its `done` goes through. Where it lands is Question 2: on the feature branch (the member rebases, as members already do) or on the member's branch.
- **A6 — Order is already enforced.** A member's `done … integrate ff` needs its branch to hold the feature branch's tip: a member that did not rebase after an amendment landed is refused by the existing fast-forward. Only the message may need to name the amendment (Question 5).
- **A7 — The group's end.** The group's `done` refuses while a member is open, as today. The amendments member is archived last, after the others; one that collected nothing is dropped instead of archived (Question 4).
- **A8 — Architecture & Codemap stay in the group plan.** That section is not locked, and the group's `done` applies it. Moving it into the amendments member would change `done`; left for later (Question 8).
- **A9 — What it does not change.** Members' plans, the design lock, the pre-commit hook and the write guard stay as they are: the amendments member is a plan like any other, with its own Target Files. Single checkout (`aapp.planWorktrees off`): Question 6.

### 2.2 Kit changes, as few as possible
- `lib/cmd_plan.sh`: `draft … group` drafts the amendments member too; the group's `done` drops an empty amendments member; the landing step of A5 (its shape is Question 3).
- `templates/amendments-template.md` (new): the three sections of A1 over the plan template's header, or a block appended to the plan template when the member is drafted (Question 1).
- `templates/group-template.md`: §3 names the amendments member as the last.
- `templates/AGENTS.md`: the rule for agents: a file outside your member is a scope request in the group's amendments member, asked of the developer; never amend a member in development.
- Docs: `lib/docs/verbs/draft.md`, `lib/docs/verbs/done.md`, the contract of the landing step, `MANUAL.md` (groups), `CHEATSHEET.md`, `ARCHITECTURE.md`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Settle the open questions in the review; then declare the failing tests (`aapp tdd`).

### Phase 2: Core Implementation
- [ ] Task 2.1: `draft … group` drafts the amendments member; the template.
- [ ] Task 2.2: The landing step (Question 2, 3).
- [ ] Task 2.3: The group's `done` and the empty amendments member.
- [ ] Task 2.4: The agent rule; the contracts and docs.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
*(Proposed, to be settled with the questions.)*
- [ ] `lib/cmd_plan.sh` -> `draft … group` with the amendments member; the group's `done`; the landing step.
- [ ] `NEW FILE` -> `templates/amendments-template.md` -> the amendments member's sections.
- [ ] `templates/group-template.md` -> §3 names the amendments member.
- [ ] `templates/AGENTS.md` -> the scope-request rule.
- [ ] `lib/docs/verbs/draft.md` -> `draft … group` and the amendments member.
- [ ] `lib/docs/verbs/done.md` -> the group's `done` and the empty amendments member.
- [ ] `MANUAL.md` -> groups: the amendments member.
- [ ] `CHEATSHEET.md` -> the landing step.
- [ ] `ARCHITECTURE.md` -> groups: the amendments member.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> the design lock stays as it is.
- [ ] `templates/blast-radius-guard.sh` -> the write guard stays as it is.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Always, or asked for?** (a) every `draft … group` drafts the amendments member; (b) a bare token asks for it (`draft <slug> group amendments`); (c) the first scope request drafts it. And: its own template file, or a block appended to the plan template?
* [ ] **Question 2 — Where an amendment lands.** (a) On the feature branch: the member rebases, as members already do; between landing and the member's `done` the feature branch may carry a test that expects the member's work (red for that window, harmless with one member at a time, checked at the group's `done`). (b) On the member's branch: the feature branch is never red, but the amendment travels inside the member's integration, and a member made for an issue is squashed at `done`, folding the amendment into the member's commit and losing its own record.
* [ ] **Question 3 — The landing step's shape.** No new verb. Candidates: a token on `aapp commit` (`commit "<msg>" land`), a token on `aapp done` (`done <id> integrate keep-open`), or reusing the issue-fix landing (`issue close` lands one commit and keeps nothing open). Which existing mechanism it mirrors, and whether it runs the test gate (with Question 2 (a) the gate would fail by design).
* [ ] **Question 4 — The empty amendments member.** Dropped by the group's `done` without a trace, archived as empty, or aborted (`plan abort`) by the group's `done`?
* [ ] **Question 5 — Messages.** Does a member's refused `done` (not rebased onto a landed amendment) need a message naming the amendment, or is the fast-forward refusal enough?
* [ ] **Question 6 — Single checkout.** With `aapp.planWorktrees off` two plans in development share one checkout: does the amendments member work there at all (the active-plan buffer holds one plan), or does a group always use worktrees?
* [ ] **Question 7 — Order with P-99.** A4 relies on P-99's narrow, owner-only `refine <id> file`. Does this plan wait for P-99, or carry its own narrow step (which P-99 would then reuse)?
* [ ] **Question 8 — Architecture & Codemap.** Keep them in the group plan (A8), or move them into the amendments member later?
* [ ] **Question 9 — Who may write a request.** Any session writes into the amendments member's `Scope requests` (it is the one place for them), or only its owner, with requests passed to it another way? This is where P-99's ownership rule meets this plan.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted from groups P-72 and P-91: an amendments member per group; early draft for review between agents. Related: P-99 (who may amend a plan in development).
