# 🗺️ Plan P-65: Pre-Flight Concurrency & Conflict Audit CLI
* **Created:** 2026-10-10 | **Last Refined:** 2026-10-10
* **Target Issue / Milestone:** Milestone: Monorepo & Two-Context Architecture
* **Plan ID:** P-65
* **Changelog:** Added: `aapp plan conflict-check` and `conflict-free` commands to audit plan concurrency and blast-radius overlap
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

AAPP strictly enforces the **Disjointness Invariant**: no two concurrently in-flight blueprints (`⚡ In Development`) may target the same files, preventing race conditions, colliding git diffs, and worktree merge conflicts.

However, currently this disjointness is verified **only at activation time**:
- `aapp start <id>` runs `check_disjointness_activation_gate` in `lib/cmd_plan.sh:155`, which only compares `<id>` against plans *already* in development.
- Pair 7 (`check_pair7_inflight_boundary_collision`) in `lib/planning_health.sh:590` only audits plans that are already marked `⚡ In Development`.

**The Problem:** Developers and multi-agent dispatchers have zero pre-flight visibility into plan compatibility. When planning a sprint or organizing a multi-plan feature branch (RFC P-64), there is no CLI tool to determine whether two incubator/backlog blueprints can execute concurrently, or which pending blueprints are safe to start alongside currently active plans, without attempting a failed `aapp start`.

**Goal:** Introduce pre-flight concurrency audit subcommands to the `aapp plan` suite:
1. `aapp plan conflict-check <id1> <id2>`: Compare two specific blueprints directly, regardless of their current status (`🟣`, `🔷`, or `⚡`), and report whether they are disjoint or identify exact colliding targets.
2. `aapp plan conflict-free`: Scan `.plans/current/` and list all blueprints that can be safely started right now without colliding with actively in-flight plans.
3. `aapp plan conflict-free <id>`: Query which other blueprints in `.plans/current/` can run concurrently with plan `<id>`.

---

## 2. Technical Blueprint

### 2.1 Subcommand Suite & CLI Ingress

The `aapp plan` verb dispatcher in `lib/cmd_plan.sh` is extended with three concurrency subcommands:

#### 1. `aapp plan conflict-check <id1> <id2>`
- **Ingress**: Two plan identifiers (accepts `P-<N>`, bare `<N>`, filename stems, or slugs).
- **Behavior**:
  - Resolves both plan paths via `resolve_plan_path` / `find_plan_file`.
  - Extracts declared `### 📂 Target Files` using `parse_plan_target_paths`.
  - Intersects the target lists:
    - Shared documentation files (`CHANGELOG.md`, `MANUAL.md`, `CODEMAP.md`, etc., recognized via `aapp_is_shared_doc`) are exempted from collisions per P-48 union-merge rules and noted as `ℹ️ [Shared Doc]`.
    - Any non-shared target in common is flagged as a collision.
- **Output & Exit Codes**:
  - **No collisions**: Exit `0`.
    ```text
    ✔ Plans P-64 and P-65 are disjoint and can run concurrently.
      ℹ️  [Shared Doc] CHANGELOG.md (exempt; union merge)
    ```
  - **Collisions detected**: Exit `1`.
    ```text
    ✘ Collision detected between P-62 and P-63:
      -> Colliding target: tests/verbs/status.sh
      Plans cannot be in development simultaneously in the same workspace.
    ```

#### 2. `aapp plan conflict-free` (no arguments)
- **Ingress**: No positional arguments.
- **Behavior**:
  - Scans `.plans/current/*.md` for plans in `⚡ In Development` (or bound in active buffers).
  - If **zero plans are in development**: outputs that all incubator/backlog blueprints are currently conflict-free.
  - If **1+ plans are in development**: aggregates all active non-shared Target Files into an in-flight conflict set.
  - Iterates every pending plan in `.plans/current/` (`🟣 Under Review`, `🔷 Frozen`):
    - Tests candidate Target Files against the active conflict set.
    - Groups output into:
      1. **Conflict-Free (Ready to run concurrently)**: Lists plan IDs and titles.
      2. **Conflicting (Blocked by in-flight work)**: Lists plan IDs, titles, colliding file(s), and the specific in-flight plan holding them.
- **Exit Code**: `0` always (informational query).

