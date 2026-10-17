# 🗺️ Plan P-101: Group Amendments Member
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** none
* **Plan ID:** P-101
* **Changelog:** Added: every group has an amendments member that takes the files and decisions development finds, with approval, landing and status, so members stay as frozen (P-101)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🔷 Frozen
* **Base:** `11ab9bc` (feature/group-lifecycle-and-amendments)
* **Worktree:** .workspace/P101 (plan/P101-group-amendments-member)
* **Group:** P-103
* **Commits:** `913c44b` (plan/P101-group-amendments-member)
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
A group's members meet, during development, what their frozen plans did not foresee: a file outside the member (a test elsewhere asserting the behaviour the member changes), a decision that replaces group text, late scope. Today each means unfreezing the member, editing it and starting it again, and any session can do it.

Goal: every group has one more member, its **amendments member**, the one place where what development finds is requested, approved, recorded and made. Members are never amended after start (P-99 protects them); their sessions request, the amendments member implements and lands on the feature branch, members rebase. The group gets one ordered record of what its planning missed. Review: `.plans/pickup/p103-group-lifecycle-rfc.md` (C12–C14, C16, C17, C20–C28, A6, A7, A9–A11; user decisions in its §4; settled 2026-10-17). Builds on P-99 (owner-only refine, the lock rule for `Kind: amendments`, the `refine` events).

---

## 2. Technical Blueprint

### 2.1 The member
- **Created with the group.** `aapp draft <slug> group` drafts the group and `<slug>-amendments` in one commit, from `templates/amendments-template.md`: header `* **Kind:** amendments`, `* **Commit Mode:** microcommits`, `* **Group:** <id>`; no Target Files; sections `## Scope Requests`, `## Decisions`, `## Follow-ups`, after §6 (the design lock reads §4 up to the next numbered section, so they must not sit inside §2–§5). It has no `## Architecture & Codemap`: the group plan is the one guide (2.4). The group's `* **Members:**` lists it last. A group drafted while the plan-id provider is unreachable is refused: its amendments member could not be linked offline (offline sync does not know groups, as joining one offline is refused already).
- **Started with the group, never frozen.** It has no design to review and no files to lock: `aapp start <group>` also starts it, ⚡ In Development, on the feature branch in its own worktree whatever `aapp.planWorktrees` says (as a plan made for an issue). `freeze` stays as it is. It stays ⚡ In Development until every other member is archived. A session working in its worktree is its owner (P-99 D1).
- **Always `microcommits`.** `aapp_plan_commit_mode <plan>` (`lib/aapp-lib.sh`, beside `aapp_commit_mode`) is `microcommits` for `Kind: amendments`, otherwise the repository's mode; `aapp_plan_stamp_modes` and the atomic refusal of `aapp commit` read it, so a repository on `atomic` lands amendments in phases.
- `templates/group-template.md` §3 names it as the last member.

### 2.2 Requests and approval
- **A request.** `aapp refine <amend-id> request "<summary>" [file <path> | heading "<heading>"]`, run from the checkout of a member of the same group: the kit appends one line to `## Scope Requests`, the requester taken from that checkout's bound plan; refused from anywhere else, and for a requester outside the group. A member asks for itself, never for another. The member's plan is never touched.
- **Line and states.** `- **R<n>** <date> · P-<requester> · <target> · <summary> — <state>`; `<target>` is `` `<path>` `` or `§ <heading>`; `<state>` is `pending`, `approved (<approver>)`, `refused: <reason>`, `landed \`<sha>\`` (a file) or `applied` (a heading, 2.4). Only verbs move a state.
- **`aapp.amendmentApprovalRequired`** (`true` | `false`, default `true`; one accessor, refused naming the key on any other value).
  - `true`: `refine <amend-id> approve <n>` approves `R<n>`, records the approver (the `agent`/`vendor`/`model` tokens when given, else `git config user.name`) and adds the request's file to the amendments member's `### 📂 Target Files`, the change P-99's lock accepts. A person or a managing agent approves; the kit does not check which. `refine <amend-id> refuse <n> "<reason>"` refuses it. `refine <amend-id> file …` is refused, naming `approve`.
  - `false`: the owner adds a file with `refine <amend-id> file <path> "<reason>"`; requests remain a record.
  - Both: an added file is refused when an active member lists it (the disjointness gate otherwise runs only at `start`).
- **No new gate.** A file without an approved request is not in the Target Files: the write guard refuses the edit, pre-commit the commit.
- **What the verbs print.** `request` with approval required: "R<n> recorded, waiting for approval. Do not implement `<path>`; continue with your own Target Files, or stop." `approve`: "`<path>` added to <amend-id>'s Target Files; implement it in `<worktree>`." `refuse`: the reason. Each kind fires P-99's `refine` events.

