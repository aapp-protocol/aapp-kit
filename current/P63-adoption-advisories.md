# 🗺️ Plan P-63: Adoption Advisories
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-10
* **Target Issue / Milestone:** Milestone: Monorepo & Two-Context Architecture
* **Plan ID:** P-63
* **Changelog:** Added: adoption checklist: `aapp init` records detected setup advice as checkbox tasks; tracked in `aapp status`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

`aapp init` sets up what the kit owns (worktrees, hooks, skills). Some of what a project needs for a clean adoption is the adopter's to do, because the kit never edits adopter build configuration:

1. **Build tool exclusions**: a monorepo tool that crawls the repository can pick up plan worktrees (`aapp.planWorktreePath`, default `.workspace/{id}`) as duplicate projects unless it is told to ignore that directory.
2. **Quality gates**: the P-60 `pre-done` test gate is opt-in and has to be registered by the adopter.
3. **Hook wiring**: where a hook manager or an existing hook owns the pre-commit hook, the adopter has to call `.githooks/aapp-pre-commit` from it.

Today such advice is printed once by `init` and scrolls away.

**Core Principle:** The kit never rewrites adopter build configuration files.

**Goal:** a durable adoption checklist at `.plans/adoption.md`.
- `aapp init` detects what applies and adds it as a checkbox task with a stable tag (`[MONO-NX]`, `[GATE-TEST]`) and a copy-paste instruction.
- Re-running `aapp init` ticks tasks it can verify (`- [ ]` → `- [x]`) and never unticks one.
- `aapp status` shows the count of open tasks until none is left.

**Local to each clone.** The kit writes this file by itself, so it is never committed: a file `init` changes on every developer's machine would diverge on the shared `plans` branch and block `pull`. Each clone keeps its own checklist. A task a teammate resolved in the code is ticked on the next `init`, or never appears; only a hand-ticked dismissal is not shared.

---

## 2. Technical Blueprint

### 2.1 The File (`.plans/adoption.md`)

- Seeded from `templates/adoption.md` by `sync_tier3_data`, as `ISSUES.md` is: once, never overwritten.
- **Untracked**: `init` writes the line `adoption.md` into `.plans/.gitignore` (the file it already maintains for the local `pickup/` store), on a new install and, when missing, on a re-run. The file is never staged, committed or pushed.
- Plan worktrees read it through their `.plans` link.
- The template is a title, a short note and an empty list. No date and no count line: nothing in the file changes unless a task is added or ticked.
- One flat list; a task is one line:
  ```markdown
  # 📋 Adoption Checklist

  > Setup the kit detected but leaves to you. `aapp init` adds tasks and ticks the ones it can verify; tick a task yourself to dismiss it.

  - [ ] `[MONO-NX]` Add `/.workspace` to `.nxignore`, so Nx does not discover plan worktrees as duplicate projects.
  - [x] `[GATE-TEST]` Register a `pre-done` test gate: …
  ```

### 2.2 Rules Catalogue (`lib/cmd_init.sh`)

`sync_adoption_checklist` holds the catalogue as one list; a rule is one entry: tag, trigger, check, text. `<dir>` is the first path segment of `aapp.planWorktreePath` (`.workspace` by default); when that path leaves the repository (absolute, or starting with `..`), the `MONO-*` rules do not apply.

| Tag | Trigger | Check (ticks the task) | Text |
| :--- | :--- | :--- | :--- |
| `[MONO-NX]` | `nx.json` at the root | `.nxignore` has a line `<dir>` or `/<dir>`, with or without a trailing `/` | Add `/<dir>` to `.nxignore`, so Nx does not discover plan worktrees as duplicate projects. |
| `[MONO-BAZEL]` | `WORKSPACE`, `WORKSPACE.bazel` or `MODULE.bazel` at the root | `.bazelignore` has a line `<dir>` | Add `<dir>` to `.bazelignore`, so Bazel does not load plan worktrees as packages. |
| `[GATE-TEST]` | always | `.agents/skills/aapp-hooks/registry.tsv` has a `pre-done` row | Register a `pre-done` test gate: copy `examples/hooks/test-gate.sh.sample` from the kit to `.agents/hooks/test-gate.sh`, set its test command, then `aapp hook-hash .agents/hooks/test-gate.sh pre-done 900 gate >> .agents/skills/aapp-hooks/registry.tsv`. |

