# Project Rules: Agent Planning Kit (AAPP)

How we build here. Agents read this before writing code; humans keep it true.
`CODEMAP.md` says **what exists** and how it is called; this file says **how to build**.
Try to keep each rule in one place only.

---

## 🧭 1. Project Summary
- **What it does:** A kit that keeps plans, agent rules and git hooks out of a project's source tree
  (orphan-branch worktrees `.plans/`, `.agents/`, `.githooks/`) and refuses agent edits and commits
  outside the files a started plan declares.
- **Who it is for:** many adopter projects, of any stack. Never key a rule to this repository's own
  paths; split it into a universal part and a part the adopter declares.
- **Stack:** Perl 5.26+ (core modules only) and git. No build step. The kit is being ported from
  Bash (group P-111): new code is Perl in `lib/AAPP/`; verbs not yet ported stay in `lib/*.sh` until
  P-122 removes them.
- **Run from a clone:** `./aapp develop` links this clone as the global `aapp`; `aapp test` runs the
  bash verb suites and `t/test-run` the Perl test files (one command from P-125).

## ✍️ 2. Code Style & Conventions
- **Perl:** every module starts `use 5.026; use strict; use warnings; use utf8;`. No sub named like
  a Perl built-in (`say`, `print`, `open` …). `// return` only for a single-value check. No warnings
  on paths every process runs.
- **Perl defaults and lists:** every default lives in `AAPP::Constants`; an allow-list sits at the
  top of its module; `AAPP::Paths::kit_dir` is the one kit locator; code works on every OS.
- **One implementation:** a helper used in more than one place lives in `AAPP::Util`; plan, status
  and ledger parsing in `AAPP::State` and `AAPP::Text`; JSON only through `AAPP::JSON`. Reuse them,
  never add another copy. (The bash verbs use `lib/aapp-lib.sh` until P-122.)
- **Shell (until P-122):** keep macOS's Bash 3.2 working — no associative arrays, no Bash 4+
  features; no GNU-only options (e.g. `sort -z`); iterate paths NUL-safely (`find -print0`);
  `shellcheck`, with `# shellcheck` directives next to what they explain.
- **Portability:** platforms not yet verified are listed in MANUAL §14, not logged as issues.
- **CLI arguments:** bare tokens (`aapp commit amend`, `aapp test strict`), never new `--flags`.
- **Clean breaks:** no compatibility aliases, shims or dual syntax unless the plan lists them under
  *Migration & Compatibility Strategy*. Before announcement, breaking changes are cheap.
- **Perl comments:** every sub has one header and nothing else above it: `# Usage :`, `# Purpose :`
  (at most 3 lines), `# Returns :`. No history, no issue or bug descriptions, no commented-out code;
  inside a sub, a one-line comment only where a line cannot say what it does.
- **Commits:** code goes through `aapp commit` while a plan is started; every code commit adds a
  `CHANGELOG.md` line; subject ≤ 72 characters; AI commits carry emailless `AI-Agent:` /
  `AI-Vendor:` / `AI-Model:` trailers.

## 📦 3. Libraries & Dependencies
- **Use:** Perl 5.26+ core modules only (`Digest::SHA`, `File::Spec`, `File::Path`,
  `File::Basename`, `File::Copy`, `POSIX`, `Time::HiRes`, `Cwd`) and git. The bash verbs still use
  coreutils, `awk`, `sed`, `grep`, and `sha256sum` or `shasum` until P-122.
- **Avoid:** CPAN modules (`JSON::PP` included: `AAPP::JSON` is the kit's JSON), `python3`, `jq`,
  network tools, package managers, and anything an adopter would have to install.
- **Adding a dependency:** needs a plan and the user's approval.

## 🚨 4. Error Handling
- **Fail closed.** No silent fallbacks (`|| true`, `|| pwd`, unchecked defaults) unless the reason is
  in a code comment and the plan lists it in its Fallback Inventory.
- **Messages:** Perl code prints through `AAPP::Logger::print_msg` (`[ TAG ] text`) and exits with
  the exit code of its return number (`RETURN_*` in `AAPP::Constants`); the log file
  (`aapp.perlLogFile`) is plain text, emoji stripped. The bash verbs print `❌ [Context] what went
  wrong` to stderr with a `👉` line for the fix, and exit `1`.
- **Perl fatal errors & stack traces:** Unrecoverable I/O or system errors use `die "System: <message>\n"`;
  internal protocol or state invariant violations use `die "AAPP: <message>\n"`. `AAPP::Runner`'s
  `$SIG{__DIE__}` handler intercepts them, formats them as `[FATAL ERROR]:[System|AAPP] <message> (file: <file> line: <line>)`
  with caller location and full call stack trace (under `DEBUG_LEVEL >= 1`), logs to the configured log file,
  and exits with `return_on_error()`. Never use untraced string warnings (`warn "..."`) or silent `return 0`
  fallbacks for unrecoverable errors.
- **Repository check:** the `aapp` dispatcher asserts a git repository once; commands rely on
  `REPO_ROOT` instead of re-deriving it.

Each command's refusals and exit behaviour are in its contract (`lib/docs/verbs/<verb>.md`) and in
`CODEMAP.md`.

## 🧪 5. Testing
- **Location:** Perl test files `t/core/<name>.t` (contracts `lib/docs/core/<name>.md`) and
  `t/verb/<verb>.t` (contracts `lib/docs/verbs/<verb>.md`), one `test_*` sub per contract line, run
  by the engine `lib/AAPP/Tests.pm`. The bash verb suites `tests/verbs/<verb>.sh` (helpers in
  `tests/test_helpers.sh`) stay until P-125 replaces them.
- **Run:** `t/test-run` (`strict`, `quiet`, a file or `verb <name>`; `t/test-run help`), or
  `prove -l t/`; `aapp test strict quiet` for the bash suites. Both are green before a commit.
- **How tests check:** kit libraries are called through `lib_call`; results are read as literal text
  (files, git, output), never through the kit's own parsers (`AAPP::JSON` may read a JSON document).
- **Expectations:** declare failure-first tests for new behaviour (`aapp tdd`). Every daily verb and
  core module has a contract, and every test a contract names must exist —
  `tests/verb_contracts_test.sh` checks this.

## 📚 6. Documentation — Where & When
- **Users:** `README.md` (overview, install), `MANUAL.md` (full manual), `CHEATSHEET.md` (one page,
  checked against the code).
- **Developers:** `ARCHITECTURE.md`, `.agents/CODEMAP.md`, command contracts in `lib/docs/verbs/`,
  core module contracts in `lib/docs/core/`. A group member leaves `ARCHITECTURE.md` and
  `CODEMAP.md` to its group plan's `## Architecture & Codemap`.
- **Changes:** `CHANGELOG.md` (Keep a Changelog), a short line per code commit that names the plan.
- **Update when:** a change alters commands, options, configuration keys, hooks or workflows —
  update `MANUAL.md` and the command's contract, and `README.md` if it is introductory.