### 2.3 Landing
- `aapp commit` in an amendments member adds the trailer `Plan-ID: <amend-id>` to its commits.
- `aapp commit "<msg>" land` commits and lands; `aapp commit land` lands what is committed. Run in the amendments member's worktree only. Landing moves the feature branch to the amendments member's tip by P-55's path: `_ig_preflight` (refuses "rebase first" when the branch lacks the feature branch tip) and the `merge --ff-only` of `_ig_run`, without archive or cleanup; never `git branch -f`. No test gate: an amendment may expect a member's work (a test landed ahead, turned green by that member).
- An approved request whose file the landed commits touch becomes `landed` with the last such commit.
- The output names the members whose branch lacks the new tip: they rebase (`git rebase --autostash <feature branch>`); a member's `done … integrate ff` already refuses until they do.
- A landed test that asserts a member's behaviour makes other members' gates wait for that member: the order is visible in status (2.6), not prevented.

### 2.4 One guide: correcting the group's text
- The group plan's `## Architecture & Codemap` is the one guide members code from. A correction is written into it, never copied into the amendments member.
- In the amendments member's worktree, the corrected section is edited in the group plan; then `aapp refine <amend-id> decision <n> "<reason>"` (approval required: `R<n>` is an approved `heading` request) or `aapp refine <amend-id> decision "<heading>" "<reason>"` (approval not required) commits, in one plans commit, the group plan and a line in `## Decisions`: `- **D<k>** <date> · § <heading> · R<n> · <reason>`. `R<n>` becomes `applied`.
- Refused when the group plan's change touches anything but that heading's section, when the request is not approved, and outside the amendments member's worktree. P-99's lock accepts the group section change only with that `Decisions` line.
- A corrected section keeps its base line, so the group's `done` applies it as any other. The group plan is current throughout, and its archived copy shows what was implemented; `git -C .plans log -p` on it shows each change, the `Decisions` line why.
- Members read it at the two moments an agent reads: `aapp start` / `freeze-start` of a member prints "Member of group <id>: read its `## Architecture & Codemap` in `<group plan>` before coding."; `aapp status` in a checkout bound to a member prints "Bound to <id>, member of group <gid>: re-read the group's `## Architecture & Codemap` before continuing." (the `/aapp` skill runs it at every session start and resume). A correction made while an agent is mid-session reaches it at its next start or resume.

