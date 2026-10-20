# 🗺️ Plan P-115: Perl Core And State Model
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-115
* **Changelog:** Added: Perl 5.26+ core (`AAPP::Config`, `AAPP::Paths`, `AAPP::Text`, `AAPP::JSON`, `AAPP::State`), decorative-only emoji normalizer, and hybrid `aapp` verb dispatcher retiring `python3` (P-115)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `3090f15` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P115 (plan/P115-perl-core-and-state-model)
* **Group:** P-111
* **Commits:** `562f1e1` (plan/P115-perl-core-and-state-model), `ec35d04` (plan/P115-perl-core-and-state-model), `4bc85a3` (plan/P115-perl-core-and-state-model), `1b58dd9` (plan/P115-perl-core-and-state-model), `4cf40d2` (plan/P115-perl-core-and-state-model), `7f57beb` (plan/P115-perl-core-and-state-model), `d1b106b` (plan/P115-perl-core-and-state-model), `b840103` (plan/P115-perl-core-and-state-model)
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
Needs P-127 (foundation: Constants, Paths, Config, Logger, Runner) done; runs before the Perl test harness (P-126), which builds on this core and its `AAPP::JSON`. Builds the shared Perl 5.26+ core and single-pass workspace state model (`lib/AAPP/*.pm`) porting `lib/aapp-lib.sh` (2,493 lines), `lib/output.sh` (219 lines), `lib/plan_states.sh` (394 lines), `lib/plan_resolver.sh` (450 lines), `lib/planning_health.sh` (842 lines), and `lib/commit_engine.sh` (109 lines). This plan also folds in the "Perl in place of python3" JSON migration (`AAPP::JSON`) and updates `aapp` so ported verbs dispatch directly to `AAPP::Cmd::<Verb>` while unported verbs continue running in bash.

---

## 2. Technical Blueprint

### 2.1 Core Modules (`lib/AAPP/`)
1. **`lib/AAPP/Config.pm` (`lib/plan_states.sh`), extending P-127's module:** P-127 already reads all repository settings once per process (`git config --list -z`) with `get`, `get_all`, `get_int`, `keys_with_prefix`; this member adds `get_bool` and the Plan Status Registry (`aapp.planState.<slug>`, `plan_status_line`, `plan_status_text`, `plan_status_slug`, `plan_status_is`, `plan_status_render`, `plan_set_status`, `plan_state_sections`).
2. **`lib/AAPP/Paths.pm` (`lib/aapp-lib.sh`), extending P-127's module:** P-127 already resolves the root, git dir and common dir with one `git rev-parse`; this member adds `PRIMARY_ROOT`, `PLANS_DIR`, `AGENTS_DIR`, `HOOKS_DIR`, and `OFFLINE_DIR` once per process via a single `git rev-parse --show-toplevel --git-common-dir --git-dir` call, plus pure-Perl glob matching (`glob_to_regex`, `match_pattern_list`), platform detection (`aapp_os`), and the unified named lock engine (`aapp_lock_acquire`, `aapp_lock_release`, `aapp_lock_held`).
3. **`lib/AAPP/Text.pm` (`lib/aapp-lib.sh`, `lib/output.sh`):**
   - Decorative-only emoji normalizer: `s/^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s]+)+//` for heading levels/names, plan statuses, kind headers, and table cells.
   - UTF-8 character counter (`aapp_char_len`), wrapping (`out_wrap`), truncation (`out_cut`), and pickup line splitter (`pickup_entry_split`, `pickup_title_max`, `pickup_entry_files`).
4. **`lib/AAPP/JSON.pm` (`lib/output.sh`, `lib/hook_dispatcher.sh`):**
   - Ordered `@_` key-value builder (`json_obj`, `json_list`, `json_str`, `json_strn`, `json_num`, `json_numn`, `json_bool`), 2-space pretty-printer, envelope/notices/error builders (`docs/reference/08-output-json.md`), and JSON reader for `blast-radius-guard` tool payloads, `.claude/settings.json` merging, and pause snapshots. Never uses `JSON::PP` or `python3`.
