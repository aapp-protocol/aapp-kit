# 🗺️ Plan P-130: Perl Amendments Ledger
* **Created:** 2026-10-23 | **Last Refined:** 2026-10-23
* **Target Issue / Milestone:** none
* **Plan ID:** P-130
* **Changelog:** Changed: the amendments ledger enforces each request's owner plan and reason, checks every claim on a file across plans and ledgers, and keeps no worktree of its own
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
A group's amendments member is the group's central ledger: every change to the group's planning after it was drafted (a file a member needs, a re-scope, a missing dependency, a shortcoming, a correction of the group's text) is requested, decided and recorded there, in one file an orchestrator (a person, an agent, a web view) reads and acts on. The plan the change belongs to keeps the same record under `### Amendments`, so its logic stays with it, archived or not.

P-129 gave the bash kit the route (the requester makes an approved change in one commit; for another owner it lands at once on the parent and the owner records it; the requester's `done` closes its requests). What it lacks is built here once, in Perl, on the modules P-116 (hooks), P-119 (`refine`, `start`, `done`, `plan abort`) and P-120 (`commit`) port: the owner is enforced from the group's own records, every request says why, every claim on a file is checked across plans and ledgers, and the ledger needs no worktree. The bash kit keeps P-129's behaviour unchanged.

---

## 2. Technical Blueprint

### 2.1 A request carries its details
1. `aapp refine <amend-id> request "<why>" file <path> [for <owner-id>]`, from the requester's checkout: the requester and its plan ID come from the checkout's bound plan; the why is required and is the line copied into the owner's `### Amendments`.
2. The owner is enforced from the group's records, the §4 Target Files of the group plan and every member, in `current/` and `done/`, earlier amendment lines included:
   - one plan lists the path: that plan is the owner; `for` may be omitted and is filled in; a different `for` is refused, naming the owner;
   - several plans list it (a shared document): `for` is required and names one of them;
   - no plan of the group lists it (a new file): the owner is the requester, unless `for` names another plan of the group;
   - a plan outside the group lists it: refused, naming that plan.
3. A request without a file or heading records a deviation, a missing dependency or a shortcoming of the planning; it is listed with the others (2.5) and closed like them.
4. The next R number is taken inside the plans commit's lock, so two agents requesting at once never share a number.

### 2.2 One reader of claims
`AAPP::State` answers, for a path, every claim on it: the design targets (§4) of every plan in development, and every approved, not yet committed request in every amendments member in `current/`; an owner's amendment record lines (`-> R<n> (by …)`) and an amendments member's own Target Files are no claims. `approve`, `start` / `freeze-start` (the disjointness gate), the write guard and the pre-commit hook all ask it, so an approval holds a file against every plan and every group until its commit.

### 2.3 Who makes the change, and the record
1. The owner is another plan: the requester's one commit (`aapp commit "<msg>" amendment <n>`) lands at once on its parent branch, built on the tip under the `integrate/<parent>` lock and refused when the file moved there; the requester is rebased; the owner's Target Files line and `### Amendments` line (the why, the requester, the landed commit) are written in the same plans commit.
2. The requester owns it: the commit stays on its branch and lands with its `done`, which writes its own record.
3. The amendments member makes no change itself: what it would land would land late for the rest of the group.
4. A re-scope of a member in development goes through the ledger, one request per file with its why, never through an unfreeze of its §2 and §4.

### 2.4 The amendments member has no worktree
It never commits code: the group's `start` gives it no branch and no worktree; `decision` runs from a checkout bound to a plan of the group; its `done` integrates nothing and records `none`; its §4 stays empty.

### 2.5 The ledger is readable as one record
`aapp plan-status <amend-id> [json]` lists every request (file, heading, or deviation) with its requester, owner, why, state and commit, so an orchestrator collects the group's whole picture with one command.

### 2.6 Port notes
P-116, P-119 and P-120 port P-129's bash behaviour; this member changes their Perl code as §2.1–2.5 say. The contracts (`refine`, `commit`, `done`, `start`, `freeze-start`, `plan-status`) and the amendments template follow.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`: a request without a why, or with an owner the records contradict, is refused; the amendments member's worktree goes.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests first
- [ ] Task 1.1: Failing tests in `t/verb/refine.t`, `t/verb/commit.t`, `t/verb/done.t`, `t/verb/start.t`, `t/verb/plan-status.t` for §2.1–2.5.

### Phase 2: Requests and claims
- [ ] Task 2.1: The request's why and the owner's enforcement (§2.1.1–2); deviation requests (§2.1.3); the R number inside the lock (§2.1.4).
- [ ] Task 2.2: The one reader of claims in `AAPP::State`, asked by `approve`, `start`/`freeze-start`, the write guard and the pre-commit hook (§2.2).

### Phase 3: The ledger
- [ ] Task 3.1: A re-scope through the ledger (§2.3.4); the amendments member without a worktree (§2.4); `plan-status` of the ledger, terminal and JSON (§2.5).

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run both test runners; concurrent requests, a claim across two groups, a start refused by an approval.
- [ ] Task 4.2: Contracts, the amendments template and `templates/AGENTS.md`; the group's `## Architecture & Codemap` by a request to P-112.
- [ ] Task 4.3: Log every finding outside the Target Files as an issue; none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/AAPP/State.pm` -> The one reader of claims; request line readers (owner, why).
- [ ] `lib/AAPP/Plan.pm` -> `start`/`freeze-start` disjointness by claims; the amendments member without a worktree.
- [ ] `lib/AAPP/Cmd/Plan.pm` -> `refine request|approve|decision`, `done`, `plan abort`, `plan-status` of the ledger.
- [ ] `lib/AAPP/Cmd/Commit.pm` -> `commit … amendment <n>` over the claims reader.
- [ ] `lib/AAPP/Hooks/WriteGuard.pm` -> Claims from the one reader.
- [ ] `lib/AAPP/Hooks/PreCommit.pm` -> Claims from the one reader; the owner's amendment lines accepted by the design lock.
- [ ] `templates/amendments-template.md` -> The ledger's role; no Target Files, no worktree.
- [ ] `templates/AGENTS.md` -> Plan groups: the request's why and owner; re-scope through the ledger.
- [ ] `lib/docs/verbs/refine.md` -> Contract.
- [ ] `lib/docs/verbs/commit.md` -> Contract.
- [ ] `lib/docs/verbs/done.md` -> Contract.
- [ ] `lib/docs/verbs/start.md` -> Contract.
- [ ] `lib/docs/verbs/freeze-start.md` -> Contract.
- [ ] `lib/docs/verbs/plan-status.md` -> Contract.
- [ ] `t/verb/refine.t` -> Tests.
- [ ] `t/verb/commit.t` -> Tests.
- [ ] `t/verb/done.t` -> Tests.
- [ ] `t/verb/start.t` -> Tests.
- [ ] `t/verb/plan-status.t` -> Tests.
- [ ] `CHEATSHEET.md` -> The request's form.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/*.sh` -> The bash kit keeps P-129's behaviour; P-122 removes it.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** A deviation request (no file, no heading): a request like the others, or its own word (`refine <amend-id> note "<text>"`)?
* [ ] **Question 2:** Its place in the group's order: after P-120 (this draft's assumption: it changes P-116's, P-119's and P-120's Perl code), before P-121?

---

## 📦 6. Change Log & Refinement History
* **2026-10-23:** Drafted from the review of P-129 with the developer: the owner enforced, the why required, claims checked across plans and ledgers, the ledger without a worktree, built in Perl only.
