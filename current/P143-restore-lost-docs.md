# 🗺️ Plan P-143: Restore Lost Docs
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Target Issue / Milestone:** none
* **Plan ID:** P-143
* **Changelog:** Fixed: the user docs cover every verb form, every setting the kit reads and the sections lost when MANUAL.md was split; duplicate reference pages are merged and settings that do not exist removed
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `f6d03e1` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P143 (plan/P143-restore-lost-docs)
* **Commits:** `7449222` (plan/P143-restore-lost-docs), `e43ace5` (plan/P143-restore-lost-docs)
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log <sev> <type> "<symptom>" file <path>…`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
P-57 (`f737a91`) cut `MANUAL.md` from 2,312 lines to 92, and (`d0da4fa`) `README.md` from 474 lines to 76, moving their content into `docs/`; part of it never arrived. How to adopt the kit is left thin, and how to develop the kit itself is gone. P-57 also committed two drafts of three reference topics, and P-110 renamed the extra copies to 16–19 instead of merging them. Sessions since then edited whichever copy they found, so no settings page is complete and two pages list settings the kit never reads.

The commands and settings behave as documented before the split, so the lost text is still true and is restored now, before the Perl port; the port's docs plan (P-137) then starts from complete docs. Goal: every verb form, every setting and every topic of the old manual is documented once, in one place, and nothing documented is fictional.

Inventory of what is missing (method, counts, page by page): `.plans/pickup/docs-loss-inventory.md`. Old text: `git show f737a91^:MANUAL.md` and `git show d0da4fa^:README.md`.

---

## 2. Technical Blueprint

### 2.1 Merge the duplicates; reuse the freed numbers
| Page | Becomes |
|---|---|
| `13-planning-health-engine.md` + `17-planning-health-diagnostics.md` | 13 (17 freed) |
| `14-agent-skills-and-slash-commands.md` + `18-agent-skills-catalog.md` + `19-skills-and-slash-commands.md` | 14, with the skills that exist in `.agents/skills/` only (`/aapp-commit` goes) (18, 19 freed) |
| `03-configuration-matrix.md` + the key tables of `15` and `16` | 03, the one settings catalog (§2.2) |
| `15-configuration-hierarchy.md` | 15, the hierarchy only (`main.conf`, precedence, allowlist, origins) |
| `16-configuration-options.md` | removed (16 freed) |
| `20-group-amendments.md` | 16 |

The freed 17, 18, 19 take the restored pages of §2.3. A page that merges keeps every fact of each copy that is still true; nothing is dropped because it appears only in the copy being removed.

### 2.2 Settings: one file, grouped by role, true to the code
- `03-configuration-matrix.md` is the one file for settings: every `aapp.*` key the kit reads (`aapp`, `lib/`, `.githooks`, `templates/`, `scripts/`) is there and nowhere else is a key described in full. 15 keeps only how settings are resolved (`main.conf`, precedence, allowlist, origins) and links to 03 for the keys.
- Keys are grouped by role, one `##` header per group, so each group has a stable anchor. Starting grouping (the sweep may move a key; every key sits in exactly one group):
  - **Attribution & notes:** `aiAttribution`, `aiNotes`, `aiNotesGuard`, `aiCredits`, `aiAlias`, `aiAgent`, `aiVendor`, `aiModel`, `notesRemote`, `noteTTL`
  - **Commits & changelog:** `commitMode`, `changelogMode`, `subjectMaxLen`, `bodyMaxLen`, `maxBodyLines`, `commitLineMaxLen`, `changelogMaxLen`
  - **Plans & worktrees:** `planId`, `planBranch`, `planWorktrees`, `planWorktreePath`, `planSession`, `planState.*`, `devBranch`, `syncWorktrees`, `templateSync`, `docs.*`, `pickupTitleMax`
  - **Groups & amendments:** `amendmentApprovalRequired`
  - **Issues & fixes:** `issueId`, `issueFixWait`, `fixMaxFiles`, `fixMaxLines`, `fixCollision`, `maxEmergencyHotfixes`, `issueArchiveMax`, `issueCacheMax`, `issueSyncWindow`
  - **Integration, branches & sync:** `integrate`, `integrateTarget`, `integrateCleanup`, `integrateWait`, `autoRebase`, `protectedBranches`, `protectStable`, `pullStrategy`, `syncStrategy`, `remote`
  - **Write guard:** `allowPath`, `quarantineIgnored`
  - **Hooks, plugins & governance:** `hook.*`, `hookTimeout`, `pluginTimeout`, `allowLocalHooks`, `governance`, `governanceHandler`, `governanceTimeout`
  - **Offline:** `offlineEnabled`, `offlineOnly`, `offlineIdOffset`
  - **Status & output:** `statusItemsMax`, `statusOutputWidth`, `statusTextMax`, `jsonLocalPath`
  - **Release:** `tagPrefix`, `releaseBranch`, `initialVersion`
  - **Companion:** `companion.*`
  - **Tests & logging:** `testCommand`, `perlLogFile`
  - **Kit-internal (set by verbs, not by hand):** `internal.*` and any key the kit writes for itself
