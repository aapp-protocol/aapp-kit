# 🗺️ Plan P-110: Docs Reference Renumber & Modular Adoption Links
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #172
* **Plan ID:** P-110
* **Changelog:** Changed: Reference documentation sequence renumbered and adoption links modernized
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
* **Status:** ⚡ In Development
* **Base:** `7213771` (develop)
* **Worktree:** .workspace/P110 (plan/P110-docs-reference-renumber)
* **Commits:** `1e1cdf2` (plan/P110-docs-reference-renumber), `968c3d8` (plan/P110-docs-reference-renumber)
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

During the execution of Plan P-57 (Modular Manual Specification), documentation was decomposed into `docs/concepts/` and `docs/reference/`. However, two integration gaps remained:

1. **Prefix Collisions in `docs/reference/`**:
   Multiple files in `docs/reference/` share identical numeric prefixes (`03-`, `04-`, `05-`, `06-`):
   - Two files prefixed `03-` (`03-agent-skills-and-slash-commands.md`, `03-configuration-matrix.md`)
   - Two files prefixed `04-` (`04-configuration-options.md`, `04-plugin-and-hook-engine.md`)
   - Two files prefixed `05-` (`05-ai-attribution-and-notes.md`, `05-planning-health-engine.md`)
   - Two files prefixed `06-` (`06-plugin-protocol.md`, `06-skills-and-slash-commands.md`)
   Each file contains valuable, distinct reference documentation (e.g., config options catalog vs tabular matrix, agent skills vs interactive slash command flows), but their non-unique prefixes create ambiguity in visual ordering and navigation.

2. **Monolithic Legacy Assumptions in Adoption Engine**:
   `lib/adoption.sh` and `tests/adoption_test.sh` were designed under Plan P-63 assuming a single monolithic `MANUAL.md`. They assert headings strictly against `MANUAL.md` and generate tasks in `.plans/adoption.md` with pointers formatted as `→ MANUAL: <heading>`, forcing `MANUAL.md` to host a synthetic lookup directory rather than pointing users directly to the authoritative modular files in `docs/`.

**Architectural Goal**:
1. Assign every reference document in `docs/reference/` a distinct, sequential number (01 through 19) preserving all content.
2. Update all internal cross-links and `MANUAL.md`'s Diátaxis reference index to reflect the clean sequence.
3. Modernize `lib/adoption.sh` rules catalogue so adoption tasks point directly to modular documentation targets (e.g. `→ docs/concepts/...` or `→ docs/reference/...`).
4. Update `tests/adoption_test.sh` to verify heading/target existence across `docs/` rather than requiring `MANUAL.md` proxies.
5. Verify 100% compliance with `tests/doc_links_test.sh` and full test suites.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All references across `MANUAL.md`, `README.md`, `CHEATSHEET.md`, and `docs/**/*.md` will be updated to the new canonical file paths.

### 2.1 Canonical Numbering Sequence for `docs/reference/` (01–19)

| New Slot | Canonical File Name | Topic / Scope | Former Name / Collision |
| :--- | :--- | :--- | :--- |
| **01** | `01-lifecycle-state-machine.md` | Plan statuses, state transitions, execution gates | *(unchanged)* |
| **02** | `02-cli-commands-and-verbs.md` | Complete reference for all 35 CLI verbs | *(unchanged)* |
| **03** | `03-configuration-matrix.md` | Tabular settings dictionary (`git config aapp.*`) | *(was 03)* |
| **04** | `04-configuration-options.md` | Configuration options, scopes, and resolution hierarchy | *(was 04)* |
| **05** | `05-configuration-hierarchy.md` | Precedence order, Git config inheritance, and CI env | *(was 15)* |
| **06** | `06-plugin-and-hook-engine.md` | Lifecycle hook triggers, `registry.tsv` contract | *(was 04)* |
| **07** | `07-action-plugin-protocol.md` | JSON envelope exchange contract for action plugins | *(was 06-plugin-protocol.md)* |
| **08** | `08-issue-tracker-protocol.md` | External issue tracker integration contract & sync | *(was 07-issue-protocol.md)* |
| **09** | `09-ai-attribution-and-notes.md` | Emailless semantic trailers, Git notes switchboard | *(was 05)* |
| **10** | `10-planning-health-engine.md` | 8-pair invariant integrity engine and `aapp doctor` | *(was 05/13)* |
| **11** | `11-agent-skills-reference.md` | Catalog of 13 Universal Skills, tool bindings, custom skills | *(was 03/14)* |
| **12** | `12-slash-commands-and-dispatch.md`| Interactive slash commands and chat dispatch flows | *(was 06)* |
| **13** | `13-output-json-schemas.md` | Programmatic JSON telemetry schemas for CLI consumers | *(was 08-output-json.md)* |
| **14** | `14-event-telemetry.md` | Append-only out-of-tree event audit logging contracts | *(was 09)* |
| **15** | `15-integration-and-rebase.md` | Integration mechanics, automated rebase, and cleanup | *(was 10)* |
| **16** | `16-document-governance.md` | Three-tier document governance model | *(was 11)* |
| **17** | `17-git-plumbing.md` | Detached orphan commits, remote sync, worktree repairs | *(was 12)* |