#### 3. `aapp plan conflict-free <id>` (with reference plan)
- **Ingress**: One positional plan identifier `<id>`.
- **Behavior**:
  - Resolves `<id>` and extracts its non-shared Target Files.
  - Compares `<id>` against every other blueprint in `.plans/current/`.
  - Groups and lists:
    1. **Compatible Blueprints**: Other plans that share zero non-shared targets with `<id>`.
    2. **Incompatible Blueprints**: Plans that share one or more targets with `<id>`, naming the colliding files.
- **Exit Code**: `0` always.

#### 4. Plan sets and groups (developer, 2026-10-11)
The tool is standalone: it works on any plans, in any status, grouped or not. A group plan (P-64) is one more input:
- `aapp plan conflict-check <id> <id>…`: two or more plans; a group plan ID expands to its planned members. Exit 0 when all are pairwise disjoint, 1 otherwise, naming each colliding pair and file.
- `aapp plan conflict-free <group>`: the group's **implementation order**: members in waves, each wave pairwise disjoint (and disjoint from plans already in flight), so one agent per member of a wave can work at the same time. Members are placed in their listed order, each into the first wave it fits. The output names, for each member held back, the file and member that pushed it to a later wave, so the plans can be reshaped and checked again. Exit 0 (informational).
- **Group Member Status Filtering**:
  - `✅ Done` members: omitted from wave scheduling (their work is already integrated into the feature branch).
  - `⚡ In Development` members: treated as active in-flight locks (candidate Wave 1 plans cannot collide with them).
  - Pending members (`🟣 Under Review`, `🔷 Frozen`, `📝 Refining`): scheduled into subsequent execution waves (`Wave 1`, `Wave 2`, etc.).
- Shared docs stay exempt as in §2.1.

#### 5. Machine-Readable Automation Token (`json`)
Following AAPP keyword token conventions (no double dashes `--`), appending the bare keyword `json` to any subcommand switches output from human ANSI text to structured JSON on stdout (exit codes remain strictly unchanged: 0 clean, 1 collision for `conflict-check`):
- `aapp plan conflict-check <id> <id>… json`:
  ```json
  {
    "clean": true,
    "plans": ["P-64", "P-65"],
    "collisions": [],
    "shared_docs": ["CHANGELOG.md"]
  }
  ```
  On collision (exit 1):
  ```json
  {
    "clean": false,
    "plans": ["P-62", "P-63"],
    "collisions": [
      {
        "plan_a": "P-62",
        "plan_b": "P-63",
        "target": "tests/verbs/status.sh"
      }
    ],
    "shared_docs": []
  }
  ```
- `aapp plan conflict-free <group> json`:
  ```json
  {
    "group": "P-64",
    "waves": [
      { "wave": 1, "plans": ["P-65", "P-66"] },
      { "wave": 2, "plans": ["P-67"], "held_back": [ { "plan": "P-67", "collides_with": "P-65", "target": "tests/verbs/plan.sh" } ] }
    ]
  }
  ```
- `aapp plan conflict-free [json]` / `aapp plan conflict-free <id> json`:
  ```json
  {
    "conflict_free": ["P-65", "P-66"],
    "conflicting": [
      { "plan": "P-67", "collides_with": "P-60", "target": "lib/cmd_test.sh" }
    ]
  }
  ```

### 2.2 Core Comparison Helper (`lib/cmd_plan.sh`)

