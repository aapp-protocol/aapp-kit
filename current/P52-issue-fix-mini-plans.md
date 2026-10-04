# 🗺️ Plan P-52: Issue Fix Mini Plans (`aapp issue fix`)
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-04
* **Target Issue / Milestone:** #98 *(also resolves #87)*
* **Plan ID:** P-52
* **Changelog:** Added: `aapp issue fix` opens a temporary mini plan for a small or emergency fix; frozen plans no longer block edits
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
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

**Goal:** a small or emergency fix gets a **temporary mini plan** scoped to one issue and its files: created when the fix starts, deleted when it completes. The issue row (with the fix commit's SHA) is the permanent record; no ledger row, no archive file, no plan number. No new verb: it is a subcommand of `aapp issue`.

---

## 2. Technical Blueprint

### 2.1 Start: `aapp issue fix <num> file <path> [file <path>]…` (`lib/cmd_issue.sh`)
Refuses, with nothing written, when:
- `#<num>` is not an active row in `ISSUES.md`;
- no `file` is given, or a fix for `#<num>` is already in progress (its mini plan exists);
- any listed file (except shared docs, P-48) is in the file list of a plan in development, or of another mini plan: `❌ P-51 is changing lib/cmd_commit.sh; make the fix inside P-51 or wait.`

Then, in one `plans_commit` (`fix(start): #<num>`):
- creates `current/fix-<num>.md`: `Plan ID: #<num>`, `Target Issue: #<num>`, `Status: ⚡ In Development`, `Changelog: Fixed: <row's Target Plan / Fix text>` (editable), `Commits: none`, and a §4 file list of exactly the given files;
- binds the worktree's active-plan buffer to `#<num>`, saving the previous value in the existing `.prev` slot (an interrupted plan is set aside, not touched).

### 2.2 During the fix
The mini plan is an ordinary in-development file list, so existing machinery applies unchanged: the guard and hook confine edits to its files; `aapp commit` records commits in its header and writes its changelog entry tagged `` (`#<num>`) `` (P-48).

### 2.3 Complete: `aapp issue close <num>` (`lib/cmd_issue.sh`)
When `current/fix-<num>.md` exists:
- refuses if the mini plan recorded no commit (nothing was fixed);
- archives the issue row as today, using the mini plan's **last recorded commit** as the SHA and the summary `Fixed via aapp issue fix: <files>`;
- deletes the mini plan and restores the saved active-plan buffer (back to the interrupted plan, if any);
- all in the one close commit. The plugin notification (P-32) is unchanged.

### 2.4 Abandon: `aapp issue fix <num> abort`
Deletes the mini plan and restores the buffer without closing the issue; refuses if the mini plan recorded commits (close it instead).

### 2.5 No-plan rule in guard and hook (#98)
The frozen-plan special case is removed from `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`: whether or not plans are frozen, behaviour depends only on plans (and mini plans) in development. See Q1 for what "no plan in development" allows.

### 2.6 Recognising mini plans
`current/fix-<num>.md` files are not `P-xx` plans: the plan resolver, Pair 4 (Plan ID integrity), the state matrix and `aapp plan-status` skip them, and the plan-numbering seed ignores them. The guard, hook and `aapp commit` treat them as in-development plans (2.2).

### 2.7 Agent-facing text
- `templates/AGENTS.md` / `.agents/AGENTS.md`: small fixes and blocking mid-plan bugs go through `aapp issue allocate` → `aapp issue fix` → `aapp commit` → `aapp issue close`; *Emergency Hotfix Extensions* is retired from invariant 5 and Issue Escape Triage. CLI Reference row for `aapp issue` shows `fix`.
- `templates/plan-template.md`: invariant 5 "Blocking & small" points to `aapp issue fix`.
- Skills: `aapp-start` (blocking bug mid-plan), `aapp-digest` (small fix path).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Existing plans keep any *Emergency Hotfix Extensions* they already list; new hotfixes use `aapp issue fix`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/issue.sh`: `fix` creates the mini plan and binds the buffer in one commit; refusals (inactive issue, no file, fix already open, file owned by a plan in development); edits outside the files refused by the guard; `close` archives with the fix SHA and file list, deletes the mini plan and restores the previous buffer; `close` with no commit refused; `abort` removes an uncommitted fix and refuses a committed one.
- [ ] Task 1.2: `tests/write-guard_test.sh` and `tests/pre-commit_test.sh`: a frozen plan no longer blocks edits (#98); a mini plan confines like a plan.
- [ ] Task 1.3: `tests/plan_resolver_test.sh`: Pair 4 and the resolver ignore `fix-<num>.md`; `tests/verbs/matrix.sh`: the matrix does not list it.

### Phase 2: Implementation
- [ ] Task 2.1: `fix`, `fix … abort` and the mini-plan path of `close` in `lib/cmd_issue.sh`.
- [ ] Task 2.2: Remove the frozen special case in `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` (Q1 rule).
- [ ] Task 2.3: Mini-plan recognition in `lib/plan_resolver.sh`, `lib/planning_health.sh`, `lib/cmd_matrix.sh`, `lib/cmd_plan.sh`, `lib/cmd_init.sh` (seed).
- [ ] Task 2.4: Contract `lib/docs/verbs/issue.md`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: AGENTS.md (both), `templates/plan-template.md`, skills `aapp-start`, `aapp-digest` (2.7).
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md`, `.agents/CODEMAP.md`, `ARCHITECTURE.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`; then fix #97 through `aapp issue fix 97` as the first real use.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_issue.sh` -> `fix`, `fix … abort`, mini-plan path of `close`.
- [ ] `templates/blast-radius-guard.sh` -> Drop the frozen special case.
- [ ] `templates/aapp-pre-commit` -> Drop the frozen special case.
- [ ] `lib/plan_resolver.sh` -> Skip mini plans.
- [ ] `lib/planning_health.sh` -> Pair 4 skips mini plans.
- [ ] `lib/cmd_matrix.sh` -> Matrix skips mini plans.
- [ ] `lib/cmd_plan.sh` -> `plan-status` and plan scans skip mini plans.
- [ ] `lib/cmd_init.sh` -> Plan-number seed ignores mini plans.
- [ ] `lib/docs/verbs/issue.md` -> Contract: `fix`, `abort`, close of a fix.
- [ ] `tests/verbs/issue.sh` -> Mini-plan lifecycle tests.
- [ ] `tests/write-guard_test.sh` -> Frozen plans don't block; mini plan confines.
- [ ] `tests/pre-commit_test.sh` -> Same at commit time.
- [ ] `tests/plan_resolver_test.sh` -> Resolver and Pair 4 ignore mini plans.
- [ ] `tests/verbs/matrix.sh` -> Matrix ignores mini plans.
- [ ] `templates/plan-template.md` -> Invariant 5 points to `aapp issue fix`.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Blocking bug mid-plan.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Small fix path.
- [ ] `templates/AGENTS.md` -> Fix path; retire hotfix extensions; CLI Reference.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Issue fixes and mini plans.
- [ ] `CHEATSHEET.md` -> `aapp issue fix`.
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
* [ ] **Question 1 — With no plan or mini plan in development, are code edits allowed?** (a) **Allowed**, as when no plan exists today; `aapp issue fix` is the recommended path but not forced. Frees small fixes immediately; such fixes leave only the issue row and commit as record. (b) **Refused**: every code edit needs a plan or a mini plan in development, so every change has a scoped record; a fresh repository needs `aapp issue fix` (or a plan) before its first edit. Recommendation: (a) — it is the direct fix for #98 ("a frozen plan should not block a small fix"); while a plan *is* in development, non-plan files are refused anyway, so `aapp issue fix` becomes the natural path exactly when it matters.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-04:** Drafted from #98 and the developer's design: issue-scoped mini plans, created at the start of a fix and deleted at completion; the issue row is the record (no ledger, no archive, no plan number, no extra column); serves the emergency hotfix path (#87); a subcommand of `aapp issue`, no new verb.
