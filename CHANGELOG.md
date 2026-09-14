# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
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
