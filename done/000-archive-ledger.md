# 🏛️ Archival Ledger (Completed Plans DB)

Append-only master ledger of verified, shipped, and archived architecture blueprints.

| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-09-15 | `P-13` | [`P13-plan-ids-and-shorthand-resolution.md`](P13-plan-ids-and-shorthand-resolution.md) | Ergonomic Plan IDs & Resolver | `726c1d4` | Canonical unpadded `P-<num>` standard, POSIX shorthand resolver (`lib/plan_resolver.sh`), Planning Health Pairs 4 & 5 (`lib/planning_health.sh`), and 132 passing tests. |
| 2026-09-15 | `P-8` | [`plan-feature-aapp-flat-issues-and-archival.md`](plan-feature-aapp-flat-issues-and-archival.md) | Flat Issue Ledger & Archival Protocol | `32f8799` | Flat single-table schema with Sev/Type/Date, 10-domain taxonomy, Relocation Invariant, master archive ledger (`000-issues-archive.md`), bulletproof POSIX auto-prune, planning-health engine (`lib/planning_health.sh`), and 109 passing tests. |
| 2026-09-14 | `P-7` | [`plan-feature-aapp-slash-commands.md`](plan-feature-aapp-slash-commands.md) | `ISSUE-061` | `362cf80` | Universal AAPP Skills (`templates/skills/`), Claude Code settings decoupling (`templates/claude/`), write-guard self-protection closing inode bypass, and 101/101 automated test cases. |
| 2026-09-10 | `P-6` | [`plan-feature-aapp-adaptive-branch-guard.md`](plan-feature-aapp-adaptive-branch-guard.md) | Feature: Adaptive Branch Protection | `d0d3b76` | Smart Adaptive Branch Protection guard (`templates/aapp-pre-commit`), 6 new tests (`tests/pre-commit_test.sh`), onboarding docs (`README.md`, `MANUAL.md`). |
| 2026-09-10 | `P-5` | [`plan-v1.0.3-docs-templates-and-test-alignment.md`](plan-v1.0.3-docs-templates-and-test-alignment.md) | `ISSUE-020` (Batch 4: `ISSUE-020`–`ISSUE-030`, `ISSUE-039`) | `ebff63e` | Aligned TOC anchors, syntax check descriptions, starter templates (`templates/*`), and modernized example blueprint (`examples/example-plan-unified-install-and-upgrade.md`). |
| 2026-09-10 | `P-4` | [`plan-feature-aapp-develop-mode.md`](plan-feature-aapp-develop-mode.md) | Feature: `aapp develop` | `22586a8` | Live symlink development mode (`lib/cmd_develop.sh`, `aapp develop`) |
| 2026-09-09 | `P-3` | [`plan-v1.0.2-cli-reliability-and-posix-fallback.md`](plan-v1.0.2-cli-reliability-and-posix-fallback.md) | `ISSUE-009` | `43ce5d7` | POSIX JSON fallback in `blast-radius-guard.sh`, dev workspace safety |
| 2026-09-09 | `P-2` | [`plan-decouple-root-anchors-to-worktrees.md`](plan-decouple-root-anchors-to-worktrees.md) | Layout Refinement | `a35cc9f` | Dual-location worktree resolution for `CODEMAP`, `ARCHITECTURE`, `CHANGELOG` |
| 2026-09-09 | `P-1` | [`plan-v1.0.1-core-fixes.md`](plan-v1.0.1-core-fixes.md) | `ISSUE-001` | `b9e0daf` | PreToolUse exit code 2, path normalization, safe git plumbing |
| 2026-09-08 | `P-0` | [`foundation-setup.md`](foundation-setup.md) *(Bootstrap)* | v1.0.0 | `507e4a3` | Multi-orphan worktree infrastructure setup |
