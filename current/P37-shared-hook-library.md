# 🗺️ Plan P-37: Shared Hook Library
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #82
* **Plan ID:** P-37
* **Status:** 🔷 Frozen
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

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

## 1. Context & Architectural Goal

### Problem Statement
The Target Files parser exists as four near-verbatim copies — `lib/cmd_plan.sh:105`
(`parse_plan_target_paths`), `.githooks/aapp-pre-commit:246` and `.githooks/blast-radius-guard:302`
(`parse_plan_section`), and `lib/planning_health.sh:576` (`get_plan_targets`, Pair 7) — and all four
share two defects (`#82`):

1. **Blockquote prose is parsed as a target.** No copy skips `>` lines, so the template's own
   authoring-rule prose yields the phantom target `backticked path` on every plan. A backticked path
   in any §4 blockquote becomes writable.
2. **The section boundary bleeds.** In unpatched code, the region ends only at `### 🛑 Out of Bounds`
   or a `## ` heading, so any subsection placed between Target Files and Out of Bounds is absorbed
   and every backticked path in it becomes a write target. Under the refined fail-closed architecture,
   only named target-bearing headings contribute targets. Per the consensus specifications in the tri-plan
   RFC, `### 🧪 Required Test Files` is formally recognized as a dedicated target-bearing section (Option A),
   allowing test files declared under it to legitimately receive write access without section bleed into
   arbitrary unlisted headings.

All four defects widen the blast radius silently, and because the parser is copied four times, every fix
must be made across four modules — which is how copies drift. The duplication is wider than the parser:
`glob_to_regex` and `match_pattern_list` are copied between both hooks, and the Status-line regex
appears 22 times across `lib/cmd_plan.sh`, both hooks and `lib/plan_states.sh`.

**Why the copies exist.** Hooks are installed into `.githooks/`, a committed branch shared with the
team, and deliberately source nothing: enforcement must not depend on a particular machine's kit.
Duplication was the price of that self-containment.

### Architectural Goal
One shared, pure-function library that the CLI, planning health engine, and both hook engines source,
fixing `#82` once and establishing clean platform infrastructure.

1. **Single source** at `lib/aapp-lib.sh` — it is shared code, and `lib/` is where kit code lives.
2. **`templates/` remains the complete install manifest** via a tracked symlink
   `templates/aapp-lib.sh -> ../lib/aapp-lib.sh`.
3. **Hooks stay self-contained and version-locked**: `aapp init` installs a real copy into
   `.githooks/aapp-lib.sh`, and hooks source it from their own directory.
4. **The parser becomes fail-closed by construction**: only whitelisted target-bearing headings
   (`Target Files`, `Emergency Hotfix Extensions`, and `Required Test Files`) contribute targets;
   blockquotes never do.
5. **Out-of-Bounds and section extraction are preserved**: `parse_plan_oob_paths` isolates
   `### 🛑 Out of Bounds`, and `extract_plan_section` unifies design-lock section parsing in
   `templates/aapp-pre-commit`.
6. **Cross-platform OS detection**: `aapp_os` provides a pure, portable OS query
   (`linux`, `darwin`, `windows`, `wsl`, `bsd`, `unknown`) for diagnostic reporting and platform branches.
7. **A failed library load refuses the commit**, never degrades to unguarded.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. All four inline parser copies are deleted, not kept
   beside the library. A hook that cannot load the library refuses the commit; there is no inline
   fallback parser.

### 2.1 Layout: `lib/` Source, `templates/` Symlink, `.githooks/` Copy

```text
lib/aapp-lib.sh                                  ← the only authored copy (regular file)
templates/aapp-lib.sh -> ../lib/aapp-lib.sh      ← tracked symlink; keeps templates/ the install manifest
.githooks/aapp-lib.sh                            ← real file, installed by aapp init (direct regular file copy)
```

| Consumer | Sources |
| :--- | :--- |
| `lib/cmd_plan.sh` | `"$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"` (self-relative) |
| `lib/planning_health.sh` (Pair 7 collision gate) | `"$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"` (self-relative) |
| `.githooks/aapp-pre-commit`, `.githooks/blast-radius-guard` | `"$(dirname "$0")/aapp-lib.sh"` |