5. **`lib/AAPP/Output.pm` (`lib/output.sh`, `lib/aapp-lib.sh`):**
   - Shared terminal and JSON record renderers (`out_width`, `issue_render_terminal`, `issue_render_json`).
6. **`lib/AAPP/State.pm` (`lib/aapp-lib.sh`, `lib/plan_resolver.sh`):**
   - Single-pass workspace state loader: reads `$(git rev-parse --git-path aapp_active_plan)`, held plans across worktrees (`aapp_held_plans`, `aapp_plan_held_by`), every `.plans/current/*.md` (header fields, Status slug, `Commits:`, `Base:`, `Worktree:`, `Also Closes:`, §3 required tests, §4 `Target Files` / `Emergency Hotfix Extensions` / `Required Test Files` / `Out of Bounds`), Plan ID & Issue ID resolvers/allocators (`resolve_plan_path`, `allocate_plan_id`, `allocate_issue_id`, `issue_id_normalize`), and the issue/archive/roadmap/offline ledgers (`ledger_row`, `ledger_rows`, `ledger_issue_records`, `roadmap_queue_entries`, and the external description/note store under `${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md`).
7. **`lib/AAPP/CommitEngine.pm` (`lib/commit_engine.sh`):**
   - Ports `plans_commit($subject, @paths)` with explicit pathspec staging (`git commit -- <paths>`), lock-retry resilience, and attribution decoration.
8. **`lib/AAPP/Health.pm` (`lib/planning_health.sh`):**
   - Ports all 8 mechanical verification pairs (Pairs 1–8) plus `check_fix_cells`, `check_issues_table_shape`, `check_ledger_issues`, `check_issues_added_rows`, and `check_pickup_entries` over `AAPP::State`.

### 2.2 Hybrid `aapp` Dispatcher & `python3` Retirement
- `aapp` checks if `lib/AAPP/Cmd/<Verb>.pm` exists: if so, invokes Perl (`perl -I"$AAPP_LIB" -MAAPP::Cmd::<Verb> -e 'exit AAPP::Cmd::<Verb>::run(@ARGV)' -- "$CMD" "$@"`); otherwise sources `lib/cmd_<verb>.sh`.
- Replaces the kit's own `python3` JSON calls in `lib/cmd_pause.sh`, `lib/cmd_status.sh`, `lib/cmd_init.sh`, `templates/blast-radius-guard.sh`, and the pause-reason reader in `templates/aapp-pre-commit` with `AAPP::JSON`. (The adopter Python syntax check in `templates/aapp-pre-commit` is left untouched for `#159`.)
- No test changes here. This member runs after P-127 and before the Perl test harness (P-126), so the slimmed bash suites (P-113) are its safety net: they must stay green. The Perl test modules for these libraries are written later, in P-123, directly against `AAPP::*`.
- `AAPP::JSON` is the kit's one JSON writer and reader, for the code and for the Perl tests alike; nothing else parses or emits JSON.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible` (Transitional bash/Perl coexistence within group `P-111` until `P-122`)
- **Fallback Inventory**:
  - `lib/aapp-lib.sh`, `lib/output.sh`, `lib/plan_states.sh`, `lib/plan_resolver.sh`, `lib/planning_health.sh`, and `lib/commit_engine.sh` are retained unchanged for unported bash verbs (`P-117`–`P-121`) and deleted in `P-122`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Modules (`lib/AAPP/*.pm`)
- [x] Task 1.1: Extend P-127's `lib/AAPP/Config.pm` and `lib/AAPP/Paths.pm` (§2.1–2.2); implement `lib/AAPP/Text.pm`, `lib/AAPP/JSON.pm`, and `lib/AAPP/Output.pm`.
- [x] Task 1.2: Implement `lib/AAPP/State.pm`, `lib/AAPP/CommitEngine.pm`, and `lib/AAPP/Health.pm`.

### Phase 2: Dispatcher, `python3` Retirement & Core Wrapper Tests
- [ ] Task 2.1: Update `aapp` to route ported verbs to `lib/AAPP/Cmd/*.pm` and unported verbs to `lib/cmd_*.sh`.
- [ ] Task 2.2: Replace `python3` JSON calls in `lib/cmd_init.sh`, `lib/cmd_pause.sh`, `lib/cmd_status.sh`, `templates/blast-radius-guard.sh`, and `templates/aapp-pre-commit` (pause reason) with `AAPP::JSON`, and update `lib/cmd_init.sh` to copy `lib/AAPP/*.pm` into `.githooks/AAPP/`.
- [ ] Task 2.3: Run `./aapp test strict quiet` (the bash suites) green after each module switch.

