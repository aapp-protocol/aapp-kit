# 🗺️ Plan P-25: Delimited Template Sync & Tiered Document Governance
* **Created:** 2026-09-21 | **Last Refined:** 2026-09-21
* **Target Issue / Milestone:** #73 *(supersedes #73 upon completion)*
* **Plan ID:** P-25
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement
In `lib/cmd_init.sh`, the file copying engine relies on `copy_guarded()`, which unconditionally returns early if the destination file exists (`if [ -f "$dest" ]; then return 0; fi`). Consequently, running `aapp init` or `aapp upgrade` never refreshes existing template-derived files in active worktrees.

When protocol invariants, status enums, or planning schemas evolve in the upstream kit (e.g. adopting the `🟣 Under Review`, `📝 Refining`, `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED` enum, or introducing Plan ID headers), existing clones retain stale templates (such as `.plans/plan-template.md`). Scaffolding new plans from these stale templates results in invalid plans that fail commit validation.

Conversely, naively overwriting files would destroy bespoke project particulars (e.g. project-specific checklists, custom rules, architectural designs, and active issue rows).

### Architectural Goal
Replace monolithic `copy_guarded` with a **Three-Tier Document Governance Model**:
1. **Tier 1 (Pure Engine Templates)**: Scaffold assets (`plan-template.md`, `release_checklist.md`, `000-archive-ledger.md`) kept synchronized with canonical protocol invariants.
2. **Tier 2 (Hybrid Documents)**: Protocol blocks synchronized within strict HTML delimiter boundaries (`<!-- AAPP-*:START -->` ... `<!-- AAPP-*:END -->`), preserving surrounding project-specific prose.
3. **Tier 3 (Pure Project Data)**: Live ledgers (`ISSUES.md`, `state_matrix.md`, `CODEMAP.md`, `ARCHITECTURE.md`) initialized once, never overwritten by template sync.

Provide a configurable Git switchboard (`aapp.templateSync = safe | strict | manual`), an explicit CLI sync verb (`aapp sync-templates`), and template drift detection integrated into `aapp status`.

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Existing unmanaged files lacking delimiter markers are upgraded non-destructively: if no markers are found in hybrid files, standard protocol blocks are appended with clear boundary comments (consistent with `tests/install_test.sh` Test 7 adoption behavior).

### 2.1 Three-Tier Classification Matrix

| Tier | Classification | Files | Synchronization Strategy |
| :--- | :--- | :--- | :--- |
| **Tier 1** | Pure Reusable Template | `.plans/plan-template.md`<br>`.plans/release/release_checklist.md`<br>`.plans/done/000-archive-ledger.md` | Standard protocol sync. If file matches known upstream release hash or is unmodified, update cleanly. If modified, update delimited invariants block or produce `.new` diff for review. |
| **Tier 2** | Hybrid Governance Document | `.agents/AGENTS.md`<br>`.plans/pickup.md` | Delimited Block Sync (`<!-- AAPP-PROTOCOL:START -->`). Core protocol block upgraded in-place; all surrounding custom rules/tasks preserved. |
| **Tier 3** | Pure Project Domain Data | `.plans/ISSUES.md`<br>`.plans/state_matrix.md`<br>`.plans/issues_road_map.md`<br>`.agents/CODEMAP.md`<br>`ARCHITECTURE.md` | Seeded on initial install only (`copy_guarded`). Never overwritten during template sync. |

### 2.2 Delimiter Protocol & Marker Standard
Hybrid and template files adopt standard HTML delimiter comments:

```markdown
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - MANAGED BY AAPP. CUSTOMIZATIONS GO OUTSIDE. -->
... standard protocol text ...
<!-- AAPP-PROTOCOL:END -->
```

The synchronizer:
1. Validates that both `START` and `END` tags exist.
2. Replaces lines strictly between the markers with updated template contents.
3. Errors out safely without writing if an unclosed `START` or `END` tag is detected.

### 2.3 Git Configuration Switchboard (`aapp.templateSync`)

Configurable via `git config aapp.templateSync <mode>`:

- **`safe` (Default)**: Automatically synchronizes Tier 1 templates and Tier 2 delimited blocks when canonical templates change. Never modifies Tier 3 files.
- **`strict`**: Enforces strict conformance. Replaces Tier 1 templates and Tier 2 blocks; warns if user modifications conflict with core invariants.
- **`manual`**: Preserves existing files untouched; reports drift advisory in `aapp status`.

