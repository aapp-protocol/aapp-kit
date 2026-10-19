# 🗺️ Plan P-122: Remove Bash Clean Break
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-122
* **Changelog:** Changed: Complete the Perl port clean break by converting `./aapp` to a pure `#!/usr/bin/env perl` entry point and deleting all 23 legacy `lib/*.sh` bash modules.
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
Plan `P-122` is the tenth and final member of group `P-111` (*Perl Port Of The Kit*). Once `P-115` through `P-121` have ported every core module, hook, and CLI verb into `lib/AAPP/`, `P-122` executes the clean-break cutover:
1. Converts `./aapp` into a pure `#!/usr/bin/env perl` dispatcher (~60 lines) with zero bash sourcing.
2. Deletes all 23 legacy `lib/*.sh` files (`git rm lib/*.sh`).
3. Verifies that zero `python3` calls and zero `lib/*.sh` references remain anywhere in the kit runtime, hooks, or user documentation (`README.md`, `MANUAL.md`, `docs/`), while leaving `ARCHITECTURE.md` and `.agents/CODEMAP.md` to the group plan `P-111`'s `## Architecture & Codemap` section applied on group `done`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** `./aapp`, `lib/*.sh`, and user-facing docs (`README.md`, `MANUAL.md`, `docs/`). `lib/AAPP/Tests*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 Pure-Perl `./aapp` Entry Point (`aapp`)
Replaces the transitional hybrid dispatcher in `./aapp` with the final `#!/usr/bin/env perl` entry point (`use 5.026; use strict; use warnings; use utf8;`):
- Resolves its own symlink/real path via `Cwd::abs_path(__FILE__)` and `File::Basename::dirname` to locate `<kit-root>/lib` (`use lib ...`) and `$ENV{AAPP_KIT_ROOT}`.
- Parses global options (`-C <dir>`, `--json`, `-h`/`--help`, `-v`/`--version`) and dispatches the verb to the corresponding `AAPP::Cmd::<Verb>::run(@ARGV)` module via a static dispatch table.
- Exits with the exact integer return code from `run(...)`.

### 2.2 Deletion of All 23 Legacy `lib/*.sh` Files
Removes every bash library file from `lib/` via `git rm`:
- Core & shared helpers: `lib/common.sh`, `lib/rules.sh`, `lib/health.sh`, `lib/integrate.sh`, `lib/help.sh`
- Verb modules: `lib/cmd_ai.sh`, `lib/cmd_commit.sh`, `lib/cmd_companion.sh`, `lib/cmd_done.sh`, `lib/cmd_draft.sh`, `lib/cmd_freeze.sh`, `lib/cmd_hook.sh`, `lib/cmd_init.sh`, `lib/cmd_issue.sh`, `lib/cmd_note.sh`, `lib/cmd_offline.sh`, `lib/cmd_pause.sh`, `lib/cmd_refine.sh`, `lib/cmd_release.sh`, `lib/cmd_start.sh`, `lib/cmd_status.sh`, `lib/cmd_tdd.sh`, `lib/cmd_test.sh`

### 2.3 User Documentation Sync (`README.md`, `MANUAL.md`, `docs/`)
- Updates system requirements in `README.md`, `MANUAL.md`, and `docs/` to state that AAPP requires `git` and `perl` (`>= 5.26`, core modules only) and no longer requires `python3`, `bash 4+`, or external JSON/SHA utilities.
- Note: `ARCHITECTURE.md` and `.agents/CODEMAP.md` are updated by the group plan `P-111` (`## Architecture & Codemap`) when `aapp done P-111` runs.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pure-Perl `./aapp` & Legacy Bash Removal
- [ ] Task 1.1: Convert `./aapp` to a pure `#!/usr/bin/env perl` script dispatching directly to `AAPP::Cmd::*`.
- [ ] Task 1.2: Delete all 23 `lib/*.sh` files via `git rm`.

### Phase 2: Documentation & Self-Hosted Hook Refresh
- [ ] Task 2.1: Run `./aapp init` (or `./aapp sync`) to ensure `.githooks/AAPP/` in the self-hosted repository is completely up to date with `lib/AAPP/`.
- [ ] Task 2.2: Update `README.md`, `MANUAL.md`, and `docs/` where runtime dependencies (`perl >= 5.26`, removal of `python3`) are documented.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run the complete `./aapp test` suite (`verb` + `core`) and `./aapp test --check-docs` and verify 100% pass rate with zero `lib/*.sh` files present.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c aapp` and `perl -c` across all `lib/AAPP/**/*.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `aapp` -> Final pure-Perl CLI entry point (`#!/usr/bin/env perl`) with zero bash sourcing.
- [ ] `lib/common.sh` -> Delete legacy bash core module.
- [ ] `lib/rules.sh` -> Delete legacy bash rules module.
- [ ] `lib/health.sh` -> Delete legacy bash health module.
- [ ] `lib/integrate.sh` -> Delete legacy bash integration module.
- [ ] `lib/help.sh` -> Delete legacy bash help module.
- [ ] `lib/cmd_ai.sh` -> Delete legacy bash `ai` verb module.
- [ ] `lib/cmd_commit.sh` -> Delete legacy bash `commit` verb module.
- [ ] `lib/cmd_companion.sh` -> Delete legacy bash `companion` verb module.
- [ ] `lib/cmd_done.sh` -> Delete legacy bash `done` verb module.
- [ ] `lib/cmd_draft.sh` -> Delete legacy bash `draft` verb module.
- [ ] `lib/cmd_freeze.sh` -> Delete legacy bash `freeze` verb module.
- [ ] `lib/cmd_hook.sh` -> Delete legacy bash `hook` verb module.
- [ ] `lib/cmd_init.sh` -> Delete legacy bash `init` verb module.
- [ ] `lib/cmd_issue.sh` -> Delete legacy bash `issue` verb module.
- [ ] `lib/cmd_note.sh` -> Delete legacy bash `note` verb module.
- [ ] `lib/cmd_offline.sh` -> Delete legacy bash `offline` verb module.
- [ ] `lib/cmd_pause.sh` -> Delete legacy bash `pause` verb module.
- [ ] `lib/cmd_refine.sh` -> Delete legacy bash `refine` verb module.
- [ ] `lib/cmd_release.sh` -> Delete legacy bash `release` verb module.
- [ ] `lib/cmd_start.sh` -> Delete legacy bash `start` verb module.
- [ ] `lib/cmd_status.sh` -> Delete legacy bash `status` verb module.
- [ ] `lib/cmd_tdd.sh` -> Delete legacy bash `tdd` verb module.
- [ ] `lib/cmd_test.sh` -> Delete legacy bash `test` verb module.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness and all `lib/AAPP/Tests/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Authored technical blueprint and locked blast radius for `P-122`.