*(Note: Content from duplicates will be cleanly structured so no operational text or diagrams are lost).*

### 2.2 Modernizing Adoption Rules Catalogue (`lib/adoption.sh`)

Update `RULES` in `lib/adoption.sh` to associate each rule directly with its modular documentation file:
- Instead of generating `→ MANUAL: <heading>`, generate `→ docs/concepts/<file>#<anchor>` or `→ docs/reference/<file>#<anchor>`.
- Update `get_all_adoption_manual_headings()` and `test_manual_headings_exist()` in `tests/adoption_test.sh` to assert that every referenced heading exists in its declared target file in `docs/`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Sequential Renaming & Content Consolidation
- [ ] Task 1.1: Rename files in `docs/reference/` to the non-colliding 01–17 sequence using `git mv`.
- [ ] Task 1.2: Merge and verify that all unique content from colliding pairs (`03-`/`14-`, `04-`/`15-`, `05-`/`13-`, `06-`/`14-`) is fully preserved in their target files.
- [ ] Task 1.3: Update frontmatter `title:` and continuous navigation footers across all renamed files.

### Phase 2: Index & Cross-Link Synchronization
- [ ] Task 2.1: Update `MANUAL.md` Section 2 Diátaxis directory to list the unified 01–17 reference files.
- [ ] Task 2.2: Update cross-links across `docs/concepts/*.md`, `docs/recipes/**/*.md`, `README.md`, and `CHEATSHEET.md`.
- [ ] Task 2.3: Update `lib/cmd_install.sh` and `tests/install_test.sh` to package and verify the new reference file list.

### Phase 3: Adoption Engine Modernization
- [ ] Task 3.1: Update `lib/adoption.sh` rules catalogue to format task guidance with direct modular document links.
- [ ] Task 3.2: Update `tests/adoption_test.sh` to verify heading presence in the corresponding modular documentation files.
- [ ] Task 3.3: Prune the temporary Section 4 directory from `MANUAL.md` once adoption rules link directly to `docs/`.

### Phase 4: Verification & Gate Enforcement
- [ ] Task 4.1: Run `tests/doc_links_test.sh` and ensure 100% link resolution.
- [ ] Task 4.2: Run `bash tests/adoption_test.sh` and verify all adoption tests pass.
- [ ] Task 4.3: Execute `./aapp test strict quiet jobs 4` to confirm all 63 test suites are green.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `docs/reference/` -> Renamed and consolidated sequential reference files (01–17).
- [ ] `MANUAL.md` -> Updated Diátaxis directory links and pruned proxy directory.
- [ ] `lib/adoption.sh` -> Modernized adoption rules catalogue linking directly to modular docs.
- [ ] `tests/adoption_test.sh` -> Verification test updated to check headings in modular docs.
- [ ] `tests/doc_links_test.sh` -> Dead link test assertions updated for new paths.
- [ ] `tests/install_test.sh` -> Installation distribution assertions updated for new paths.
- [ ] `lib/cmd_install.sh` -> Packaging file list synchronized if applicable.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Core planning lifecycle engine remains untouched.
- [ ] `templates/blast-radius-guard.sh` -> Guard engine remains untouched.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook remains untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-19:** Blueprint drafted from Issue #172. Specified non-colliding sequential numbering (01–17) for `docs/reference/`, modernization of `lib/adoption.sh` links, and test assertions in `tests/adoption_test.sh`.
* **2026-10-19:** Plan initialized from `pickup.md`.
* **2026-10-19:** Refined blast radius and locked module boundaries.
