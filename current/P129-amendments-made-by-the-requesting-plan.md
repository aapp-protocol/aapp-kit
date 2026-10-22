# 🗺️ Plan P-129: Amendments Made By The Requesting Plan
* **Created:** 2026-10-22 | **Last Refined:** 2026-10-22
* **Target Issue / Milestone:** none
* **Plan ID:** P-129
* **Changelog:** Changed: an approved amendment is made by the member that requested it, in one commit recorded in the plan that owns the logic, archived or not
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
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
Today an approved file request (P-101) is added to the group's amendments member's Target Files: the change is made in that member's worktree, landed on the feature branch with `aapp commit … land`, and the requesting member rebases onto it. For a file only the requester needs (P-126 needing defaults in `AAPP::Constants`), that is two worktrees, a separate landing and a rebase, and the change is recorded in the amendments member instead of the plan whose work it is.

This plan keeps the amendments member as the log and the approval point, and moves the work and its record to where they belong:
- the **requester** (the member in development that asked) makes the approved change from its own worktree, in one commit;
- the **owner** (the plan the logic belongs to: the requester by default, or another plan of the same group, current or archived) receives the file, the work description and the commit, so its logic stays together. An amendment for another plan lands on the parent branch at once; the requester's own lands with its `done`;
- the request line stays in the amendments member as the history, and the requester's `done` closes it.

Corrections of the group's text (`heading` requests, `decision`) stay as they are.

---

## 2. Technical Blueprint

### 2.1 Request: requester and owner
1. `aapp refine <amend-id> request "<summary>" file <path> [for <plan-id>]`, from the requester's own checkout as today. `for` names the owner: the group plan or a member of the same group, in `current/` or archived in `done/`; without it the owner is the requester. Any other plan is refused.
2. The request line carries both: `- **R<n>** <date> · <requester> · <path> · <summary> · for <owner> — pending` (` · for <owner>` only when the owner is not the requester).
3. `heading "<heading>"` requests are unchanged.

### 2.2 Approve: the requester may write the file
1. `approve <n>` checks the file against every other plan in development (as today), sets `approved (<approver>)`, and no longer adds the file to the amendments member's Target Files.
2. The write guard (`templates/blast-radius-guard.sh`) and the pre-commit hook (`templates/aapp-pre-commit`) treat the file of each approved request naming the bound plan as its requester, with no commit yet, as a target of that plan, next to its §4. One reader in `lib/aapp-lib.sh` (`amend_approved_files <plan-id>`) serves both. The requester's §4 is never edited, so its design lock stays as it is.
3. Once R<n>'s commit is made the file is no longer writable through R<n>: a further change to it is a new request, which keeps changes to one file apart.
4. With `aapp.amendmentApprovalRequired = false` a file request is approved when it is made (`approved (auto)`); `refine <amend-id> file <path> "<reason>"` leaves the kit (clean break).

### 2.3 Commit: one commit per amendment
1. `aapp commit "<msg>" amendment <n>` from the requester's worktree commits R<n>'s change: refused unless R<n> is approved, names the bound plan as requester, has no commit yet, and the staged files are exactly R<n>'s file. The commit carries the trailer `Amendment: R<n>`. It does not count against the requester's `atomic` commit mode and is not recorded in the requester's `* **Commits:**`.
2. **Owner is another plan: lands at once.** The commit is built on the tip of the requester's parent branch (the branch in its `* **Base:**`: the feature branch for a group member), without a visible worktree, and the parent branch moves to it only when it has not moved meanwhile (as `done`'s landing does). It is refused when R<n>'s file on the parent's tip differs from the requester's copy before the change (another landing changed it): "rebase onto `<parent>` first". A parent that moved in other files is no reason to refuse. The change leaves the requester's index and worktree, and the requester's branch is rebased onto the parent (`git rebase --autostash`). The commit's hash is final: the request line becomes `landed \`<sha>\``, and the owner's record (§2.4.2) is written in the same plans commit. Other members get it with their next rebase. A squash of the requester later covers only its own commits, on top of the amendment.
3. **Owner is the requester: lands with its `done`.** The commit stays on the requester's branch, and the request line becomes `committed`.

### 2.4 The record in the owner, and closing at done
1. The requester's `done` refuses nothing because of amendments. It finds its own amendment commits by their trailer after integration (with `ff` the commit itself; with a squash the squash commit), and then closes every request it made, in the same plans commit as the archive: `landed \`<sha>\`` becomes `closed · landed \`<sha>\``; an approved request never committed becomes `closed · unused`. `aapp plan abort` closes the requester's open requests as `closed · withdrawn`. A closed request's file needs a new request.
2. The owner's record, written when the commit lands (§2.3.2, or the requester's `done` for its own):
   - its `### 📂 Target Files` gains `- [x] \`<path>\` -> R<n> (by <requester>)`;
   - its `### Amendments`, a subsection of §4 after `### 🛑 Out of Bounds` (created on first use), gains `- R<n> <date> · \`<path>\` · <summary> (by <requester>, landed \`<sha>\`)`.
   Its `* **Commits:**` line stays its own work, so it agrees with `000-archive-ledger.md`.
