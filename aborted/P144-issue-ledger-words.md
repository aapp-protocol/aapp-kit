# 🗺️ Plan P-144: Issue Ledger Words
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Target Issue / Milestone:** none
* **Plan ID:** P-144
* **Changelog:** Changed: `aapp refine issues` and its `branch` / `note` tokens become `aapp issue commit`, `aapp issue branch`, `aapp issue note`; every issue word fires a new `pre-issue` gate and `post-issue`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ❌ Aborted
* **Aborted:** 2026-10-28 | **Reason:** Group P-140 aborted: Absorbed into group P-111
* **Base:** none
* **Group:** P-140
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log <sev> <type> "<symptom>" file <path>…`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A member of group P-140 (noun-first CLI). `aapp refine issues "<msg>"` carries three jobs on one verb: committing a hand edit of the issue ledgers, naming the branch an issue's fix lands on (`branch <num> <name>`), and adding a note kept outside Git (`note <num> "<text>"`). Each becomes its own word on the `issue` noun: `aapp issue commit`, `aapp issue branch`, `aapp issue note`. Their checks, effects and provider calls stay as they are; what changes is that each word does one thing, and `refine issues` leaves the kit. Runs after the Perl port (P-111): the code moved is the ported Perl code. The group's §2 rules apply.

---

## 2. Technical Blueprint

### 2.1 The words
| Today | After | Module (`lib/AAPP/Runner/Issue/…`) |
|---|---|---|
| `aapp refine issues "<msg>"` | `aapp issue commit "<msg>"` | `Commit.pm` |
| `aapp refine issues "<msg>" branch <num> <name>` | `aapp issue branch <num> <name>` | `Branch.pm` |
| `aapp refine issues "<msg>" note <num> "<text>"` (repeatable) | `aapp issue note <num> "<text>"` | `Note.pm` |

- **`issue commit "<msg>"`:** commits a hand edit of existing rows of `ISSUES.md` and `issues_road_map.md`, after the same checks as today (table shape, cell count, fix cells, repeated ids, rows added by hand, work-queue lines and sections, each failure named, nothing committed); one commit `issue(triage): <msg>` holding only the ledger files. A row is never added here: `aapp issue log` is the one writer of new rows. Where a tracker keeps the record (the ledgers are not tracked), it is refused: issues are changed on the tracker. After the commit the provider receives one `issue.refine` per changed row, as today.
- **`issue branch <num> <name>`:** names the branch active issue `#<num>`'s fix must land on, in its own commit `issue(triage): #<num> lands on <name>`; the development branch's name clears the cell. Refused: `#<num>` not an active row; `<name>` a branch that exists neither here nor on a remote. Already so: exit 0, `already targets`, no commit. Where a tracker keeps the record, the change goes to the provider and nothing is committed, as today.
- **`issue note <num> "<text>"`:** adds one dated note with its author to active issue `#<num>`. Notes are never in the ledger or in Git: a provider that names `notes` in `handled` keeps them, otherwise the kit's store on this machine does. Nothing is committed. Several notes: run it several times.
- The noun: the three words join the `issue` noun's words (`log`, `hotfix`, `fix`, `queue`, `close`, `abort`, `list`) under `lib/AAPP/Runner/Issue.pm`, in the layout of group §2, with one public `run` each. Their shared ledger code stays in the ledger module the port provides; nothing is copied into the word modules.
- `aapp help issue` lists the three words with the others; the `issue` contract (`lib/docs/verbs/issue.md`) gains them and the `refine` contract loses its `issues` forms.

### 2.2 Events: `pre-issue` and `post-issue`
The issue noun gets its own event pair, fired by **every** issue word: `log`, `hotfix`, `fix`, `queue`, `close`, `abort`, `list`, and the three of §2.1.

| Event | When | Mode |
|---|---|---|
| `pre-issue` (new) | before the word reads or writes anything; for `list`, before the ledger (or the provider) is read | gate: a registered handler that refuses stops the word (exit 1, nothing written); `notify` or a local `aapp.hook.pre-issue` only acts |
| `post-issue` (exists) | after the word's commit or effect; for `list`, after the listing | observer |

