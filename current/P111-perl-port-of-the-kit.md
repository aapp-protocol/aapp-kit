# 🧩 Group Plan P-111: Perl Port Of The Kit
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Plan ID:** P-111
* **Changelog:** Changed: port the kit runtime, hooks and test harness from bash to Perl 5.26+ with a single-pass workspace state model, decorative-only emojis and a built-in JSON engine (P-111)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Feature Branch:** none
* **Members:** P-113, P-114, P-115, P-116, P-117, P-118, P-119, P-120, P-121, P-122, P-112
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-111` (or `aapp refine <id> group P-111`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
The kit's design holds; its cost is ~20.5k lines of bash spawning ~45k processes in a single verb suite (`1,494 s` CPU across 1,764 assertions, `sys > user` 2:1). This group ports the test harness, hooks, and CLI verbs from bash (and `python3` JSON helpers) to Perl 5.26+:
1. **Slim and modularize the test suite (`P-113`, `P-114`):** keep verb behaviour and core wrapper tests, fold `#nnn` regressions into behaviour tests, add `lib/docs/core/<module>.md` contracts, and move to the `AAPP::Tests` Perl harness (`Logsniffer::Tests` model) with per-test fixture copies, `die`-based diagnostics, parallel module workers, and an end-of-run failure recap.
2. **Single-pass Perl core and state model (`P-115`):** read `git config`, paths, active-plan buffer, `.plans/current/*.md`, plan states, and ledgers once per process (`AAPP::State`), with a single deterministic kit JSON module (`AAPP::JSON`, retiring `python3`) and decorative-only emoji normalization (`AAPP::Text`).
3. **Port hooks and verbs by slice (`P-116`–`P-121`), then remove bash (`P-122`):** hooks first (cutting process spawns on every commit across all suites), then the issue/offline lane, read-only verbs, plan lifecycle, commit/integration, and setup/release, ending with a clean break removing all legacy `.sh` libraries.

Design & measurements: `.plans/pickup/perl-port-rfc.md` (settled 2026-10-19). Merge criterion: every member archived and the `pre-done` gate green on `feature/perl-port-of-the-kit`.