| `[HOOK-WIRING]` | `HOOK_MANAGER_NOTICE=1`: `core.hooksPath` points elsewhere, `.git/hooks/pre-commit` is executable, or `.githooks/pre-commit` is not a shell script | `aapp-pre-commit` is named in the active pre-commit hook file or in a hook manager's file: `.husky/pre-commit`, `lefthook.yml`, `.lefthook.yml`, `.pre-commit-config.yaml` | Call `.githooks/aapp-pre-commit` from your pre-commit hook (the line `init` prints; recipes in `MANUAL.md` §7). |

The scan runs after `init` has detected the hook manager; the notice `init` prints today stays.

**Not in the catalogue** (listed in `MANUAL.md` §14 as unverified, with the reason):
- Turborepo: it follows the package manager's workspace list and has no ignore file of its own.
- pnpm: its `packages` globs are relative to the root, so only a glob such as `**` reaches the worktree directory.
- TypeScript: `include` wildcards never match a directory whose name starts with a dot.

### 2.3 Sync Protocol

For each rule, by its tag:
1. **A line with the tag exists and is `- [x]`**: left alone. A tick, the kit's or the human's, is never undone.
2. **A line exists and is `- [ ]`**: ticked when the check passes; otherwise left alone.
3. **No line**: appended as `- [ ]` when the trigger holds and the check fails. Nothing is added for a setup that is already right.
4. A line's text is never rewritten and no line is deleted: the human owns the file.

Nothing is committed: the file is ignored, so the plans worktree stays clean and `pull` / `sync` are never blocked by it. With open tasks, `init`'s report ends with one line: `📋 <N> adoption task(s) open: .plans/adoption.md`.

### 2.4 `aapp status` (`lib/cmd_status.sh`)

- Open tasks are the tagged unticked lines: `` ^- \[ \] `\[ `` in `.plans/adoption.md`; a missing file counts as 0. The count is read with `grep -c … || true` into a variable defaulted to 0, never `|| echo 0` (which prints a second `0` when the file has no match).
- With open tasks, the overview line gains ` | <N> adoption` after the pickup count (so `status short` stays one line), and the briefing prints, after the pickup pillar: `📋 Adoption: <N> open task(s) in .plans/adoption.md`.
- With none, nothing is printed: the output is as it is today.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A repository without `.plans/adoption.md` gets it on its next `aapp init`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/install_test.sh::test_adoption_seeded_and_untracked` -> asserts `init` creates `.plans/adoption.md`, lists it in `.plans/.gitignore`, commits no version of it and leaves the plans worktree clean
- [ ] `tests/install_test.sh::test_adoption_adds_detected_rules` -> asserts `nx.json` adds `[MONO-NX]`, a Bazel marker adds `[MONO-BAZEL]`, and `[GATE-TEST]` is added without a `pre-done` row
- [ ] `tests/install_test.sh::test_adoption_skips_satisfied_rules` -> asserts a rule whose check already passes adds no line
- [ ] `tests/install_test.sh::test_adoption_rerun_ticks_verified` -> asserts after `.nxignore` gains the directory, a re-run ticks `[MONO-NX]` and the plans branch gains no commit
- [ ] `tests/install_test.sh::test_adoption_rerun_is_quiet` -> asserts a re-run with nothing new changes no byte
- [ ] `tests/install_test.sh::test_adoption_keeps_human_edits` -> asserts a hand-ticked task and a hand-edited line survive a re-run
- [ ] `tests/install_test.sh::test_adoption_hook_wiring` -> asserts a foreign `core.hooksPath` adds `[HOOK-WIRING]`, and naming `aapp-pre-commit` in the hook ticks it on a re-run
- [ ] `tests/install_test.sh::test_adoption_gitignore_added_on_rerun` -> asserts an existing `.plans/.gitignore` without the line gains it
- [ ] `tests/install_test.sh::test_adoption_follows_worktree_path` -> asserts a custom `aapp.planWorktreePath` names its directory, and a path outside the repository adds no `MONO-*` task
- [ ] `tests/verbs/status.sh::test_overview_counts_open_adoption_tasks` -> asserts open tasks add `| <N> adoption` to the overview and the `📋 Adoption:` line to the briefing
- [ ] `tests/verbs/status.sh::test_no_adoption_output_when_none_open` -> asserts with no file or no open task the output has neither

