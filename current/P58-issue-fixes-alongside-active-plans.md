# 🗺️ Plan P-58: Issue Fixes Alongside Active Plans
* **Created:** 2026-10-07 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** None (follow-up to P-52, from its review)
* **Plan ID:** P-58
* **Changelog:** Added: `/aapp-fix #<num>` skill; `aapp issue fix` waits for uncommitted work instead of refusing, takes its files from the issue log, and a plan cannot start on a file a queued plan blocker will change
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
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

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

P-52 lets an issue fix touch a file that an active plan also lists: the plan picks the fix up by rebase (worktree) or continues on top of it (single checkout). Running that unattended exposed three gaps:

1. **A dirty file refuses at once.** `aapp issue fix` refuses a file with uncommitted changes in its working copy ("commit or stash them first"). An unattended fixer must not commit or stash another plan's work, and nothing tells it what to do instead; a person or session that is about to commit is not given time to do so.
2. **A plan can start on a file a queued fix will change.** The activation gate refuses a start when a target file is shared with a ⚡ plan (open mini plans included), but not when a queued 🧱 Plan Blocker is about to change that file, so the new plan starts on code that is known to change under it.
3. **The other plan is never told.** When a fix lands in a file another active plan lists, that plan's agent does not know; in a worktree its branch lacks the fix until it rebases, which P-55's integration check would only reveal at the end.

