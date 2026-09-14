# 🏛️ Archival Ledger (Completed Plans DB)

Append-only master ledger of verified, shipped, and archived architecture blueprints.

| Date Completed | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |
| :--- | :--- | :--- | :--- | :--- |
| 2026-09-15 | [`plan-feature-aapp-flat-issues-and-archival.md`](plan-feature-aapp-flat-issues-and-archival.md) | Flat Issue Ledger & Archival Protocol | `32f8799` | Flat single-table schema with Sev/Type/Date, 10-domain taxonomy, Relocation Invariant, master archive ledger (`000-issues-archive.md`), bulletproof POSIX auto-prune, planning-health engine (`lib/planning_health.sh`), and 109 passing tests. |
| 2026-09-14 | [`plan-feature-aapp-slash-commands.md`](plan-feature-aapp-slash-commands.md) | `ISSUE-061` | `362cf80` | Universal AAPP Skills (`templates/skills/`), Claude Code settings decoupling (`templates/claude/`), write-guard self-protection closing inode bypass, and 101/101 automated test cases. |
| 2026-09-10 | [`plan-feature-aapp-adaptive-branch-guard.md`](plan-feature-aapp-adaptive-branch-guard.md) | Feature: Adaptive Branch Protection | `d0d3b76` | Smart Adaptive Branch Protection guard (`templates/aapp-pre-commit`), 6 new tests (`tests/pre-commit_test.sh`), onboarding docs (`README.md`, `MANUAL.md`). |
| 2026-09-10 | [`plan-v1.0.3-docs-templates-and-test-alignment.md`](plan-v1.0.3-docs-templates-and-test-alignment.md) | `ISSUE-020` (Batch 4: `ISSUE-020`–`ISSUE-030`, `ISSUE-039`) | `ebff63e` | Aligned TOC anchors, syntax check descriptions, starter templates (`templates/*`), and modernized example blueprint (`examples/example-plan-unified-install-and-upgrade.md`). |
| 2026-09-10 | [`plan-feature-aapp-develop-mode.md`](plan-feature-aapp-develop-mode.md) | Feature: `aapp develop` | `22586a8` | Live symlink development mode (`lib/cmd_develop.sh`, `aapp develop`) |
| 2026-09-09 | [`plan-v1.0.2-cli-reliability-and-posix-fallback.md`](plan-v1.0.2-cli-reliability-and-posix-fallback.md) | `ISSUE-009` | `43ce5d7` | POSIX JSON fallback in `blast-radius-guard.sh`, dev workspace safety |
| 2026-09-09 | [`plan-decouple-root-anchors-to-worktrees.md`](plan-decouple-root-anchors-to-worktrees.md) | Layout Refinement | `a35cc9f` | Dual-location worktree resolution for `CODEMAP`, `ARCHITECTURE`, `CHANGELOG` |
| 2026-09-09 | [`plan-v1.0.1-core-fixes.md`](plan-v1.0.1-core-fixes.md) | `ISSUE-001` | `b9e0daf` | PreToolUse exit code 2, path normalization, safe git plumbing |
| 2026-09-08 | [`foundation-setup.md`](foundation-setup.md) | v1.0.0 | `507e4a3` | Multi-orphan worktree infrastructure setup |
