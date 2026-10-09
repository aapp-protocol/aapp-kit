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

During project onboarding and ongoing tool upgrades, `aapp init` performs automated infrastructure synchronization (orphan worktrees, hook engines, Claude settings, skills). However, crucial adoption integration requirements cannot be automatically mutated by the kit without violating adopter ownership boundaries:
1. **Monorepo scanner exclusions**: Tools such as Nx (`nx.json`), Turborepo (`turbo.json`), pnpm (`pnpm-workspace.yaml`), Bazel (`WORKSPACE` / `MODULE.bazel`), and TypeScript (`tsconfig.json`) crawl workspace roots by default. Unless explicitly configured to ignore `/.workspace/`, they register ephemeral plan worktrees as duplicate packages or trigger indexing loops.
2. **Quality gates & hook wiring**: Critical verification checks—such as registering P-60's `pre-done` test gate or chaining `.githooks/aapp-pre-commit` into pre-existing hook managers (Husky, Lefthook, pre-commit framework)—currently print transient stdout warnings that scroll off-screen and disappear.
3. **Branching & CI alignment**: Aligning `aapp.devBranch` with team branching topology and ensuring CI test runners guard `develop`.

**Core Principle:** The kit must *never* silently rewrite or mutate adopter build configuration files (e.g. editing `pnpm-workspace.yaml` or `.nxignore` automatically).

**Goal:** Establish a durable, persistent adoption checklist at `.plans/adoption.md`.
- `aapp init` scans the repository for known build systems, monorepos, hook managers, and quality gates, generating or updating `.plans/adoption.md`.
- Tasks are authored with stable tags (`[MONO-NX]`, `[GATE-TEST]`) and concrete, copy-paste instructions.
- Re-running `aapp init` (or `aapp upgrade`) automatically marks verified tasks complete (`- [ ]` → `- [x]`) and never unchecks human-ticked items.
- `aapp status` surfaces the open adoption count in its overview metric, keeping adoption visible upon desk return until onboarding is 100% complete.

---

## 2. Technical Blueprint

### 2.1 File Location & Data Model (`.plans/adoption.md`)

