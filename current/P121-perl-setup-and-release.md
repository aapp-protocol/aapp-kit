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
Plan `P-121` is the ninth member of group `P-111` (*Perl Port Of The Kit*). It ports the remaining setup, lifecycle, and operational verbs — `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`, `release`, `companion`, `hook`, `pause`/`resume`, and `test` — from `lib/cmd_init.sh` (1,517 lines), `lib/cmd_release.sh` (715 lines), `lib/cmd_companion.sh` (387 lines), `lib/cmd_hook.sh` (340 lines), `lib/cmd_pause.sh` (509 lines), and `lib/cmd_test.sh` into `lib/AAPP/Cmd/*.pm`.

This plan also eliminates the last two `python3` invocations in the codebase:
1. `lib/cmd_init.sh` (`.claude/settings.json` hook merger) is replaced by `AAPP::JSON::decode_json` + ordered key-preserving merge + 2-space pretty-print (`AAPP::JSON::encode_json_pretty`).
2. `lib/cmd_pause.sh` (pause snapshot serializer/reader) is replaced by `AAPP::JSON`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Cmd/*.pm`, `lib/cmd_*.sh`, `aapp`). `lib/AAPP/Tests*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Cmd::Init` (`lib/AAPP/Cmd/Init.pm`) — `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`
Ports `lib/cmd_init.sh`:
- `init` / `upgrade` / `sync`:
  - Scaffolds or upgrades `.plans` (`orphan` worktree or directory), `.agents` (`AGENTS.md` managed `<!-- AAPP-PROTOCOL:START -->` block, `PROJECT.MD`, `CODEMAP.md`, `.agents/skills/aapp*`), and `.githooks/` (`pre-commit`, `commit-msg`, `post-commit`, `blast-radius-guard`, `test-gate.sh`).
  - Copies `lib/AAPP/*.pm` (including subdirectories `lib/AAPP/Cmd/*.pm` and `lib/AAPP/Hook/*.pm` as needed by hooks) into `.githooks/AAPP/` so adopter repositories execute all hooks stand-alone with zero external runtime dependencies.
  - Merges `PreToolUse` (`blast-radius-guard`) into `.claude/settings.json` using `AAPP::JSON` (`decode_json` + `encode_json_pretty`), preserving existing user settings and key ordering with zero `python3` dependency.
  - Configures `core.hooksPath`, `notes.rewriteRef`, and `aapp.*` defaults.
- `install` / `uninstall`: installs or removes the global `aapp` launcher symlink/copy in `~/.local/bin` (or target prefix).
- `develop`: configures the self-hosting kit repository worktrees and symlinks.

### 2.2 `AAPP::Cmd::Release` (`lib/AAPP/Cmd/Release.pm`) — `aapp release`
Ports `lib/cmd_release.sh`:
- Implements pre-flight release verification (`preflight` / `check`) and release execution (`<version>` / `patch` / `minor` / `major`):
  - Verifies clean working tree, branch parity (`main`), zero active `⚡ In Development` or `🟥 BLOCKED` plans, zero `Plan Blockers` in `issues_road_map.md`, passing test suite, and non-empty `## [Unreleased]` in `CHANGELOG.md`.
  - Condenses/rolls `## [Unreleased]` into `## [<version>] - <YYYY-MM-DD>`, updates version strings, commits the release, and creates the annotated Git tag `v<version>`.

### 2.3 `AAPP::Cmd::Companion` (`lib/AAPP/Cmd/Companion.pm`) — `aapp companion`
Ports `lib/cmd_companion.sh`:
- Manages companion skills, IDE rules, and agent customization targets (`status`, `sync`, `enable`, `disable`, `list`) across supported agent directories (`.claude/`, `.cursor/`, `.agents/`).

### 2.4 `AAPP::Cmd::Hook` (`lib/AAPP/Cmd/Hook.pm`) — `aapp hook`
Ports `lib/cmd_hook.sh`:
- Manages repository hook inspection, installation, repair, and test-gate configuration (`status`, `install`, `repair`, `test-gate`).

### 2.5 `AAPP::Cmd::Pause` (`lib/AAPP/Cmd/Pause.pm`) — `aapp pause` and `aapp resume`
Ports `lib/cmd_pause.sh`:
- `pause ["<reason>"]`: sets `git config aapp.paused true`, stashes uncommitted work per active worktree, and writes the pause state snapshot using `AAPP::JSON` (replacing `python3`).
- `resume`: reads the pause snapshot via `AAPP::JSON::decode_json`, restores per-worktree stashes, clears `aapp.paused`, and reports restored worktrees.
- `pause status [--json]`: reports pause state and quarantined worktrees.

### 2.6 `AAPP::Cmd::Test` (`lib/AAPP/Cmd/Test.pm`) — `aapp test`
Ports `lib/cmd_test.sh`:
- Invokes `AAPP::Tests::run(@ARGV)` in-process (when running kit self-tests) or runs the adopter repository's configured test command / `test-gate.sh`, supporting `--list`, `--check-docs`, suite/test filters, and `--jobs N`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Init, Pause & JSON Settings Merger (`AAPP::Cmd::Init`, `AAPP::Cmd::Pause`)
- [ ] Task 1.1: Implement `lib/AAPP/Cmd/Init.pm` covering `init`, `upgrade`, `sync`, `install`, `uninstall`, `develop`, `.githooks/AAPP/` module installation, and `.claude/settings.json` merging via `AAPP::JSON`.
- [ ] Task 1.2: Implement `lib/AAPP/Cmd/Pause.pm` covering `pause`, `resume`, and `pause status` using `AAPP::JSON` for snapshot serialization.

### Phase 2: Release, Companion, Hook & Test (`AAPP::Cmd::Release`, `Companion`, `Hook`, `Test`)
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Release.pm`, `lib/AAPP/Cmd/Companion.pm`, `lib/AAPP/Cmd/Hook.pm`, and `lib/AAPP/Cmd/Test.pm`.
- [ ] Task 2.2: Wire `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`, `release`, `companion`, `hook`, `pause`, `resume`, and `test` in `./aapp` to their `AAPP::Cmd::*` modules, and slim the corresponding `lib/cmd_*.sh` files to thin shims.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test init release companion hook pause test` and full `./aapp test` to verify 100% pass rate against the locked test suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Init.pm` -> `init`, `install`, `upgrade`, `uninstall`, `develop`, and `sync` implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Release.pm` -> `aapp release` pre-flight and release tagging implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Companion.pm` -> `aapp companion` skill and IDE rule management implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Hook.pm` -> `aapp hook` status, installation, and repair implementation.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Pause.pm` -> `aapp pause` and `aapp resume` emergency brake implementation using `AAPP::JSON`.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Test.pm` -> `aapp test` CLI entry delegating to `AAPP::Tests`.
- [ ] `aapp` -> Dispatch `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`, `release`, `companion`, `hook`, `pause`, `resume`, and `test` to `AAPP::Cmd::*`.
- [ ] `lib/cmd_init.sh` -> Transitional shim delegating to `AAPP::Cmd::Init` until `P-122`.
- [ ] `lib/cmd_release.sh` -> Transitional shim delegating to `AAPP::Cmd::Release` until `P-122`.
- [ ] `lib/cmd_companion.sh` -> Transitional shim delegating to `AAPP::Cmd::Companion` until `P-122`.
- [ ] `lib/cmd_hook.sh` -> Transitional shim delegating to `AAPP::Cmd::Hook` until `P-122`.
- [ ] `lib/cmd_pause.sh` -> Transitional shim delegating to `AAPP::Cmd::Pause` until `P-122`.
- [ ] `lib/cmd_test.sh` -> Transitional shim delegating to `AAPP::Cmd::Test` until `P-122`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness and all `lib/AAPP/Tests/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Authored technical blueprint and locked blast radius for `P-121`.

