# 🗺️ Plan P-63: Adoption Advisories
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-10
* **Target Issue / Milestone:** Milestone: Monorepo & Two-Context Architecture
* **Plan ID:** P-63
* **Changelog:** Added: adoption checklist: `aapp init` writes a local setup guide of checkbox tasks to `.plans/adoption.md`; open tasks show in `aapp status`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `20e4182` (develop)
* **Worktree:** .workspace/P63 (plan/P63-adoption-advisories)
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

`aapp init` sets up what the kit owns (worktrees, hooks, skills). The rest of a clean adoption is the adopter's: naming the project's branches, pushing the kit's branches, filling the project rules, wiring a foreign hook manager, telling a build tool to ignore plan worktrees, reviewing the settings `init` seeded with defaults. Today some of this is printed once by `init` and scrolls away, and most is not mentioned at all.

**Core Principle:** The kit serves many projects and teams. It never assumes a project's branch names, tools or policies, and never rewrites adopter build configuration; it asks.

**Goal:** a welcome setup guide, the adoption checklist at `.plans/adoption.md`.
- `aapp init` adds everything a user may need to adjust as a checkbox task: a stable tag (`[DEV-BRANCH]`), a copy-paste instruction, and the manual section that explains it.
- Re-running `aapp init` ticks tasks it can verify (`- [ ]` → `- [x]`) and never unticks one. A task the kit cannot verify is ticked by the user.
- `aapp status` shows the count of open tasks until none is left.

**Local to each clone.** The kit writes this file by itself, so it is never committed: a file `init` changes on every developer's machine would diverge on the shared `plans` branch and block `pull`. Each clone keeps its own checklist, which also fits its content: `aapp.*` settings are per-clone git config (#126). A task a teammate resolved in the code is ticked on the next `init`, or never appears; a hand tick is not shared.

---

## 2. Technical Blueprint

### 2.1 The File (`.plans/adoption.md`)

- Seeded from `templates/adoption.md` by `sync_tier3_data`, as `ISSUES.md` is: once, never overwritten.
- **Untracked**: `init` writes the line `adoption.md` into `.plans/.gitignore` (the file it already maintains for the local `pickup/` store), on a new install and, when missing, on a re-run. The file is never staged, committed or pushed.
- Plan worktrees read it through their `.plans` link.
- No date and no count line: nothing in the file changes unless a task is added or ticked.
- The template is the title, a note and the section headings; tasks are appended under their section:
  ```markdown
  # 📋 Adoption Checklist

  > Your setup guide. `aapp init` adds tasks and ticks the ones it can verify; tick a task yourself when it is done or does not apply.

  ## 🌿 Branches & Remote
  - [ ] `[DEV-BRANCH]` Name your development branch: `git config aapp.devBranch <name>`. → MANUAL: Adaptive Branch Protection & Repository Topologies

  ## 👥 Team
  ## 📁 Project Files
  ## 🛡️ Hooks & Gates
  ## 🛠️ Build Tools
  ## ⚙️ Settings to Review
  ```