**Goal:** fixes and active plans coordinate through the existing mechanisms: the same wait roller, the existing activation gate, the agent text, and one notice at close. No new verb, key or event (events are P-23's Q3).

---

## 2. Technical Blueprint

### 2.1 Wait instead of refuse (`lib/cmd_issue.sh`)
- `aapp issue fix <num> file …`: while any of its files has uncommitted changes in this working copy, `fix` waits with the existing roller (2 s, 3 s, …, printed) up to `aapp.issueFixWait`, re-checking each time; then refuses as today. `0` keeps refusing at once (dispatch runners).
- `aapp issue fix next-blocker`: claims the top blocker it can take now (P-52's skip); when every queued blocker has dirty files, it waits the same way for the first to become takeable.
- **Single-checkout hint.** When the wait times out on files listed by the plan bound in this checkout, that plan's own work is the cause and nobody else will clear it: the message names the remedy, `aapp issue hotfix "<text>" file <path>…` (which stashes that work), instead of "commit or stash".
- The fixer never commits or stashes another plan's work itself.

### 2.2 Activation gate counts queued Plan Blockers (`lib/cmd_plan.sh`)
`check_disjointness_activation_gate` (used by `start` and `freeze-start`) also reads the backticked Location paths of every issue under 🧱 Plan Blockers that is active and not 🔵 Planned. A target file among them (shared docs excepted, P-48) refuses the start, with nothing changed: `❌ src/x.py has a pending fix (#102); fix it first ('aapp issue fix next-blocker') or start another plan.` A promoted blocker (Planned) is not in the queue and does not gate; open mini plans are already counted as ⚡ plans.

### 2.3 Notice at close (`lib/cmd_issue.sh`)
`aapp issue close <num>` of a mini plan prints, for every other active plan (⚡ or BLOCKED, mini plans excluded) whose Target Files include one of the fix's files: `ℹ️  P-51 also lists lib/x.sh: it picks this fix up at its next rebase.` Output only; nothing is written.

### 2.4 The fixer's skill: `/aapp-fix [#<num>]` (`templates/skills/aapp-fix/SKILL.md`)
The fixer in the main checkout (often an automated runner) is a role of its own with no entry point today. A CLI-first skill, like the other lifecycle skills:
1. **Claim:** `/aapp-fix #<num>` runs `aapp issue fix <num>`; `/aapp-fix` alone runs `aapp issue fix next-blocker`. **The files come from the issue log** (the row's Location); `file <path>` is only for adding a file the log does not name. Run it with a tool timeout longer than `aapp.issueFixWait`: it waits (printed) while another fix is open or a file is busy.
2. **Fix:** edit only the mini plan's files (the guard enforces it), then `aapp commit`.
3. **Close:** `aapp issue close <num>`; read its output (plan unblocked, stash re-applied or in conflict, "P-51 also lists …").
4. **Rules:** never commit or stash another plan's work; after a timeout, leave that issue and take another; if the fix proves more than small, `aapp issue fix <num> abort` and promote with `aapp draft <slug> issue <num>`.
5. **Fail closed:** on any refusal, stop and explain; never edit the mini plan or the ledgers by hand.
`aapp init` installs every directory under `templates/skills/`, so no code registers it.

### 2.5 Files from the issue log (`lib/cmd_issue.sh`)
`fix` takes from the Location cell only the backticked tokens that are paths: present in the working tree, or path-shaped (contain `/` or a file extension), with any `:lines` suffix stripped. A hand-written cell like `` `templates/aapp-pre-commit` (`ALWAYS_ALLOWED_REGEX`) `` yields just the file (seen fixing #97). Rows written by `hotfix` hold only paths.

### 2.6 Agent text
- `templates/AGENTS.md` / `.agents/AGENTS.md` (Issue Escape Triage and the small-fix lines): a fixer never commits or stashes another plan's work; `fix` waits for it, and after a timeout the fixer leaves that issue (`next-blocker` takes another) and retries later. Every plan in a worktree rebases with `git rebase --autostash <devBranch>` when it resumes and before `aapp done`: fixes to its files may have landed; conflicts in its own lines are its to resolve. A start refused for a pending fix means: fix it first, or start another plan.
- `templates/skills/aapp-start/SKILL.md`: the gate's new refusal; rebase at resume.
- `templates/AGENTS.md` / `.agents/AGENTS.md`: the small-fix lines point to `/aapp-fix #<num>`.
- `templates/skills/aapp-done/SKILL.md`: rebase onto the development branch before `aapp done` when the plan lives in a worktree.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- `aapp.issueFixWait 0` keeps today's immediate refusal for anyone who relies on it.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/issue.sh`: `fix` on a dirty file waits (printed) and proceeds once the file is committed within the wait; times out with the plain message, or with the hotfix hint when the bound plan lists the file; `0` refuses at once; `next-blocker` waits when every blocker is dirty and claims the first to clear; `close` prints the notice for another active plan listing a fixed file, and none otherwise.
- [ ] Task 1.3: `tests/verbs/issue.sh`: `fix <num>` without `file` takes only path tokens from a hand-written Location (`` `a/b.sh` (`SOME_REGEX`) `` → `a/b.sh`; `:lines` stripped). `tests/install_test.sh`: `aapp-fix` is installed with the other skills and follows the CLI-first structure.
- [ ] Task 1.2: `tests/verbs/start.sh`: `start` refuses a plan whose target file is in a queued Plan Blocker's Location (nothing changed), and starts once the blocker is closed or promoted; shared docs never gate. `tests/verbs/freeze-start.sh`: the same through `freeze-start`.

### Phase 2: Implementation
- [ ] Task 2.1: Wait-on-dirty and the single-checkout hint in `lib/cmd_issue.sh` (2.1).
- [ ] Task 2.2: Plan Blocker files in `check_disjointness_activation_gate` (`lib/cmd_plan.sh`) (2.2).
- [ ] Task 2.3: Close-time notice in `lib/cmd_issue.sh` (2.3).
- [ ] Task 2.5: Path-only Location parsing in `lib/cmd_issue.sh` (2.5); `templates/skills/aapp-fix/SKILL.md` (2.4).
- [ ] Task 2.4: Contracts `lib/docs/verbs/issue.md`, `start.md`, `freeze-start.md`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: AGENTS.md (both), skills `aapp-start`, `aapp-done` (2.6).
- [ ] Task 3.2: `MANUAL.md` (Hotfixes and Issue Fixes: fixes in another plan's files; the start gate), `CHEATSHEET.md`, `.agents/CODEMAP.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_issue.sh` -> Wait on dirty files, single-checkout hint, close-time notice.
- [ ] `lib/cmd_plan.sh` -> Activation gate counts queued Plan Blocker files.
- [ ] `lib/docs/verbs/issue.md` -> Contract: wait, hint, notice.
- [ ] `lib/docs/verbs/start.md` -> Contract: pending-fix refusal.
- [ ] `lib/docs/verbs/freeze-start.md` -> Contract: pending-fix refusal.
- [ ] `tests/verbs/issue.sh` -> Wait, hint and notice tests.
- [ ] `tests/verbs/start.sh` -> Gate tests.
- [ ] `tests/verbs/freeze-start.sh` -> Gate test through `freeze-start`.
- [ ] `templates/AGENTS.md` -> Fixer and plan-side rules (2.4).
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Gate refusal; rebase at resume.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Rebase before `done` in a worktree.
- [ ] `NEW FILE` -> `templates/skills/aapp-fix/SKILL.md` -> The fixer's CLI-first skill, `/aapp-fix [#<num>]`.
- [ ] `tests/install_test.sh` -> `aapp-fix` installed with the other skills.
- [ ] `MANUAL.md` -> Fixes in another plan's files; the start gate.
- [ ] `CHEATSHEET.md` -> `fix` waits; start gate; `/aapp-fix`.
- [ ] `.agents/CODEMAP.md` -> Gate and notice.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Guard rules are P-52's; nothing changes there.
- [ ] `templates/aapp-pre-commit` -> Same.
- [ ] `lib/hook_dispatcher.sh` -> No new event (P-23 Q3).
- [ ] `lib/verbs.tsv` -> No new verbs.
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified.)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-07:** Added the fixer's skill `/aapp-fix [#<num>]` (developer: files come from the issue log, `file` only adds) and path-only Location parsing (from fixing #97).
* **2026-10-07:** Drafted from the developer's questions after P-52's first real use (#97): wait instead of refusing on uncommitted work, no start on a file a queued plan blocker will change, the agent text for fixes in another plan's files, and a close-time notice. Kept out of P-52 so P-52 can close as implemented and verified.
