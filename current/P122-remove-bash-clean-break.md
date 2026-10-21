# 🗺️ Plan P-122: Remove Bash Clean Break
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
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
1. Converts `./aapp` into a pure `#!/usr/bin/env perl` dispatcher (~80 lines) with zero bash sourcing, preserving the `AAPP_PLUGIN_STEP` re-entrancy guard and `.agents/skills/$CMD` action-plugin fallthrough.
2. Deletes all **30** legacy `lib/*.sh` files (`git rm lib/*.sh`) and the `templates/aapp-lib.sh` symlink.
3. Updates user documentation (`README.md`, `MANUAL.md`) to state the Perl 5.26+ runtime requirement, while leaving `ARCHITECTURE.md` and `.agents/CODEMAP.md` to the group plan `P-111`'s `## Architecture & Codemap` section applied on group `done`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** `./aapp`, the 30 `lib/*.sh` files, `templates/aapp-lib.sh`, and user-facing docs (`README.md`, `MANUAL.md`). `tests/AAPP/*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 Pure-Perl `./aapp` Entry Point (`aapp`)
Replaces the transitional hybrid dispatcher in `./aapp` with the final `#!/usr/bin/env perl` entry point (`use v5.26; use strict; use warnings;`):
- Resolves its own symlink/real path via `Cwd::abs_path(__FILE__)` and `File::Basename::dirname` to locate `<kit-root>/lib` (`use lib ...`) and `$ENV{AAPP_DIR}` / `$AAPP_VERSION`. Where the installed kit is comes from `AAPP::Paths::kit_dir()` (the one answer, OS-aware); the bash dispatcher's own lookup (`$XDG_DATA_HOME/aapp-kit`, `$HOME/.local/share/aapp-kit`) is not carried over as a copy (decided 2026-10-21 in P-115).
- Dispatches all built-in CLI verbs (`status`, `matrix`, `plan-status`, `help`, `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `plan`, `issue`, `offline`, `commit`, `note`, `ai`, `init`, `install`, `upgrade`, `uninstall`, `develop`, `push`, `pull`, `sync`, `release`, `companion`, `hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, `hook-hash`, `pause`, `resume`, `unpause`, `test`) directly to `AAPP::Cmd::*`.
- Preserves the action-plugin fallthrough (`aapp` lines 225–245): when an unknown `$verb` matches `^[a-z0-9][a-z0-9_-]*$` and `.agents/skills/$verb` exists in the target repository (and `$ENV{AAPP_PLUGIN_STEP}` is not set), sets `$ENV{AAPP_PLUGIN_STEP} = 1` and dispatches via `AAPP::HookDispatcher::plugin_run($verb, @ARGV)`.

### 2.2 Deletion of All 30 Legacy `lib/*.sh` Files and `templates/aapp-lib.sh`
Removes every bash library file from `lib/` and `templates/` via `git rm` with zero code naming or migrating the former `.sh` files (any leftover copies in local `.githooks/` checkouts are removed once by hand):
- Core & shared libraries (9 files): `lib/aapp-lib.sh`, `lib/output.sh`, `lib/plan_states.sh`, `lib/plan_resolver.sh`, `lib/planning_health.sh`, `lib/commit_engine.sh`, `lib/hook_dispatcher.sh`, `lib/attribution.sh`, `lib/group_docs.sh`
- Adoption & verb modules (21 files): `lib/adoption.sh`, `lib/cmd_ai.sh`, `lib/cmd_commit.sh`, `lib/cmd_companion.sh`, `lib/cmd_develop.sh`, `lib/cmd_help.sh`, `lib/cmd_hook.sh`, `lib/cmd_init.sh`, `lib/cmd_install.sh`, `lib/cmd_issue.sh`, `lib/cmd_matrix.sh`, `lib/cmd_note.sh`, `lib/cmd_offline.sh`, `lib/cmd_pause.sh`, `lib/cmd_plan.sh`, `lib/cmd_release.sh`, `lib/cmd_status.sh`, `lib/cmd_sync.sh`, `lib/cmd_test.sh`, `lib/cmd_uninstall.sh`, `lib/cmd_upgrade.sh`
- Symlink (1 file): `templates/aapp-lib.sh`

