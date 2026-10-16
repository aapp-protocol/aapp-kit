# 🗺️ Plan P-95: Plugin Runtime And Dx Fixes
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** #156
* **Also Closes:** #157, #158
* **Plan ID:** P-95
* **Changelog:** Fixed: Action plugin help fallthrough, dispatcher AAPP_REPO_ROOT export, and sample plugin queue handling
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `ca752a1` (develop)
* **Worktree:** .workspace/P95 (plan/P95-plugin-runtime-and-dx-fixes)
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
During the action plugin and issue-tracker lifecycle audit, three closely related gaps were identified in plugin runtime ergonomics, discovery, and sample handling:
1. **Issue #156 (`lib/cmd_help.sh`)**: Running `aapp help <custom-tool>` or `aapp <custom-tool> help` currently fails with `❌ Unknown command: '<custom-tool>'` for valid action plugins installed in `.agents/skills/<custom-tool>/`. The `cmd_help.sh` dispatch loop strictly queries `lib/verbs.tsv` and has no fallthrough to check project skills.
2. **Issue #157 (`aapp` entrypoint)**: Primary dispatcher `aapp` resolves `REPO_ROOT` for non-exempt commands, but does not export `AAPP_REPO_ROOT` before executing discovered action plugins (`exec "$CANDIDATE" "$@"`). Custom plugins must redundantly invoke `git rev-parse --show-toplevel`.
3. **Issue #158 (`examples/plugins/aapp-issue-tracker/run.sample`)**: The reference sample issue tracker plugin documents `issue.queue` and `issue.unqueue` in comments, but lacks explicit branches in its `case` statement, allowing them to fall into the unhandled wildcard (`*) echo '{"status": "ok"}'`).

This plan resolves all three issues together, ensuring seamless developer experience (DX) and robust runtime contracts for both action plugins and lifecycle provider plugins.

---

## 2. Technical Blueprint

### A. Action Plugin Help Fallthrough (`lib/cmd_help.sh` and `aapp`)
1. In `lib/cmd_help.sh`:
   - If `$HELP_VERB` is not matched in `lib/verbs.tsv`, before outputting `❌ Unknown command`:
   - Determine `REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"`.
   - If `[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.agents/skills/$HELP_VERB" ]`:
     - Resolve candidate entrypoint via `resolve_plugin_entrypoint "$REPO_ROOT/.agents/skills/$HELP_VERB" "$HELP_VERB"`.
     - If candidate exists and is executable:
       - If `"$HELP_FULL"` = "full" and `"$REPO_ROOT/.agents/skills/$HELP_VERB/SKILL.md"` exists, print `cat "$REPO_ROOT/.agents/skills/$HELP_VERB/SKILL.md"`.
       - Else if `"$REPO_ROOT/.agents/skills/$HELP_VERB/SKILL.md"` exists, extract description or run `"$CANDIDATE" --help` (or `"$CANDIDATE" help`). If `--help` exits 0, display its output; otherwise extract and display the skill description from `SKILL.md`.
       - Exit 0.
     - If `SKILL.md` exists even without an executable entrypoint (a pure prompt/instruction skill):
       - If `"$HELP_FULL"` = "full", print `cat "$REPO_ROOT/.agents/skills/$HELP_VERB/SKILL.md"`.
       - Otherwise print synopsis from frontmatter `description` or title, with note "Refusals, effects and tests: aapp help $HELP_VERB full".
       - Exit 0.
2. In `aapp`:
   - Line 114: Expand the `aapp <verb> help` check so it recognizes action plugins in `.agents/skills/$CMD` in addition to `verbs.tsv`.

### B. Standardize `AAPP_REPO_ROOT` Export (`aapp`)
1. In `aapp` (Section 2a):
   - When asserting `REPO_ROOT` in a Git repository, export both `REPO_ROOT` and `AAPP_REPO_ROOT="$REPO_ROOT"`.
   - In Section 2c (Action Plugin Fallthrough), ensure `export AAPP_REPO_ROOT="$CWD_GIT_ROOT"` is set before `exec "$CANDIDATE" "$@"`.

### C. Reference Sample Issue Tracker Queue Handling (`examples/plugins/aapp-issue-tracker/run.sample`)
1. In `run.sample`:
   - Add explicit case branch for `issue.queue|issue.unqueue`:
     - When `issue.queue`: update issue record or status in `$store` to mark queued state (e.g. updating column or logging queue status), returning `{"status": "ok", "message": "sample tracker marked #<id> queued"}`.
     - When `issue.unqueue`: revert queued state, returning `{"status": "ok", "message": "sample tracker marked #<id> unqueued"}`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Help Fallthrough & Dispatcher Exports
- [ ] Task 1.1: Update `aapp` to export `AAPP_REPO_ROOT` alongside `REPO_ROOT`, and allow `aapp <custom-plugin> help` to route to `cmd_help.sh`.
- [ ] Task 1.2: Update `lib/cmd_help.sh` to inspect `.agents/skills/$HELP_VERB` for action plugins and `SKILL.md` before failing with unknown command.

### Phase 2: Sample Issue Tracker Updates
- [ ] Task 2.1: Add explicit `issue.queue` and `issue.unqueue` event handling to `examples/plugins/aapp-issue-tracker/run.sample`.

### Phase 3: Verification & Test Coverage
- [ ] Task 3.1: Add automated tests in `tests/hooks_test.sh` asserting `aapp help <action-plugin>`, `aapp <action-plugin> help`, and `AAPP_REPO_ROOT` export.
- [ ] Task 3.2: Verify `run.sample` handles `issue.queue` and `issue.unqueue` in `tests/plugin_protocol_test.sh`.
- [ ] Task 3.3: Run the full test suite (`./aapp test`) to guarantee zero regressions.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Export AAPP_REPO_ROOT and enable <plugin> help routing.
- [ ] `lib/cmd_help.sh` -> Add action plugin and skill discovery fallthrough before unknown command error.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> Add explicit issue.queue and issue.unqueue event handling.
- [ ] `tests/hooks_test.sh` -> Add tests for action plugin help fallthrough and AAPP_REPO_ROOT propagation.
- [ ] `tests/plugin_protocol_test.sh` -> Test sample issue tracker queue/unqueue handling.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_issue.sh` -> Issue lifecycle commands are tested and working; do not modify.
- [ ] `lib/verbs.tsv` -> Standard built-in verbs registry remains unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan activated into ⚡ In Development via start.
* **2026-10-16:** Plan locked and frozen into 🔷 Frozen via freeze.
- 2026-10-16: Scaffolded blueprint P-95 from issue #156, attached issues #157 and #158.
- 2026-10-16: Fully specified technical blueprint, target files, and execution checklist for help fallthrough, environment propagation, and sample tracker queue events.
*Tracks how the plan evolved across sessions.*