**Self-Relative Sourcing for Kit Modules:**
Kit modules residing in `lib/` must source `aapp-lib.sh` relative to their own file location via
`"$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"`, never relying on the `$AAPP_LIB` environment variable
exported by the dispatcher. When called from external scripts (`cmd_status.sh`, `cmd_pause.sh`,
`cmd_test.sh`), direct test harnesses (`tests/pre-commit_test.sh`, `tests/plan_resolver_test.sh`), or
standalone CLI executions, `$AAPP_LIB` is frequently unset.
Furthermore, kit modules must assert the load sentinel and fail closed immediately if missing. Silent
skips (e.g. `if [ -f ... ]; then . ...; fi`) are strictly prohibited in core kit modules.

**Cross-Platform Install & Loud Init Failure:**
`aapp install`'s `cp -r lib templates` preserves the relative symlink inside the installed kit.
In `lib/cmd_init.sh`, rather than blindly trusting `templates/aapp-lib.sh` (which on Windows clones with
`core.symlinks=false` checks out as a 1-line text file containing `../lib/aapp-lib.sh`), `cmd_init.sh`
copies strictly from `$AAPP_LIB/aapp-lib.sh`.
If `$AAPP_LIB/aapp-lib.sh` is missing or unreadable, `cmd_init.sh` **fails loudly with exit code 1**,
printing the missing path, operating system (via `aapp_os`), and remediation advice. Silent fallbacks
that copy 1-line stubs are strictly forbidden.

Hooks reached through the worktree symlink (`.plans/.githooks -> ../.githooks`) resolve `dirname "$0"`
to the same directory. This is the kit's **first tracked symlink** — none exist today.

### 2.2 Why a Copy in `.githooks/`, Not the Installed Kit

After `P-36` every contributor must have `aapp` installed, so hooks *could* source the library
straight from `~/.local/share/aapp-kit/`. **Rejected:** enforcement would then depend on each
machine's installed kit version — a teammate on an older kit would enforce an older parser against
the same repository. The copy on the `githooks` branch means every contributor enforces identical
rules, refreshed together by `aapp init`.

### 2.3 Library Contents — Pure Functions Only

The library is sourced by enforcement engines, so it must be inert at source time:

- **Purity Rule:** pure functions: arguments or stdin in, stdout out; no state mutation or side effects.
- **Allowed:** `parse_plan_target_paths`, `parse_plan_oob_paths`, `extract_plan_section`,
  `glob_to_regex`, `match_pattern_list`, `aapp_os`, and a load sentinel `aapp_lib_loaded`.
  `extract_plan_section` operates as a pure stdin stream filter extracting numbered markdown sections (`## N.`)
  for design-lock enforcement.
- **`aapp_os` specification:** pure query with no state mutation, writing standard platform token to
  stdout: `aapp_os [uname_s] [proc_version_path]`. When arguments are omitted, defaults to live
  `uname -s` and `/proc/version`. Returns `linux`, `darwin`, `windows` (Cygwin/MinGW/MSYS), `wsl`,
  `bsd`, or `unknown`.
  *Documented Invariant:* `wsl` represents a GNU userland and shares behavior with `linux` for userland
  tools (e.g. `sed -i`). Parameterized inputs allow 100% deterministic unit testing of all platform
  branches without host mocking.
- **Forbidden:** top-level statements with side effects, `set` options that alter the caller, reads
  of the `aapp` environment, and repository-root resolution. `P-33` showed root resolution is
  context-dependent (some callers must derive, others inherit), so it is not a pure function.
- The Status-line regex is a consolidation candidate but deferred to a dedicated follow-up plan (tracked under `#85`).

### 2.4 Parser Boundary Rules (fixes `#82` defects for Target Files, OOB & Pair 7)