- Each key: type, default (read from the code, not from older docs), the verbs that read it, and **every possible value explained**: each value of an enum on its own line with what it does; for numbers the unit, the range and what `0` means; for paths and lists the form and an example. Families with a variable part (`companion.<name>.*`, `hook.*`, `planState.*`, `docs.*`) are one entry, with the part named.
- Every verb description that depends on a setting links to the setting's group in 03 (`03-configuration-matrix.md#<group-anchor>`): in 02, in the other reference pages, in the recipes and in `CHEATSHEET.md`. They name the key and link; they do not restate its values.
- Settings no code reads are removed from every page: `aapp.allowVendor`, `aapp.branchParity`, `aapp.changelogFile`, `aapp.copilotReview`, `aapp.lastRelease`, `aapp.logFile`, `aapp.notesScope`, `aapp.plansDir`, `aapp.preReleaseGate`, `aapp.releaseBundling`, `aapp.tagLedgerMax`, `aapp.worktreeRoot`.
- Keys missing today are added: `aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`, `aapp.releaseBranch`, `aapp.amendmentApprovalRequired`, and any other the sweep finds.
- Environment variables (`AAPP_*`) the kit reads: their own group in 03, with the same detail and the same check.

### 2.3 Restore the lost sections
Each subsection of the old MANUAL that has no equivalent is restored where it belongs, rewritten only where the behaviour changed since (checked against `lib/docs/verbs/*.md`):

| Old MANUAL subsection | Goes to |
|---|---|
| §5 Companion Development & Multi-Repository Co-Development | `17-companion-development.md` (new) |
| §8 Plan ID Allocation (`aapp.planId`) & the `aapp-planid` provider | `18-plan-id-allocation.md` (new) |
| §14 Platform Verification Status (matrix, how to verify, how to report) | `19-platform-verification.md` (new); always the last reference page, so it stays visible at the end of the map |
| §8 CLI Management Suite (`hooks`, `plugins`, `hook-test`, `hook-hash`); Transparent Command Fallthrough & Polyglot Plugins | `04-plugin-and-hook-engine.md` |
| §7 Linked Worktree Hook Architecture; Subprocess vs. Source Rationale; Multi-File Hook Architecture; Test Suite Harness & Sandbox Confinement | `docs/concepts/02-blast-radius-engine.md` (hook dispatch) and `docs/recipes/integrations/` (hook managers) |
| §12 Committing Plan Edits (`aapp refine`); One Changelog Entry per Plan (`aapp.changelogMode`) | `01-lifecycle-state-machine.md` |
| §5 Token Management & Context Efficiency | `14-agent-skills-and-slash-commands.md` |
| §11 Q: aligning several plans that touch the same code | `docs/guides/01-troubleshooting.md` |
| §15 Project Files & Protocol Upgrade; Project Rules; Template Synchronization & Drift; Test Gates; Monorepo & Build Tool Isolation | `docs/recipes/getting-started/adopt-existing-repo.md` |

| Old README §4 Inspection-Only Mode (cloned adopter repositories); First-Run Onboarding Loop | `docs/recipes/getting-started/adopt-existing-repo.md` |
| Old README §6 Seamless Adoption & In-Place Protocol Upgrades; Existing Hook Managers | `docs/recipes/getting-started/adopt-existing-repo.md`; hook managers in `docs/recipes/integrations/` |
| Old README §5 Branching Topologies (trunk, stable vs. edge) & Adaptive Branch Protection | `10-integration-and-rebase.md` |
| Old README §7 Remote Sync & Multi-Machine Workflow (sync, safety checks, restoring on a new machine or CI) | `12-git-plumbing.md` |
| Old MANUAL Local Developer Overrides & CI Confinement (`aapp.hook.*`, `aapp.allowLocalHooks`) | `04-plugin-and-hook-engine.md`; CI side in `docs/recipes/integrations/github-actions-ci.md` |
| Old README §4 Contributor / Development Setup; old MANUAL Q: develop or contribute locally; old README §12 Testing & Verification Suites | `CONTRIBUTING.md` (§2.6) |

