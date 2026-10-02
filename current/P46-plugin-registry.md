# 🗺️ Plan P-46: Plugin Registry
* **Created:** 2026-09-29 | **Last Refined:** 2026-09-29
* **Target Issue / Milestone:** #94
* **Plan ID:** P-46
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 1. Context & Architectural Goal

Standard plugin names are hardcoded in about nine places. `cmd_plugins_status()` (`lib/cmd_hook.sh:171`) spells each one out in its own `if`/`elif` block, and the custom-plugin skip list (`case ... aapp-*|hello-tool ...`) repeats them. CODEMAP §5 is the only catalog, and it is documentation only and does not ship to adopters. Every new plugin (P-32 adds `aapp-issue`) or action means hand-syncing all of these copies.

**Goal:** one shipped registry, `lib/plugins.tsv`, in the style of `lib/verbs.tsv`. `aapp plugins` renders standard extension points from it; docs point to it instead of copying it.

---

## 2. Technical Blueprint

### 2.1 `lib/plugins.tsv`

```text
# name	role	state	events	counter	sample
aapp-planid	Team Plan ID Authority	shipped	plan.allocate	aapp.planId	examples/plugins/aapp-planid/run.sample
aapp-issue-tracker	Team Issue Tracker	shipped	issue.allocate,issue.close	aapp.issueId	examples/plugins/aapp-issue-tracker/run.sample
aapp-review	Adversarial Review	planned:P-15	-	-	-
hello-tool	Custom CLI Showcase	shipped	-	-	examples/plugins/hello-tool/run.sample
```

- `state`: `shipped`, or `planned:<plan-id>` for a name reserved before its plugin ships.
- `events`: comma-separated Plugin Payload Standard events the kit sends (`-` = CLI-invoked or not yet defined).
- `counter`: git config key shown as the local fallback when the plugin is absent (`-` = none).
- Shipped by `aapp install` already (it copies all of `lib/`); read from `$AAPP_BASE/lib/plugins.tsv`, the same base `cmd_hook.sh` uses for `examples/`.

### 2.2 `cmd_plugins_status()` (`lib/cmd_hook.sh`)

- Two sections, so plugin developers see every kit-owned name whether installed or not:
  - **Standard Extension Points:** every registry row, always listed (including `hello-tool`, which today appears only when installed), one loop replacing the per-plugin blocks. States: ACTIVE / CONFIGURED BUT NOT EXECUTABLE / SAMPLE AVAILABLE / NOT INSTALLED (with the fallback-counter line when `counter` is set), and `RESERVED (planned, <plan-id>)` for `planned:` rows. A `planned:` name that is installed early shows its installed state plus `reserved for <plan-id>; may be replaced`.
  - **Custom Action Plugins:** every other installed plugin with an executable entrypoint, with the command that runs it.
- Reserved prefix: an installed, executable `aapp-*` plugin that has no registry row is listed under Custom with a warning instead of being silently skipped:
  ```
  ⚠️ aapp-deploy uses the reserved aapp- prefix but is not a kit plugin.
     A future kit release may claim this name and replace or shadow it; rename it.
  ```
  A warning, not a refusal: the plugin keeps working. Kit skills under `.agents/skills/aapp-*` have no executable entrypoint and are not plugins, so they never trigger it.
- Missing or unreadable `plugins.tsv` → exit 1 with a clear diagnostic (fail closed).
- Per-row output keeps today's format and wording; the visible changes are `hello-tool` always listed, the `RESERVED` rows and the prefix warning.

### 2.3 Not the hooks registry

`.agents/skills/aapp-hooks/registry.tsv` is adopter-owned (seeded from `templates/skills/`, SHA-locked handlers per event, guard self-protected). `lib/plugins.tsv` is kit-owned and changes only with kit releases. Do not merge them: a kit catalog inside adopter copies would go stale every release (the #73 / P-25 problem). Reuse only its conventions: comment-header schema, tab-separated columns, and the row-parsing approach in `lib/cmd_hook.sh:55`.

### 2.4 Out of scope

- `lib/plan_resolver.sh` (`aapp-planid`, `aapp-issue-tracker` passed to `_allocate_id`) and `lib/cmd_issue.sh` (`aapp-issue-tracker` passed to `resolve_plugin_entrypoint`) keep their plugin names as literals: a file lookup would only add a failure path. A registry test (§3) guarantees every such literal has a row.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests First (red)
- [ ] Task 1.1: In `tests/hooks_test.sh`, add:
  - every registry row appears under Standard Extension Points, installed or not (incl. `hello-tool`);
  - `aapp-review` shows `RESERVED (planned, P-15)`; installed early, it shows its state plus `reserved for P-15`;
  - an installed executable `aapp-deploy` (no row) is listed under Custom with the reserved-prefix warning; a kit skill dir without an entrypoint is not;
  - a missing `plugins.tsv` makes `aapp plugins` exit 1;
  - registry consistency: every `examples/plugins/*` directory has a row, and every plugin-name literal in `lib/*.sh` has a row — the third argument of `_allocate_id` and the quoted second argument of `resolve_plugin_entrypoint` calls.

### Phase 2: Registry & Rendering
- [ ] Task 2.1: Add `lib/plugins.tsv` with the four rows in §2.1.
- [ ] Task 2.2: Rewrite `cmd_plugins_status()`: one loop over the registry for Standard Extension Points (states incl. `RESERVED`), Custom section from every other executable plugin, reserved-prefix warning; fail closed when the registry is missing.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Existing `aapp plugins` assertions in `tests/hooks_test.sh` still pass; run `./aapp test strict quiet`.
- [ ] Task 3.2: `.agents/CODEMAP.md` §5 and `ARCHITECTURE.md` name `lib/plugins.tsv` as the source of truth; `MANUAL.md` plugin section and `CHEATSHEET.md` providers line describe the two sections, reserved names and the prefix warning.
- [ ] Task 3.3: `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/plugins.tsv` -> Shipped plugin registry.
- [ ] `lib/cmd_hook.sh` -> Render standard extension points from the registry.
- [ ] `tests/hooks_test.sh` -> Registry rendering, reserved names, prefix warning, consistency.
- [ ] `.agents/CODEMAP.md` -> §5 points to the registry.
- [ ] `ARCHITECTURE.md` -> Name the registry as source of truth.
- [ ] `MANUAL.md` -> Plugin section: two sections, reserved names, prefix warning.
- [ ] `CHEATSHEET.md` -> Providers line points to the registry.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Allocators keep their literal plugin names.
- [ ] `lib/cmd_issue.sh` -> Close hand-off keeps its literal plugin name.
- [ ] `examples/plugins/` -> Samples unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Register P-15's `aapp-review` now or when P-15 ships? → RESOLVED (developer, 2026-10-03): now, as `planned:P-15`.** Shown as `RESERVED (planned, P-15)` so plugin developers see the name is taken before it ships.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-03:** Pre-freeze review: checklist rebuilt tests-first for all four rows and the new behaviours; `hello-tool` always listed (replaces "output identical"); concrete literal-name test; early-installed reserved names; `cmd_issue.sh` out of scope; MANUAL/CHEATSHEET in scope; registry read via `$AAPP_BASE`.
* **2026-10-03:** Refreshed after P-32: `aapp-issue-tracker` row, `events` column (Plugin Payload Standard), `state` column with `planned:` reservations (Q1), two-section `aapp plugins` output, reserved-prefix warning for unregistered `aapp-*` plugins.
* **2026-09-29:** §2.3 added: separation from the hooks registry.
* **2026-09-29:** Plan initialized from issue #94 (~60-80 lines; above the <10-line small-fix threshold).
