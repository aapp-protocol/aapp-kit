# 🗺️ Plan P-118: Perl Readonly Verbs
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-118
* **Changelog:** Changed: Port read-only verbs (`status`, `matrix`, `plan-status`, `help`) to `AAPP::Cmd::Status`, `AAPP::Cmd::Matrix`, `AAPP::Cmd::PlanStatus`, and `AAPP::Cmd::Help` over `AAPP::State` and `AAPP::Output`.
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
Plan `P-118` is the sixth member of group `P-111` (*Perl Port Of The Kit*). It ports the four read-only reporting and discovery verbs (`status`, `matrix`, `plan-status`, `help`) from `lib/cmd_status.sh` (922 lines) and `lib/help.sh` (373 lines) into `lib/AAPP/Cmd/Status.pm`, `lib/AAPP/Cmd/Matrix.pm`, `lib/AAPP/Cmd/PlanStatus.pm`, and `lib/AAPP/Cmd/Help.pm`.

In bash, `aapp status` re-parses `state_matrix.md`, `ISSUES.md`, `issues_road_map.md`, `pickup.md`, and every `.plans/current/P*.md` file through separate `awk` processes and spawns per-worktree `git` invocations. In Perl, all four verbs read from the in-memory `AAPP::State` object and batch worktree inspection via `AAPP::Repo`, rendering human tables and `--json` payloads (`AAPP::Output` + `AAPP::JSON` preserving table key order).

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Cmd/*.pm`, `lib/cmd_status.sh`, `lib/help.sh`, `aapp`). `lib/AAPP/Tests*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Cmd::Status` (`lib/AAPP/Cmd/Status.pm`) — `aapp status`
Ports `cmd_status` from `lib/cmd_status.sh`:
- Scans the four pillars via `AAPP::State` and `AAPP::Repo`:
  1. **Active Development & Worktree State**: current checkout, active plan pointer (`.git/aapp-active-plan`), pause state (`aapp.paused`), active worktrees (`.workspace/*`), uncommitted changes, and unintegrated commits.
  2. **Shipped / Recent History**: recent commits on `main` and recently archived plans in `.plans/done/000-done-archive.md`.
  3. **Issue Lane**: counts and summaries of `Plan Blockers` and `Queued` (`Urgent`, `Normal`, `Low`) from `issues_road_map.md`, plus total open issues in `ISSUES.md` and offline queue status.
  4. **Plan Lane & Pickup**: counts and ordered lists of `⚡ In Development`, `🟥 BLOCKED`, `🔷 Frozen` (Greenlight), and `📝 Refining` / `🟣 Under Review` (Incubator) plans from `state_matrix.md`, plus unchecked ideas in `.plans/pickup.md` and files in `.plans/pickup/`.
- Runs `AAPP::Health::check_all($state)` to surface any ledger/plan drift advisories.
- Supports `--json`, `--short` / `--brief`, and section filters, emitting ordered JSON objects via `AAPP::JSON::json_obj(...)`.

### 2.2 `AAPP::Cmd::Matrix` (`lib/AAPP/Cmd/Matrix.pm`) — `aapp matrix`
Ports `cmd_matrix` from `lib/cmd_status.sh`:
- Displays the Greenlight (`🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`) and Incubator (`🟣 Under Review`, `📝 Refining`) tables from `.plans/state_matrix.md` in human-determined order, enriched with live worktree binding, group membership (`Group: P-<num>`), blocked status, and open question counts.
- Supports zone filters (`greenlight`, `incubator`, `active`, `blocked`, `group <id>`) and `--json` output.

### 2.3 `AAPP::Cmd::PlanStatus` (`lib/AAPP/Cmd/PlanStatus.pm`) — `aapp plan-status`
Ports `cmd_plan_status` from `lib/cmd_status.sh`:
- Inspects a specific plan (`P-<num>`, `<num>`, slug, or active plan when omitted).
- Reports header metadata (`Plan ID`, `Status`, `Commit Mode`, `Changelog Mode`, `Base`, `Group`, `Commits`, `Blocked On`, `Emergency Hotfixes`, `Also Closes`), task checklist progress (`checked / total` per phase in `## 3.`), declared `### 📂 Target Files` (and whether each exists or is modified), TDD declaration status (`### 🧪 Tests`), open questions count (`## 5.`), and group member matrix when inspecting a group plan.
- Supports `--json` output with deterministic key order.

### 2.4 `AAPP::Cmd::Help` (`lib/AAPP/Cmd/Help.pm`) — `aapp help` (`-h`, `--help`, `version`)
Ports `lib/help.sh` into `lib/AAPP/Cmd/Help.pm`:
- Renders top-level command overview (`aapp`, `aapp help`, `aapp --help`) and per-verb detailed usage (`aapp help <verb>`, `aapp <verb> --help`, `aapp <verb> -h`).
- Provides `usage_error($verb, $msg)` helper used across all `AAPP::Cmd::*` modules so unknown flags or missing positional arguments print the exact verb synopsis and fail closed with exit code `1`.

### 2.5 CLI Dispatch & Transitional Shims (`aapp`, `lib/cmd_status.sh`, `lib/help.sh`)
- Route `status`, `matrix`, `plan-status`, `help`, `-h`, `--help`, `version`, `-v`, `--version` in `./aapp` to `AAPP::Cmd::Status`, `AAPP::Cmd::Matrix`, `AAPP::Cmd::PlanStatus`, and `AAPP::Cmd::Help`.
- Retain thin transitional wrappers in `lib/cmd_status.sh` and `lib/help.sh` for any bash verb not yet ported in `P-119`–`P-121`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Help & Usage Module (`AAPP::Cmd::Help`)
- [ ] Task 1.1: Implement `lib/AAPP/Cmd/Help.pm` covering top-level help, per-verb help topics, version display, and `usage_error`.

### Phase 2: Status, Matrix & PlanStatus (`AAPP::Cmd::Status`, `Matrix`, `PlanStatus`)
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Status.pm` over `AAPP::State`, `AAPP::Repo`, `AAPP::Health`, and `AAPP::Output`.
- [ ] Task 2.2: Implement `lib/AAPP/Cmd/Matrix.pm` and `lib/AAPP/Cmd/PlanStatus.pm` with human and `--json` output modes.
- [ ] Task 2.3: Wire `status`, `matrix`, `plan-status`, and `help` in `./aapp` and slim `lib/cmd_status.sh` and `lib/help.sh` to thin shims.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test status matrix plan-status help` and full `./aapp test` to verify 100% pass rate against the locked test suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Status.pm` -> `aapp status` implementation over `AAPP::State` and `AAPP::Output`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Matrix.pm` -> `aapp matrix` implementation over `AAPP::State` and `AAPP::Output`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/PlanStatus.pm` -> `aapp plan-status` implementation over `AAPP::State` and `AAPP::Output`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Help.pm` -> `aapp help` and per-verb synopsis/usage display.
- [ ] `aapp` -> Dispatch `status`, `matrix`, `plan-status`, and `help` directly to their `AAPP::Cmd::*` modules.
- [ ] `lib/cmd_status.sh` -> Transitional shim delegating to `AAPP::Cmd::Status`, `Matrix`, and `PlanStatus` until `P-122`.
- [ ] `lib/help.sh` -> Transitional shim delegating to `AAPP::Cmd::Help` until `P-122`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness and all `lib/AAPP/Tests/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Authored technical blueprint and locked blast radius for `P-118`.