## 2. Shared Decisions
- **Perl floor & dependencies:** Perl `5.26` (`use 5.026; use strict; use warnings; use utf8;`). Core modules only (`Digest::SHA`, `File::Spec`, `File::Path`, `File::Basename`, `File::Copy`, `POSIX`, `Time::HiRes`, `Cwd`). Zero CPAN dependencies.
- **One kit JSON module (`AAPP::JSON`), never `JSON::PP`:** `JSON::PP` is absent from Debian's `perl-base`, packaged apart on Fedora/RHEL, and Perl hash order / alphabetical `canonical` sorting violates the table-order contract (`docs/reference/08-output-json.md`). `AAPP::JSON` provides an ordered `@_` key-value builder (`json_obj(k1 => $v1, ...)`), 2-space pretty-printer, and reader for write-guard payloads, `.claude/settings.json`, and pause snapshots — replacing `python3` everywhere (folding in the "Perl in place of python3" pickup entry).
- **Emojis are decorative only (`AAPP::Text`):** Every parser normalizes headings, statuses, and table cells by stripping leading non-ASCII symbols/emojis and spaces via `^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s])+`. This strips all kit emojis (including `ℹ️` U+2139 `Ll`, arrows `Sm`, skin tones `Sk`, keycaps `Me`) while keeping leading ASCII symbols (`` ` ``, `$`, `~`) and accented/non-Latin letters (`Árak`, `日本語`). Emojis are emitted for human readers only and never required when reading back.
- **One workspace state read per process (`AAPP::State`):** One `git config --list -z` and one `git rev-parse --show-toplevel --git-common-dir --git-dir` per process, plus one in-memory pass over `aapp_active_plan`, `.plans/current/*.md` (headers, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), plan states, and ledgers. Hooks and verbs query `AAPP::State` in memory.
- **Strict top-level boundary during the port (`P-115`–`P-121`):** `aapp` routes ported verbs to `AAPP::Cmd::<Verb>` in Perl and unported verbs to `lib/cmd_<verb>.sh` in bash. Unported bash verbs continue sourcing `lib/*.sh` until ported; bash never shells out to Perl per-helper inside loops. `aapp init` copies `lib/AAPP/*.pm` into `.githooks/AAPP/` alongside the hooks so `.githooks/` works standalone in any clone without a build step.
- **Tests or code, never both:** `P-113` and `P-114` change only tests, contracts, and the test runner (`lib/cmd_test.sh`, `.agents/hooks/test-gate.sh`); `P-115`–`P-122` change only kit code (`lib/`, `templates/`, `aapp`), verified by the unchanged Perl test suite. Feature freeze on `lib/` and `templates/` once `P-114` lands.
- **Modular test harness (`AAPP::Tests`):** Each test module (`lib/AAPP/Tests/Verb/*.pm`, `lib/AAPP/Tests/Core/*.pm`) is a plain list of `sub test_... { my ($self) = @_; ... }` with assertion/fixture helpers on `$self`. Test order and descriptions live in `lib/docs/verbs/<verb>.md` and `lib/docs/core/<module>.md` (`## Tests`), checked both ways by the contract test. Each module builds its initialized Git fixture once and copies it per test (rewriting the 6 `.git/worktrees` path files in-process) so any test runs alone. Modules run in parallel (`jobs N`), failures `die` with `file:line` + `rc`/`out`, and `not ok` lines are repeated after the summary banner (`test-gate.sh` prints from the summary line to the end).
- **Adopter plugins and hooks:** Keep the language-neutral JSON stdin + POSIX environment protocol unchanged.

## 3. Members & Order
1. **P-113** (`P113-slim-the-test-suites.md`): slim the bash suites to verb behaviour and core wrappers, fold `#nnn` regressions into behaviour tests, and author `lib/docs/core/<module>.md` contracts. Code untouched.
2. **P-114** (`P114-perl-test-harness.md`): build `AAPP::Tests` (`lib/AAPP/Tests.pm` + verb/core test modules), wire `aapp test` and `.agents/hooks/test-gate.sh` end-recap. Code untouched.
3. **P-115** (`P115-perl-core-and-state-model.md`): `AAPP::Config`, `AAPP::Paths`, `AAPP::Text` (emoji-free normalizer + wrap/cut), `AAPP::JSON` (retiring `python3`), `AAPP::State`, and `aapp` hybrid verb routing.
4. **P-116** (`P116-perl-hooks-and-write-guard.md`): port `aapp-pre-commit`, `aapp-commit-msg`, `aapp-post-commit`, `aapp-post-rewrite`, `blast-radius-guard.sh`, and `hook_dispatcher` to Perl over `AAPP::State` and `AAPP::JSON`.
5. **P-117** (`P117-perl-issue-and-offline-lane.md`): port `issue` (all subverbs) and `offline` to Perl.
6. **P-118** (`P118-perl-readonly-verbs.md`): port `status`, `matrix`, `plan-status`, and `help` to Perl.
7. **P-119** (`P119-perl-plan-lifecycle.md`): port `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` (`conflict-check`, `conflict-free`, `abort`) to Perl.
8. **P-120** (`P120-perl-commit-and-integration.md`): port `commit` (standard, `amend`, `adopt`, `land`), branch integration (`ff`, `squash`), `note`, and `ai` to Perl.
9. **P-121** (`P121-perl-setup-and-release.md`): port `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync` (`push`, `pull`, `sync`), `release`, `companion`, `hook`, `pause`/`resume`, and `test` to Perl.
10. **P-122** (`P122-remove-bash-clean-break.md`): remove legacy `lib/*.sh` and bash hook bodies; finalize `ARCHITECTURE.md` and `.agents/CODEMAP.md` sections on `P-111`.
11. **P-112** (`P112-perl-port-of-the-kit-amendments.md`): group amendments member (started with the group, archived last).

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
No changes.

### .agents/CODEMAP.md
No changes.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Group drafted and refined from settled RFC (`.plans/pickup/perl-port-rfc.md`).