The checklist lives in `.plans/adoption.md` on the orphan `plans` branch:
- **Clean checkout boundary**: Storing adoption tasks in `.plans/` avoids dirtying code branches (`develop`, `main`, feature branches) with metadata commits.
- **Universal access**: Linked worktrees (`.workspace/<id>`) access `.plans/` via the canonical relative symlink established by `aapp start`.
- **Markdown schema**:
  ```markdown
  # 📋 Project Adoption & Integration Advisories
  * **Last Scanned:** YYYY-MM-DD
  * **Status:** <N> open task(s) remaining (<M> completed)

  ## 🛠️ Monorepo & Build Tool Exclusions
  - [ ] `[MONO-NX]` Add `/.workspace` to `.nxignore` to prevent Nx from discovering plan worktrees as duplicate projects.
  - [x] `[MONO-PNPM]` Add `!./.workspace/**` to `pnpm-workspace.yaml` under `packages`.

  ## 🛡️ Quality Gates & Hook Wiring
  - [ ] `[GATE-TEST]` Register `pre-done` test gate in `.agents/skills/aapp-hooks/registry.tsv` (SHA-256 of `.agents/hooks/test-gate.sh`).
  - [ ] `[HOOK-WIRING]` Wire `aapp-pre-commit` into `.husky/pre-commit` to enforce Layer 2 blast-radius checks.
  ```

### 2.2 Detection Engine & Rules Catalog (`lib/cmd_init.sh`)

`lib/cmd_init.sh` gains helper `sync_adoption_advisories()`, executed during Phase 6. The rule catalog inspects the project root:

| Rule Tag | Detection Trigger | Verification Check (Auto-Tick `- [x]`) | Advisory Instruction |
| :--- | :--- | :--- | :--- |
| `[MONO-NX]` | `nx.json` exists in project root | `.nxignore` exists and contains `/.workspace` or `.workspace` | Add `/.workspace` to `.nxignore`. |
| `[MONO-PNPM]` | `pnpm-workspace.yaml` exists in root | `pnpm-workspace.yaml` contains `!.workspace` or `!./.workspace/**` | Add `!./.workspace/**` to `packages` list in `pnpm-workspace.yaml`. |
| `[MONO-TURBO]` | `turbo.json` exists in root | `.turboignore` exists and contains `/.workspace` or `.workspace` | Add `/.workspace` to `.turboignore`. |
| `[MONO-BAZEL]` | `WORKSPACE`, `WORKSPACE.bazel`, or `MODULE.bazel` exists | `.bazelignore` exists and contains `/.workspace` or `.workspace` | Add `.workspace` to `.bazelignore`. |
| `[MONO-TS]` | Root `tsconfig.json` or `tsconfig.base.json` exists | `"exclude"` list contains `".workspace"` | Add `".workspace"` to `"exclude"` array in root `tsconfig.json`. |
| `[GATE-TEST]` | Always evaluated | `pre-done` hook registered in `.agents/skills/aapp-hooks/registry.tsv` | Copy `examples/hooks/test-gate.sh.sample` to `.agents/hooks/test-gate.sh` and register SHA in registry.tsv. |
| `[HOOK-WIRING]` | `HOOK_MANAGER_NOTICE=1` (existing non-aapp hook manager) | Active pre-commit hook runs `aapp-pre-commit` | Add call to `.githooks/aapp-pre-commit` inside active hook script. |
| `[BRANCH-TOPOLOGY]`| Dual-branch topology detected (`develop` present) | `git config aapp.devBranch` is explicitly set | Configure `git config aapp.devBranch develop`. |

### 2.3 Idempotency & Auto-Verification Protocol

1. **Parse existing tasks**: If `.plans/adoption.md` exists, parse existing lines for `[TAG]` and their completion status (`- [x]` vs `- [ ]`).
2. **Preserve human ticks**: Any task already marked `- [x]` is preserved as `- [x]`. `aapp init` NEVER reverts a checked box to unchecked.
3. **Auto-verification**: If an existing task is `- [ ]` and the Verification Check passes, transition it to `- [x]`.
4. **Append new discoveries**: If a new tool is introduced (e.g. adopter adds `nx.json`), append the new advisory under the appropriate category.
5. **No deletions**: Obsolete or completed tasks remain visible for historical audit unless cleared by the human.

### 2.4 Visibility in `aapp status` (`lib/cmd_status.sh`)

`lib/cmd_status.sh` inspects `.plans/adoption.md`:
- Count open tasks: `ADOPTION_OPEN=$(grep -c '^[[:space:]]*- \[ \]' .plans/adoption.md 2>/dev/null || echo 0)`
- If `ADOPTION_OPEN > 0`:
  - Overview line appends: `| <N> adoption tasks`
    Example: `📊 Overview: 17 issues | 8 plans | 7 pickup | 2 adoption tasks`
  - Guidance section outputs:
    `📋 Adoption Tasks: 2 pending items in .plans/adoption.md (run 'cat .plans/adoption.md' to inspect)`

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Repositories without `.plans/adoption.md` generate it on their next `aapp init`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/install_test.sh`: Add tests for `aapp init` creating `.plans/adoption.md` upon detecting `nx.json`, `pnpm-workspace.yaml`, and `HOOK_MANAGER_NOTICE`.
- [ ] Task 1.2: `tests/install_test.sh`: Add test for idempotency (re-run auto-ticks resolved condition; never reverts human `- [x]`).
- [ ] Task 1.3: `tests/verbs/status.sh`: Add test verifying `aapp status` displays open adoption tasks count in overview line when items are pending, and omits or reports clean when 0.

### Phase 2: Implementation
- [ ] Task 2.1: Add `templates/adoption.md` starter template and schema.
- [ ] Task 2.2: Implement `sync_adoption_advisories()` in `lib/cmd_init.sh` with rule detection catalog and idempotent reconciliation.
- [ ] Task 2.3: Update `lib/cmd_status.sh` to parse `.plans/adoption.md` and display open adoption task count.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md` with the Adoption Advisories specification and rule catalog.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/adoption.md` -> Base template for adoption advisories checklist.
- [ ] `lib/cmd_init.sh` -> Adoption scanner, rules catalog, and idempotent sync engine.
- [ ] `lib/cmd_status.sh` -> Overview metric and adoption task reporting.
- [ ] `tests/install_test.sh` -> Unit tests for advisory detection and idempotency.
- [ ] `tests/verbs/status.sh` -> Unit tests for status briefing metric.
- [ ] `MANUAL.md` -> User documentation for adoption checklist and supported build tool rules.
- [ ] `.agents/CODEMAP.md` -> Architecture reference for adoption engine.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Plan lifecycle engine untouched.
- [ ] `lib/cmd_issue.sh` -> Issue management untouched.
- [ ] `.githooks/*` -> Core hook runners untouched.
- [ ] `templates/blast-radius-guard.sh` -> Guard logic untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Location. → RESOLVED (developer / RFC C6 & A3, 2026-10-10): (a) `.plans/adoption.md`.** `.plans/` is mounted on the orphan `plans` branch, keeping the active code tree free from configuration metadata churn, while remaining accessible across linked plan worktrees via symlink.
* [x] **Question 2 — Re-runs and auto-ticking. → RESOLVED (developer / RFC consensus, 2026-10-10): (a) Hybrid verification.** `aapp init` automatically marks verified tasks complete (`- [x]`) when the file system inspection confirms the condition is met (e.g. `.nxignore` contains `/.workspace`), but strictly preserves existing `- [x]` states and never unchecks a human's tick.

---

## 📦 6. Change Log & Refinement History
* **2026-10-10:** Deep research completed: defined rules catalog (`[MONO-NX]`, `[MONO-PNPM]`, `[MONO-TURBO]`, `[MONO-BAZEL]`, `[MONO-TS]`, `[GATE-TEST]`, `[HOOK-WIRING]`), idempotency protocol, status overview metrics, resolved Q1/Q2, and locked blast radius.
* **2026-10-09:** Drafted from the developer's idea (RFC A3): a central adoption checklist instead of one-off init output.
