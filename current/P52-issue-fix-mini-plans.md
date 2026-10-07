# 🗺️ Plan P-52: Issue Fix Mini Plans (`aapp issue fix`)
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** #98 *(also resolves #87)*
* **Plan ID:** P-52
* **Changelog:** Added: `aapp issue hotfix` blocks a plan on a logged, queued issue, and `aapp issue fix` opens a temporary mini plan for it, one fix at a time; frozen plans no longer block edits
* **Status:** 🔷 Frozen
* **Base:** `2d7ba74` (develop)
* **Commits:** `d0b734d` (develop)
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 1. Context & Architectural Goal

Small fixes have no safe, recorded path:

1. **Frozen plans block everything (#98).** With a plan `🔷 Frozen` and none in development, the guard (`templates/blast-radius-guard.sh:408-421`) and the hook refuse every edit outside the always-allowed files. A frozen plan is backlog; it should restrict nothing. This blocked the one-word fix for #97.
2. **Same-file hazard.** A fix made in the same files as a plan in development mixes into that plan's commits: whoever commits first stages both edits.
3. **Emergency hotfixes fight the design lock (#87).** A blocking bug outside a plan's files must be added under *Emergency Hotfix Extensions* in the plan's §4, which the design lock refuses once frozen — forcing a Refining → freeze → start round trip (twice during P-48).
4. **No record of small fixes beyond the issue row**, and no file confinement while making them.
5. **Unbound checkouts adopt plans held elsewhere.** With no buffer, the guard, the hook (also its changelog check), `aapp commit` and `aapp active` take the single `⚡` plan as active even when another worktree holds it, so a checkout next to a plan's worktree is confined to that plan, or refused when two run. Mini plans are `⚡` too and would add to it (RFC C11, C15).
6. **A plan that hits a blocking bug has no hotfix path.** Blocking it, logging the issue, and getting the fix done elsewhere are separate manual steps with no record on the plan of how often it was interrupted (RFC p52-p54, settled design).

**Goal:** a small or emergency fix gets a **temporary mini plan** scoped to one issue and its files: created when the fix starts, deleted when it completes. The issue row (with the fix commit's SHA) is the permanent record; no ledger row, no archive file, no plan number. A plan that hits a blocking bug outside its files **hands it off with one command**, which logs the issue, queues it, records the hotfix on the plan and blocks it; fixes run **one at a time**, taken from that queue. No new verb: `hotfix` and `fix` are subcommands of `aapp issue`.

---

## 2. Technical Blueprint

### 2.1 Hotfix: `aapp issue hotfix "<text>" [file <path>]… [plan]` (`lib/cmd_issue.sh`)
Run by the agent in the plan's worktree; the plan is the one bound in that worktree's buffer. Refuses, with nothing written, when no plan is bound. Plan work vs hotfix is decided by **scope, not by file** (RFC, settled 2026-10-07): a bug unrelated to the plan's change is a hotfix even in one of the plan's own files, otherwise the plan would stall for good. **In single-checkout mode** (no `* **Worktree:**` recorded, so the fix will share this working copy), uncommitted changes in the listed files are set aside first: `git stash push --include-untracked -m "aapp-hotfix:<plan>:#<num>" -- <files>`, recorded by SHA in `$(git rev-parse --git-path aapp_hotfix_stash)` (SHA addressing as `aapp pause` does); other work in progress stays in place. In worktree mode nothing is stashed: the plan's work stays in its worktree. Then, under the issue lock (2.6) and in **one** `.plans` commit (`issue(hotfix): #<num> blocks <plan>`):
- allocates the issue number (`allocate_issue_id`: the `aapp-issue-tracker` provider when installed, else the local counter);
- writes the `ISSUES.md` row: Symptom = `<text>`, Sev `High`, Type `CORE`, Location = the `file` paths as backticked paths (written once; an observation cell, never changed), Target Plan / Fix = `blocks [<plan>](current/<file>)`, Status 🟡 Incubated;
- queues `#<num>` under **🧱 Plan Blockers** at the top of `issues_road_map.md` (hotfix order; reorderable like any road-map section);
- appends `#<num>` to the plan's append-only `* **Emergency Hotfixes:**` line (no duplicates; never removed, whatever later happens to the fix);
- blocks the plan through `refine`'s write function (P-49), called in-process: Status `🟥 BLOCKED`, `#<num>` appended to `* **Blocked On:**` (a list, recording the status it had before);
- **limit:** when the plan's `Emergency Hotfixes:` count exceeds `aapp.maxEmergencyHotfixes` (default **2**), the block is **permanent**: `Blocked On:` carries `hotfix limit reached (#…)`, `issue close` never lifts it, only the developer does (by re-scoping the plan with `refine`). The issue is still logged and queued, and its fix still proceeds;
- re-derives `state_matrix.md` (`sync_state_matrix`), commits, prints the issue number.

**`plan` token (big issue):** instead of queueing, drafts a plan from the issue (P-50's promotion, called internally) and marks the row 🔵 Planned with the draft's link. The issue stays in the blocked plan's `Blocked On:`; `aapp done` of the new plan closes it (P-32), which unblocks through 2.4. An overestimate costs little: the draft can be refined into an issue fix, or aborted to go the mini-plan way.

### 2.2 Start a fix: `aapp issue fix next-blocker` | `aapp issue fix <num> file <path> [file <path>]…` (`lib/cmd_issue.sh`)
Runs in the main checkout; refused inside a recorded plan worktree (P-54).
- **One fix at a time.** While a mini plan exists, `fix` waits, printing each wait (2 s, 3 s, 4 s, …), up to `aapp.issueFixWait` minutes (default **5**; `0` = fail fast, for dispatch runners). When the limit is reached → exit 1: `⏳ #41 is still being fixed; retry later.` One at a time keeps fixes in different commits and the single `.prev` buffer slot safe (RFC C93). Agent text: run it with a tool timeout longer than the wait.
- **`next-blocker`** claims the top 🧱 Plan Blocker it can take now (one whose files have no uncommitted changes here; others are skipped and stay queued, so the queue never stalls); the mini plan's files are the backticked paths in that issue row's Location (any `:lines` suffix ignored). Bare `next` already means "peek the next ID" (`aapp issue next`), hence the explicit token.
- **`<num> file …`** starts a fix for any active issue, or adds files to the open mini plan of `#<num>`.

Refuses, with nothing written, when:
- `#<num>` is not an active row in `ISSUES.md`, or `next-blocker` finds an empty queue;
- no file is known (no `file` token and no Location paths);
- any file has uncommitted changes in this working copy (they would mix into the fix commit): `❌ lib/x.sh has uncommitted changes here; commit or stash them first.` A fix that came through `hotfix` never hits this: the stash already set those files aside.

Which plan lists a file no longer matters: a plan in development picks the fix up by rebase (worktree) or simply continues on top of it (single checkout), and a bound mini plan may edit its own files even when a `🟥 BLOCKED` plan lists them (2.9).

Then, under the issue lock (2.6) and in one `plans_commit` (`fix(start): #<num>`):
- creates `current/fix-<num>.md`: `Plan ID: #<num>`, `Target Issue: #<num>`, `Status: ⚡ In Development`, `Changelog: Fixed: <text>` (the row's Target Plan / Fix text, or its Symptom for hotfix rows, whose Target Plan / Fix is the plan link; editable), `Commits: none`, and a §4 file list of exactly those files;
- binds the worktree's active-plan buffer to `#<num>`, saving the previous value in the existing `.prev` slot (an interrupted plan is set aside, not touched).

### 2.3 During the fix
The mini plan is an ordinary in-development file list, so existing machinery applies unchanged: the guard and hook confine edits to its files; `aapp commit` records commits in its header and writes its changelog entry tagged `` (`#<num>`) `` (P-48).

### 2.4 Complete: `aapp issue close <num>` (`lib/cmd_issue.sh`)
When `current/fix-<num>.md` exists:
- refuses if the mini plan recorded no commit (nothing was fixed);
- archives the issue row as today, using the mini plan's **last recorded commit** as the SHA and the summary `Fixed via aapp issue fix: <files>` (plus `; unblocks <plan>` for a hotfix);
- deletes the mini plan and restores the saved active-plan buffer (back to the interrupted plan, if any);
- in single-checkout mode, re-applies the plan's hotfix stash recorded for `#<num>` (by SHA) on top of the fix; a conflict keeps the stash and is reported with the files to resolve; nothing is lost.

For every close of an issue that blocks a plan — through `issue close`, or `aapp done` of a promoted plan (P-32, the same `issue_close_local` path):
- removes `#<num>` from 🧱 Plan Blockers and from the plan's `Blocked On:`; `Emergency Hotfixes:` is untouched;
- when `Blocked On:` is then empty and the block is not permanent, restores the plan's previous status;
- re-derives `state_matrix.md`; prints the next step: `rebase <plan branch> onto <devBranch>` (P-54);
- all in the one close commit. The plugin notification (P-32) is unchanged.

### 2.5 Abandon: `aapp issue fix <num> abort`
Deletes the mini plan and restores the buffer without closing the issue; refuses if the mini plan recorded commits (close it instead). A hotfix issue stays queued and in its plan's `Blocked On:`: the plan is still blocked by that bug.

### 2.6 Issue lock
Agents can claim faster than a commit lands, and local allocation reads and bumps a git-config counter, so two hotfixes could get the same number and two `next-blocker` calls the same issue. One lock directory, `$(git rev-parse --git-common-dir)/aapp_issue.lock`, shared by every worktree and taken atomically with `mkdir`, covers `hotfix` (allocate → row → queue → block → commit) and the start of a `fix` (claim → mini plan → commit); it is held for seconds, not for the whole fix. Waiters use the same roller within `aapp.issueFixWait`. The holder writes its PID right after `mkdir`. Stale: an **empty** PID after a few seconds; a **non-empty** PID only when that process is gone, whatever the lock's age (provider calls and `.plans` commits retrying on their own lock may take long). Taking over a stale lock prints a notice. With the `aapp-issue-tracker` provider installed, it is the authority for allocation and claims (it gains a `next-blocker` action, mirroring `allocate`); the lock still guards the local writes.

### 2.7 Configuration (`lib/cmd_init.sh`, seeded only when absent)
| Key | Default | Meaning |
| :--- | :--- | :--- |
| `aapp.issueFixWait` | `5` | Minutes `fix` and the issue lock wait; `0` = fail fast |
| `aapp.maxEmergencyHotfixes` | `2` | Hotfixes a plan may take; the next one blocks it permanently. P-55 reads it as its integration fallback |

Both are more hardcoded defaults for #99 to gather.

### 2.8 No-plan rule in guard and hook (#98)
The frozen-plan special case is removed from `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`: whether or not plans are frozen, behaviour depends only on plans (and mini plans) in development. With none in development, edits are allowed (Q1), subject to 2.9's rule for plans held elsewhere.

### 2.9 Plans held by another worktree
- **Discovery skips them.** A library helper in `lib/aapp-lib.sh` lists the `⚡` plans (and mini plans) not held by another worktree's buffer. It reads `git worktree list` once and each worktree's buffer once, skips the current worktree and worktrees whose directory is gone (as `find_worktree_holding_plan` does). All five single-plan discovery sites use it: the guard, the hook's plan check, the hook's changelog check, `aapp commit` and `aapp active` without an id.
- **Overlap checks do not.** The activation gate (`check_disjointness_activation_gate`) and Pair 7 keep counting every `⚡` plan: overlap across worktrees is what they detect.
- **A bound mini plan may edit its own files even when a `🟥 BLOCKED` plan lists them** (guard and hook): the BLOCKED rule stops the blocked plan, not its sanctioned fix.
- **Their files stay protected.** In a checkout with no buffer, the guard and the hook refuse files in the Target Files of a plan held elsewhere (shared docs excepted, P-48), mirroring the existing refusal for `🟥 BLOCKED` plans' files: `❌ lib/x.sh belongs to P-51 (in ../repo-P51).` All other files follow Q1.

### 2.10 Recognising mini plans
`current/fix-<num>.md` files are not `P-xx` plans: the plan resolver, Pair 4 (Plan ID integrity), the state matrix and `aapp plan-status` skip them, and the plan-numbering seed ignores them. The guard, hook and `aapp commit` treat them as in-development plans (2.3), including 2.9.

### 2.11 Agent-facing text
- `templates/AGENTS.md` / `.agents/AGENTS.md`: a blocking bug **unrelated to the plan's change** → `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan), then stop, even when the file is one of the plan's own; a bug the plan's change causes, or code it must rewrite anyway, is plan work. In single-checkout mode the hotfix stashes the plan's uncommitted work in those files and `issue close` re-applies it. Small fixes in the main checkout: `aapp issue fix next-blocker` (or `<num> file …`) → `aapp commit` → `aapp issue close`; run `fix` with a tool timeout longer than `aapp.issueFixWait`. *Emergency Hotfix Extensions* is retired from invariant 5 and Issue Escape Triage. CLI Reference row for `aapp issue` shows `hotfix` and `fix`.
- `templates/plan-template.md`: invariant 5 "Blocking & small" points to `aapp issue hotfix`; the header comment documents `Emergency Hotfixes:` and `Blocked On:` as written by verbs.
- Skills: `aapp-start` (blocking bug mid-plan → hotfix), `aapp-digest` (small fix path).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Existing plans keep any *Emergency Hotfix Extensions* they already list; new hotfixes use `aapp issue hotfix` / `aapp issue fix`.
- Checkouts with no buffer next to a worktree holding a plan (P-39 worktrees made by hand) no longer adopt that plan: its files are refused there, all other files are free (2.9).
- **Order:** needs P-49 (the `blocked` write function) and P-50's promotion (for `plan`), or brings the latter with it.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/issue.sh`, hotfix: `hotfix` allocates the number, writes the row (Location = backticked `file` paths, Target Plan / Fix = plan link), queues it under 🧱 Plan Blockers, appends `Emergency Hotfixes:`, blocks the plan with the previous status kept, re-derives the matrix, all in one commit; refuses with no bound plan or a file in the plan's own Target Files; the hotfix over `aapp.maxEmergencyHotfixes` blocks permanently and the issue is still logged and queued; no duplicate in `Emergency Hotfixes:`; `plan` drafts a plan, marks the row Planned and does not queue.
- [ ] Task 1.7: `tests/verbs/issue.sh`: `hotfix` accepts a file of the plan's own targets; in single-checkout mode it stashes only the listed files' uncommitted changes (others stay), the mini plan edits that file although the plan is BLOCKED (guard and hook), and `close` re-applies the stash on top of the fix (a conflict keeps the stash); `fix` refuses a file with uncommitted changes; `next-blocker` skips a blocker with dirty files and claims the next. `tests/write-guard_test.sh`, `tests/pre-commit_test.sh`: a bound mini plan may edit and commit its file when a BLOCKED plan lists it.
- [ ] Task 1.2: `tests/verbs/issue.sh`, fix: `fix next-blocker` claims the top blocker with its Location files; `fix <num> file …` starts a fix or adds files to the open one; a second `fix` waits with printed waits and fails after `aapp.issueFixWait` (`0` fails at once); refusals (inactive issue, empty queue, no files, file owned by a plan in development or a BLOCKED plan; the plan-worktree refusal is P-54's); edits outside the files refused by the guard; `close` archives with the fix SHA, deletes the mini plan, restores the previous buffer, removes the issue from the queue and `Blocked On:`, restores the plan's status when the list empties (not a permanent block) and re-derives the matrix; `close` with no commit refused; `abort` keeps a hotfix issue queued and refuses a committed fix; `done` of a promoted plan unblocks the blocked plan.
- [ ] Task 1.3: `tests/verbs/issue.sh`, lock: two concurrent `hotfix` calls get different numbers; two concurrent `next-blocker` calls claim different issues; a lock with a dead PID or an empty PID (after a few seconds) is taken over with a notice; a live PID is waited on.
- [ ] Task 1.4: `tests/write-guard_test.sh` and `tests/pre-commit_test.sh`: a frozen plan no longer blocks edits (#98); a mini plan confines like a plan.
- [ ] Task 1.5: `tests/write-guard_test.sh`, `tests/pre-commit_test.sh`, `tests/verbs/commit.sh`, `tests/verbs/active.sh`: with a plan bound in another worktree, an unbound checkout does not adopt it (guard, hook, changelog check, `aapp commit`, `aapp active`) and is refused that plan's files but not others; the activation gate still sees the held plan.
- [ ] Task 1.6: `tests/plan_resolver_test.sh`: Pair 4 and the resolver ignore `fix-<num>.md`; `tests/verbs/matrix.sh`: the matrix does not list it. `tests/install_test.sh`: the two keys seeded only when absent.

### Phase 2: Implementation
- [ ] Task 2.7: Scope rule and stash (2.1, 2.4), dirty-file refusal and skip (2.2) in `lib/cmd_issue.sh`; BLOCKED-plan exception for a bound mini plan in `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`.
- [ ] Task 2.1: `hotfix`, `fix` (`next-blocker`, `<num> file`, wait roller, `abort`) and the close path (mini plan, unblock, queue) in `lib/cmd_issue.sh`; the issue lock; 🧱 Plan Blockers subheader handling.
- [ ] Task 2.2: Remove the frozen special case in `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` (Q1 rule).
- [ ] Task 2.3: Unbound-plan helper in `lib/aapp-lib.sh`; use it at the five discovery sites (guard, hook ×2, `lib/cmd_commit.sh`, `aapp active` in `lib/cmd_plan.sh`); held plans' files refused in unbound checkouts (2.9).
- [ ] Task 2.4: Mini-plan recognition in `lib/plan_resolver.sh`, `lib/planning_health.sh`, `lib/cmd_matrix.sh`, `lib/cmd_plan.sh`, `lib/cmd_init.sh` (seed); seed `aapp.issueFixWait` and `aapp.maxEmergencyHotfixes`.
- [ ] Task 2.5: Provider `next-blocker` action: `examples/plugins/aapp-issue-tracker/run.sample` and the provider contract in `MANUAL.md`.
- [ ] Task 2.6: Contracts `lib/docs/verbs/issue.md`, `lib/docs/verbs/commit.md`, `lib/docs/verbs/active.md`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: AGENTS.md (both), `templates/plan-template.md`, `templates/issues_road_map.md` (🧱 Plan Blockers), skills `aapp-start`, `aapp-digest` (2.11).
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md`, `.agents/CODEMAP.md`, `ARCHITECTURE.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`; then fix #97 through `aapp issue fix 97 file …` as the first real use.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_issue.sh` -> `hotfix`, `fix` (`next-blocker`, `<num> file`, wait, `abort`), close path with unblock, issue lock.
- [ ] `templates/blast-radius-guard.sh` -> Drop the frozen special case; skip and protect held plans (2.9).
- [ ] `templates/aapp-pre-commit` -> Drop the frozen special case; skip and protect held plans, plan and changelog checks (2.9).
- [ ] `lib/plan_resolver.sh` -> Skip mini plans.
- [ ] `lib/planning_health.sh` -> Pair 4 skips mini plans.
- [ ] `lib/cmd_matrix.sh` -> Matrix skips mini plans.
- [ ] `lib/cmd_plan.sh` -> `plan-status` and plan scans skip mini plans; `aapp active` discovery skips held plans.
- [ ] `lib/aapp-lib.sh` -> Unbound-plan helper (2.9).
- [ ] `lib/cmd_commit.sh` -> Discovery skips held plans.
- [ ] `lib/cmd_init.sh` -> Plan-number seed ignores mini plans; seed `aapp.issueFixWait`, `aapp.maxEmergencyHotfixes`.
- [ ] `lib/docs/verbs/issue.md` -> Contract: `fix`, `abort`, close of a fix.
- [ ] `lib/docs/verbs/commit.md` -> Discovery skips held plans.
- [ ] `lib/docs/verbs/active.md` -> Discovery skips held plans.
- [ ] `tests/verbs/issue.sh` -> Mini-plan lifecycle tests.
- [ ] `tests/write-guard_test.sh` -> Frozen plans don't block; mini plan confines.
- [ ] `tests/pre-commit_test.sh` -> Same at commit time.
- [ ] `tests/verbs/commit.sh` -> Held plans not adopted.
- [ ] `tests/verbs/active.sh` -> Held plans not adopted.
- [ ] `tests/plan_resolver_test.sh` -> Resolver and Pair 4 ignore mini plans.
- [ ] `tests/verbs/matrix.sh` -> Matrix ignores mini plans.
- [ ] `tests/install_test.sh` -> New keys seeded only when absent.
- [ ] `templates/issues_road_map.md` -> 🧱 Plan Blockers subheader.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> `next-blocker` action.
- [ ] `templates/plan-template.md` -> Invariant 5 points to `aapp issue hotfix`; `Emergency Hotfixes:` / `Blocked On:` header comment.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Blocking bug mid-plan → hotfix.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Small fix path.
- [ ] `templates/AGENTS.md` -> Hotfix and fix path; retire hotfix extensions; CLI Reference.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Hotfix, issue fixes and mini plans; provider `next-blocker` action; new keys.
- [ ] `CHEATSHEET.md` -> `aapp issue hotfix`, `aapp issue fix`, new keys.
- [ ] `.agents/CODEMAP.md` -> Mini plans.
- [ ] `ARCHITECTURE.md` -> Mini plans in the lifecycle.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/done/000-archive-ledger.md` -> Mini plans never reach the ledger.
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — With no plan or mini plan in development, are code edits allowed? → RESOLVED (developer, 2026-10-04): (a), with held plans' files refused (2.9).** (a) **Allowed**, as when no plan exists today; `aapp issue fix` is the recommended path but not forced. Frees small fixes immediately; such fixes leave only the issue row and commit as record. (b) **Refused**: every code edit needs a plan or a mini plan in development, so every change has a scoped record; a fresh repository needs `aapp issue fix` (or a plan) before its first edit. Recommendation: (a) — it is the direct fix for #98 ("a frozen plan should not block a small fix"); while a plan *is* in development, non-plan files are refused anyway, so `aapp issue fix` becomes the natural path exactly when it matters.

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-07:** Plan activated into ⚡ In Development via start.
* **2026-10-07:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-07:** Refined (RFC, settled 2026-10-07): plan work vs hotfix by scope, not by file (`hotfix` accepts the plan's own files); single-checkout hotfix stashes only the fix's files and `close` re-applies them; worktree mode resumes with `rebase --autostash` (P-54); a bound mini plan may edit files a BLOCKED plan lists; `fix` refuses only files with uncommitted changes; `next-blocker` skips blockers it cannot take.
* **2026-10-07:** Implementation notes (`d0b734d`): the plans-branch design lock skips mini plans (`fix-*.md`), since a ⚡ plan's §4 is locked and `aapp issue fix <num> file` must extend an open fix; the `done`-unblocks test lives in `tests/verbs/issue.sh` (a target), not `tests/verbs/done.sh`; `hotfix … plan` makes two commits (the hotfix, then `draft`'s own).
* **2026-10-07:** Renamed `aapp issue handoff` to `aapp issue hotfix` (developer): vendor-neutral, and one word with `Emergency Hotfixes:` and `aapp.maxEmergencyHotfixes`; misuse is caught both ways (`hotfix` needs a bound plan, `fix` is refused in a plan worktree).
* **2026-10-05:** Refined from the P-52/P-54 review RFC (settled hand-off and fix design; C97–C101): `aapp issue handoff "<text>" [file …] [plan]` logs, queues (🧱 Plan Blockers), records `Emergency Hotfixes:` and blocks the plan in one commit, permanently above `aapp.maxEmergencyHotfixes` (2); `fix next-blocker` takes files from the row's Location; fixes one at a time with a verbose wait (`aapp.issueFixWait`, 5, `0` = fail fast); close unblocks and prints the rebase step; issue lock with PID-based stale recovery; provider `next-blocker` action.
* **2026-10-04:** Refined from the P-52/P-54 review RFC (C11, C15, C16, C52, C53, C55; user decisions on Q1 and C17): plans held by another worktree are skipped by the five discovery sites and their files protected in unbound checkouts (2.6); `fix` refuses files of BLOCKED plans; bugs in a plan's own files stay plan work; Q1 resolved (a).
* **2026-10-04:** Drafted from #98 and the developer's design: issue-scoped mini plans, created at the start of a fix and deleted at completion; the issue row is the record (no ledger, no archive, no plan number, no extra column); serves the emergency hotfix path (#87); a subcommand of `aapp issue`, no new verb.
