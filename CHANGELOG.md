# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Config-Backed Monotonic Plan ID Allocation (`P-22`): Replaces three-tier file scanning with an atomic monotonic counter in git config (`aapp.planId`) and adds optional multi-contributor provider plugin contract, superseding `#69`.
- Lifecycle Plugin Hooks & Action Plugins Engine (`P-12`): Adds zero-dependency lifecycle hook engine with hash-locked registry (`registry.tsv`), Dual Delivery dispatch (`stdin` JSON + POSIX env), and action plugin support.
- Automated Remote Worktree Synchronization (`P-10`): Adds `aapp push`, `aapp pull`, and `aapp sync` to automate synchronization across isolated orphan worktrees (`.plans`, `.agents`, `.githooks`) with `--ff-only` safety.
- Clean Break Invariant & Migration Strategy: Mandates clean-break default requiring legacy shims, backwards-compatibility fallbacks, and aliases to be explicitly declared in Section 2 of plans.
- Master Emergency Brake & Multi-Worktree State Preserver (`P-21`): Adds `aapp pause` and `aapp resume` for atomic multi-worktree collision prevention, quarantining in-flight changes into SHA-addressed stashes.

### Changed
- Project Documentation Strategy & Plan Template Sync: Added Documentation Conventions section to `PROJECT.MD` and anchored plan template doc sync invariant to project conventions.
- Strict Status Enum Clean Break: Purged legacy dual-syntax fallbacks (`🟠`, `🟢`, `🟡`) in favor of canonical status markers (`⚡ In Development`, `🔷 Frozen`, `📝 Refining`).
- Color-Blind Friendly Plan Status Standard: Adopted distinct silhouettes across plan lifecycle (`🟣 Under Review`, `📝 Refining`, `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`).
- Canonical Blueprint Planning Decoupling (`P-20`): Decoupled active plan buffer management to `aapp active`, added `aapp plan-status`, and established Canonical Planning Invariant.
- Polyglot Callable Contract Standard: Added dual-pattern contract specifications in codemap templates for system scripting and application code.
- Portability & Relative Path Enforcement: Added Section 1b pre-commit check rejecting machine-specific `file:///` URIs and absolute home paths in tracked files (`#71`).
- First-Run Onboarding Loop & Context Alignment (`P-19`): Pre-seeds pickup onboarding item and adds 3-step first-loop guidance to `aapp init` completion.
- Security & Threat Model Documentation: Formulated pair-programming trust model, 4-layer defense hierarchy, and OS containment boundaries in documentation.
- Single-Active-Plan Architecture & Worktree Isolation: Decoupled specification freeze from active coding context with per-worktree active plan buffer (`#57`).
- Flagless CLI Switchboard: Added atomic plan management verbs with disjointness activation gates preventing target collisions between active plans.
- Linked Worktree Resolution & Fail-Closed Quarantine: Resolves `.plans/` across linked worktrees via `git-common-dir` with fail-closed write protection.
- Planning-Health Pair 7: Added collision validator ensuring concurrent active plans never claim intersecting target files.
- Universal Skills & Governance Templates: Added `aapp-start`, `aapp-freeze-start`, `aapp-plan` universal skills, and updated governance templates.
- Frozen Plan Immutability & Design-Lock: Added commit-time design-lock blocking modifications to technical blueprints and blast radius on frozen plans (`#68`).
- Invariant Documentation Allowlist: Added `CHEATSHEET.md` to Section 3 always-allowed invariants alongside `README.md` and `MANUAL.md`.
- Historical AI Attribution Scrubber (`scripts/scrub-attribution.sh`): Added migration script to convert legacy co-author trailers to emailless trailers.
- Planning-Health Pair 6: Added commit hash validator asserting all recorded hashes resolve to valid commits in git object database.
- AI Attribution Suite (`lib/cmd_ai.sh`): Implemented `aapp ai-*` switchboard (`ai-status`, `ai-commit`, `ai-notes`, `ai-off`, `ai-credits`) with emailless trailers and option C git notes.
- Multi-Agent Path Authorization: Added Section 2c allowlist for Claude Code, Antigravity, Cursor, and Codex, with Section 2b hard-deny security boundaries (`#65`).
- Plan ID Canonical Standard & Shorthand Resolver (`lib/plan_resolver.sh`): Added unpadded Plan ID resolution (`P-9`, `9`), slugs, and `#` issue collision rejection.
- Planning-Health Pairs 4 & 5: Added Plan ID uniqueness validation and mechanical blocking of self-protection paths in Target Files.
- Flat Issue Ledger & Relocation Invariant: Consolidated `ISSUES.md` into a single flat database table and relocated resolved issues to archive ledger.
- Planning-Health Pairs 1-3: Added referential integrity validation between issues, priority board, and archive ledger.

