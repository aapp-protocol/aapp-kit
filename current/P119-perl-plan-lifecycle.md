# 🗺️ Plan P-119: Perl Plan Lifecycle
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-119
* **Changelog:** Changed: Port plan lifecycle verbs (`draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` subverbs) to `AAPP::Plan` and `AAPP::Cmd::*` modules.
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
Plan `P-119` is the seventh member of group `P-111` (*Perl Port Of The Kit*). It ports the entire plan lifecycle — `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` (including `conflict-check`, `conflict-free`, and `abort`) — from `lib/cmd_draft.sh` (405 lines), `lib/cmd_refine.sh` (922 lines), `lib/cmd_tdd.sh` (507 lines), `lib/cmd_freeze.sh` (1,073 lines), `lib/cmd_start.sh` (660 lines), and `lib/cmd_done.sh` (1,137 lines) into `lib/AAPP/Plan.pm` and dedicated `lib/AAPP/Cmd/*.pm` modules.

In bash, every lifecycle transition (`draft -> refine -> tdd -> freeze -> start -> done`) re-runs multi-pass `awk` over `state_matrix.md`, `ISSUES.md`, and every `.plans/current/P*.md` file. In Perl, `AAPP::Plan` mutates the parsed plan AST and `state_matrix.md` rows in memory via `AAPP::State`, runs `AAPP::Health` and `AAPP::Rules` in-process, and commits `.plans` atomically via `AAPP::Repo`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Plan.pm`, `lib/AAPP/Cmd/*.pm`, `lib/cmd_*.sh`, `aapp`). `lib/AAPP/Tests*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Plan` (`lib/AAPP/Plan.pm`) — Shared Plan Lifecycle & AST Mutation
Provides shared operations across plan lifecycle verbs:
- **Plan ID allocation & scaffolding**: reads/increments `.plans/.plan-counter`, renders `templates/plan-template.md` or `templates/group-plan-template.md`, populates `* **Plan ID:** P-<num>`, `* **Commit Mode:**`, `* **Changelog Mode:**`, `* **Group:**`, and registers the Incubator row in `.plans/state_matrix.md`.
- **Group plan mechanics**: manages `## Members` table in group plans, auto-scaffolds the `<slug>-amendments` member (`P-<num+1>`) on `aapp draft <slug> group`, validates member order and dependency graph, and enforces group-level freeze/start/done rules (`ARCHITECTURE.md` and `.agents/CODEMAP.md` section handling on group `done`).
- **Header & section surgical rewrite**: updates `* **Last Refined:**`, `* **Status:**`, `* **Base:**`, `* **Commits:**`, `* **Blocked On:**`, `* **Also Closes:**`, and `state_matrix.md` zone placement (Incubator <-> Greenlight) while preserving surrounding markdown byte-for-byte.
- **Blast Radius & Conflict Analysis**: implements `conflict_check($state, $plan_id)` comparing `### 📂 Target Files` of a candidate plan against all `🔷 Frozen`, `⚡ In Development`, and `🟥 BLOCKED` plans, factoring in `conflict-free` declarations and group siblings.

### 2.2 `AAPP::Cmd::Draft` (`lib/AAPP/Cmd/Draft.pm`) — `aapp draft`
Ports `lib/cmd_draft.sh`:
- Supports `aapp draft <slug> [title "<title>"] [issue <num>] [group [<group-id>]] [commit-mode <atomic|microcommits>] [changelog-mode <plan|commit>]`.
- When `issue <num>` is given, links the new plan in the issue's `Target Plan / Fix` cell in `ISSUES.md` and sets the issue status to `🔵 Planned` in the same `.plans` commit (`plan(draft): scaffold P-<num> (<slug>)`).
- When `group` is given without an ID, scaffolds a group plan (`P-<n>`) and its companion `<slug>-amendments` member plan (`P-<n+1>`). When `group <group-id>` is given, scaffolds a member plan under `P-<group-id>` and appends it to the group's `## Members` table.

### 2.3 `AAPP::Cmd::Refine` (`lib/AAPP/Cmd/Refine.pm`) — `aapp refine`
Ports `lib/cmd_refine.sh`:
- Plan refinement: `aapp refine <id> ["<msg>"] [slug <new-slug>] [closes <num> [remove]] [blocked <num> [remove]] [commit-mode <mode>] [changelog-mode <mode>] [unfreeze]`.
- Enforces the session/worktree ownership rule (refuses amending a plan or group in development from another checkout), updates `* **Last Refined:**`, renames `P<num>-<old>.md` and repairs `state_matrix.md` and `ISSUES.md` links when `slug <new-slug>` is passed, runs `AAPP::Health` validation, and commits `plan(refine): P-<num> <msg>` in `.plans`.
- Ledger refinement: `aapp refine issues "<msg>" [note <num> "<text>"]` (validates no hand-added rows in `ISSUES.md`, attaches optional issue note in `refs/notes/issues`) and `aapp refine pickup "<msg>"` (validates `pickup.md` title length `<= aapp.pickupTitleMax` and referenced `.plans/pickup/` files).

### 2.4 `AAPP::Cmd::Tdd` (`lib/AAPP/Cmd/Tdd.pm`) — `aapp tdd`
Ports `lib/cmd_tdd.sh`:
- Supports `aapp tdd <id> [add <test-id> file <test-file> ["<desc>"]] [remove <test-id>] [exempt "<reason>"] [status] [verify]`.
- Manages `### 🧪 Tests` in `## 3.` and test file entries in `### 📂 Target Files` (`## 4.`), and verifies that declared tests fail before implementation and pass after implementation according to `aapp.tdd`.

### 2.5 `AAPP::Cmd::Freeze` (`lib/AAPP/Cmd/Freeze.pm`) — `aapp freeze`
Ports `lib/cmd_freeze.sh`:
- Validates all freeze gates for `<id>` (or a group and its members): non-empty `## 1.` / `## 2.` / `## 3.`, valid `* **Changelog:** <Added|Changed|Fixed>: <one line>`, non-empty `### 📂 Target Files` with zero Pair 5 self-protected paths, zero unresolved checkboxes in `## 5. Open Questions`, TDD gate satisfaction when `aapp.tdd` requires it, and target-file conflict check against Greenlight plans.
- Moves the plan from Incubator to Greenlight (`🔷 Frozen`) in `.plans/state_matrix.md`, sets `* **Status:** 🔷 Frozen`, and commits `plan(freeze): lock blast radius and greenlight P-<num> (<slug>)`.

### 2.6 `AAPP::Cmd::Start` (`lib/AAPP/Cmd/Start.pm`) — `aapp start`, `aapp freeze-start`, `aapp active`
Ports `lib/cmd_start.sh`:
- `start [<id>] [worktree | branch | here]`: verifies `aapp.paused` is false and the plan is `🔷 Frozen` (or resumes an already-started plan in its bound worktree), records `* **Base:** <sha> (<branch>)`, transitions `* **Status:** ⚡ In Development` in both the plan and `state_matrix.md`, creates `.workspace/P<num>-<slug>` on branch `plan/P<num>-<slug>` when running in worktree mode, and writes `.git/aapp-active-plan`.
- `freeze-start <id> ...`: runs `AAPP::Cmd::Freeze` followed immediately by `AAPP::Cmd::Start`.
- `active [clear | <id>]`: prints or rebinds the local checkout's active plan pointer.

### 2.7 `AAPP::Cmd::Done` (`lib/AAPP/Cmd/Done.pm`) & `AAPP::Cmd::Plan` (`lib/AAPP/Cmd/Plan.pm`) — `aapp done`, `aapp plan`
Ports `lib/cmd_done.sh` and `cmd_plan` subverbs:
- `done [<id>]`: verifies all `## 3.` task checkboxes are `[x]`, verifies recorded `* **Commits:**` exist on the branch and pass `CHANGELOG.md` and TDD checks, integrates the worktree branch onto the base branch (via `AAPP::Integrate` / `AAPP::Repo` when run from a worktree), moves `.plans/current/P<num>-<slug>.md` to `.plans/done/`, appends the completion row to `.plans/done/000-done-archive.md`, removes the row from `state_matrix.md`, relocates any `* **Target Issue / Milestone:** #<num>` and `* **Also Closes:**` issues to `.plans/done/000-issues-archive.md` (and prunes `issues_road_map.md`), and clears `.git/aapp-active-plan`.
- `plan` subverbs (`AAPP::Cmd::Plan`): `conflict-check [<id>]`, `conflict-free <id1> <id2> [reason "<text>"] [remove]`, `abort <id>`, and `list` / `show`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Shared Plan Engine (`AAPP::Plan`)
- [ ] Task 1.1: Implement `lib/AAPP/Plan.pm` with counter allocation, template rendering, header/section AST rewrites, `state_matrix.md` zone transitions, group plan member table management, and target-file conflict analysis.

### Phase 2: Lifecycle Command Modules (`Draft`, `Refine`, `Tdd`, `Freeze`, `Start`, `Done`, `Plan`)
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Draft.pm`, `lib/AAPP/Cmd/Refine.pm`, and `lib/AAPP/Cmd/Tdd.pm`.
- [ ] Task 2.2: Implement `lib/AAPP/Cmd/Freeze.pm`, `lib/AAPP/Cmd/Start.pm`, `lib/AAPP/Cmd/Done.pm`, and `lib/AAPP/Cmd/Plan.pm`.
- [ ] Task 2.3: Wire `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` in `./aapp` to their `AAPP::Cmd::*` modules and convert `lib/cmd_draft.sh`, `lib/cmd_refine.sh`, `lib/cmd_tdd.sh`, `lib/cmd_freeze.sh`, `lib/cmd_start.sh`, and `lib/cmd_done.sh` into thin transitional shims.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test draft refine tdd freeze start freeze-start done active plan` and full `./aapp test` to verify 100% pass rate against the locked test suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Plan.pm` -> Shared plan AST mutation, scaffolding, `state_matrix.md` transitions, group member management, and conflict analysis.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Draft.pm` -> `aapp draft` implementation (standalone, issue promotion, group and member plans).
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Refine.pm` -> `aapp refine` implementation for plans, `issues`, and `pickup`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Tdd.pm` -> `aapp tdd` implementation for failure-first test declarations and verification.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Freeze.pm` -> `aapp freeze` implementation and freeze-gate verification.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Start.pm` -> `aapp start`, `aapp freeze-start`, and `aapp active` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Done.pm` -> `aapp done` archival, issue relocation, and group completion implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Plan.pm` -> `aapp plan` subverbs (`conflict-check`, `conflict-free`, `abort`).
- [ ] `aapp` -> Dispatch `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` to `AAPP::Cmd::*`.
- [ ] `lib/cmd_draft.sh` -> Transitional shim delegating to `AAPP::Cmd::Draft` until `P-122`.
- [ ] `lib/cmd_refine.sh` -> Transitional shim delegating to `AAPP::Cmd::Refine` until `P-122`.
- [ ] `lib/cmd_tdd.sh` -> Transitional shim delegating to `AAPP::Cmd::Tdd` until `P-122`.
- [ ] `lib/cmd_freeze.sh` -> Transitional shim delegating to `AAPP::Cmd::Freeze` until `P-122`.
- [ ] `lib/cmd_start.sh` -> Transitional shim delegating to `AAPP::Cmd::Start` until `P-122`.
- [ ] `lib/cmd_done.sh` -> Transitional shim delegating to `AAPP::Cmd::Done` until `P-122`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness and all `lib/AAPP/Tests/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Authored technical blueprint and locked blast radius for `P-119`.

