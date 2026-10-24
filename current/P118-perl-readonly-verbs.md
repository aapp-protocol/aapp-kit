# 🗺️ Plan P-118: Perl Readonly Verbs
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-118
* **Changelog:** Changed: Port read-only verbs (`status`, `matrix`, `plan-status`, `help`) to `AAPP::Cmd::Status`, `AAPP::Cmd::Matrix`, `AAPP::Cmd::PlanStatus`, and `AAPP::Cmd::Help` over `AAPP::State` with structured log event telemetry
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
Plan `P-118` is the sixth member of group `P-111` (*Perl Port Of The Kit*). It ports the project adoption scanner (`lib/adoption.sh`, 503 lines) and the four read-only reporting and discovery verbs — `status` (`lib/cmd_status.sh`, 937 lines), `matrix` (`lib/cmd_matrix.sh`, 332 lines), `plan-status` (`cmd_plan_status` in `lib/cmd_plan.sh`), and `help` (`lib/cmd_help.sh`, 176 lines) — into `lib/AAPP/Adoption.pm`, `lib/AAPP/Cmd/Status.pm`, `lib/AAPP/Cmd/Matrix.pm`, `lib/AAPP/Cmd/PlanStatus.pm`, and `lib/AAPP/Cmd/Help.pm`.

