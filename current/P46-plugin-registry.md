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
# name	role	actions	counter	sample
aapp-planid	Team Plan ID Authority	allocate	aapp.planId	examples/plugins/aapp-planid/run.sample
hello-tool	Custom CLI Showcase	-	-	examples/plugins/hello-tool/run.sample
```

- `actions`: comma-separated `AAPP_ACTION` values the kit calls (`-` = CLI-invoked).
- `counter`: git config key shown as the local fallback when the plugin is absent (`-` = none).
- Shipped by `aapp install` already (it copies all of `lib/`); resolved like `verbs.tsv` (`$AAPP_LIB`, then script dir, then installed share dir).

### 2.2 `cmd_plugins_status()` (`lib/cmd_hook.sh`)

- Replace the per-plugin blocks with one loop over `plugins.tsv` rows, keeping today's four states (ACTIVE / CONFIGURED BUT NOT EXECUTABLE / SAMPLE AVAILABLE / NOT INSTALLED) and the fallback-counter line when `counter` is set.
- Build the custom-plugin skip list from the registry names (plus the existing `aapp-*|aapp|plan|*.sample|node_modules|vendor` patterns).
- Missing or unreadable `plugins.tsv` → exit 1 with a clear diagnostic (fail closed).
- Output stays identical for the current two plugins.

### 2.3 Not the hooks registry

`.agents/skills/aapp-hooks/registry.tsv` is adopter-owned (seeded from `templates/skills/`, SHA-locked handlers per event, guard self-protected). `lib/plugins.tsv` is kit-owned and changes only with kit releases. Do not merge them: a kit catalog inside adopter copies would go stale every release (the #73 / P-25 problem). Reuse only its conventions: comment-header schema, tab-separated columns, and the row-parsing approach in `lib/cmd_hook.sh:55`.

### 2.4 Out of scope

- `lib/plan_resolver.sh` keeps its literal `aapp-planid`: the allocator passes a constant, and a file lookup would only add a failure path. A registry test (§3) guarantees the literal has a row.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Registry
- [ ] Task 1.1: Add `lib/plugins.tsv` with rows for `aapp-planid` and `hello-tool`.

### Phase 2: Status Rendering
- [ ] Task 2.1: Rewrite `cmd_plugins_status()` standard-points section as a loop over the registry; fail closed when it is missing.
- [ ] Task 2.2: Derive the custom-plugin skip list from registry names.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `tests/hooks_test.sh`: `aapp plugins` output unchanged; every `examples/plugins/*` directory has a registry row; every literal plugin name in `lib/*.sh` has a row.
- [ ] Task 3.2: CODEMAP §5 and `ARCHITECTURE.md` point to `lib/plugins.tsv` as the source of truth.
- [ ] Task 3.3: `CHANGELOG.md` under `## [Unreleased]`; run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/plugins.tsv` -> Shipped plugin registry.
- [ ] `lib/cmd_hook.sh` -> Render standard extension points from the registry.
- [ ] `tests/hooks_test.sh` -> Registry consistency and unchanged output.
- [ ] `.agents/CODEMAP.md` -> §5 points to the registry.
- [ ] `ARCHITECTURE.md` -> Name the registry as source of truth.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Allocator keeps its literal plugin name.
- [ ] `examples/plugins/` -> Samples unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Register P-15's `aapp-review` now or when P-15 ships?** Registering now documents the reserved name early; waiting keeps the registry to plugins that exist.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-29:** §2.3 added: separation from the hooks registry.
* **2026-09-29:** Plan initialized from issue #94 (~60-80 lines; above the <10-line small-fix threshold).
