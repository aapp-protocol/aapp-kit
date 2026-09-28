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
- **Stack:** Bash (`#!/usr/bin/env bash`), git, and standard Unix tools. No build step.
- **Run from a clone:** `./aapp develop` links this clone as the global `aapp`; `aapp test` runs the
  suites.

## ✍️ 2. Code Style & Conventions
- **Shell:** keep macOS's Bash 3.2 working — no associative arrays, no Bash 4+ features.
- **Portability:** no GNU-only options (e.g. `sort -z`); iterate paths NUL-safely (`find -print0`).
  Platforms not yet verified are listed in MANUAL §14, not logged as issues.
- **Linting:** `shellcheck`; keep `# shellcheck` directives next to what they explain.
- **CLI arguments:** bare tokens (`aapp commit amend`, `aapp test strict`), never new `--flags`.
- **Clean breaks:** no compatibility aliases, shims or dual syntax unless the plan lists them under
  *Migration & Compatibility Strategy*. Before announcement, breaking changes are cheap.
- **One parser:** plan parsing lives in `lib/aapp-lib.sh`; reuse it, never add another copy.
- **Commits:** code goes through `aapp commit` while a plan is started; every code commit adds a
  `CHANGELOG.md` line; subject ≤ 72 characters; AI commits carry emailless `AI-Agent:` /
  `AI-Vendor:` / `AI-Model:` trailers.

## 📦 3. Libraries & Dependencies
- **Use:** Bash, git, coreutils, `awk`, `sed`, `grep`, and `sha256sum` or `shasum`.
- **Optional:** `python3`, only behind `command -v python3` with a working fallback.
- **Avoid:** `jq`, network tools, package managers, and anything an adopter would have to install.
- **Adding a dependency:** needs a plan and the user's approval.

## 🚨 4. Error Handling
- **Fail closed.** No silent fallbacks (`|| true`, `|| pwd`, unchecked defaults) unless the reason is
  in a code comment and the plan lists it in its Fallback Inventory.
- **Messages:** to stderr, as `❌ [Context] what went wrong`, followed by a `👉` line with the fix.
  Exit `1` on failure.
- **Repository check:** the `aapp` dispatcher asserts a git repository once; commands rely on
  `REPO_ROOT` instead of re-deriving it.

Each command's refusals and exit behaviour are in its contract (`lib/docs/verbs/<verb>.md`) and in
`CODEMAP.md`.

## 🧪 5. Testing
- **Location:** `tests/*_test.sh` suites, `tests/verbs/<verb>.sh` contract suites, shared helpers in
  `tests/test_helpers.sh`.
- **Run:** `aapp test` (all), `aapp test strict quiet`, `aapp test verb <name>`.
- **Expectations:** declare failure-first tests for new behaviour (`aapp tdd`). Every daily verb has a
  contract in `lib/docs/verbs/`, and every test a contract names must exist —
  `tests/verb_contracts_test.sh` checks this.

## 📚 6. Documentation — Where & When
- **Users:** `README.md` (overview, install), `MANUAL.md` (full manual), `CHEATSHEET.md` (one page,
  checked against the code).
- **Developers:** `ARCHITECTURE.md`, `.agents/CODEMAP.md`, command contracts in `lib/docs/verbs/`.
- **Changes:** `CHANGELOG.md` (Keep a Changelog), a short line per code commit that names the plan.
- **Update when:** a change alters commands, options, configuration keys, hooks or workflows —
  update `MANUAL.md` and the command's contract, and `README.md` if it is introductory.