- **Manual link**: every task ends with `→ MANUAL: <section heading>`, the heading of the `MANUAL.md` section that explains it. It is a heading, not a path: an installed kit ships no manual yet (#127); when it does, the same catalogue field renders a path.

### 2.2 Rules Catalogue (`lib/adoption.sh`)

One list; a rule is one entry: tag, section, trigger, check, text, manual heading. `init` sources the file and calls `sync_adoption_checklist`. A rule without a check is a **review task**: only the user ticks it.

`<dir>` is the first path segment of `aapp.planWorktreePath` (`.workspace` by default); when that path leaves the repository, the `MONO-*` rules do not apply.

**🌿 Branches & Remote**

| Tag | Added when | Ticked when | Asks |
| :--- | :--- | :--- | :--- |
| `[DEV-BRANCH]` | `aapp.devBranch` is unset | the key is set | Name the development branch; tick it when the kit's defaults (`develop dev development`) are yours or you work on one branch. |
| `[STABLE-BRANCH]` | `aapp.protectedBranches` is unset and the default branch is not in `main master production` | the key is set | Name the protected branches. |
| `[REMOTE]` | `aapp.remote` names no existing remote | it names one | Add a remote or set `aapp.remote`. |
| `[FIRST-PUSH]` | the remote exists and a branch of `aapp.syncWorktrees` is not on it | all are | Run `aapp push`, so teammates can get the plans, rules and hooks. |

**👥 Team**

| Tag | Added when | Ticked when | Asks |
| :--- | :--- | :--- | :--- |
| `[PLAN-ID-PROVIDER]` | always | `.agents/skills/aapp-planid/` exists | More than one contributor needs an `aapp-planid` provider, or two people allocate the same Plan ID; tick it when you work alone. |
| `[TEAM-SETTINGS]` | always | review task | Settings are local to this clone: agree the project's values and set them on every clone (#126). |

**📁 Project Files**

| Tag | Added when | Ticked when | Asks |
| :--- | :--- | :--- | :--- |
| `[INIT-FILES]` | `.gitignore`, `.gitattributes`, `CHANGELOG.md` or `ARCHITECTURE.md` is untracked or modified | all are tracked and clean | Commit the files `init` wrote on the code branch; plan worktrees are cut from it. |
| `[PROJECT-RULES]` | `.agents/PROJECT.MD` still has template placeholders | none remains | Fill the project rules, or run `/aapp-digest Onboarding`. |
| `[PROJECT-MAP]` | `.agents/CODEMAP.md` or `ARCHITECTURE.md` is identical to its template | both differ | Map the codebase, or run `/aapp-digest Onboarding`. |
| `[TEMPLATE-DRIFT]` | a `*.new` file from a template sync exists | none exists | Merge each `*.new` file into its original and delete it. |
| `[ISSUES-SCHEMA]` | `.plans/ISSUES.md` lacks the ledger header (the test `init` already makes) | the header is there | Adapt the file to the flat issue ledger. |
| `[PROTOCOL-BLOCK]` | a synced file has an unclosed `AAPP-PROTOCOL:START` marker | none has | Close the marker so the block syncs again. |

**🛡️ Hooks & Gates**

| Tag | Added when | Ticked when | Asks |
| :--- | :--- | :--- | :--- |
| `[WRITE-GUARD]` | the Claude settings do not name `blast-radius-guard` (e.g. `python3` was missing at `init`) | they do | Install `python3` and re-run `aapp init`, or add the guard hook by hand. |
| `[HOOK-WIRING]` | `HOOK_MANAGER_NOTICE=1`: `core.hooksPath` points elsewhere, `.git/hooks/pre-commit` is executable, or `.githooks/pre-commit` is not a shell script | `aapp-pre-commit` is named in the active pre-commit hook file, `.husky/pre-commit`, `lefthook.yml`, `.lefthook.yml` or `.pre-commit-config.yaml` | Call `.githooks/aapp-pre-commit` from your pre-commit hook. |
| `[GATE-TEST]` | always | the hooks registry has a `pre-done` row | Register a `pre-done` test gate from `examples/hooks/test-gate.sh.sample` with `aapp hook-hash`; tick it when you do not want one. |

**🛠️ Build Tools**

| Tag | Added when | Ticked when | Asks |
| :--- | :--- | :--- | :--- |
| `[MONO-NX]` | `nx.json` at the root | `.nxignore` has a line `<dir>` or `/<dir>` | Add `/<dir>` to `.nxignore`. |
| `[MONO-BAZEL]` | `WORKSPACE`, `WORKSPACE.bazel` or `MODULE.bazel` at the root | `.bazelignore` has a line `<dir>` | Add `<dir>` to `.bazelignore`. |

Not in the catalogue, listed in `MANUAL.md` §14 as unverified with the reason: Turborepo (follows the package manager's workspace list), pnpm (root-relative globs), TypeScript (`include` wildcards skip dot-directories).

**⚙️ Settings to Review** (review tasks, added always; `init` seeded the default shown)

| Tag | Setting and default | Asks |
| :--- | :--- | :--- |
| `[SET-WORKTREES]` | `aapp.planWorktrees` = `off` | One worktree and branch per plan? Group plans need `on`. |
| `[SET-INTEGRATE]` | `aapp.integrate` = `manual` | How `done` integrates a plan branch: `manual`, `squash`, `ff`, `hook`. |
| `[SET-COMMIT-MODE]` | `aapp.commitMode` = `atomic`, `aapp.changelogMode` = `plan` | One commit per plan or many; one changelog entry per plan or per commit. |
| `[SET-ATTRIBUTION]` | `aapp.aiAttribution` = `none` | Record which agent wrote a commit: `lax`, `strict`, `notes`. |

The scan runs after `init` has detected the hook manager and seeded its settings; the notices `init` prints today stay.

### 2.3 Sync Protocol

For each rule, by its tag:
1. **A line with the tag exists and is `- [x]`**: left alone. A tick, the kit's or the user's, is never undone.
2. **A line exists and is `- [ ]`**: ticked when the rule has a check and it passes; otherwise left alone.
3. **No line**: appended under the rule's section as `- [ ]` when the trigger holds and the check does not pass. Nothing is added for a setup that is already right.
4. A line's text is never rewritten and no line is deleted: the user owns the file. A missing section heading is appended at the end.

Nothing is committed: the file is ignored, so the plans worktree stays clean and `pull` / `sync` are never blocked by it. With open tasks, `init`'s report ends with one line: `📋 <N> setup task(s) open: .plans/adoption.md`.

### 2.4 `aapp status` (`lib/cmd_status.sh`)

- `adoption_open_count` in `lib/adoption.sh` is the one reader of open tasks (tagged unticked lines, `` ^- \[ \] `\[ ``; a missing file is 0); `init`'s report line and `status` both call it.
- With open tasks, the overview line gains ` | <N> adoption` after the pickup count (so `status short` stays one line), and the briefing prints, after the pickup pillar: `📋 Adoption: <N> open task(s) in .plans/adoption.md`.
- With none, nothing is printed: the output is as it is today.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A repository without `.plans/adoption.md` gets it on its next `aapp init`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/adoption_test.sh::test_seeded_and_untracked` -> asserts `init` creates `.plans/adoption.md` with its sections, lists it in `.plans/.gitignore`, commits no version of it and leaves the plans worktree clean
- [x] `tests/adoption_test.sh::test_gitignore_line_added_on_rerun` -> asserts an existing `.plans/.gitignore` without the line gains it
- [x] `tests/adoption_test.sh::test_fresh_install_tasks` -> asserts a fresh project gets `[DEV-BRANCH]`, `[PLAN-ID-PROVIDER]`, `[TEAM-SETTINGS]`, `[INIT-FILES]`, `[PROJECT-RULES]`, `[PROJECT-MAP]`, `[GATE-TEST]` and the four `SET-*` tasks, each under its section
- [x] `tests/adoption_test.sh::test_satisfied_rules_add_nothing` -> asserts a rule whose check already passes adds no line
- [x] `tests/adoption_test.sh::test_branch_and_remote_rules` -> asserts `[DEV-BRANCH]` ticks once `aapp.devBranch` is set, `[STABLE-BRANCH]` appears for a default branch outside the list, `[REMOTE]` for a missing remote and `[FIRST-PUSH]` until the kit's branches are on it
- [x] `tests/adoption_test.sh::test_project_file_rules` -> asserts `[INIT-FILES]`, `[PROJECT-RULES]`, `[PROJECT-MAP]`, `[TEMPLATE-DRIFT]`, `[ISSUES-SCHEMA]` and `[PROTOCOL-BLOCK]` appear on their trigger and tick once resolved
- [x] `tests/adoption_test.sh::test_hook_rules` -> asserts a foreign `core.hooksPath` adds `[HOOK-WIRING]` and naming `aapp-pre-commit` ticks it; a `pre-done` registry row ticks `[GATE-TEST]`; settings without the guard add `[WRITE-GUARD]`
- [x] `tests/adoption_test.sh::test_build_tool_rules_follow_worktree_path` -> asserts `nx.json` and a Bazel marker add their tasks naming the configured directory, the ignore line ticks them, and a worktree path outside the repository adds none
- [x] `tests/adoption_test.sh::test_review_tasks_only_user_ticks` -> asserts a review task stays open over re-runs and a hand tick survives
- [x] `tests/adoption_test.sh::test_rerun_is_quiet` -> asserts a re-run with nothing new changes no byte, and the plans branch gains no commit
- [x] `tests/adoption_test.sh::test_user_edits_survive` -> asserts a hand-ticked task, a reworded line and a deleted line's absence are kept as the user left them, except that a still-triggered deleted task returns
- [x] `tests/adoption_test.sh::test_manual_headings_exist` -> asserts every catalogue entry's manual heading is a heading in `MANUAL.md`
- [x] `tests/verbs/status.sh::test_overview_counts_open_adoption_tasks` -> asserts open tasks add `| <N> adoption` to the overview and the `📋 Adoption:` line to the briefing
- [x] `tests/verbs/status.sh::test_no_adoption_output_when_none_open` -> asserts with no file or no open task the output has neither

### Phase 1: Tests First (red)
- [x] Task 1.1: The Required Tests above; all fail.

### Phase 2: Implementation
- [x] Task 2.1: `templates/adoption.md`.
- [x] Task 2.2: `lib/adoption.sh`: the catalogue, `sync_adoption_checklist`, `adoption_open_count`.
- [x] Task 2.3: `lib/cmd_init.sh`: seeding, the `.plans/.gitignore` line, the call after settings and hook detection, the report line.
- [x] Task 2.4: `lib/cmd_status.sh`: the overview segment and the briefing line.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run the kit suites; the Required Tests pass.
- [x] Task 3.2: `lib/docs/verbs/status.md`: the overview segment and the briefing line.
- [x] Task 3.3: `MANUAL.md`: an "Adoption Checklist" section explaining every task (the link target of tasks with no section of their own), §14 for the tools left out; `CHEATSHEET.md`.
- [x] Task 3.4: `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [x] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/adoption.md` -> The checklist's starter: title, note, section headings.
- [ ] `NEW FILE` -> `lib/adoption.sh` -> The rules catalogue, `sync_adoption_checklist`, `adoption_open_count`.
- [ ] `lib/cmd_init.sh` -> Seeding, the `.plans/.gitignore` line, the sync call, the report line.
- [ ] `lib/cmd_status.sh` -> Open-task count in the overview and the briefing.
- [ ] `lib/docs/verbs/status.md` -> Contract: the adoption segment and line.
- [ ] `NEW FILE` -> `tests/adoption_test.sh` -> The checklist suite.
- [ ] `tests/verbs/status.sh` -> The count in the overview and the briefing.
- [ ] `MANUAL.md` -> The "Adoption Checklist" section, the catalogue, the tools left out (§14).
- [ ] `CHEATSHEET.md` -> The checklist in the `init` and `status` rows.
- [ ] `ARCHITECTURE.md` -> The adoption checklist.
- [ ] `.agents/CODEMAP.md` -> `lib/adoption.sh`.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/adoption_test.sh`
- [ ] `tests/verbs/status.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Plan lifecycle engine untouched.
- [ ] `lib/cmd_issue.sh` -> Issue management untouched.
- [ ] `.githooks/*` -> Core hook runners untouched.
- [ ] `templates/blast-radius-guard.sh` -> Guard logic untouched.
- [ ] `lib/cmd_upgrade.sh` -> `upgrade` does not run `init`; it keeps telling the user to.
- [ ] `lib/cmd_install.sh` -> Installing the manual is #127.
- [ ] `tests/install_test.sh` -> The checklist has its own suite.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Location. → RESOLVED (developer, 2026-10-12): `.plans/adoption.md`, untracked.** It stays out of the code tree and is reachable from plan worktrees through their `.plans` link, but it is local to each clone: a file the kit writes on every machine would diverge on the shared `plans` branch.
* [x] **Question 2 — Re-runs and auto-ticking. → RESOLVED (developer / RFC consensus, 2026-10-10): (a) Hybrid verification.** `aapp init` automatically marks verified tasks complete (`- [x]`) when the file system inspection confirms the condition is met (e.g. `.nxignore` contains `/.workspace`), but strictly preserves existing `- [x]` states and never unchecks a human's tick.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan activated into ⚡ In Development via start.
* **2026-10-12:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-12:** A welcome setup guide: the catalogue covers everything a user may need to adjust (branches, remote, team, project files, hooks, build tools, settings to review), each task with its manual section; catalogue in `lib/adoption.sh`, its own test suite.
* **2026-10-12:** The checklist is local to each clone: ignored in `.plans/.gitignore`, never committed. `[HOOK-WIRING]` is back in the catalogue.
* **2026-10-12:** Aligned with the code: repository facts only (clone-level advice stays out), catalogue cut to rules checked against the tools (Nx, Bazel, test gate), no date or count line, directory from `aapp.planWorktreePath`, the checklist's own commit, status wording, Required Tests.
* **2026-10-10:** Deep research completed: defined rules catalog (`[MONO-NX]`, `[MONO-PNPM]`, `[MONO-TURBO]`, `[MONO-BAZEL]`, `[MONO-TS]`, `[GATE-TEST]`, `[HOOK-WIRING]`), idempotency protocol, status overview metrics, resolved Q1/Q2, and locked blast radius.
* **2026-10-09:** Drafted from the developer's idea (RFC A3): a central adoption checklist instead of one-off init output.