In bash, `aapp status` re-parses `state_matrix.md`, `ISSUES.md`, `issues_road_map.md`, `pickup.md`, and every `.plans/current/P*.md` file through separate `awk` processes and spawns per-worktree `git` invocations. In Perl, all four verbs read from the in-memory `AAPP::State` object in a single process, rendering human output, `short` output, and `json` payloads (`AAPP::Output` + `AAPP::JSON`).

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Adoption.pm`, `lib/AAPP/Cmd/*.pm`, `lib/adoption.sh`, `lib/cmd_status.sh`, `lib/cmd_matrix.sh`, `lib/cmd_help.sh`, `lib/cmd_plan.sh`, `aapp`) plus switching `t/core/adoption.t` and `t/core/matrix.t` from bash `source` wrappers to direct `AAPP::Adoption` and `AAPP::Cmd::Matrix` calls per `P-111`'s core-wrapper rule.

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§4.4 `status`, `matrix`, `help`):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (§3.4 `status`, `matrix`, `help`, `plan-status`):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epoch E4, Actions A042–A050):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 `AAPP::Adoption` (`lib/AAPP/Adoption.pm`) — `lib/adoption.sh` (503 lines)
Ports `lib/adoption.sh` into `lib/AAPP/Adoption.pm`:
- Implements adoption detection and drift warnings (`detect_existing_project`, `detect_legacy_artifacts`, `adoption_status_summary`, `adoption_drift_warnings`) called by `aapp status`, plus the seed/sync helpers (`adoption_seed_changelog`, `adoption_seed_codemap`, `adoption_sync_version`) called by `aapp init` (`P-121`).

### 2.2 `AAPP::Cmd::Status` (`lib/AAPP/Cmd/Status.pm`) — `aapp status` (`lib/cmd_status.sh`, 937 lines)
Ports `cmd_status` from `lib/cmd_status.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help status full` and `lib/docs/verbs/status.md`, verified under the unchanged bash suite `tests/verbs/status.sh` (its Perl file comes after the ports, P-134).
- Scans the 4 workspace pillars (Shipped, Issues, Plans, Pickup) from `AAPP::State`, `AAPP::Health`, `AAPP::Adoption`, `AAPP::Issue`, and `AAPP::Cmd::Offline`, and renders terminal (`AAPP::Output`) and `json` (`AAPP::JSON`) output.

### 2.3 `AAPP::Cmd::Matrix` (`lib/AAPP/Cmd/Matrix.pm`) — `aapp matrix` (`lib/cmd_matrix.sh`, 332 lines)
Ports `cmd_matrix` from `lib/cmd_matrix.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help matrix full` and `lib/docs/verbs/matrix.md`, verified under `t/core/matrix.t`.
- Rebuilds `.plans/state_matrix.md` from `.plans/current/P*.md` headers via `AAPP::State` while preserving human row ordering, and verifies matrix sync on `check`.
- Rows within a section sort by plan number as a number: P-15 before P-128, through `AAPP::Util::plan_sort` (the one plan sort; `AAPP::State::current_plans` already returns plans in that order). The bash verb sorts the IDs as text, which puts P-128 before P-15; the port does not carry that over.

### 2.4 `AAPP::Cmd::PlanStatus` (`lib/AAPP/Cmd/PlanStatus.pm`) — `aapp plan-status` (`cmd_plan_status` in `lib/cmd_plan.sh`)
Ports `cmd_plan_status` from `lib/cmd_plan.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help plan-status full` and `lib/docs/verbs/plan-status.md`.
- Inspects the specified plan or active plan (`$(git rev-parse --git-path aapp_active_plan)`) over `AAPP::State`.

### 2.5 `AAPP::Cmd::Help` (`lib/AAPP/Cmd/Help.pm`) — `aapp help` (`lib/cmd_help.sh`, 176 lines)
Ports `cmd_help` from `lib/cmd_help.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help help full` and `lib/docs/verbs/help.md`.
- Renders top-level and per-verb help from `lib/verbs.tsv` and `lib/docs/verbs/<verb>.md` (`<!-- FULL -->` split), plus version output.

### 2.6 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §4.4, each reporting subverb emits structured telemetry to `.git/aapp.log`:
- `AAPP::Cmd::Status`: emits `post-status` (`open_adoption_tasks => $n`, `issues => { ... }`, `plans => { ... }`).
- `AAPP::Cmd::Matrix`: emits `post-matrix` (`plans_count => $n`, `in_sync => 0|1`).
- `AAPP::Cmd::Help`: emits `post-help` (`verb => $verb`, `full => 0|1`).
- `AAPP::Cmd::PlanStatus`: emits `post-plan-status` (`plan_id => $id`, `status => $status`).

### 🔄 Migration & Compatibility Strategy
- **Transitional Coexistence (`P-118` → `P-122`):** While `status`, `matrix`, `plan-status`, and `help` dispatch directly to Perl from `aapp`, `lib/cmd_plan.sh` (ported in `P-119`) and `lib/cmd_init.sh` (ported in `P-121`) still call `cmd_matrix` (`lib/cmd_matrix.sh`) and `adoption_*` (`lib/adoption.sh`) from bash. During `P-118`–`P-121`, `lib/cmd_matrix.sh` and `lib/adoption.sh` delegate to `AAPP::Cmd::Matrix` and `AAPP::Adoption` (or remain intact alongside them) until `P-122` deletes all `lib/*.sh` files.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Adoption & Matrix (`AAPP::Adoption`, `AAPP::Cmd::Matrix`)
- [ ] Task 1.1: Implement `lib/AAPP/Adoption.pm` (`lib/adoption.sh`) and switch `t/core/adoption.t` to call `AAPP::Adoption` directly without bash `source` wrappers.
- [ ] Task 1.2: Implement `lib/AAPP/Cmd/Matrix.pm` (`aapp matrix [check]`) with `post-matrix` telemetry, and switch `t/core/matrix.t` to call `AAPP::Cmd::Matrix` directly without bash `source` wrappers.

### Phase 2: Status, PlanStatus & Help (`AAPP::Cmd::Status`, `PlanStatus`, `Help`)
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Status.pm` (`aapp status [short | json]` with `post-status`), `lib/AAPP/Cmd/PlanStatus.pm` (`aapp plan-status [id]` with `post-plan-status`), and `lib/AAPP/Cmd/Help.pm` (`aapp help [<verb> [full]]` with `post-help`).
- [ ] Task 2.2: Wire `status`, `matrix`, `plan-status`, `help`, `--help`, `-h`, `--version`, and `-v` in `./aapp` to their `AAPP::Cmd::*` modules, and keep transitional bash shims in `lib/adoption.sh`, `lib/cmd_matrix.sh`, `lib/cmd_status.sh`, `lib/cmd_help.sh`, and `lib/cmd_plan.sh` (`cmd_plan_status`).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `./aapp test strict quiet` (the bash suites, `tests/verbs/status.sh`, `matrix.sh`, `plan-status.sh`, `help.sh` among them) and `t/test-run strict quiet` (`t/core`, with `adoption.t` and `matrix.t`) green.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Adoption.pm` -> Project adoption detection, drift warnings, and seed/sync helpers.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Status.pm` -> `aapp status [short | json]` implementation with `post-status` telemetry over `AAPP::State` and `AAPP::Output`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Matrix.pm` -> `aapp matrix [check]` implementation with `post-matrix` telemetry over `AAPP::State`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/PlanStatus.pm` -> `aapp plan-status [id]` implementation with `post-plan-status` telemetry over `AAPP::State`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Help.pm` -> `aapp help [<verb> [full]]` and version display with `post-help` telemetry over `lib/verbs.tsv` and `lib/docs/verbs/*.md`.
- [ ] `aapp` -> Dispatch `status`, `matrix`, `plan-status`, `help`, `--help`, `-h`, `--version`, and `-v` directly to `AAPP::Cmd::*`.
- [ ] `lib/adoption.sh` -> Transitional shim delegating to `AAPP::Adoption` until `P-121`/`P-122`.
- [ ] `lib/cmd_matrix.sh` -> Transitional shim delegating to `AAPP::Cmd::Matrix` until `P-119`/`P-122`.
- [ ] `lib/cmd_status.sh` -> Transitional shim delegating to `AAPP::Cmd::Status` until `P-122`.
- [ ] `lib/cmd_help.sh` -> Transitional shim delegating to `AAPP::Cmd::Help` until `P-122`.
- [ ] `lib/cmd_plan.sh` -> Delegate `cmd_plan_status` to `AAPP::Cmd::PlanStatus` until `P-119`.
- [ ] `t/core/adoption.t` -> Switch from bash `source` wrappers to direct `AAPP::Adoption` calls.
- [ ] `t/core/matrix.t` -> Switch from bash `source` wrappers to direct `AAPP::Cmd::Matrix` calls.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine (P-126) and every test file in `t/` stay out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`post-status`, `post-matrix`, `post-help`, `post-plan-status`), and execution checklist with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_status.sh`, `lib/cmd_matrix.sh`, `lib/cmd_help.sh`, and `lib/adoption.sh` contracts.