An old subsection whose behaviour no longer exists is not restored; it is named in §6 with the plan or commit that removed it.

### 2.6 Adopting and developing: two entry points
- **Adopting** (a project that uses the kit): `README.md`'s Quick Start stays short and links to `docs/recipes/getting-started/adopt-existing-repo.md`, which walks the whole path: install, `aapp init` in an existing repository, cloning a repository that already uses AAPP (inspection-only until installed), the first session, existing hook managers, upgrading the protocol in place (`aapp upgrade`, template sync), and the pages to read next.
- **Developing the kit** (contributors): a new `CONTRIBUTING.md` at the repository root, where GitHub shows it, linked from `README.md`'s own section "Developing the Kit":
  - setting up: clone, `./aapp develop` (what it links, how to undo it), running from the clone;
  - testing: `./aapp test`, `t/test-run`, `prove -l t/`, what each runs;
  - how the kit is developed with its own protocol: plans in `.plans/`, groups, `aapp commit`, issues; links to the pages that explain them;
  - where the conventions are: `.agents/PROJECT.MD`, `.agents/CODEMAP.md`, `ARCHITECTURE.md`;
  - reporting a bug, and reporting a platform result (link to 19).

### 2.4 Commands: every form, explained
`02-cli-commands-and-verbs.md` covers every form of every verb in `lib/verbs.tsv` as `aapp help <verb>` prints it: what it does, in one or two lines, and a link to the page that explains it in depth. Forms not named today (`issue close … sha`, `plugins action`) are added; the old §5 "Command Reference (CLI Fast Commands)" text is the source for the explanations.

### 2.5 Links
`MANUAL.md`'s map lists the final 01–19 pages; every link in `docs/`, `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `COOKBOOK.md` and `lib/adoption.sh` points at an existing page; `tests/doc_links_test.sh` passes. `CHEATSHEET.md`'s settings and commands agree with 02 and 03.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Merge
- [ ] Task 1.1: Merge 13 + 17, and 14 + 18 + 19 (§2.1); drop `/aapp-commit`.
- [ ] Task 1.2: Settings: build 03 from the code sweep, grouped by role with every value explained (§2.2); cut 15 to the hierarchy; remove 16; remove the fictional keys everywhere.
- [ ] Task 1.4: Link every setting a verb description names to its group in 03 (§2.2), across 02, the reference pages, the recipes and `CHEATSHEET.md`.
- [ ] Task 1.3: Move `20-group-amendments.md` to 16.