### Fixed
- Documentation Anchor Integrity & Table of Contents Synchronization (`README.md`, `MANUAL.md`): Fixes broken navigation links across the Table of Contents in both `README.md` and `MANUAL.md`. Synchronizes section numbering and titles in `README.md` (adding missing entries for Section 9 AI Attribution and Section 10 Security, and updating Section 8 Universal Skills), fixes Command Reference anchor in `MANUAL.md`, completes Section 4 subheadings, and removes decorative emojis from markdown headings (`Smart Adaptive Branch Protection`, `Flat Issue Ledger Schema`, `The Relocation Invariant & Archival Protocol`, `Priority Board`, `Issue Conciseness Invariant`) to ensure 100% deterministic, cross-platform anchor resolution matching GitHub's Markdown slugger API without trailing unicode variation selectors.
- Signature-Gated Self-Consumption (`aapp`, `lib/cmd_install.sh`, `lib/cmd_init.sh`, `lib/cmd_help.sh`, `README.md`, `CHEATSHEET.md`, `tests/install_test.sh`): Replaces unconstrained `rm -rf` basename allowlist with content-based kit signature and clean working tree checks (`is_safe_to_consume_kit_dir`), preserving directories with extra files, non-kit contents, or uncommitted modifications (#51). Expanded install test suite to 54 passing tests.
- Drop-in Target Repository Resolution (`lib/cmd_init.sh`, `tests/install_test.sh`): Resolves target repository to enclosing project root when `agent-planning-kit` or `aapp-develop-kit` is executed from outside the kit directory, preferring kit repository root only when cwd is inside it (#50). Expanded install test suite to 49 passing tests.
- Glob Path Traversal Precision & Safe Character Class Matching (`templates/blast-radius-guard.sh`, `templates/aapp-pre-commit`, `tests/write-guard_test.sh`, `tests/pre-commit_test.sh`): Implements pure-Bash `glob_to_regex` compilation and 3-tier fast path matching (`Exact` -> `Prefix` -> `Regex`) in write-guard and pre-commit engines (#56). Resolves path traversal porosity where single-star wildcards (`*`) unintentionally matched slashes (`/`), adds recursive globstar (`**`) and single-character (`?`) matching, and supports parameterized bracket character classes (`[...]`) with strict anti-"funny regex" boundaries, expanding automated test coverage to 209 test cases.
- Write-Guard Deny Schema & Telemetry (`templates/blast-radius-guard.sh`, `tests/write-guard_test.sh`): Adds `hookEventName: "PreToolUse"` and `permissionDecisionReason` to `hookSpecificOutput` in both Python and POSIX fallback paths and mirrors violation notices to stderr so agents receive actionable self-correction feedback (#52), with complete test assertions (#62).
- Deterministic Pre-Commit Worktree Changelog Verification (`templates/aapp-pre-commit`, `tests/pre-commit_test.sh`): Replaced non-deterministic 900s wall-clock mtime check on `.plans/CHANGELOG.md` with git-verified worktree status checks (`status --porcelain` and latest commit inspection) and root index staging checks (#55), expanding test coverage to 188 automated tests.
- Hook Status Enum & Draft Plan Isolation (`templates/blast-radius-guard.sh`, `templates/aapp-pre-commit`): Filters out incubator drafts (`🔴 Under Review`, `🟡 Refining`) from active plans in write-guard and pre-commit, ensuring unfrozen blueprints do not lock the blast radius or block repository commits before being greenlit (#64).

### Removed
- Dropped `--keep` Flag (`aapp`, `lib/cmd_install.sh`, `lib/cmd_init.sh`, `lib/cmd_help.sh`, `README.md`, `CHEATSHEET.md`, `tests/install_test.sh`): Restores pure zero-flag minimalism for `aapp init` and `aapp install`, while retaining signature-gated and uncommitted-change content protections (`is_safe_to_consume_kit_dir`) and preserving `aapp develop` for kit development.

### Changed
- Architecture & Codemap Sync Invariant (`ARCHITECTURE.md`, `templates/plan-template.md`, `templates/architecture.md`): Aligns blueprint template execution invariants (Invariant 5) and Phase 3 verification checklist to require keeping `ARCHITECTURE.md` and `CODEMAP.md` in sync whenever new modules, commands, or interface contracts are implemented, and updates root system architecture documentation to accurately reflect the multi-worktree engine.
- PreToolUse Matcher Coverage: Added `MultiEdit` to PreToolUse matcher in `templates/claude/settings.json` and `lib/cmd_init.sh` with automatic non-destructive settings upgrade during `aapp init` (closing matcher half of `#53`).
- Added `.git/config` and `*/.git/config` to Section 2 self-protection in `templates/blast-radius-guard.sh`.
- Added Guard allowlist metrics line to `aapp init` completion banner.
- Updated `MANUAL.md`, `README.md`, and `templates/AGENTS.md` to document the Layer 1 evaluation pipeline, allowlist configuration, and the Layer 1 tool-scoped vs. Layer 2 commit gate boundary.
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