### 2.5 The end
- The amendments member's `done` refuses while another member of the group is open, and while a request is `pending`, or `approved` but not landed or applied, listing them.
- With no recorded commit it is archived when every request was refused or applied, or none was made; the ledger's commit column is `none`, never the repository's `HEAD` (`cmd_done`'s fallback).

### 2.6 Status and plan-status
- `aapp plan-status <amend-id>` (and its `json`) lists the requests with their states.
- `aapp status` shows the amendments member under its group: "<k> requests wait for approval: aapp plan-status <amend-id>" (only when approval is required) and "<m> landed; P-<x> must rebase onto <feature branch>". Next Action names waiting requests first.
- JSON: the amendments member's object gets `requests` (`pending`, `approved`, `refused`, `landed`, `applied` counts) and `must_rebase` (member ids); documented in `docs/reference/08-output-json.md` (an added field keeps the version).

### 2.7 Agent rule (`templates/AGENTS.md`)
A file or a change of the group's text outside your member goes to the group's amendments member as a request; after a request, do not touch its file until `aapp plan-status` shows it approved; continue with your own Target Files, or stop. Rebase when a landing names your member. The group plan's `## Architecture & Codemap` is your guide: read it when your member starts and at every session start or resume.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Declare the failing tests (`aapp tdd`).

### Phase 2: Core Implementation
- [ ] Task 2.1: The template; `draft … group` drafts the amendments member, refused offline; `start <group>` starts it; `aapp_plan_commit_mode` (2.1).
- [ ] Task 2.2: `request`, `approve`, `refuse`, `file` for an amendments member; the config accessor; the disjointness check on add (2.2).
- [ ] Task 2.3: `Plan-ID` on its commits; `commit … land` on P-55's path; request lines to `landed` (2.3).
- [ ] Task 2.4: `decision` writing the group's text with its record; the member lines at start and in status (2.4).
- [ ] Task 2.5: The amendments member's `done` rules (2.5).
- [ ] Task 2.6: `plan-status`, `status` and the JSON field (2.6).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Contracts: `lib/docs/verbs/draft.md`, `refine.md`, `commit.md`, `done.md`, `start.md`, `freeze-start.md`, `plan-status.md`, `status.md`; `docs/reference/08-output-json.md`.
- [ ] Task 3.2: `MANUAL.md` (groups: the amendments member, the config key, the one guide), `CHEATSHEET.md` (the tokens), `templates/AGENTS.md` (2.7).
- [ ] Task 3.3: `./aapp test strict quiet`.
- [ ] Task 3.4: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> `draft … group`; `request`/`approve`/`refuse`/`file`/`decision`; the member line at start; the amendments member's `done`; `plan-status`.
- [ ] `lib/cmd_commit.sh` -> `Plan-ID` on its commits; `land`.
- [ ] `lib/aapp-lib.sh` -> `aapp_plan_commit_mode`; `aapp_plan_stamp_modes` reads it.
- [ ] `lib/cmd_status.sh` -> the amendments lines, Next Action, the JSON field.
- [ ] `NEW FILE` -> `templates/amendments-template.md` -> the amendments member.
- [ ] `templates/group-template.md` -> §3 names the amendments member.
- [ ] `templates/AGENTS.md` -> the agent rule (2.7).
- [ ] `lib/docs/verbs/draft.md` -> `draft … group` and the amendments member.
- [ ] `lib/docs/verbs/refine.md` -> `request`, `approve`, `refuse`, `file`, `decision`.
- [ ] `lib/docs/verbs/commit.md` -> `land`, the trailer.
- [ ] `lib/docs/verbs/done.md` -> the amendments member's `done`.
- [ ] `lib/docs/verbs/start.md` -> the member line at start.
- [ ] `lib/docs/verbs/freeze-start.md` -> the member line at start.
- [ ] `lib/docs/verbs/plan-status.md` -> the requests.
- [ ] `lib/docs/verbs/status.md` -> the amendments lines.
- [ ] `docs/reference/08-output-json.md` -> `requests`, `must_rebase`.
- [ ] `tests/verbs/draft.sh` -> the amendments member drafted with the group.
- [ ] `tests/verbs/refine.sh` -> requests, approval, refusal, the config key, `decision` (the group plan and its `Decisions` line in one commit; refused outside the heading's section).
- [ ] `tests/verbs/commit.sh` -> the trailer, `land` (fast-forward only, refusal without the tip).
- [ ] `tests/verbs/done.sh` -> pending requests refused, the empty member archived with `none`.
- [ ] `tests/verbs/plan-status.sh` -> the requests.
- [ ] `tests/verbs/status.sh` -> the amendments lines and the JSON field.
- [ ] `tests/verbs/start.group.sh` -> the member line at start.
- [ ] `tests/integrate_test.sh` -> the group's `done` applying a corrected section.
- [ ] `tests/output_json_test.sh` -> a group's `members` include its amendments member; `plan.requests` in the fixture.
- [ ] `tests/verbs/issue.branch.sh` -> the group's amendments member archived before the group's `done`.
- [ ] `MANUAL.md` -> groups: the amendments member, `aapp.amendmentApprovalRequired`, refining the group plan after `start` (from a member's worktree, or after `aapp active <group>`).
- [ ] `CHEATSHEET.md` -> the tokens.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> its lock rule for `Kind: amendments` is P-99's.
- [ ] `templates/blast-radius-guard.sh` -> the write guard stays as it is.
- [ ] `lib/group_docs.sh` -> reused as it is.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-17:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-17:** Plan activated into ⚡ In Development via start.
* **2026-10-17:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-17:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted from groups P-72 and P-91: an amendments member per group; early draft for review between agents.
* **2026-10-17:** Refined from the settled review (`.plans/pickup/p103-group-lifecycle-rfc.md`): members never amended; requests, approval (`aapp.amendmentApprovalRequired`), landing on P-55's fast-forward path, members rebase; the end rules; status and JSON. Questions 1–9 answered by the review. One guide (developer): corrections are written into the group plan's `## Architecture & Codemap` with a `Decisions` line, never copied into the amendments member; members read the group plan at start and at every session start or resume.
* **2026-10-17:** Unfrozen to add `lib/aapp-lib.sh` (developer's OK): the amendments member is always `microcommits` (`aapp_plan_commit_mode`); it is started by the group's `start`, never frozen (`freeze` refuses a plan without Target Files, and there is nothing to review); a group drafted offline is refused; the MANUAL says where the group plan is refined after `start`.
* **2026-10-17:** Unfrozen to add `tests/output_json_test.sh` and `tests/verbs/issue.branch.sh` (developer's OK): their group fixtures now get an amendments member; plan work, not a hotfix. This group has no amendments member to take it (P-101 creates it).