### Phase 3: Verification
- [ ] Task 3.1: Run `./aapp test strict quiet` to verify all core, JSON, state, and verb contracts pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/AAPP/Config.pm` -> Extend P-127's reader: `get_bool` and the plan-state registry (`plan_states.sh`).
- [ ] `lib/AAPP/Paths.pm` -> Extend P-127's resolver: worktree and plans paths, glob matcher, OS detector, named locks.
- [ ] `NEW FILE` -> `lib/AAPP/Text.pm` -> Emoji-stripping heading/value normalizer, UTF-8 char length, wrap/cut, and pickup splitter.
- [ ] `NEW FILE` -> `lib/AAPP/JSON.pm` -> Deterministic ordered JSON writer, pretty-printer, envelope builder, and reader.
- [ ] `NEW FILE` -> `lib/AAPP/Output.pm` -> Shared terminal and JSON record renderers (`output.sh`).
- [ ] `NEW FILE` -> `lib/AAPP/State.pm` -> Single-pass workspace, active-plan, blueprint, resolver, and ledger state model (`aapp-lib.sh`, `plan_resolver.sh`).
- [ ] `NEW FILE` -> `lib/AAPP/CommitEngine.pm` -> Unified `.plans` worktree commit engine (`commit_engine.sh`).
- [ ] `NEW FILE` -> `lib/AAPP/Health.pm` -> 8-pair mechanical planning health validator (`planning_health.sh`).
- [ ] `aapp` -> Hybrid Perl/bash verb dispatcher.
- [ ] `lib/cmd_init.sh` -> Sync `lib/AAPP/*.pm` into `.githooks/AAPP/` and replace `python3` in `.claude/settings.json` merge.
- [ ] `lib/cmd_pause.sh` -> Replace `python3` pause snapshot read/write with `AAPP::JSON`.
- [ ] `lib/cmd_status.sh` -> Replace `python3` pause banner read with `AAPP::JSON`.
- [ ] `templates/blast-radius-guard.sh` -> Replace `python3` JSON parsing/output with `AAPP::JSON`.
- [ ] `templates/aapp-pre-commit` -> Replace `python3` pause reason read with `AAPP::JSON` (leaving adopter Python check untouched for `#159`).

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/*` -> Tests change in P-126 and the test migration members only.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-20:** Task 1.2 done: State (128 plan files, ledgers, ids, records, resolver identical to bash; the resolver's exact id match differs only where bash over-matches, #183), CommitEngine (attribution through a bridge to `attribution.sh` until P-116's `AAPP::Attribution`), Health (all checks find the same violations; checks return their violation count). State reads only; plan-header and ledger writers stay in bash until the verb members. An installed `aapp-planid` provider is refused until P-116 ports the dispatcher. Held plans are judged from the same checkout as the active buffer (the cause of #181).
* **2026-10-20:** Task 1.1 done: Config, Paths, Text, JSON, Output, each compared with its bash original in scratch runs. Decisions: `use utf8` port-wide, text decoded at reads (plans, ledgers, git config), file paths kept as bytes; statuses, headings and cells matched by name, emoji decorative only (no emoji-class helper); git calls whose failure is an answer go through `Paths::git_capture` (stderr discarded); the JSON reader keeps key order and reports bad input as a return value, never `die`. Amendment R1 (P-112) asks for Logger's log file to be opened as UTF-8.
* **2026-10-20:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-19:** Plan drafted as member 3 of group P-111 from settled RFC (`.plans/pickup/perl-port-rfc.md`).
* **2026-10-19:** Added `AAPP::Output`, `AAPP::CommitEngine`, and `AAPP::Health`, kept `#159` adopter check untouched, registered transitional bash/Perl coexistence in §2, and added `tests/AAPP/Core/*.pm` per RFC §5.1.3 & §5.1.5.

