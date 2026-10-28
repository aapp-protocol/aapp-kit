# 🗺️ Plan P-118: Perl Readonly Verbs
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-118
* **Changelog:** Changed: Port workspace recovery and discovery verbs (`status`, `help`, `pickup commit`) and `AAPP::Adoption` to `lib/AAPP/Runner/` over `AAPP::State` with structured log event telemetry
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-118` is the thirteenth member of group `P-111` (*Perl Port Of The Kit*). It ports the project adoption scanner (`lib/adoption.sh`, 503 lines), workspace status briefing (`status`, `lib/cmd_status.sh`, 937 lines), contract-backed help (`help`, `lib/cmd_help.sh`, 176 lines), and pickup commit (`aapp pickup commit`) into the noun-first command hierarchy under `lib/AAPP/Runner/Status.pm`, `lib/AAPP/Runner/Help.pm`, `lib/AAPP/Runner/Pickup.pm`, and `lib/AAPP/Adoption.pm`.

Plan-specific queries (`matrix` and `plan-status`) are moved under the `aapp plan` noun (`aapp plan matrix` and `aapp plan status`) owned by `P-119`.

In bash, `aapp status` re-parses `state_matrix.md`, `ISSUES.md`, `issues_road_map.md`, `pickup.md`, and every `.plans/current/P*.md` file through separate `awk` processes and spawns per-worktree `git` invocations. In Perl, `AAPP::Runner::Status` reads from the in-memory `AAPP::State` object in a single process, rendering human output, `short` output, and `json` payloads (`AAPP::Output` + `AAPP::JSON`).

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Adoption.pm`, `lib/AAPP/Runner/Status.pm`, `lib/AAPP/Runner/Help.pm`, `lib/AAPP/Runner/Pickup.pm`, `lib/adoption.sh`, `lib/cmd_status.sh`, `lib/cmd_help.sh`, `aapp`) plus switching `t/core/adoption.t` from bash `source` wrappers to direct `AAPP::Adoption` calls per `P-111`'s core-wrapper rule.

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§4.4 `status`, `help`):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (Epochs E0 & E1 `status`, `help`):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epochs E0 & E1, Actions A001–A004, A034):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 `AAPP::Adoption` (`lib/AAPP/Adoption.pm`) — `lib/adoption.sh` (503 lines)
Ports `lib/adoption.sh` into `lib/AAPP/Adoption.pm`:
- Implements adoption catalogue target queries (`get_all_adoption_doc_targets`, `get_all_adoption_manual_headings`), open checklist counter (`adoption_open_count`), and adoption checklist synchronization (`sync_adoption_checklist`).

### 2.2 `AAPP::Runner::Status` (`lib/AAPP/Runner/Status.pm`) — `aapp status` (`lib/cmd_status.sh`, 937 lines)
Ports `cmd_status` from `lib/cmd_status.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help status full` and `lib/docs/verbs/status.md`.
- Scans the 4 workspace pillars (Shipped, Issues, Plans, Pickup) from `AAPP::State`, `AAPP::Health`, `AAPP::Adoption`, `AAPP::Issue`, and `AAPP::Runner::Offline`, rendering terminal (`AAPP::Output`) and `json` (`AAPP::JSON`) output.

### 2.3 `AAPP::Runner::Help` (`lib/AAPP/Runner/Help.pm`) — `aapp help` (`lib/cmd_help.sh`, 176 lines)
Ports `cmd_help` from `lib/cmd_help.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help help full` and `lib/docs/verbs/help.md`.
- Renders top-level and per-verb help from `lib/verbs.tsv` and `lib/docs/verbs/<verb>.md` (`<!-- FULL -->` split), plus version output.

### 2.4 `AAPP::Runner::Pickup` (`lib/AAPP/Runner/Pickup.pm`) — `aapp pickup commit`
Implements the pickup noun and commit action:
- `aapp pickup commit "<msg>"`: verifies pickup file shape via `AAPP::Health::check_pickup_entries`, commits `.plans/pickup.md` and referenced files in `.plans/pickup/` with `pickup: <msg>`.

### 2.5 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §4.4:
- `AAPP::Runner::Status`: emits `post-status` (`shipped_count`, `queued_issues_count`, `plans_count`, `pickup_count`, `open_adoption_tasks`, `bound_plan`, `group_guide_shown`, `pending_requests`, `unblocked_by_status`, `next_action`).
- `AAPP::Runner::Help`: emits `post-help` (`topic => $topic`, `status => 'ok'|'unknown_topic'`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Adoption (`AAPP::Adoption`)
- [ ] Task 1.1: Implement `lib/AAPP/Adoption.pm` (`lib/adoption.sh`) and switch `t/core/adoption.t` to call `AAPP::Adoption` directly without bash `source` wrappers.

### Phase 2: Status, Help & Pickup (`AAPP::Runner::Status`, `Help`, `Pickup`)
- [ ] Task 2.1: Implement `lib/AAPP/Runner/Status.pm` (`aapp status [short | json]` with `post-status`).
- [ ] Task 2.2: Implement `lib/AAPP/Runner/Help.pm` (`aapp help [<verb> [full]]` with `post-help`).
- [ ] Task 2.3: Implement `lib/AAPP/Runner/Pickup.pm` (`aapp pickup commit "<msg>"`).
- [ ] Task 2.4: Wire `status`, `help`, `--help`, `-h`, `--version`, `-v`, and `pickup` in `./aapp` to `AAPP::Runner::*`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `prove -l t/core/adoption.t` and syntax check `perl -c` across new `lib/AAPP/Runner/*.pm` modules.
- [ ] Task 3.2: Verify `./aapp status` and `./aapp help` display correctly.
- [ ] Task 3.3: Verify `CHANGELOG.md` updates.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Adoption.pm` -> Project adoption detection, drift warnings, and seed/sync helpers.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Status.pm` -> `aapp status [short | json]` implementation with `post-status` telemetry over `AAPP::State` and `AAPP::Output`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Help.pm` -> `aapp help [<verb> [full]]` and version display with `post-help` telemetry over `lib/verbs.tsv` and `lib/docs/verbs/*.md`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Pickup.pm` -> `aapp pickup commit` command runner.
- [ ] `aapp` -> Dispatch `status`, `help`, `--help`, `-h`, `--version`, `-v`, and `pickup` directly to `AAPP::Runner::*`.
- [ ] `lib/adoption.sh` -> Transitional shim delegating to `AAPP::Adoption` until `P-121`/`P-122`.
- [ ] `lib/cmd_status.sh` -> Transitional shim delegating to `AAPP::Runner::Status` until `P-122`.
- [ ] `lib/cmd_help.sh` -> Transitional shim delegating to `AAPP::Runner::Help` until `P-122`.
- [ ] `t/core/adoption.t` -> Switch from bash `source` wrappers to direct `AAPP::Adoption` calls.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine and other test files in `t/` (except declared target `t/core/adoption.t`) stay out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` remain out of bounds during code port.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Aligned with noun-first CLI architecture (`lib/AAPP/Runner/`); moved `matrix` and `plan-status` to `P-119` (`aapp plan matrix`, `aapp plan status`); added `AAPP::Runner::Pickup`.
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`post-status`, `post-help`), and execution checklist with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_status.sh`, `lib/cmd_help.sh`, and `lib/adoption.sh` contracts.
