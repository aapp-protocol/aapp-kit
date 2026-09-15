# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Plan ID Canonical Standard & Shorthand Resolver Engine (`lib/plan_resolver.sh`): Adds POSIX resolution for blueprints via unpadded Plan IDs (`P-9`, `9`), slugs (`guard-path`), or filenames, with strict `#` issue collision rejection and transition verb empty-query protection.
- Planning-Health Pairs 4 & 5 (`lib/planning_health.sh`): Adds Pair 4 (Plan ID uniqueness, reference integrity, and header/filename agreement) and Pair 5 (mechanical blocking of Section 2 self-protection files in blueprint Target Files).
- ADR-Style Chronological Blueprint Filenames (`P<N>-<slug>.md`): Migrated active incubator blueprints to unpadded `P<N>-<slug>.md` (`P9` through `P13`).
- Plan ID column added to Master Archival Ledger (`templates/000-archive-ledger.md`, `.plans/done/000-archive-ledger.md`), indexing historical completed blueprints `P-0` through `P-8` without renaming historical files on disk.
- Test suite expanded to 132 automated test cases with dedicated `tests/plan_resolver_test.sh` (19 test cases), plus additions in `tests/install_test.sh` and `tests/pre-commit_test.sh`.
- Flat Issue Ledger (`templates/issues.md`, `.plans/ISSUES.md`): Single flat database table (zero subheadings) with standardized columns (`#`, `Sev`, `Type`, `Date`, `Location`, `Symptom / Problem`, `Target Plan / Fix`, `Status`) and unpadded numeric identifiers (`#1`, `#49`, `#64`).
- Universal Extensible Domain Taxonomy (`Type` column) with 10 recommended core tokens (`CORE`, `CLI`, `UI`, `DB`, `NET`, `SEC`, `HOOK`, `DOCS`, `TEST`, `PERF`) and open regex `^[A-Z0-9_-]+$` with non-blocking advisory warnings.
- The Relocation Invariant & Master Issue Archive Ledger (`templates/done-issues-archive.md`, `.plans/done/000-issues-archive.md`): Physical relocation of resolved issues out of active backlog to an append-only archive ledger, preserving active table purity (`✅ Resolved` does not exist in active `ISSUES.md`).
- Priority Board `⭐ User Priority` Band (`templates/issues_road_map.md`, `.plans/issues_road_map.md`): Human appetite overrides taking precedence over architectural severity.
- Three-Pair Planning-Health Integrity Engine (`lib/planning_health.sh`): Validates numeric disjointness between active issues and archive ledger, referential integrity between priority board and active issues, and clean pickup note routing.
- Detect-and-Block Pre-Commit Guard (`templates/aapp-pre-commit`): Detects and blocks commits if any resolved rows remain in active `ISSUES.md`, and auto-prunes resolved issues from `issues_road_map.md` with bulletproof POSIX ID-anchored regex `^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?(#|ISSUE-)?[0-9]+`?.*(✅|[Rr]esolved)`.
- Non-destructive custom `ISSUES.md` initialization in `lib/cmd_init.sh` emitting advisory guidance pointing to `MANUAL.md` without modifying existing non-flat files.
- Automated regression test cases for flat schema, non-destructive init, bulletproof POSIX auto-pruning, detect-and-block validation, and planning health, expanding the test suite to 109 automated test cases.
- Missing `#64` issue row added to `.plans/ISSUES.md`, with count-preservation assertion verifying `49 (archived) + 15 (active) = 64 (unique project issues #1..#64)`.