3. An archived owner (`done/`) gets the same lines appended. The archived plan stays final: nothing in it is rewritten; its after-care is appended as amendments, so a reader looking back at how its work was done also finds what came later. Only a commit or `done` of the same group appends, and the pre-commit design lock accepts these two lines in the owner and nothing else.

### 2.5 The amendments member
Keeps the request log (`## Scope Requests`), approval, refusal, and the group text's decisions (`## Decisions`). It no longer implements files: its template, its §3 and its `done` check (no request still pending or approved) follow.

### 2.6 Rules, docs, Perl port
`templates/AGENTS.md` (Plan groups: after approval the requester makes the change with `aapp commit … amendment <n>`), the verb contracts (`refine`, `commit`, `done`), `MANUAL.md`, `CHEATSHEET.md` and `ARCHITECTURE.md` describe the new route. The Perl port carries it: the group P-111 members porting `refine`/`done` (P-119), `commit` (P-120) and the hooks (P-116) take this behaviour as the bash one.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`: an approved file never enters the amendments member's Target Files again; `refine … file` goes.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests first
- [ ] Task 1.1: Failing tests for §2.1–2.5 in the `refine`, `commit` and `done` verb suites; the write guard is called directly there (as `companion.sh` does), the pre-commit hook runs with each commit. (`tests/pre-commit_test.sh` and `tests/write-guard_test.sh` belong to P-112 while group P-111 runs.)

### Phase 2: Request, approve, write
- [ ] Task 2.1: `request … for <plan-id>` and the request line (§2.1); `approve` without the amendments member's Target Files, auto-approval, `file` removed (§2.2).
- [ ] Task 2.2: `amend_approved_files` read by the write guard and the pre-commit hook; the file locked after its commit (§2.2.2–3).

### Phase 3: Commit, record and close
- [ ] Task 3.1: `aapp commit … amendment <n>`: the trailer; landing at once on the parent with the requester's rebase when the owner is another plan (§2.3).
- [ ] Task 3.2: The owner's record, current or archived, and the lock's acceptance (§2.4.2–3).
- [ ] Task 3.3: `done` closes the requester's requests and records its own amendments; `plan abort` withdraws them (§2.4.1).
- [ ] Task 3.4: The amendments member's template and done check (§2.5).

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run automated test suites and verify edge cases (owner archived, the parent moved meanwhile, the requester squashed after an amendment landed, an unused approval at done).
- [ ] Task 4.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 4.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 4.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 4.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> `request … for`, `approve`, auto-approval, `file` removed; `done` closes requests and records own amendments; `plan abort` withdraws.
- [ ] `lib/cmd_commit.sh` -> `commit … amendment <n>`: trailer, landing at once on the parent, the requester's rebase, the owner's record.
- [ ] `lib/aapp-lib.sh` -> Request line readers (owner, state, hash), `amend_approved_files`, the owner's record writer.
- [ ] `templates/blast-radius-guard.sh` -> Approved request files are targets of their requester until committed.
- [ ] `templates/aapp-pre-commit` -> The same at commit time; the owner's amendment lines accepted by the design lock.
- [ ] `templates/amendments-template.md` -> The member keeps the log and the decisions only.
- [ ] `templates/AGENTS.md` -> Plan groups: the requester makes the approved change.
- [ ] `lib/docs/verbs/refine.md` -> Contract.
- [ ] `lib/docs/verbs/commit.md` -> Contract.
- [ ] `lib/docs/verbs/done.md` -> Contract.
- [ ] `tests/verbs/refine.sh` -> Tests.
- [ ] `tests/verbs/commit.sh` -> Tests.
- [ ] `tests/verbs/done.sh` -> Tests.
- [ ] `lib/verbs.tsv` -> Usage lines of `refine` and `commit`.
- [ ] `MANUAL.md` -> Plan groups and amendments.
- [ ] `CHEATSHEET.md` -> The new tokens.
- [ ] `ARCHITECTURE.md` -> The amendments route.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/` -> The Perl port takes this behaviour in its own members (P-116, P-119, P-120).

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1:** Bash code on `feature/perl-port-of-the-kit`, the branch the installed kit runs, so it is used at once; the Perl members port it (notes in P-116, P-119, P-120). Decided 2026-10-22.
* [x] **Question 2:** The landed hash in the owner only on its `### Amendments` line (§2.4.2), so its `* **Commits:**` line agrees with the archive ledger. Decided 2026-10-22.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-22:** Drafted from the design settled in chat (requester makes the change, owner keeps the record).
* **2026-10-22:** Review: an amendment for another plan lands on the parent at once (no squash handling, no hash tracking); the file locks after its commit; `done` refuses nothing and closes the requests.
