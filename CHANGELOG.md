# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
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

### Changed
- Moved `SKIP_BLAST_RADIUS=1` check to hook entrypoints to guarantee emergency bypass.
- Reorganized starter files: canonical `CODEMAP.md` seeded in `.agents/`, canonical `ISSUES.md` seeded in `.plans/`, and public `ARCHITECTURE.md` & `CHANGELOG.md` seeded at repository root with automatic legacy migration.