Implement helper function:
```bash
# plan_compare_targets <plan_a_path> <plan_b_path>
# Emits list of non-shared colliding paths on stdout.
# Returns 0 if disjoint, 1 if collision detected.
```
- Reuses `parse_plan_target_paths` from `lib/aapp-lib.sh`.
- Reuses `aapp_is_shared_doc` from `lib/aapp-lib.sh`.
- Ensures consistent parsing identical to `check_disjointness_activation_gate` and `check_pair7_inflight_boundary_collision`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Pure additive enhancement to `aapp plan`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/plan.sh`: Add test `test_conflict_check_disjoint_plans_exit_zero`.
- [ ] Task 1.2: `tests/verbs/plan.sh`: Add test `test_conflict_check_overlapping_plans_exit_one_and_names_target`.
- [ ] Task 1.3: `tests/verbs/plan.sh`: Add test `test_conflict_check_exempts_shared_docs`.
- [ ] Task 1.4: `tests/verbs/plan.sh`: Add test `test_conflict_free_against_active_in_flight_plans`.
- [ ] Task 1.5: `tests/verbs/plan.sh`: Add test `test_conflict_free_with_reference_plan`.
- [ ] Task 1.6: `tests/verbs/plan.sh`: Add test `test_conflict_check_many_plans_and_group_expands`.
- [ ] Task 1.7: `tests/verbs/plan.sh`: Add test `test_conflict_free_group_orders_members_in_waves` (three members, two colliding: two waves, the held-back member names the file and member).
- [ ] Task 1.8: `tests/verbs/plan.sh`: Add test `test_group_waves_respect_in_flight_plans`.
- [ ] Task 1.9: `tests/verbs/plan.sh`: Add test `test_group_waves_filters_done_and_inflight_members` (done members skipped, inflight members anchor collisions).
- [ ] Task 1.10: `tests/verbs/plan.sh`: Add test `test_conflict_subcommands_json_token_output` (validates structured JSON and exit code parity across check, free, and waves).

### Phase 2: Core Implementation
- [ ] Task 2.1: Implement `plan_compare_targets()` helper in `lib/cmd_plan.sh`.
- [ ] Task 2.2: Implement `cmd_plan_conflict_check()` and wire into `cmd_plan` dispatcher.
- [ ] Task 2.3: Implement `cmd_plan_conflict_free()` (handling both 0-arg and 1-arg cases).
- [ ] Task 2.4: Update `aapp plan` switchboard / help output to list `conflict-check` and `conflict-free`.
- [ ] Task 2.5: Plan sets, group waves, member status filtering, and `json` token support (§2.1.4, §2.1.5), reading group members through P-64's parsers.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases (non-existent plan IDs, plans with empty target files).
- [ ] Task 3.2: Update `lib/docs/verbs/plan.md` verb contract.
- [ ] Task 3.3: Update `MANUAL.md` with Concurrency & Conflict Audit CLI documentation.
- [ ] Task 3.4: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.5: Verify `CHANGELOG.md` updates and run syntax/build checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> Implement `conflict-check` and `conflict-free` subcommands and comparison helper.
- [ ] `lib/docs/verbs/plan.md` -> Update contract documentation for `plan` verb.
- [ ] `tests/verbs/plan.sh` -> Test suite covering disjoint checks, collisions, shared docs, and conflict-free queries.
- [ ] `MANUAL.md` -> User documentation for plan concurrency auditing.
- [ ] `.agents/CODEMAP.md` -> Architecture reference for plan conflict validation.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_issue.sh` -> Issue management untouched.
- [ ] `lib/planning_health.sh` -> Health validation pairs untouched.
- [ ] `.githooks/*` -> Commit-time enforcement untouched.
- [ ] `templates/blast-radius-guard.sh` -> Write guard untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Exit codes for scriptability. → RESOLVED (developer, 2026-10-10): `conflict-check` returns exit 0 on clean/disjoint, exit 1 on collision.** This allows scripts, CI checks, or multi-agent dispatchers (`aapp dispatch`) to automate concurrency checks via `if aapp plan conflict-check P1 P2; then ... fi`.
* [x] **Question 2 — Scope of `conflict-free`. → RESOLVED (developer, 2026-10-10): Pure target files comparison.** Scans `### 📂 Target Files` of plans in `.plans/current/`. Pending issue blocker checks remain in `aapp start` activation gates.
* [x] **Question 3 — Order beyond shared files. → RESOLVED (developer/agent, 2026-10-11): (a) Files only; waves govern file-disjoint concurrency.** Waves model concurrent execution safety (blast radius disjointness). If a plan has an API or semantic dependency without file collision, the human sequences their execution order. A prospective `After:` header can be revisited if automated multi-agent dependency graphs require it.
* [x] **Question 4 — Sequence with P-64. → RESOLVED (developer/agent, 2026-10-11): (a) P-65 executes after P-64.** P-65 consumes P-64's group template, `# 🧩 Group Plan` heading marker, and group member parsers in `lib/aapp-lib.sh`. One cohesive design.

---

## 6. Change Log & Refinement History
* **2026-10-11:** Resolved Q3 (waves govern file-disjoint concurrency) and Q4 (P-65 after P-64). Added keyword token 'json' (no double dashes) for structured automation output across check and free subcommands. Added group member status filtering for done and in-flight members.
* **2026-10-11:** Standalone for any plans; plan sets; a group plan's members ordered in waves (developer). Q3, Q4 open.
* **2026-10-10:** Scaffolded and fully refined from developer specification: added `conflict-check <id1> <id2>`, `conflict-free` (0-arg for in-flight plans), and `conflict-free <id>` (1-arg for reference plan). Defined CLI ingress, output formatting, exit codes, and test checklist.