### Phase 1: Tests First (red)
- [ ] Task 1.1: The Required Tests above; all fail.

### Phase 2: Implementation
- [ ] Task 2.1: `templates/adoption.md`.
- [ ] Task 2.2: `sync_adoption_checklist` in `lib/cmd_init.sh`: seeding, the `.plans/.gitignore` line, catalogue, sync protocol, report line.
- [ ] Task 2.3: `lib/cmd_status.sh`: the count, the overview segment, the briefing line.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run the kit suites; the Required Tests pass.
- [ ] Task 3.2: `lib/docs/verbs/status.md`: the overview segment and the briefing line.
- [ ] Task 3.3: `MANUAL.md` (the checklist, the catalogue, §14 for the tools left out) and `CHEATSHEET.md`.
- [ ] Task 3.4: `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/adoption.md` -> The checklist's starter: title, note, empty list.
- [ ] `lib/cmd_init.sh` -> `sync_adoption_checklist`: catalogue, sync protocol, report line; the `.plans/.gitignore` line.
- [ ] `lib/cmd_status.sh` -> Open-task count in the overview and the briefing.
- [ ] `lib/docs/verbs/status.md` -> Contract: the adoption segment and line.
- [ ] `tests/install_test.sh` -> Checklist seeding, detection, re-runs.
- [ ] `tests/verbs/status.sh` -> The count in the overview and the briefing.
- [ ] `MANUAL.md` -> The adoption checklist, its catalogue, the tools left out (§14).
- [ ] `CHEATSHEET.md` -> The checklist in the `init` and `status` rows.
- [ ] `ARCHITECTURE.md` -> The adoption checklist.
- [ ] `.agents/CODEMAP.md` -> `sync_adoption_checklist`.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/install_test.sh`
- [ ] `tests/verbs/status.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Plan lifecycle engine untouched.
- [ ] `lib/cmd_issue.sh` -> Issue management untouched.
- [ ] `.githooks/*` -> Core hook runners untouched.
- [ ] `templates/blast-radius-guard.sh` -> Guard logic untouched.
- [ ] `lib/cmd_upgrade.sh` -> `upgrade` does not run `init`; it keeps telling the user to.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Location. → RESOLVED (developer, 2026-10-12): `.plans/adoption.md`, untracked.** It stays out of the code tree and is reachable from plan worktrees through their `.plans` link, but it is local to each clone: a file the kit writes on every machine would diverge on the shared `plans` branch.
* [x] **Question 2 — Re-runs and auto-ticking. → RESOLVED (developer / RFC consensus, 2026-10-10): (a) Hybrid verification.** `aapp init` automatically marks verified tasks complete (`- [x]`) when the file system inspection confirms the condition is met (e.g. `.nxignore` contains `/.workspace`), but strictly preserves existing `- [x]` states and never unchecks a human's tick.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** The checklist is local to each clone: ignored in `.plans/.gitignore`, never committed. `[HOOK-WIRING]` is back in the catalogue.
* **2026-10-12:** Aligned with the code: repository facts only (clone-level advice stays out), catalogue cut to rules checked against the tools (Nx, Bazel, test gate), no date or count line, directory from `aapp.planWorktreePath`, the checklist's own commit, status wording, Required Tests.
* **2026-10-10:** Deep research completed: defined rules catalog (`[MONO-NX]`, `[MONO-PNPM]`, `[MONO-TURBO]`, `[MONO-BAZEL]`, `[MONO-TS]`, `[GATE-TEST]`, `[HOOK-WIRING]`), idempotency protocol, status overview metrics, resolved Q1/Q2, and locked blast radius.
* **2026-10-09:** Drafted from the developer's idea (RFC A3): a central adoption checklist instead of one-off init output.
