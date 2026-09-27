# 🗺️ Plan P-37: Shared Hook Library
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #82
* **Plan ID:** P-37
* **Status:** 📝 Refining
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
The Target Files parser exists as three near-verbatim copies — `lib/cmd_plan.sh:105`
(`parse_plan_target_paths`), `.githooks/aapp-pre-commit:246` and `.githooks/blast-radius-guard:302`
(`parse_plan_section`) — and all three share two defects (`#82`):

1. **Blockquote prose is parsed as a target.** No copy skips `>` lines, so the template's own
   authoring-rule prose yields the phantom target `backticked path` on every plan. A backticked path
   in any §4 blockquote becomes writable.
2. **The section boundary bleeds.** The region ends only at `### 🛑 Out of Bounds` or a `## `
   heading, so any other `###` subsection placed after Target Files is absorbed and every backticked
   path in it becomes a write target. `P-34`'s `### 🧪 Required Test Files` is live proof: it grants
   `tests/install_test.sh` write access that is declared nowhere.

Both defects widen the blast radius silently, and because the parser is copied, every fix must be
made three times — which is how copies drift. The duplication is wider than the parser:
`glob_to_regex` and `match_pattern_list` are copied between both hooks, and the Status-line regex
appears 22 times across `lib/cmd_plan.sh`, both hooks and `lib/plan_states.sh`.

**Why the copies exist.** Hooks are installed into `.githooks/`, a committed branch shared with the
team, and deliberately source nothing: enforcement must not depend on a particular machine's kit.
Duplication was the price of that self-containment.

### Architectural Goal
One shared, pure-function library that the CLI and both hook engines source, fixing `#82` once.

1. **Single source** at `lib/aapp-lib.sh` — it is shared code, and `lib/` is where kit code lives.
2. **`templates/` remains the complete install manifest** via a tracked symlink
   `templates/aapp-lib.sh -> ../lib/aapp-lib.sh`.
3. **Hooks stay self-contained and version-locked**: `aapp init` installs a real copy into
   `.githooks/aapp-lib.sh`, and hooks source it from their own directory.
4. **The parser becomes fail-closed by construction**: only named target-bearing headings contribute
   targets; blockquotes never do.
5. **Out-of-Bounds enforcement is preserved**: `parse_plan_oob_paths` replaces `parse_plan_section`
   calls for `### 🛑 Out of Bounds` with equivalent fail-closed boundary isolation.
6. **A failed library load refuses the commit**, never degrades to unguarded.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. The three inline parser copies are deleted, not kept
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
| `lib/cmd_plan.sh` (and any kit code) | `$AAPP_LIB/aapp-lib.sh` |
| `.githooks/aapp-pre-commit`, `.githooks/blast-radius-guard` | `"$(dirname "$0")/aapp-lib.sh"` |

**Cross-Platform Install & Windows Resilience:**
`aapp install`'s `cp -r lib templates` preserves the relative symlink inside the installed kit.
In `lib/cmd_init.sh`, rather than blindly trusting `templates/aapp-lib.sh` (which on Windows clones with
`core.symlinks=false` checks out as a 1-line text file containing `../lib/aapp-lib.sh`), `cmd_init.sh`
copies from `$AAPP_LIB/aapp-lib.sh` directly (falling back to `cp -L "$AAPP_TEMPLATES/aapp-lib.sh"`).
This guarantees `.githooks/aapp-lib.sh` is always written as a functional regular file on all operating
systems, while `templates/` continues to represent the complete manifest for Unix packages.

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

- **Allowed:** functions that take arguments and write to stdout — `parse_plan_target_paths`,
  `parse_plan_oob_paths`, `glob_to_regex`, `match_pattern_list`, and a load sentinel `aapp_lib_loaded`.
- **Forbidden:** top-level statements with side effects, `set` options that alter the caller, reads
  of the `aapp` environment, and repository-root resolution. `P-33` showed root resolution is
  context-dependent (some callers must derive, others inherit), so it is not a pure function.
