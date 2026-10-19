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
Builds the shared Perl 5.26+ core and single-pass workspace state model (`lib/AAPP/*.pm`) that all hooks (`P-116`) and verbs (`P-117`–`P-121`) consume, folds in the "Perl in place of python3" JSON migration, and updates `aapp` so ported verbs dispatch directly to `AAPP::Cmd::<Verb>` while unported verbs continue running in bash.

---

## 2. Technical Blueprint

### 2.1 Core Modules (`lib/AAPP/`)
1. **`lib/AAPP/Config.pm`:** Reads all repository settings once per process via `git config --list -z`, providing typed accessors (`get`, `get_int`, `get_bool`, `get_regexp`) and plan-state registry resolution (`aapp.planState.<slug>`).
2. **`lib/AAPP/Paths.pm`:** Resolves `REPO_ROOT`, `GIT_COMMON_DIR`, `GIT_DIR`, `PRIMARY_ROOT`, `PLANS_DIR`, `AGENTS_DIR`, `HOOKS_DIR`, and `OFFLINE_DIR` once per process via a single `git rev-parse --show-toplevel --git-common-dir --git-dir` call, plus pure-Perl glob matching (`match_pattern_list`).
3. **`lib/AAPP/Text.pm`:**
   - Decorative-only emoji normalizer: `s/^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s]+)+//` for heading levels/names, plan statuses, kind headers, and table cells.
   - UTF-8 character-width wrapping (`out_wrap`) and truncation (`out_cut`) matching `lib/output.sh`.
4. **`lib/AAPP/JSON.pm`:**
   - Ordered `@_` key-value builder (`json_obj`, `json_list`, `json_str`, `json_strn`, `json_num`, `json_numn`, `json_bool`), 2-space pretty-printer, envelope/notices/error builders (`docs/reference/08-output-json.md`), and JSON reader for `blast-radius-guard` tool payloads, `.claude/settings.json` merging, and pause snapshots. Never uses `JSON::PP` or `python3`.
5. **`lib/AAPP/State.pm`:**
   - Single-pass workspace state loader: reads `aapp_active_plan`, held plans across worktrees (`.git/worktrees/*/aapp_active_plan`), every `.plans/current/*.md` (header fields, Status slug, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), and the issue/roadmap/pickup ledgers once per process.

### 2.2 Hybrid `aapp` Dispatcher & `python3` Retirement
- `aapp` checks if `lib/AAPP/Cmd/<Verb>.pm` exists: if so, invokes Perl (`perl -I"$AAPP_LIB" -MAAPP::Cmd::<Verb> -e 'AAPP::Cmd::<Verb>::run(@ARGV)' -- "$@"`); otherwise sources `lib/cmd_<verb>.sh`.
- Replaces all remaining `python3` calls in `lib/cmd_pause.sh`, `lib/cmd_status.sh`, `lib/cmd_init.sh`, `templates/blast-radius-guard.sh`, and `templates/aapp-pre-commit` with `AAPP::JSON`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Modules (`lib/AAPP/*.pm`)
- [ ] Task 1.1: Implement `lib/AAPP/Config.pm`, `lib/AAPP/Paths.pm`, `lib/AAPP/Text.pm`, and `lib/AAPP/JSON.pm`.
- [ ] Task 1.2: Implement `lib/AAPP/State.pm` (single-pass plan, worktree buffer, status registry, and ledger state reader/writer).

### Phase 2: Dispatcher & `python3` Retirement
- [ ] Task 2.1: Update `aapp` to route ported verbs to `lib/AAPP/Cmd/*.pm` and unported verbs to `lib/cmd_*.sh`.
- [ ] Task 2.2: Replace `python3` JSON calls in `lib/cmd_init.sh`, `lib/cmd_pause.sh`, `lib/cmd_status.sh`, `templates/blast-radius-guard.sh`, and `templates/aapp-pre-commit` with `AAPP::JSON`, and update `lib/cmd_init.sh` to copy `lib/AAPP/*.pm` into `.githooks/AAPP/`.

### Phase 3: Verification
- [ ] Task 3.1: Run `./aapp test strict quiet` to verify all core, JSON, state, and verb contracts pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/AAPP/Config.pm` -> Single-pass `git config --list -z` reader and plan-state registry.
- [ ] `NEW FILE` -> `lib/AAPP/Paths.pm` -> Single-pass repository/worktree path resolver and glob matcher.
- [ ] `NEW FILE` -> `lib/AAPP/Text.pm` -> Emoji-stripping heading/value normalizer and UTF-8 character wrap/cut.
- [ ] `NEW FILE` -> `lib/AAPP/JSON.pm` -> Deterministic ordered JSON writer, pretty-printer, and reader.
- [ ] `NEW FILE` -> `lib/AAPP/State.pm` -> Single-pass workspace, active-plan, blueprint, and ledger state model.
- [ ] `aapp` -> Hybrid Perl/bash verb dispatcher.
- [ ] `lib/cmd_init.sh` -> Sync `lib/AAPP/*.pm` into `.githooks/AAPP/` and replace `python3` in `.claude/settings.json` merge.
- [ ] `lib/cmd_pause.sh` -> Replace `python3` pause snapshot read/write with `AAPP::JSON`.
- [ ] `lib/cmd_status.sh` -> Replace `python3` pause banner read with `AAPP::JSON`.
- [ ] `templates/blast-radius-guard.sh` -> Replace `python3` JSON parsing/output with `AAPP::JSON`.
- [ ] `templates/aapp-pre-commit` -> Replace `python3` pause reason read and adopter Python check with `AAPP::JSON`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness is locked (tests or code change in a plan, never both).
- [ ] `lib/AAPP/Tests/Core/*.pm` -> Core test modules are untouched in this plan.
- [ ] `lib/AAPP/Tests/Verb/*.pm` -> Verb test modules are untouched in this plan.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan drafted as member 3 of group P-111 from settled RFC (`.plans/pickup/perl-port-rfc.md`).