### Phase 2: Restore
- [ ] Task 2.1: New pages 17 (companion development), 18 (plan id allocation), 19 (platform verification, last) from the old MANUAL (§2.3).
- [ ] Task 2.2: Restore the other subsections of §2.3 into their pages.
- [ ] Task 2.3: 02 covers every verb form (§2.4).
- [ ] Task 2.4: Adopting: the adopt recipe walks the whole path; README's Quick Start links it (§2.6).
- [ ] Task 2.5: Developing: `CONTRIBUTING.md`, and README's "Developing the Kit" section linking it (§2.6).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Sweep again (the inventory's method): every subsection of the old MANUAL and the old README is restored or named in §6 as removed behaviour; every key the code reads is in 03 and every key in the docs is read by the code; every token of every `aapp help <verb>` usage line is in 02.
- [ ] Task 3.2: Links (§2.5): `MANUAL.md` map, `README.md`, `CHEATSHEET.md`, `COOKBOOK.md`, `lib/adoption.sh`; `tests/doc_links_test.sh` and `./aapp test` pass.
- [ ] Task 3.3: `ARCHITECTURE.md` and `.agents/CODEMAP.md`: no change expected (docs only); confirm.
- [ ] Task 3.4: Verify the `CHANGELOG.md` entry.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `docs/reference/01-lifecycle-state-machine.md` -> plan edits, one changelog entry per plan
- [ ] `docs/reference/02-cli-commands-and-verbs.md` -> every verb form
- [ ] `docs/reference/03-configuration-matrix.md` -> the one settings catalog
- [ ] `docs/reference/04-plugin-and-hook-engine.md` -> hook and plugin commands, fallthrough
- [ ] `docs/reference/13-planning-health-engine.md` -> merged with 17
- [ ] `docs/reference/14-agent-skills-and-slash-commands.md` -> merged with 18 and 19; context efficiency
- [ ] `docs/reference/15-configuration-hierarchy.md` -> hierarchy only
- [ ] `docs/reference/16-configuration-options.md` -> removed
- [ ] `docs/reference/16-group-amendments.md` -> moved from 20
- [ ] `docs/reference/17-planning-health-diagnostics.md` -> removed
- [ ] `NEW FILE` -> `docs/reference/17-companion-development.md` -> restored companion section
- [ ] `docs/reference/18-agent-skills-catalog.md` -> removed
- [ ] `NEW FILE` -> `docs/reference/18-plan-id-allocation.md` -> restored plan id section
- [ ] `docs/reference/19-skills-and-slash-commands.md` -> removed
- [ ] `NEW FILE` -> `docs/reference/19-platform-verification.md` -> restored old §14, the last page
- [ ] `docs/reference/20-group-amendments.md` -> moved to 16
- [ ] `docs/reference/05-ai-attribution-and-notes.md` -> settings link to 03
- [ ] `docs/reference/06-plugin-protocol.md` -> links
- [ ] `docs/reference/07-issue-protocol.md` -> links
- [ ] `docs/reference/08-output-json.md` -> links
- [ ] `docs/reference/09-event-telemetry.md` -> links
- [ ] `docs/reference/10-integration-and-rebase.md` -> branching topologies, adaptive branch protection
- [ ] `docs/reference/11-document-governance.md` -> links
- [ ] `docs/reference/12-git-plumbing.md` -> remote sync, multi-machine, restoring on a new machine
- [ ] `docs/concepts/01-worktree-architecture.md` -> links
- [ ] `docs/concepts/02-blast-radius-engine.md` -> hook dispatch in linked worktrees
- [ ] `docs/concepts/03-two-lane-governance.md` -> links
- [ ] `docs/concepts/04-security-and-threat-model.md` -> links
- [ ] `docs/guides/01-troubleshooting.md` -> aligning plans on the same code
- [ ] `docs/recipes/getting-started/adopt-existing-repo.md` -> restored adoption topics
- [ ] `docs/recipes/getting-started/solo-developer-workflow.md` -> links
- [ ] `docs/recipes/integrations/husky-git-hooks.md` -> hook manager chaining
- [ ] `docs/recipes/integrations/lefthook-git-hooks.md` -> hook manager chaining
- [ ] `docs/recipes/integrations/github-actions-ci.md` -> CI confinement (`aapp.allowLocalHooks`), restoring in CI
- [ ] `docs/recipes/workflows/planning-a-plan-group.md` -> link to 16
- [ ] `docs/recipes/workflows/emergency-hotfixes.md` -> setting links to 03
- [ ] `docs/recipes/workflows/multi-agent-worktrees.md` -> setting links to 03
- [ ] `docs/recipes/workflows/tdd-failure-assertions.md` -> setting links to 03
- [ ] `docs/recipes/plugins-and-hooks/01-deploy-on-done-hook.md` -> setting links to 03
- [ ] `docs/recipes/plugins-and-hooks/02-custom-pre-gate-hooks.md` -> setting links to 03
- [ ] `docs/recipes/plugins-and-hooks/03-github-issues-tracker-plugin.md` -> setting links to 03
- [ ] `docs/recipes/plugins-and-hooks/04-authoring-custom-action-plugins.md` -> setting links to 03
- [ ] `docs/recipes/troubleshooting/blast-radius-recovery.md` -> setting links to 03
- [ ] `docs/recipes/troubleshooting/worktree-collision-recovery.md` -> setting links to 03
- [ ] `MANUAL.md` -> map 01–19
- [ ] `README.md` -> Quick Start links the adopt recipe; "Developing the Kit" section; links
- [ ] `NEW FILE` -> `CONTRIBUTING.md` -> developing the kit (§2.6)
- [ ] `CHEATSHEET.md` -> agrees with 02 and 03
- [ ] `COOKBOOK.md` -> links
- [ ] `lib/adoption.sh` -> doc links of the adoption rules
- [ ] `tests/doc_links_test.sh` -> page list
- [ ] `CHANGELOG.md` -> the plan's entry

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/docs/` -> verb and core contracts are the source, not a target
- [ ] `lib/AAPP/` -> no code changes; a wrong default in the code is an issue, not a doc fix

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1:** Should a test keep the docs complete from now on? **Answer:** not in this plan; a check comes after the Perl port. Until then the sweep of Task 3.1 is the check.

---

## 📦 6. Change Log & Refinement History
* **2026-10-27:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-27:** Drafted from the docs loss inventory; numbering, settings rule and restore map settled in chat.
