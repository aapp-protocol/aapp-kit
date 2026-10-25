# 🗺️ Plan P-133: Read The Whole Group Plan
* **Created:** 2026-10-24 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-133
* **Changelog:** Changed: a group member's start, its status line, the rules and the group template point agents to the whole group plan (goal, shared decisions, architecture) before work on a member
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🔷 Frozen
* **Base:** none
* **Group:** P-111
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A session that starts or resumes a group member is pointed at one section of the group plan, `## Architecture & Codemap`: by the `start`/`freeze-start` output, by the `aapp status` line in a member's worktree, by the *Plan groups* rule in `AGENTS.md`, and by the `aapp-start` skill. The group's §1 Goal (why the group exists, how success is measured) and §2 Shared Decisions are never named, so a new session can work a member without them. This plan points every one of those places at the whole group plan, and gives the group template an introduction saying so. It lands on the port's feature branch so the remaining members are worked with the group's goal in view.

Phase 0 (the group text updates to P-111 §5 and amendments) has already been applied by hand. As the first member landing before P-116, this plan also delivers the event logging foundation to `lib/AAPP/Logger.pm` (`log_event($command, $event, \%data)` and `@EVENTS` registry) and `commits.plans` telemetry to `lib/AAPP/CommitEngine.pm`, ensuring hook and verb telemetry is in place before P-116 starts emitting events.

---

## 2. Technical Blueprint
1. **Group template introduction** (`templates/group-template.md`): a block right under the header fields, before §1:
   > **Read this whole plan before starting or resuming any member.** §1 says why the group exists and how its success is measured; §2 holds the decisions every member keeps; `## Architecture & Codemap` is the target architecture. A member's own plan is read against them.
2. **Start output** (`lib/cmd_plan.sh`, the member Guide line printed by `start` and `freeze-start`): `Guide        : member of group <id>: read the whole group plan (§1 Goal, §2 Shared Decisions, ## Architecture & Codemap) in .plans/current/<file> before coding.`
3. **Status line** (`lib/cmd_status.sh`, a checkout bound to a member): `📖 Bound to <id>, member of group <gid>: re-read the whole group plan (§1 Goal, §2 Shared Decisions, ## Architecture & Codemap) in <file> before continuing.`
4. **Rule and skill** (`templates/AGENTS.md` *Plan groups*, `templates/skills/aapp-start/SKILL.md`): the sentence naming `## Architecture & Codemap` as the guide names the whole group plan, the goal and shared decisions first; reading it at every member start, session start and resume stays.
5. **Contracts and tests**: `lib/docs/verbs/start.md`, `freeze-start.md`, `status.md` carry the new lines; `tests/verbs/start.group.sh::test_member_start_points_at_group_guide` and `tests/verbs/status.sh::test_status_member_rereads_group_guide` assert them. The Perl ports of these verbs (P-118, P-119) keep the wording through the contracts.
6. **Live after init**: `templates/AGENTS.md` and the skill reach `.agents/` through `aapp init` (and an IDE reload); the change log says so.
7. **Event logging foundation** (`lib/AAPP/Logger.pm`, `lib/AAPP/CommitEngine.pm`): deliver `log_event($command, $event, \%data)` with 3 arguments and the `@EVENTS` registry in `lib/AAPP/Logger.pm` as specified in `.plans/pickup/perl-port-logging-events-spec.md`. Integrate `commits.plans` telemetry into `lib/AAPP/CommitEngine.pm`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: The group's text (RFC §5), from this plan's worktree
- [x] Task 0.1: Request in P-112, `for P-111`, each by heading with its reason: §3 *Members & Order* (the order of RFC D2/D4); the introduction above §1 (§2.1's text); `Shared Decisions` (*Tests vs. code boundary* and *Modular test harness* replaced by RFC D2–D3); `## Architecture & Codemap` (*Test Harness Sandbox Confinement* and the `Tests.pm` line: every worktree pointer rewritten, scenario projects in one fixture, verb tests through `AAPP::Cmd::*` with a thin CLI layer). (Completed by hand)
- [x] Task 0.2: Once approved, make them: the `## Architecture & Codemap` sections through `aapp refine P-112 decision <n> "<reason>"` from P-112's worktree; the introduction and §3 through `aapp refine P-111 "<msg>"` from this worktree. (Completed by hand)
- [x] Task 0.3: §2 stays as written (design-locked, no `decision` reaches it until P-130 §2.9); the introduction carries one line: "§2 *Tests vs. code boundary* and *Modular test harness* are replaced by the decisions of `.plans/pickup/perl-port-test-salvage-rfc.md` (D2, D3), recorded as R<n> in P-112." (Completed by hand)

### Phase 1: Failing tests & Logger Telemetry
- [ ] Task 1.1: Change the two test assertions and the three contract lines to the new wording; both tests fail.
- [ ] Task 1.2: Implement `AAPP::Logger::log_event($command, $event, \%data)` and `@EVENTS` in `lib/AAPP/Logger.pm`, and `commits.plans` in `lib/AAPP/CommitEngine.pm`.

### Phase 2: Pointers and introduction
- [ ] Task 2.1: The Guide line in `lib/cmd_plan.sh` and the status line in `lib/cmd_status.sh`; both tests pass.
- [ ] Task 2.2: The introduction in `templates/group-template.md`; the *Plan groups* sentence in `templates/AGENTS.md`; the group member paragraph in `templates/skills/aapp-start/SKILL.md`.

### Phase 3: Verification
- [ ] Task 3.1: `./aapp test strict quiet` and `t/test-run strict quiet` green; a group drafted from the template carries the introduction.
- [ ] Task 3.2: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `templates/group-template.md` -> The introduction above §1.
- [ ] `lib/cmd_plan.sh` -> The member Guide line of `start` and `freeze-start`.
- [ ] `lib/cmd_status.sh` -> The bound-member line.
- [ ] `templates/AGENTS.md` -> The *Plan groups* sentence naming the guide.
- [ ] `templates/skills/aapp-start/SKILL.md` -> The group member paragraph.
- [ ] `lib/docs/verbs/start.md` -> The Guide line.
- [ ] `lib/docs/verbs/freeze-start.md` -> The Guide line.
- [ ] `lib/docs/verbs/status.md` -> The bound-member line.
- [ ] `lib/AAPP/Logger.pm` -> Event logging engine and events registry.
- [ ] `lib/AAPP/CommitEngine.pm` -> Emits commits.plans event.
- [ ] `tests/verbs/start.group.sh` -> `test_member_start_points_at_group_guide`.
- [ ] `tests/verbs/status.sh` -> `test_status_member_rereads_group_guide`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/current/P111-perl-port-of-the-kit.md` -> Changed only by Phase 0, recorded in P-112.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1:** Place in the group order: the next member to start (before P-116), or elsewhere?
  * **Answer (user, 2026-10-24):** first in line once the salvage and the road map (`.plans/pickup/perl-port-test-salvage-rfc.md`) are settled.

---

## 📦 6. Change Log & Refinement History
* **2026-10-25:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-24:** Drafted as a member of P-111: every pointer to a group plan names the whole plan, the goal and shared decisions first.