### 2.3 User Documentation Sync (`README.md`, `MANUAL.md`)
- Updates system requirements in `README.md` and `MANUAL.md` to state that AAPP requires `git` and `perl` (`>= 5.26`, core modules only).
- Note: `ARCHITECTURE.md` and `.agents/CODEMAP.md` are updated by the group plan `P-111` (`## Architecture & Codemap`) when `aapp done P-111` runs.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pure-Perl `./aapp` & Legacy Bash Removal
- [ ] Task 1.1: Convert `./aapp` to a pure `#!/usr/bin/env perl` script dispatching all built-in verbs to `AAPP::Cmd::*` and preserving the `.agents/skills/$CMD` action-plugin fallthrough.
- [ ] Task 1.2: Delete all 30 `lib/*.sh` files and `templates/aapp-lib.sh` via `git rm`.
- [ ] Task 1.3: Rename the Perl logger's key `aapp.perlLogFile` to `aapp.logFile` (`LOG_KEY` in `lib/AAPP/Constants.pm`, P-127 §5): the kit logs per event, with the event logger's meaning.

### Phase 2: Documentation Sync
- [ ] Task 2.1: Update `README.md` and `MANUAL.md` where runtime dependencies (`perl >= 5.26`) are documented.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run the complete `./aapp test` suite and verify 100% pass rate with zero `lib/*.sh` files present.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c aapp` and `perl -c` across all `lib/AAPP/**/*.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `aapp` -> Final pure-Perl CLI entry point (`#!/usr/bin/env perl`) with action-plugin fallthrough and zero bash sourcing.
- [ ] `templates/aapp-lib.sh` -> Delete legacy symlink to `lib/aapp-lib.sh`.
- [ ] `lib/AAPP/Constants.pm` -> `LOG_KEY` becomes `aapp.logFile`.
- [ ] `lib/aapp-lib.sh` -> Delete legacy bash core library.
- [ ] `lib/adoption.sh` -> Delete legacy bash adoption module.
- [ ] `lib/attribution.sh` -> Delete legacy bash attribution module.
- [ ] `lib/cmd_ai.sh` -> Delete legacy bash `ai` verb module.
- [ ] `lib/cmd_commit.sh` -> Delete legacy bash `commit` verb module.
- [ ] `lib/cmd_companion.sh` -> Delete legacy bash `companion` verb module.
- [ ] `lib/cmd_develop.sh` -> Delete legacy bash `develop` verb module.
- [ ] `lib/cmd_help.sh` -> Delete legacy bash `help` verb module.
- [ ] `lib/cmd_hook.sh` -> Delete legacy bash `hook` verb module.
- [ ] `lib/cmd_init.sh` -> Delete legacy bash `init` verb module.
- [ ] `lib/cmd_install.sh` -> Delete legacy bash `install` verb module.
- [ ] `lib/cmd_issue.sh` -> Delete legacy bash `issue` verb module.
- [ ] `lib/cmd_matrix.sh` -> Delete legacy bash `matrix` verb module.
- [ ] `lib/cmd_note.sh` -> Delete legacy bash `note` verb module.
- [ ] `lib/cmd_offline.sh` -> Delete legacy bash `offline` verb module.
- [ ] `lib/cmd_pause.sh` -> Delete legacy bash `pause` verb module.
- [ ] `lib/cmd_plan.sh` -> Delete legacy bash `plan` verb module.
- [ ] `lib/cmd_release.sh` -> Delete legacy bash `release` verb module.
- [ ] `lib/cmd_status.sh` -> Delete legacy bash `status` verb module.
- [ ] `lib/cmd_sync.sh` -> Delete legacy bash `sync` verb module.
- [ ] `lib/cmd_test.sh` -> Delete legacy bash `test` verb module.
- [ ] `lib/cmd_uninstall.sh` -> Delete legacy bash `uninstall` verb module.
- [ ] `lib/cmd_upgrade.sh` -> Delete legacy bash `upgrade` verb module.
- [ ] `lib/commit_engine.sh` -> Delete legacy bash commit engine module.
- [ ] `lib/group_docs.sh` -> Delete legacy bash group docs module.
- [ ] `lib/hook_dispatcher.sh` -> Delete legacy bash hook dispatcher module.
- [ ] `lib/output.sh` -> Delete legacy bash output module.
- [ ] `lib/plan_resolver.sh` -> Delete legacy bash plan resolver module.
- [ ] `lib/plan_states.sh` -> Delete legacy bash plan states module.
- [ ] `lib/planning_health.sh` -> Delete legacy bash planning health module.
- [ ] `README.md` -> Update runtime requirements (`perl >= 5.26`, core modules only).
- [ ] `MANUAL.md` -> Update runtime requirements and hook architecture notes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/AAPP/Tests.pm` -> Test harness and all `tests/AAPP/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to list all 30 real `lib/*.sh` files, `templates/aapp-lib.sh`, and action-plugin fallthrough in `aapp`.

