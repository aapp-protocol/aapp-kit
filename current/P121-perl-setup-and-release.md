# 🗺️ Plan P-121: Perl Setup And Release
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-121
* **Changelog:** Changed: Port setup, release, companion, hook, pause/resume, and test runner verbs (`init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`, `release`, `companion`, `hook`, `pause`, `resume`, `test`) to `AAPP::Cmd::*` modules, retiring the last `python3` calls in `cmd_init.sh` and `cmd_pause.sh`.
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
Plan `P-121` is the ninth member of group `P-111` (*Perl Port Of The Kit*). It ports all 11 remaining setup, sync, release, hook, pause, companion, and test bash modules into `lib/AAPP/Cmd/*.pm`:
- `lib/cmd_init.sh` (1,072 lines) -> `lib/AAPP/Cmd/Init.pm` (`aapp init`)
- `lib/cmd_install.sh` (187 lines) -> `lib/AAPP/Cmd/Install.pm` (`aapp install`)
- `lib/cmd_upgrade.sh` (44 lines) -> `lib/AAPP/Cmd/Upgrade.pm` (`aapp upgrade`)
- `lib/cmd_uninstall.sh` (55 lines) -> `lib/AAPP/Cmd/Uninstall.pm` (`aapp uninstall`)
- `lib/cmd_develop.sh` (123 lines) -> `lib/AAPP/Cmd/Develop.pm` (`aapp develop`)
- `lib/cmd_sync.sh` (429 lines) -> `lib/AAPP/Cmd/Sync.pm` (`aapp push`, `aapp pull`, `aapp sync`)
- `lib/cmd_release.sh` (896 lines) -> `lib/AAPP/Cmd/Release.pm` (`aapp release`)
- `lib/cmd_companion.sh` (337 lines) -> `lib/AAPP/Cmd/Companion.pm` (`aapp companion`)
- `lib/cmd_hook.sh` (402 lines) -> `lib/AAPP/Cmd/Hook.pm` (`aapp hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, `hook-hash`)
- `lib/cmd_pause.sh` (584 lines) -> `lib/AAPP/Cmd/Pause.pm` (`aapp pause`, `aapp resume`, `aapp unpause`)
- `lib/cmd_test.sh` (397 lines) -> `lib/AAPP/Cmd/Test.pm` (`aapp test`)

This plan also eliminates the remaining `python3` invocations in the kit's own CLI:
1. `lib/cmd_init.sh` (`.claude/settings.json` hook merger) is replaced by `AAPP::JSON::decode_json` + ordered key-preserving merge + 2-space pretty-print (`AAPP::JSON::encode_json_pretty`).
2. `lib/cmd_pause.sh` (pause snapshot serializer/reader) is replaced by `AAPP::JSON`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Cmd/*.pm`, `lib/cmd_*.sh`, `aapp`). `tests/AAPP/*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 Setup & Lifecycle Modules (`Init`, `Install`, `Upgrade`, `Uninstall`, `Develop`)
Each module preserves the exact behavior, arguments, failure modes, and side effects specified in `aapp help <verb> full` and `lib/docs/verbs/<verb>.md` under unchanged `tests/AAPP/Verb/*.pm`:
- **`lib/AAPP/Cmd/Init.pm` (`lib/cmd_init.sh`, 1,072 lines; `lib/docs/verbs/init.md`):**
  - Scaffolds or upgrades `.plans`, `.agents` (`AGENTS.md` managed `<!-- AAPP-PROTOCOL:START -->` block, `PROJECT.MD`, `CODEMAP.md`, `.agents/skills/aapp*`, `.agents/hooks/`), and `.githooks/`.
  - Copies `lib/AAPP/` into `.githooks/AAPP/` alongside the hook entrypoints (no `.sh` library copies).
  - Merges `PreToolUse` (`blast-radius-guard`) into `.claude/settings.json` using `AAPP::JSON` (`decode_json` + `encode_json_pretty`) with zero `python3` dependency.
  - Calls `AAPP::Adoption` (`P-118`) for adoption seeding/sync.
- **`lib/AAPP/Cmd/Install.pm` (`lib/cmd_install.sh`, 187 lines; `lib/docs/verbs/install.md`):** Ports `cmd_install`.
- **`lib/AAPP/Cmd/Upgrade.pm` (`lib/cmd_upgrade.sh`, 44 lines; `lib/docs/verbs/upgrade.md`):** Ports `cmd_upgrade`.
- **`lib/AAPP/Cmd/Uninstall.pm` (`lib/cmd_uninstall.sh`, 55 lines; `lib/docs/verbs/uninstall.md`):** Ports `cmd_uninstall`.
- **`lib/AAPP/Cmd/Develop.pm` (`lib/cmd_develop.sh`, 123 lines; `lib/docs/verbs/develop.md`):** Ports `cmd_develop`.

### 2.2 Synchronization & Release Modules (`Sync`, `Release`, `Companion`)
- **`lib/AAPP/Cmd/Sync.pm` (`lib/cmd_sync.sh`, 429 lines; `lib/docs/verbs/sync.md`, `push.md`, `pull.md`):** Ports `push`, `pull`, and `sync` (`aapp help push full`, `aapp help pull full`, `aapp help sync full`).
- **`lib/AAPP/Cmd/Release.pm` (`lib/cmd_release.sh`, 896 lines; `lib/docs/verbs/release.md`):** Ports `release` (`aapp help release full`).
- **`lib/AAPP/Cmd/Companion.pm` (`lib/cmd_companion.sh`, 337 lines; `lib/docs/verbs/companion.md`):** Ports `companion` (`aapp help companion full`).

### 2.3 Hook, Pause & Test Modules (`Hook`, `Pause`, `Test`)
- **`lib/AAPP/Cmd/Hook.pm` (`lib/cmd_hook.sh`, 402 lines; `lib/docs/verbs/hooks.md`, `plugins.md`):** Ports `hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, and `hook-hash` (`aapp help hooks full`, `aapp help plugins full`) over `AAPP::HookDispatcher` and `Digest::SHA`.
- **`lib/AAPP/Cmd/Pause.pm` (`lib/cmd_pause.sh`, 584 lines; `lib/docs/verbs/pause.md`, `resume.md`):** Ports `pause`, `resume`, and `unpause` (`aapp help pause full`, `aapp help resume full`), serializing and reading the pause snapshot via `AAPP::JSON` (zero `python3`).
- **`lib/AAPP/Cmd/Test.pm` (`lib/cmd_test.sh`, 397 lines; `lib/docs/verbs/test.md`):** Ports `test` (`aapp help test full`), delegating kit self-tests to `tests/AAPP/Tests.pm` (`P-114`).

### 🔄 Migration & Compatibility Strategy
- **Transitional Coexistence (`P-121` → `P-122`):** All 11 `lib/cmd_*.sh` files are slimmed to thin shims (or retained unused once `aapp` routes every verb to `AAPP::Cmd::*`) until `P-122` deletes all 30 `lib/*.sh` files in one clean break.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Setup & Lifecycle (`Init`, `Install`, `Upgrade`, `Uninstall`, `Develop`)
- [ ] Task 1.1: Implement `lib/AAPP/Cmd/Init.pm`, `lib/AAPP/Cmd/Install.pm`, `lib/AAPP/Cmd/Upgrade.pm`, `lib/AAPP/Cmd/Uninstall.pm`, and `lib/AAPP/Cmd/Develop.pm`, using `AAPP::JSON` for `.claude/settings.json` merging and installing `.githooks/AAPP/` without legacy `.sh` copies.

### Phase 2: Sync, Release, Companion, Hook, Pause & Test (`Sync`, `Release`, `Companion`, `Hook`, `Pause`, `Test`)
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Sync.pm` (`push`, `pull`, `sync`), `lib/AAPP/Cmd/Release.pm`, and `lib/AAPP/Cmd/Companion.pm`.
- [ ] Task 2.2: Implement `lib/AAPP/Cmd/Hook.pm` (`hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, `hook-hash`), `lib/AAPP/Cmd/Pause.pm` (`pause`, `resume`, `unpause` via `AAPP::JSON`), and `lib/AAPP/Cmd/Test.pm`.
- [ ] Task 2.3: Route all remaining verbs in `./aapp` to `AAPP::Cmd::*`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test` across `verb_init_test.sh`, `verb_sync_test.sh`, `verb_release_test.sh`, `verb_companion_test.sh`, `verb_hooks_test.sh`, `verb_pause_test.sh`, and `verb_test_test.sh` to verify 100% pass rate.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Init.pm` -> `aapp init` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Install.pm` -> `aapp install` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Upgrade.pm` -> `aapp upgrade` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Uninstall.pm` -> `aapp uninstall` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Develop.pm` -> `aapp develop` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Sync.pm` -> `aapp push`, `aapp pull`, and `aapp sync` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Release.pm` -> `aapp release` pre-flight, condense, and release tagging implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Companion.pm` -> `aapp companion` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Hook.pm` -> `aapp hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, and `hook-hash` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Pause.pm` -> `aapp pause`, `aapp resume`, and `aapp unpause` implementation using `AAPP::JSON`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Test.pm` -> `aapp test` CLI entry delegating to `tests/AAPP/Tests.pm`.
- [ ] `aapp` -> Dispatch `init`, `install`, `upgrade`, `uninstall`, `develop`, `push`, `pull`, `sync`, `release`, `companion`, `hooks`, `hook-status`, `plugins`, `plugin-status`, `hook-test`, `hook-run`, `hook-hash`, `pause`, `resume`, `unpause`, and `test` to `AAPP::Cmd::*`.
- [ ] `lib/cmd_init.sh` -> Transitional shim delegating to `AAPP::Cmd::Init` until `P-122`.
- [ ] `lib/cmd_install.sh` -> Transitional shim delegating to `AAPP::Cmd::Install` until `P-122`.
- [ ] `lib/cmd_upgrade.sh` -> Transitional shim delegating to `AAPP::Cmd::Upgrade` until `P-122`.
- [ ] `lib/cmd_uninstall.sh` -> Transitional shim delegating to `AAPP::Cmd::Uninstall` until `P-122`.
- [ ] `lib/cmd_develop.sh` -> Transitional shim delegating to `AAPP::Cmd::Develop` until `P-122`.
- [ ] `lib/cmd_sync.sh` -> Transitional shim delegating to `AAPP::Cmd::Sync` until `P-122`.
- [ ] `lib/cmd_release.sh` -> Transitional shim delegating to `AAPP::Cmd::Release` until `P-122`.
- [ ] `lib/cmd_companion.sh` -> Transitional shim delegating to `AAPP::Cmd::Companion` until `P-122`.
- [ ] `lib/cmd_hook.sh` -> Transitional shim delegating to `AAPP::Cmd::Hook` until `P-122`.
- [ ] `lib/cmd_pause.sh` -> Transitional shim delegating to `AAPP::Cmd::Pause` until `P-122`.
- [ ] `lib/cmd_test.sh` -> Transitional shim delegating to `AAPP::Cmd::Test` until `P-122`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/AAPP/Tests.pm` -> Test harness and all `tests/AAPP/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to include all 11 setup/sync/hook/release bash modules and exact subverbs.