1. **Target Files (`parse_plan_target_paths`):**
   > Only whitelisted target-bearing headings contribute targets. The parser collects paths under
   > `### 📂 Target Files`, `### 🚨 Emergency Hotfix Extensions`, and `### 🧪 Required Test Files` (Option A).
   > **Any** other heading ends the region. Lines beginning with `>` are never parsed.
   
   This inverts the current rule from *"every subsection grants write access unless excluded"* to
   *"only named sections grant it"* — fail-closed by construction.
   Under Option A settled in the tri-plan RFC, declaring a test file under `### 🧪 Required Test Files`
   confers write permission to author or edit that test file, eliminating redundant double-entry in
   `### 📂 Target Files`. Conversely, `### 🧪 Required Tests` in §3 remains an execution checklist
   (tickable `- [ ]` -> `- [x]`) and never confers write access.

   **Exact Heading Matching Regex Contract:**
   To prevent prefix collisions between `Required Test Files` (in §4, grants write) and `Required Tests`
   (in §3, grants no write), and to allow optional parenthetical descriptions, all boundary headings
   use exact regex matching anchored with `(\(.*)?$`:
   - `^###[[:space:]]*📂[[:space:]]*Target Files[[:space:]]*(\(.*)?$`
   - `^###[[:space:]]*🚨[[:space:]]*Emergency Hotfix Extensions[[:space:]]*(\(.*)?$`
   - `^###[[:space:]]*🧪[[:space:]]*Required Test Files[[:space:]]*(\(.*)?$`
   - `^###[[:space:]]*🛑[[:space:]]*Out of Bounds[[:space:]]*(\(.*)?$`

   Any heading matching `^#+[[:space:]]` that is not one of the three whitelisted target headings terminates
   target collection unconditionally (covering `####` subheadings as well as `##` and `#`).

   **Scope — §4 only, fences skipped:**
   Target-bearing and Out of Bounds headings count only inside `## 💥 4.` — the design-locked
   section (`extract_plan_section 4`). Fenced code blocks (lines between ```` ``` ```` markers) are skipped
   everywhere. Without this, an example heading quoted in prose becomes a live section:
   `P-35` §2.2 quotes `### 🧪 Required Test Files` in a ```` ```markdown ```` fence, which would grant
   `src/test/kotlin/AuthTest.kt`, `tests/test_parser.py` and `tests/verbs/draft.sh` and switch on
   `P-35`'s tdd enforcement for a plan that never opted in. The only existing
   `### 🚨 Emergency Hotfix Extensions` heading (`done/P30`, line 291) sits inside §4, so scoping
   breaks nothing.

   **Bullet, Checkbox & Lifecycle Marker Stripping:**
   Target lines strip leading bullets, checkboxes, and lifecycle prefix markers before extracting the target path:
   1. Leading checkbox: `sub(/^[[:space:]]*-[[:space:]]*(\[[ xX]\][[:space:]]*)?/, "", line)`
   2. Lifecycle marker: `sub(/^`?(NEW FILE|MODIFY|DELETE|ADD|REPLACE)`?[[:space:]]*->[[:space:]]*/, "", line)`
   3. Marker token guard: `if (path ~ /^(NEW FILE|MODIFY|DELETE|ADD|REPLACE)$/) next`
   4. The first backticked token on the remaining line is extracted as the target path.

2. **Out of Bounds (`parse_plan_oob_paths`):**
   > Collects paths declared under `### 🛑 Out of Bounds` only. **Any** subsequent heading
   > (`^#+[[:space:]]`) ends the region. Lines beginning with `>` are never parsed.

3. **Section Extractor (`extract_plan_section`):**
   > Takes section number `$1` (`s`) and filters stdin:
   > ```awk
   > awk -v s="$sec" '
   >     $0 ~ "^## ([^0-9]*[[:space:]])?" s "\\." { flag=1; print; next }
   >     $0 ~ "^## ([^0-9]*[[:space:]])?[0-9]+\\." && flag { flag=0 }
   >     flag { print }
   > '
   > ```
   > Replaces the duplicate inline awk script in `templates/aapp-pre-commit:581` for frozen plan
   > immutability and design-lock enforcement.

Both `templates/aapp-pre-commit` and `templates/blast-radius-guard.sh` call both functions to populate
`PLAN_TARGETS` and `PLAN_OOB`, completely eliminating the legacy, bleed-prone `parse_plan_section` helper.
`templates/aapp-pre-commit` also uses `extract_plan_section`.
`lib/planning_health.sh` (Pair 7) calls `parse_plan_target_paths`, eliminating the fourth target parser copy.

### 2.5 Fail-Closed Load

Each hook sources the library and then asserts the sentinel:

```bash
AAPP_LIB_FILE="$(dirname "$0")/aapp-lib.sh"
if ! . "$AAPP_LIB_FILE" 2>/dev/null || ! declare -f aapp_lib_loaded >/dev/null; then
    echo "❌ [AAPP Guard] Shared library missing or unreadable: $AAPP_LIB_FILE" >&2
    echo "   Run 'aapp init' to reinstall the hook engine." >&2
    exit 1
fi
```

If the library is absent or unreadable, the hook refuses immediately rather than running unguarded.

### 2.6 Protection Model & Sanctioned Propagation

| | Protected? | Changes by |
| :--- | :--- | :--- |
| `lib/aapp-lib.sh` (source) | No | An ordinary plan listing it as a target, with tests |
| `.githooks/aapp-lib.sh` (installed) | Yes — for agents | `aapp init` (or human developers via standard git) |

This mirrors how the hook engines are handled today: `templates/blast-radius-guard.sh` is editable
under a plan, the installed copy is locked against autonomous agent writes, and `aapp init` propagates.
**Sanctioned Propagation & Agent Boundary:** The blast radius guard protects `.githooks/*` from
autonomous AI agent writes. Running `aapp init` in Phase 4 is the authorized procedural mechanism that
refreshes `.githooks/` from `templates/` and `lib/`. Human developers retain standard Git authority
over `.githooks/*`.

### 2.7 Test Harnesses Must Install the Library Beside the Hook

`tests/pre-commit_test.sh:17` copies the hook alone into `.git/hooks/pre-commit`, and
`tests/write-guard_test.sh:20` copies the guard alone into `.githooks/`. After this plan both hooks
resolve the library from their own directory, so both harnesses must copy `aapp-lib.sh` beside the
hook — otherwise the fail-closed load (§2.5) refuses every commit in both suites.

### 2.8 Known Skew Window

`lib/cmd_plan.sh` sources the library live, while hooks run their installed copy until the next
`aapp init`. Between a library change and the next init, `plan-status` and the hooks can parse
differently. This is no worse than today's independent copies, and running `aapp init` after
merge closes it.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Failure-first: behavioral regression tests are authored and confirmed Red 🔴 before the library exists.*

### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/write-guard_test.sh::test_blockquote_path_denied` -> asserts write-guard blocks writes to backticked path declared inside blockquote (#82 defect 1 Red)
- [ ] `tests/write-guard_test.sh::test_foreign_subsection_path_denied` -> asserts write-guard blocks writes to path declared inside non-whitelisted trailing subsection (e.g. `### 📝 Implementation Notes`) (#82 defect 2 Red)
- [ ] `tests/write-guard_test.sh::test_required_test_files_path_allowed` -> asserts write-guard permits edits to path declared in `### 🧪 Required Test Files` (Option A E2E Green)
- [ ] `tests/pre-commit_test.sh::test_blockquote_path_denied` -> asserts pre-commit blocks staged commit to backticked path declared inside blockquote (#82 defect 1 Red)
- [ ] `tests/pre-commit_test.sh::test_foreign_subsection_path_denied` -> asserts pre-commit blocks staged commit to path declared inside non-whitelisted trailing subsection (e.g. `### 📝 Implementation Notes`) (#82 defect 2 Red)
- [ ] `tests/pre-commit_test.sh::test_required_test_files_path_allowed` -> asserts pre-commit permits staged commits to path declared in `### 🧪 Required Test Files` (Option A E2E Green)
- [ ] `tests/aapp_lib_test.sh::test_blockquote_not_parsed` -> pure function asserts backticked path in blockquote line is ignored
- [ ] `tests/aapp_lib_test.sh::test_foreign_subsection_ends_region` -> pure function asserts non-whitelisted subsection ends target collection
- [ ] `tests/aapp_lib_test.sh::test_emergency_hotfix_is_parsed` -> pure function asserts paths under emergency hotfix section are returned
- [ ] `tests/aapp_lib_test.sh::test_emergency_hotfix_after_oob` -> pure function asserts emergency hotfix is parsed even when declared after Out of Bounds
- [ ] `tests/aapp_lib_test.sh::test_required_test_files_is_parsed` -> pure function asserts paths under `### 🧪 Required Test Files` are returned as write targets (Option A)
- [ ] `tests/aapp_lib_test.sh::test_required_tests_checklist_not_parsed` -> pure function asserts `### 🧪 Required Tests` section does not trigger target collection (no prefix bleed)
- [ ] `tests/aapp_lib_test.sh::test_new_file_marker_skipped` -> pure function asserts `NEW FILE` and lifecycle prefix markers are stripped and actual target path is extracted
- [ ] `tests/aapp_lib_test.sh::test_fenced_example_not_parsed` -> pure function asserts a target-bearing heading inside a fenced code block contributes no targets
- [ ] `tests/aapp_lib_test.sh::test_heading_outside_section4_not_parsed` -> pure function asserts a target-bearing heading outside `## 💥 4.` contributes no targets
- [ ] `tests/aapp_lib_test.sh::test_extract_plan_section` -> pure function asserts `extract_plan_section` extracts numbered markdown section `## N.` from stdin
- [ ] `tests/aapp_lib_test.sh::test_oob_paths_parsed` -> pure function asserts paths under Out of Bounds are returned while blockquotes and subsequent headings are ignored
- [ ] `tests/aapp_lib_test.sh::test_aapp_os_branches` -> asserts parameterized `aapp_os` correctly detects all platform branches (`linux`, `darwin`, `windows`, `wsl`, `bsd`, `unknown`)
- [ ] `tests/aapp_lib_test.sh::test_no_foreign_target_parsers_in_repo` -> structural test asserting no inline `awk` parsers for named target/OOB/section headings exist in `lib/` or `templates/` outside `lib/aapp-lib.sh`
- [ ] `tests/aapp_lib_test.sh::test_source_is_inert` -> asserts sourcing the library produces no output and changes no caller shell options
- [ ] `tests/pre-commit_test.sh::test_missing_library_refuses_commit` -> asserts a hook with no `aapp-lib.sh` beside it exits 1 with a diagnostic, never commits unguarded
- [ ] `tests/install_test.sh::test_init_installs_library_as_real_file` -> asserts `aapp init` installs `.githooks/aapp-lib.sh` as a regular file, not a symlink
- [ ] `tests/install_test.sh::test_init_fails_loudly_when_lib_missing` -> asserts `aapp init` exits non-zero with an OS-aware diagnostic if `$AAPP_LIB/aapp-lib.sh` is missing
- [ ] `tests/install_test.sh::test_install_preserves_template_symlink` -> asserts `aapp install` leaves `templates/aapp-lib.sh` as a symlink resolving inside the installed kit

### Phase 1: True Failure-First Behavioral Tests (Red 🔴)
- [ ] Task 1.1: Author behavioral regression tests `test_blockquote_path_denied` and `test_foreign_subsection_path_denied` (using `### 📝 Implementation Notes`) in `tests/write-guard_test.sh` and `tests/pre-commit_test.sh`; run against unpatched code and confirm FAIL (Red 🔴).
- [ ] Task 1.2: Add missing-library, loud-init-failure, and symlink tests to `tests/pre-commit_test.sh` and `tests/install_test.sh`; confirm they FAIL (Red 🔴).

### Phase 2: Library & Layout (Green 🟢)
- [ ] Task 2.1: Create `lib/aapp-lib.sh` with `parse_plan_target_paths` (recognizing Target Files, Emergency Hotfix, and Required Test Files with exact regexes and lifecycle marker stripping), `parse_plan_oob_paths`, `extract_plan_section`, `glob_to_regex`, `match_pattern_list`, `aapp_os`, and `aapp_lib_loaded`.
- [ ] Task 2.2: Create the tracked symlink `templates/aapp-lib.sh -> ../lib/aapp-lib.sh`.
- [ ] Task 2.3: In `lib/cmd_init.sh`, install `aapp-lib.sh` into `.githooks/` strictly from `$AAPP_LIB/aapp-lib.sh`; fail loudly with `aapp_os` diagnostic if missing.
- [ ] Task 2.4: Author `tests/aapp_lib_test.sh` covering pure parser functions, exact regex boundary isolation, marker stripping (`NEW FILE`), `extract_plan_section`, all `aapp_os` parameterized branches, inertness, and confirm Green 🟢.

### Phase 3: Consumer Migration
- [ ] Task 3.1: `lib/cmd_plan.sh` — delete `parse_plan_target_paths`; source `"$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"` with fail-closed load check.
- [ ] Task 3.2: `lib/planning_health.sh` — delete inline `get_plan_targets` in Pair 7; source `"$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh"` with fail-closed load check and invoke `parse_plan_target_paths`.
- [ ] Task 3.3: `templates/aapp-pre-commit` and `templates/blast-radius-guard.sh` — replace `parse_plan_section` calls with `parse_plan_target_paths` and `parse_plan_oob_paths`; replace inline `extract_plan_section` in `templates/aapp-pre-commit` with library call; delete inline `parse_plan_section`, `extract_plan_section`, `glob_to_regex` and `match_pattern_list`; add the §2.5 fail-closed load.
- [ ] Task 3.4: `tests/pre-commit_test.sh` and `tests/write-guard_test.sh` — copy `aapp-lib.sh` beside the hook under test (§2.7); add `test_required_test_files_path_allowed`; confirm Phase 1 behavioral tests now turn Green 🟢.
- [ ] Task 3.5: Run structural assertion `test_no_foreign_target_parsers_in_repo` with scoped regexes and confirm Green 🟢 across the repo.

### Phase 4: Regression & Platform Verification
- [ ] Task 4.1: Run `./aapp test strict quiet` across all discovered suites; zero regressions.
- [ ] Task 4.2: Verify the §2.1 install/init symlink behaviour on macOS (BSD `cp`) (Manual Platform Verification step); record the result in §6.
- [ ] Task 4.3: Run `aapp init` on this repository (sanctioned propagation step) so its own `.githooks/` receives the library, and confirm `aapp plan-status` no longer lists the phantom `backticked path` target.

### Phase 5: Documentation
- [ ] Task 5.1: `ARCHITECTURE.md` and `.agents/ARCHITECTURE.md` — record the shared-library rule (pure functions, `lib/` source, `templates/` symlink, `.githooks/` copy), `aapp_os`, and the target/OOB parser boundary rules.
- [ ] Task 5.2: `.agents/CODEMAP.md` — name `lib/aapp-lib.sh` as the canonical owner of plan-section parsing and OS detection.
- [ ] Task 5.3: `CHANGELOG.md` under `### Fixed` (#82) and `### Changed` (shared library).

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/aapp-lib.sh` -> Shared pure-function library: parser (whitelisted headings), section extractor, glob helpers, aapp_os, load sentinel
- [ ] `NEW FILE` -> `templates/aapp-lib.sh` -> Tracked symlink to ../lib/aapp-lib.sh
- [ ] `NEW FILE` -> `tests/aapp_lib_test.sh` -> Parser regression, structural test, aapp_os, and inertness tests
- [ ] `lib/cmd_plan.sh` -> Replace parse_plan_target_paths with the shared library via self-relative source
- [ ] `lib/planning_health.sh` -> Replace Pair 7 get_plan_targets with the shared library via self-relative source
- [ ] `lib/cmd_init.sh` -> Install aapp-lib.sh into .githooks with loud failure on missing library
- [ ] `templates/aapp-pre-commit` -> Remove inline parser, section extractor, and helpers; add fail-closed library load
- [ ] `templates/blast-radius-guard.sh` -> Remove inline parser and helpers; add fail-closed library load
- [ ] `tests/pre-commit_test.sh` -> Copy library beside hook; behavioral regression and missing-library tests
- [ ] `tests/write-guard_test.sh` -> Copy library beside guard; behavioral regression tests
- [ ] `tests/install_test.sh` -> Install, init, and missing-library failure tests
- [ ] `ARCHITECTURE.md` -> Shared-library, aapp_os, and parser-boundary rules
- [ ] `.agents/ARCHITECTURE.md` -> Shared-library, aapp_os, and parser-boundary rules in agent architecture mapping
- [ ] `.agents/CODEMAP.md` -> Name the library's ownership
- [ ] `CHANGELOG.md` -> Record under Fixed and Changed

### 🧪 Required Test Files
> Test files that prove this plan's failure cases and boundary invariants. Frozen with the blast radius;
> per-test assertions are tracked in §3 (Option A Dogfooding).
- `tests/aapp_lib_test.sh`
- `tests/pre-commit_test.sh`
- `tests/write-guard_test.sh`
- `tests/install_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Installed engine copies; refreshed only by `aapp init` (Sanctioned Propagation).
- [ ] `lib/plan_states.sh` -> Status registry; Status-regex consolidation deferred to follow-up (#85).
- [ ] `.agents/skills/*` -> Governance skills self-protection.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Consolidate the Status-line regex here?** RESOLVED: Defer to a dedicated follow-up plan (tracked under Issue #85). Keeping P-37 laser-focused on Issue #82 (target and OOB parsing), `aapp_os`, and hook library infrastructure prevents blast radius expansion into `lib/plan_states.sh` and across 22 status call sites.
* [x] **Question 2 — Windows symlink support & OS detection.** RESOLVED: Handled cleanly in `lib/cmd_init.sh`. Instead of relying on symlink dereferencing or silent fallbacks, `init` copies strictly from `$AAPP_LIB/aapp-lib.sh` (always an authentic regular file) and fails loudly with an `aapp_os` diagnostic if missing.

### Dependencies & Sequencing
- **After `P-36`:** `P-36` is completed and archived (`ae1ff90` on `develop`, `8dbe3ee` on `plans`); P-37 is fully unblocked.
- **Before `P-34`:** both target `lib/cmd_plan.sh`.
- **Concurrency constraint on Issue #84:** Issue #84 targets `templates/blast-radius-guard.sh`, which is in P-37 Target Files. Per Pair 7 (In-Flight Boundary Collision), Issue #84 cannot be placed in development concurrently with P-37 and must be executed in sequence.
- **Prerequisite in `P-34`:** satisfied in `P-34` (`f26ff3e`), where `tests/install_test.sh` was explicitly added to Target Files.
- **Tri-Plan Sequence (`P-37` -> `P-34` -> `P-35`):**
  1. `P-37` executes first: establishes `lib/aapp-lib.sh`, fixes `#82` parser defects, and whitelists `### 🧪 Required Test Files` as target-bearing (Option A).
  2. `P-34` executes second: formalizes verb contracts using `path::name -> condition` in §3.
  3. `P-35` executes third: implements opt-in failure-test declaration (`aapp tdd`, `/aapp-tdd`), adds `parse_plan_required_test_files` and `parse_plan_required_tests` to `lib/aapp-lib.sh`, and enforces §3↔§4 correspondence. Under Option A, test files declared under `### 🧪 Required Test Files` automatically receive write access without double-entry into `### 📂 Target Files`.

---

## 📦 6. Change Log & Refinement History
* **2026-09-27:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-09-27:** Drafted from `#82`, widened to cover both parser defects (blockquote parsing and
  section-boundary bleed). Layout settled after comparing options: the source lives in `lib/`
  because it is shared code, and a tracked symlink in `templates/` keeps that directory the complete
  install manifest — verified through `cp -r` (install) and plain `cp` (init). A copy in
  `.githooks/` is kept even though `P-36` guarantees an installed kit, so every contributor enforces
  the same parser version. Hard links were rejected after testing: `sed -i` silently breaks the link
  leaving stale content, and git stores no link, so clones receive independent copies.
* **2026-09-27 (Refinement 1):** Adversarial review updates: added `parse_plan_oob_paths` to library
  specification and hook migrations to eliminate `parse_plan_section` without breaking Out-of-Bounds
  rejections; added direct `$AAPP_LIB/aapp-lib.sh` copy in `lib/cmd_init.sh` to guarantee Windows
  symlink resilience; added `.agents/ARCHITECTURE.md` to Target Files to ensure doc sync compliance;
  resolved Q1 (deferred to follow-up) and Q2 (mitigated); updated status to `📝 Refining`.
* **2026-09-27 (Refinement 2 - Red Team Feedback):**
  1. Identified and migrated fourth parser copy in `lib/planning_health.sh:576` (`get_plan_targets`, Pair 7); added to Target Files.
  2. Incorporated pure-function OS detection helper `aapp_os` (`linux`, `darwin`, `windows`, `wsl`, `bsd`, `unknown`) into `lib/aapp-lib.sh`.
  3. Replaced silent symlink fallbacks in `cmd_init.sh` with strict `$AAPP_LIB` copying and loud failure with OS diagnostic.
  4. Redesigned Red phase to run against observable CLI/hook fixtures rather than non-existent functions.
  5. Replaced tautological agreement test with structural test asserting zero foreign parser copies exist in the repository.
  6. Clarified `aapp init` as the sanctioned procedural propagation mechanism to `.githooks/`.
  7. Marked P-34 prerequisite as satisfied (`f26ff3e`). Confirmed Q1 deferred and #84 kept separate.
* **2026-09-27 (Refinement 3 - Execution Invariants & Sourcing):**
  1. Mandated self-relative sourcing (`$(dirname "${BASH_SOURCE[0]}")/aapp-lib.sh`) in `lib/` modules to eliminate `$AAPP_LIB` dependency when called outside the dispatcher.
  2. Restored true failure-first Red phase with behavioral denial assertions (`tests/write-guard_test.sh`, `tests/pre-commit_test.sh`) against unpatched code.
  3. Parameterized `aapp_os [uname_s] [proc_version_path]` for deterministic unit testing of all platform branches without host mocking; documented WSL GNU userland invariant.
  4. Specified exact regex `/^[#]{3}[[:space:]]*📂 Target Files/` for structural parser assertions.
  5. Logged Issue #85 in `ISSUES.md` and `issues_road_map.md` to canonically track deferred Status regex consolidation.
  6. Added sequencing constraint for Issue #84; marked macOS BSD `cp` verification as manual.
* **2026-09-27 (Refinement 4 - Tri-Plan Alignment RFC Consensus):**
  1. Adopted Option A from consensus RFC (`tri-plan-alignment-34-35-37.md`): whitelisted `### 🧪 Required Test Files` as the third target-bearing section, granting write access to declared test files without requiring redundant double-entry in `Target Files`.
  2. Defined exact regex contract anchored with `(\(.*)?$` across all four boundary headings (`Target Files`, `Emergency Hotfix Extensions`, `Required Test Files`, `Out of Bounds`) to eliminate prefix collision with §3 `### 🧪 Required Tests`.
  3. Relocated `extract_plan_section` from `templates/aapp-pre-commit:581` to `lib/aapp-lib.sh`, making the shared library the single owner of plan section parsing.
  4. Widened library purity rule in §2.3 to "arguments or stdin in, stdout out" to accommodate stream-filtering helpers like `extract_plan_section`.
  5. Preserved ticked checkbox parsing (`-[x]`/`-[X]`) alongside plain bullets in target collection.
  6. Scoped structural parser assertion `test_no_foreign_target_parsers_in_repo` to named heading patterns.
  7. Formally updated tri-plan sequencing (`P-37` -> `P-34` -> `P-35`) and removed obsolete double-entry assumption for P-35.
* **2026-09-27 (Refinement 5 - Red Team Review Findings):**
  1. Fixed blocking `NEW FILE` stripping bug in §2.4: retained both prefix `sub()` and guard check for lifecycle markers (`NEW FILE`, `MODIFY`, etc.) so targets preceded by markers are parsed correctly; added `test_new_file_marker_skipped`.
  2. Added positive E2E tests `test_required_test_files_path_allowed` in `write-guard_test.sh` and `pre-commit_test.sh`; updated foreign subsection test fixture to non-whitelisted heading `### 📝 Implementation Notes`.
  3. Formally dogfooded Option A in P-37 itself by adding `### 🧪 Required Test Files` under §4.
  4. Generalized heading termination to `^#+[[:space:]]` not whitelisted (covering `####`).


* **2026-09-27 (Refinement 6 - RFC review of `a5c229a`):**
  1. Scoped target-bearing and Out of Bounds headings to `## 💥 4.` and skipped fenced code blocks; `P-35` §2.2's quoted example heading would otherwise grant three paths. Added `test_fenced_example_not_parsed` and `test_heading_outside_section4_not_parsed`.
  2. Dropped the `.plans/current/*.md` Out of Bounds line: its glob matches this plan's own file, and the guard allows `.plans/*` before reading any plan.