### 2.4 CLI Interface & Status Integration
- `aapp sync-templates`: Explicit CLI command to audit and synchronize all template-derived files across active worktrees.
- `aapp status`: Reports a "Templates" health indicator in the context recovery briefing:
  ```text
  📑 Templates:  All worktree templates synced (v1.0.0)
  ```
  Or, if drift is detected:
  ```text
  📑 Templates:  1 template drifted (.plans/plan-template.md carries retired enum) -> run 'aapp sync-templates'
  ```

---

## 🔨 3. Implementation Steps & Execution Checklist

- [ ] **Phase 1: Marker Standardization in Templates**
  - [ ] Standardize `templates/plan-template.md` with delimited invariants block (`<!-- AAPP-INVARIANTS:START -->`).
  - [ ] Standardize `templates/release_checklist.md` with delimited protocol markers.
  - [ ] Ensure `templates/AGENTS.md` and `templates/plan-template.md` use uniform version stamps.

- [ ] **Phase 2: Template Sync Engine (`lib/cmd_sync_templates.sh`)**
  - [ ] Implement `sync_tier1_template(src, dest, mode)`.
  - [ ] Implement `sync_tier2_hybrid(src, dest, marker_prefix)`.
  - [ ] Add SHA256 checksum comparison to skip identical files.
  - [ ] Implement `aapp.templateSync` configuration resolution (`safe` default).

- [ ] **Phase 3: CLI Wiring & Init Integration**
  - [ ] Wire `sync-templates` into `aapp` router and `lib/cmd_help.sh`.
  - [ ] Refactor `lib/cmd_init.sh` to use the tiered sync engine instead of raw `copy_guarded`.
  - [ ] Update `lib/cmd_upgrade.sh` to invoke `sync-templates` after pulling kit updates.

- [ ] **Phase 4: Status Briefing Integration**
  - [ ] Add template drift probe in `lib/cmd_status.sh`.
  - [ ] Surface concise 1-line advisory when templates carry stale status enums or missing fields.

- [ ] **Phase 5: Automated Regression Test Suite**
  - [ ] Create `tests/template_sync_test.sh` covering:
    - Tier 1 clean upgrade and checksum drift.
    - Tier 2 delimited block in-place update preserving external user prose.
    - Tier 3 project data isolation (never overwritten).
    - Unclosed delimiter safety abort (no file corruption).
    - Git config mode switches (`safe`, `strict`, `manual`).

---

## 🛡️ 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_sync_templates.sh` -> New template sync engine module
- [ ] `lib/cmd_init.sh` -> Refactor template provisioning to tiered sync
- [ ] `lib/cmd_upgrade.sh` -> Trigger template sync on upgrade
- [ ] `lib/cmd_status.sh` -> Integrate template drift health check
- [ ] `lib/cmd_help.sh` -> Register sync-templates command
- [ ] `aapp` -> Wire sync-templates CLI command
- [ ] `templates/plan-template.md` -> Add delimited invariants block
- [ ] `templates/release_checklist.md` -> Add delimited invariants block
- [ ] `tests/template_sync_test.sh` -> Automated regression test suite
- [ ] `MANUAL.md` -> Document template sync and configuration
- [ ] `ARCHITECTURE.md` -> Update architecture map with tiered template governance

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard engine self-protection
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Target data ledger (modified only via issue lifecycle)
- [ ] `.plans/state_matrix.md` -> Modified only via state transitions

---

## ❓ 5. Open Questions

1. **Conflict Resolution on Modified Tier 1 Templates**: When a user heavily customizes `.plans/plan-template.md` (without delimiters) and AAPP upgrades:
   - *Option A*: Create `.plans/plan-template.md.new` and print an advisory (similar to `.pacnew` / rpmnew).
   - *Option B*: Overwrite the invariant header only using fuzzy header anchoring.
   - *Recommendation*: Option A in `safe` mode, Option B if delimiter markers are present.
2. **Sync Scope during `aapp init`**: Should `aapp init` always run `sync-templates` automatically in `safe` mode, or only when explicitly requested?
   - *Recommendation*: Automatically in `safe` mode so developers don't have to remember a separate command.
3. **Template Version Stamping**: Should each template file carry an internal schema version (`v1.0.0`) in its marker tag?
   - *Recommendation*: Yes, matching `<!-- AAPP-PROTOCOL:START vX.Y.Z -->` in `AGENTS.md`.

---

## 📦 6. Change Log & Refinement History

* **2026-09-21:** Drafted initial canonical blueprint P-25 from issue #73 analysis. Established 3-tier document governance model, HTML delimiter standard, and git config switchboard.