- The Status-line regex is a consolidation candidate but deferred to a dedicated follow-up plan (§5 Q1).

### 2.4 Parser Boundary Rules (fixes both `#82` defects for Target Files & OOB)

1. **Target Files (`parse_plan_target_paths`):**
   > Only target-bearing headings contribute targets. The parser collects paths under
   > `### 📂 Target Files` and `### 🚨 Emergency Hotfix Extensions` only. **Any** other heading
   > (`^### ` or `^## `) ends the region. Lines beginning with `>` are never parsed.
   
   This inverts the current rule from *"every subsection grants write access unless excluded"* to
   *"only named sections grant it"* — fail-closed by construction. Test files declared under
   `### 🧪 Required Test Files` (`P-34`, `P-35`) no longer grant write access and must be listed
   in Target Files explicitly.

2. **Out of Bounds (`parse_plan_oob_paths`):**
   > Collects paths declared under `### 🛑 Out of Bounds` only. **Any** subsequent heading
   > (`^### ` or `^## `) ends the region. Lines beginning with `>` are never parsed.

Both `templates/aapp-pre-commit` and `templates/blast-radius-guard.sh` call both functions to populate
`PLAN_TARGETS` and `PLAN_OOB`, completely eliminating the legacy, bleed-prone `parse_plan_section` helper.

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

### 2.6 Protection Model — No Guard Change

| | Protected? | Changes by |
| :--- | :--- | :--- |
| `lib/aapp-lib.sh` (source) | No | An ordinary plan listing it as a target, with tests |
| `.githooks/aapp-lib.sh` (installed) | Yes — already, via the existing `.githooks/*` pattern | `aapp init` only |

This mirrors how the hook engines are handled today: `templates/blast-radius-guard.sh` is editable
under a plan, the installed copy is locked, and `aapp init` propagates. Protecting the source would
make the parser unfixable without bypassing the guard. **Honest limit:** the propagation step is
procedural — an agent can run `aapp init` through the shell, which the guard cannot see. The
parser's regression tests (§3) are what actually protect it.

### 2.7 Test Harnesses Must Install the Library Beside the Hook

`tests/pre-commit_test.sh:17` copies the hook alone into `.git/hooks/pre-commit`, and
`tests/write-guard_test.sh:20` copies the guard alone into `.githooks/`. After this plan both hooks
resolve the library from their own directory, so both harnesses must copy `aapp-lib.sh` beside the
hook — otherwise the fail-closed load (§2.5) refuses every commit in both suites.

### 2.8 Known Skew Window

`lib/cmd_plan.sh` sources the library live, while hooks run their installed copy until the next
`aapp init`. Between a library change and the next init, `plan-status` and the hooks can parse
differently. This is no worse than today's three independent copies, and running `aapp init` after
merge closes it.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Failure-first: regression tests are authored and confirmed Red 🔴 before the library exists.*

### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/aapp_lib_test.sh::test_blockquote_not_parsed` -> asserts a backticked path inside a `>` line under Target Files is not returned (#82 defect 1)
- [ ] `tests/aapp_lib_test.sh::test_foreign_subsection_ends_region` -> asserts paths under `### 🧪 Required Test Files` placed after Target Files are not returned (#82 defect 2)
- [ ] `tests/aapp_lib_test.sh::test_emergency_hotfix_is_parsed` -> asserts paths under `### 🚨 Emergency Hotfix Extensions` are returned
- [ ] `tests/aapp_lib_test.sh::test_oob_paths_parsed` -> asserts paths under `### 🛑 Out of Bounds` are returned while blockquotes and subsequent headings are ignored
- [ ] `tests/aapp_lib_test.sh::test_consumers_agree` -> asserts `cmd_plan.sh`, the pre-commit hook and the write-guard return identical targets for the same plan
- [ ] `tests/aapp_lib_test.sh::test_source_is_inert` -> asserts sourcing the library produces no output and changes no caller shell options
- [ ] `tests/pre-commit_test.sh::test_missing_library_refuses_commit` -> asserts a hook with no `aapp-lib.sh` beside it exits 1 with a diagnostic, never commits unguarded
- [ ] `tests/install_test.sh::test_init_installs_library_as_real_file` -> asserts `aapp init` installs `.githooks/aapp-lib.sh` as a regular file, not a symlink
- [ ] `tests/install_test.sh::test_install_preserves_template_symlink` -> asserts `aapp install` leaves `templates/aapp-lib.sh` as a symlink resolving inside the installed kit

### Phase 1: Failure-First Regression Tests (Red 🔴)
- [ ] Task 1.1: Author `tests/aapp_lib_test.sh` with the parser and inertness tests above, run against the current inline parsers, and confirm the two `#82` tests FAIL.
- [ ] Task 1.2: Add the missing-library and install/init tests to `tests/pre-commit_test.sh` and `tests/install_test.sh`; confirm they FAIL.

### Phase 2: Library & Layout (Green 🟢)
- [ ] Task 2.1: Create `lib/aapp-lib.sh` with `parse_plan_target_paths`, `parse_plan_oob_paths`, `glob_to_regex`, `match_pattern_list`, and `aapp_lib_loaded`.
- [ ] Task 2.2: Create the tracked symlink `templates/aapp-lib.sh -> ../lib/aapp-lib.sh`.
- [ ] Task 2.3: In `lib/cmd_init.sh`, install `aapp-lib.sh` into `.githooks/` from `$AAPP_LIB/aapp-lib.sh` (with `cp -L` fallback) alongside hook engines, ensuring cross-platform symlink resilience.
- [ ] Task 2.4: Re-run Phase 1 parser tests and confirm Green 🟢.

### Phase 3: Consumer Migration
- [ ] Task 3.1: `lib/cmd_plan.sh` — delete `parse_plan_target_paths`; source `$AAPP_LIB/aapp-lib.sh`.
- [ ] Task 3.2: `templates/aapp-pre-commit` and `templates/blast-radius-guard.sh` — replace `parse_plan_section` calls with `parse_plan_target_paths` and `parse_plan_oob_paths`; delete inline `parse_plan_section`, `glob_to_regex` and `match_pattern_list`; add the §2.5 fail-closed load.
- [ ] Task 3.3: `tests/pre-commit_test.sh` and `tests/write-guard_test.sh` — copy `aapp-lib.sh` beside the hook under test (§2.7).
- [ ] Task 3.4: Re-run all Phase 1 tests and confirm Green 🟢, including `test_consumers_agree`.

### Phase 4: Regression & Platform Verification
- [ ] Task 4.1: Run `./aapp test strict quiet` across all discovered suites; zero regressions.
- [ ] Task 4.2: Verify the §2.1 install/init symlink behaviour on macOS (BSD `cp`); record the result in §6.
- [ ] Task 4.3: Run `aapp init` on this repository so its own `.githooks/` receives the library, and confirm `aapp plan-status` no longer lists the phantom `backticked path` target.

### Phase 5: Documentation
- [ ] Task 5.1: `ARCHITECTURE.md` and `.agents/ARCHITECTURE.md` — record the shared-library rule (pure functions, `lib/` source, `templates/` symlink, `.githooks/` copy) and the target/OOB parser boundary rules.
- [ ] Task 5.2: `.agents/CODEMAP.md` — name `lib/aapp-lib.sh` as the canonical owner of plan-section parsing.
- [ ] Task 5.3: `CHANGELOG.md` under `### Fixed` (#82) and `### Changed` (shared library).

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/aapp-lib.sh` -> Shared pure-function library: parser, glob helpers, load sentinel
- [ ] `NEW FILE` -> `templates/aapp-lib.sh` -> Tracked symlink to ../lib/aapp-lib.sh
- [ ] `NEW FILE` -> `tests/aapp_lib_test.sh` -> Parser regression, consumer agreement and inertness tests
- [ ] `lib/cmd_plan.sh` -> Replace parse_plan_target_paths with the shared library
- [ ] `lib/cmd_init.sh` -> Install aapp-lib.sh into .githooks alongside the hook engines
- [ ] `templates/aapp-pre-commit` -> Remove inline parser and helpers; add fail-closed library load
- [ ] `templates/blast-radius-guard.sh` -> Remove inline parser and helpers; add fail-closed library load
- [ ] `tests/pre-commit_test.sh` -> Copy library beside hook; missing-library test
- [ ] `tests/write-guard_test.sh` -> Copy library beside guard
- [ ] `tests/install_test.sh` -> Install and init library tests
- [ ] `ARCHITECTURE.md` -> Shared-library and parser-boundary rules
- [ ] `.agents/ARCHITECTURE.md` -> Shared-library and parser-boundary rules in agent architecture mapping
- [ ] `.agents/CODEMAP.md` -> Name the library's ownership
- [ ] `CHANGELOG.md` -> Record under Fixed and Changed

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Installed engine copies; refreshed only by `aapp init` (Architectural Rule 3).
- [ ] `lib/plan_states.sh` -> Status registry; Status-regex consolidation deferred to follow-up.
- [ ] `.agents/skills/*` -> Governance skills self-protection.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Consolidate the Status-line regex here?** RESOLVED: Defer to a dedicated follow-up plan. Keeping P-37 laser-focused on Issue #82 (target and OOB parsing) and hook library infrastructure prevents blast radius expansion into `lib/plan_states.sh` and across 22 status call sites.
* [x] **Question 2 — Windows symlink support.** RESOLVED: Handled cleanly in `lib/cmd_init.sh`. Instead of relying solely on the symlink in `templates/`, `init` copies directly from `$AAPP_LIB/aapp-lib.sh` (which is always a real file) with `cp -L` fallback, ensuring complete cross-platform resilience even when cloned with `core.symlinks=false`.

### Dependencies & Sequencing
- **After `P-36`:** `P-36` is completed and archived (`ae1ff90` on `develop`, `8dbe3ee` on `plans`); P-37 is fully unblocked.
- **Before `P-34`:** both target `lib/cmd_plan.sh`.
- **Prerequisite in `P-34`:** add `tests/install_test.sh` to its Target Files explicitly. Today it
  reaches that file only through the boundary bleed this plan removes; without the addition, `P-34`
  loses write access when this plan lands.
- **Constraint on `P-35`:** under §2.4, `### 🧪 Required Test Files` grants no write access, so the
  injection verb must also add declared test files to Target Files.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-27:** Drafted from `#82`, widened to cover both parser defects (blockquote parsing and
  section-boundary bleed). Layout settled after comparing options: the source lives in `lib/`
  because it is shared code, and a tracked symlink in `templates/` keeps that directory the complete
  install manifest — verified through `cp -r` (install) and plain `cp` (init). A copy in
  `.githooks/` is kept even though `P-36` guarantees an installed kit, so every contributor enforces
  the same parser version. Hard links were rejected after testing: `sed -i` silently breaks the link
  leaving stale content, and git stores no link, so clones receive independent copies.
* **2026-09-27 (Refinement):** Adversarial review updates: added `parse_plan_oob_paths` to library
  specification and hook migrations to eliminate `parse_plan_section` without breaking Out-of-Bounds
  rejections; added direct `$AAPP_LIB/aapp-lib.sh` copy in `lib/cmd_init.sh` to guarantee Windows
  symlink resilience; added `.agents/ARCHITECTURE.md` to Target Files to ensure doc sync compliance;
  resolved Q1 (deferred to follow-up) and Q2 (mitigated); updated status to `📝 Refining`.