Payload (`data`), the shape `post-issue` already has: `command` `"issue"`, `event` the action, then the action's fields.
- **Both events:** `event` and `args` (the arguments after the word, as typed).
- **`post-issue` adds** what the action produced, keeping today's fields: `log` (`issue_id`, `sev`, `type`, `symptom`, `files`), `queue` / `unqueue` (`issue_id`, `level`), `fix` (`issue_id`, `worktree`, `branch`), `close` (`issue_id`, `commit_sha`, `summary`), `hotfix` (`issue_id`, `blocked_plan`, `files`), `abort` (`issue_id`, `reason`); new: `list` (`shown`, `total`), `commit` (`issue_ids` changed, `commit_sha`), `branch` (`issue_id`, `branch`, `commit_sha`), `note` (`issue_id`, `author`, `date`).
- **Note text is not in the payload.** A note may hold real data from a live system; it reaches only the provider that keeps notes. A handler (an event log, a sync to a server) would otherwise copy it out.
- The action today called `withdraw` in the payload is `abort`, the word's name (clean break).
- `pre-refine` / `on-refine` / `post-refine` no longer fire for issue-ledger edits.
- Handlers may do anything with the payload; the kit ignores their result.

### 2.3 Clean break
After this plan, nothing in the kit names `aapp refine issues` or its `branch` / `note` tokens: the rules (`templates/AGENTS.md`), the skills (`templates/skills/`), the templates' comments, the messages the kit prints (hints that say `aapp refine issues …`), `lib/verbs.tsv`, the contracts, and the user docs.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Contract & tests
- [ ] Task 1.1: The three words in `lib/docs/verbs/issue.md` (syntax, refusals, effects, one test line each); the `issues` forms out of `lib/docs/verbs/refine.md`.
- [ ] Task 1.2: Their tests in the issue verb's test file, carried over from today's `refine issues` tests, failing first under the new names.

### Phase 2: The words
- [ ] Task 2.1: `Commit.pm`, `Branch.pm`, `Note.pm` under `lib/AAPP/Runner/Issue/`, calling the existing ledger, branch and notes code.
- [ ] Task 2.2: `pre-issue` for every issue word, and `post-issue` with the fields of §2.2 (§2.2).
- [ ] Task 2.3: Remove the `issues` forms from `refine`.

### Phase 3: Clean break & documentation
- [ ] Task 3.1: Rules, skills, templates, messages, `lib/verbs.tsv` (§2.3).
- [ ] Task 3.2: User docs (§2.3).
- [ ] Task 3.3: `grep` the kit for `refine issues`: none left outside `CHANGELOG.md` and the plans archive.
- [ ] Task 3.4: Run `t/test-run` and the remaining bash suites; both green.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Commit.pm` -> `issue commit`
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Branch.pm` -> `issue branch`
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Note.pm` -> `issue note`
- [ ] `lib/AAPP/Runner/Issue.pm` -> the three words joined to the noun
- [ ] `lib/AAPP/Runner/Issue/` -> every issue word fires `pre-issue` and `post-issue` (§2.2)
- [ ] `docs/reference/04-plugin-and-hook-engine.md` -> `pre-issue` in the event matrix
- [ ] `docs/reference/09-event-telemetry.md` -> the `pre-issue` / `post-issue` payloads
- [ ] `lib/docs/verbs/issue.md` -> the words' contract lines
- [ ] `lib/docs/verbs/refine.md` -> the `issues` forms removed
- [ ] `lib/verbs.tsv` -> descriptions
- [ ] `t/verb/` -> the words' tests
- [ ] `templates/AGENTS.md` -> rules naming the new words
- [ ] `templates/skills/` -> skills naming the new words
- [ ] `templates/issues.md` -> comments naming the new words
- [ ] `README.md` -> user docs
- [ ] `MANUAL.md` -> user docs
- [ ] `CHEATSHEET.md` -> user docs
- [ ] `docs/` -> user docs
- [ ] `CHANGELOG.md` -> the plan's entry
*(The ported modules this plan calls, and the module that removes the `issues` forms from `refine`, are known once P-111 is done; they are confirmed here before freeze.)*

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Runner/Plan/` -> P-139
- [ ] `lib/AAPP/Runner/Pickup/` -> P-142

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1:** Events: `post-issue` like the other issue words, or keep `pre-refine` / `post-refine`? **Answer:** the issue noun gets its own pair, `pre-issue` and `post-issue`, fired by every issue word with the action in the payload (§2.2).

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Plan aborted: Group P-140 aborted: Absorbed into group P-111
*Tracks how the plan evolved across sessions.*
* **2026-10-27:** Drafted as the issue member of P-140: `refine issues` and its `branch` / `note` tokens become `issue commit`, `issue branch`, `issue note`.