### Changed
- Updated `lib/cmd_status.sh` to extract and display Plan IDs alongside status badges in Pillar [3/4], and to source `lib/plan_resolver.sh`.
- Updated `templates/plan-template.md` to include `Plan ID: P-XX` metadata header.
- Updated Universal Skills (`aapp-freeze`, `aapp-done`, `aapp-digest`) and `templates/AGENTS.md` to support shorthand resolution and enforce explicit plan targets on state transitions.
- Updated `lib/cmd_status.sh` to be strictly read-only and idempotent, removing brittle legacy parser heuristics (`sed '/Resolved Issues/,$d'` and unanchored grep) while reporting priority board drift and unsequenced active issues non-destructively.
- Updated `templates/skills/aapp-done/SKILL.md` to enforce the Relocation Invariant by moving resolved issues to `000-issues-archive.md` upon plan verification.
- Automated Issue Roadmap Hygiene in `templates/aapp-pre-commit` (Section 3b) auto-pruning resolved issues (`✅` or `Resolved`) from `issues_road_map.md` in under 5ms, enforcing an active-only priority board.
- Universal AAPP Skills (`templates/skills/aapp-*/SKILL.md`) natively stored in `.agents/skills/` and bridged to `.claude/skills/` via granular relative symlinks, exposing slash commands (`/aapp-status`, `/aapp-digest`, `/aapp-freeze`, `/aapp-done`, `/aapp-release`) across Google Antigravity, Claude Code, Cursor, and OpenAI Codex (ISSUE-061).
- Decoupled Claude Code configuration (`.agents/claude/settings.json`) versioned on the orphan `agents` worktree and bridged to `.claude/settings.json`, with non-destructive adopter migration, divergence key-merging, and `.claude/` gitignore hygiene.
- Section 2 write-guard self-protection in `blast-radius-guard.sh` for `.agents/claude/*`, `.claude/settings.json`, `.agents/skills/aapp-*`, and `.claude/skills/aapp-*` closing the inode aliasing bypass.
- Automated tests for settings decoupling, gitignore hygiene, granular skill bridging, user skill preservation, clean upgrades, and frontmatter drift control, expanding the test suite to 101 automated test cases.
- Claude Code `hookSpecificOutput.permissionDecision: "deny"` and exit code 2 in `blast-radius-guard.sh` (ISSUE-001).
- Non-destructive git plumbing orphan branch creation fallback in `cmd_init.sh` for git < 2.42 (ISSUE-003).
- Deletion (`D`) diff-filter enforcement in `aapp-pre-commit` to prevent deleting Out-of-Bounds files (ISSUE-005).
- Shell extension (`.sh`, `.bash`, `.zsh`) and CLI binary support in `CORE_CODE_REGEX` (ISSUE-036).
- Extended regression tests for backticked targets, deletions, and Claude Code JSON schema (ISSUE-031, ISSUE-032, ISSUE-040).
- Phased Implementation Steps & Execution Checklist section in `templates/plan-template.md` and `.plans/plan-template.md`.
- Dual-location CHANGELOG modification check in `templates/aapp-pre-commit` supporting both root and `.plans/CHANGELOG.md`.
- Dual-location documentation resolution in `templates/AGENTS.md`, `cmd_init.sh`, and `cmd_status.sh` for `CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, and `ISSUES.md`.
- Pure POSIX JSON decision fallback in `blast-radius-guard.sh` for zero-dependency execution without `python3` (ISSUE-009).
- Developer workspace exemption for `aapp-develop-kit` and `agent-planning-kit` in `cmd_install.sh` and `cmd_init.sh` (ISSUE-014).
- Corrupted/unclosed marker protection in `sync_agent_rules` preventing data loss when `<!-- AAPP-PROTOCOL:END -->` is missing (ISSUE-017).
- First-class `aapp develop` command linking development repositories into global paths via symlinks for live editable development.
- Master Archival Ledger seeded at `.plans/done/000-archive-ledger.md` using repo-relative paths, decoupling completed history from active `state_matrix.md` dashboards.
- Formalized `/aapp:` family command triggers and Stable vs. Edge release conventions in `templates/AGENTS.md` and `templates/release_checklist.md`.
- Smart Adaptive Branch Protection Guard in `templates/aapp-pre-commit` preventing accidental direct commits to stable branches (`main`, `master`, `production`) when active development branches exist, with full trunk-based fail-open support and `ALLOW_MAIN_COMMIT` bypass.

### Fixed
- Fixed target extraction in `blast-radius-guard.sh` and `aapp-pre-commit` when targets use backticked markers like `` `NEW FILE` -> `path` `` (ISSUE-035).
- Fixed path normalization in `blast-radius-guard.sh` to strip `$REPO_ROOT/` from absolute paths provided by Claude Code (ISSUE-002).
- Fixed subfolder cwd-relative fail-open behavior in `blast-radius-guard.sh` and `aapp-pre-commit` (ISSUE-004).
- Fixed `SKIP_BLAST_RADIUS=1` bypass evaluation order in `aapp-pre-commit` to precede CHANGELOG enforcement (ISSUE-008).
- Fixed unquoted plan variables in `cmd_status.sh` to safely handle plan filenames containing spaces (ISSUE-006).
- Fixed `ISSUES.md` table parsing in `cmd_status.sh` for bold markdown IDs and `Resolved` status filtering (ISSUE-037).
- Fixed hook manager detection in `cmd_init.sh` to warn when custom non-shell hooks are present (ISSUE-038).
- Fixed `AAPP_VERSION` subshell capture in `cmd_upgrade.sh` and suppressed installer consumption notice on upgrades (ISSUE-013).
- Fixed drop-in target repository detection in `cmd_init.sh` when initialized from standalone kit clones (ISSUE-015).
- Removed unused dead variable assignments (`IS_RESTORE`, `AAPP_IS_DROP_IN`) across CLI commands (ISSUE-018).
- Fixed relative blueprint link path in `templates/issues.md` (ISSUE-028).
- Corrected directory structure mapping in `templates/architecture.md` and `ARCHITECTURE.md` (ISSUE-029).
- Modernized and renamed example blueprint to kebab-case `examples/example-plan-unified-install-and-upgrade.md` (ISSUE-039).
- Synchronized Table of Contents anchors, syntax check descriptions, and safe orphan branch plumbing docs in `README.md` and `MANUAL.md` (ISSUE-020, ISSUE-021, ISSUE-024, ISSUE-025, ISSUE-026, ISSUE-027).
- Streamed JSON stdin in `blast-radius-guard.sh` to prevent `ARG_MAX` argument length crashes and fail-open bypass on large writes (ISSUE-041).
- Filtered resolved issues in `cmd_status.sh` roadmap parser to ensure accurate context recovery briefings (ISSUE-042).
- Safely unlinked `$SHARE_DIR` and `$BIN_DIR` symlinks before installation in `cmd_install.sh` to prevent traversing into and deleting source code (ISSUE-043).
- Replaced non-portable BSD `sed -i` with dynamic `awk` version stamping in `cmd_init.sh` (ISSUE-044).
- Cleaned up broken/dangling symlinks in `cmd_uninstall.sh` (ISSUE-045).
- Replaced obsolete POSIX `head -1` with `head -n 1` and quoted repository root expansions in `blast-radius-guard.sh` (ISSUE-046).
- Supported dash list bullets in plan status parser and trimmed leading spaces in pickup idea count in `cmd_status.sh` (ISSUE-047).
- Executed `aapp-pre-commit` via shell in `pre-commit` to prevent silent bypass when execute bit is dropped, and added explicit UTF-8 encoding in schema check (ISSUE-048).

### Changed
- Moved `SKIP_BLAST_RADIUS=1` check to hook entrypoints to guarantee emergency bypass.
- Reorganized starter files: canonical `CODEMAP.md` seeded in `.agents/`, canonical `ISSUES.md` seeded in `.plans/`, and public `ARCHITECTURE.md` & `CHANGELOG.md` seeded at repository root with automatic legacy migration.
