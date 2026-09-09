# 🗺️ Issue Priority Board

> **Role:** Sequences all 40 issues recorded in [ISSUES.md](ISSUES.md) into implementation priority bands.
>
> **Status:** 🔵 `Planned` -> Promoted to blueprints in `current/`.

---

## 🔴 Batch 1: Critical Layer 1 Enforcement & Target Parser Fixes
1. `ISSUE-001` -> Deny payload schema and non-blocking exit code fix in `blast-radius-guard.sh` 🔵 `Planned` -> [`current/plan-v1.0.1-core-fixes.md`](current/plan-v1.0.1-core-fixes.md)
2. `ISSUE-002` -> Absolute path normalization (`$REPO_ROOT`) in `blast-radius-guard.sh` 🔵 `Planned` -> [`current/plan-v1.0.1-core-fixes.md`](current/plan-v1.0.1-core-fixes.md)
3. `ISSUE-003` -> Safe detached worktree creation replacing destructive `git rm -rf .` fallback in `cmd_init.sh` 🔵 `Planned` -> [`current/plan-v1.0.1-core-fixes.md`](current/plan-v1.0.1-core-fixes.md)
4. `ISSUE-035` -> Backticked `NEW FILE` marker parsing in `blast-radius-guard.sh` and `aapp-pre-commit` 🔵 `Planned` -> [`current/plan-v1.0.1-core-fixes.md`](current/plan-v1.0.1-core-fixes.md)

## 🟠 Batch 2: Pre-Commit & Bypass Fixes
5. `ISSUE-004` -> Subdirectory cwd-relative robustness (`git rev-parse --show-toplevel`)
6. `ISSUE-005` -> Deletion (`D`) diff-filter enforcement in `aapp-pre-commit`
7. `ISSUE-006` -> Quoting `$CURRENT_PLANS` in `cmd_status.sh` for spaced plan names
8. `ISSUE-007` -> `.claude/settings.json` matcher schema alignment
9. `ISSUE-008` -> `SKIP_BLAST_RADIUS=1` bypass evaluation order before CHANGELOG check
10. `ISSUE-036` -> `CORE_CODE_REGEX` extension inclusion (`sh|bash|zsh` & CLI binaries)

## 🟡 Batch 3: CLI, Init, Status & Reliability Fixes
11. `ISSUE-009` -> Pure-POSIX fallback when `python3` is missing in `blast-radius-guard.sh`
12. `ISSUE-010` -> Warning when `.claude/settings.json` merge is skipped without `python3`
13. `ISSUE-011` -> Read both `ISSUES.md` and `issues_road_map.md` in `cmd_status.sh`
14. `ISSUE-012` -> Skip bracketed placeholder lines in `pickup.md` parser
15. `ISSUE-013` -> Export `AAPP_VERSION` outside subshell in `cmd_upgrade.sh`
16. `ISSUE-014` -> Document kit folder consumption exemption or add `--keep` flag
17. `ISSUE-015` -> Target repository detection in drop-in mode
18. `ISSUE-016` -> Dynamic version stamping in `templates/AGENTS.md` markers
19. `ISSUE-017` -> Safeguard for missing `<!-- AAPP-PROTOCOL:END -->` tag
20. `ISSUE-018` -> Remove unused dead variables `IS_RESTORE` and `AAPP_IS_DROP_IN`
21. `ISSUE-019` -> Soften `README.md` claims regarding direct shell file redirection
22. `ISSUE-037` -> `ISSUES.md` table regex supporting bold markdown and `Resolved` status in `cmd_status.sh`
23. `ISSUE-038` -> Hook manager warning when non-shell `.githooks/pre-commit` is detected

## 🟢 Batch 4: Documentation Drift, Templates & Test Suite Gaps
24. `ISSUE-020` -> Regenerate `README.md` Table of Contents and fix broken anchors
25. `ISSUE-021` -> Harmonize `aapp-pre-commit` wiring recommendation across code & docs
26. `ISSUE-022` -> Update test count in `README.md` from 69 to 70
27. `ISSUE-023` -> Synchronize slash commands lifecycle table (`/abort`, `/release`)
28. `ISSUE-024` -> Fix `MANUAL.md` broken TOC anchors and add missing sections
29. `ISSUE-025` -> Correct `MANUAL.md` claims regarding `bash -n` and `node --check`
30. `ISSUE-026` -> Clarify No-Plan Grace Period description in `MANUAL.md`
31. `ISSUE-027` -> Align `MANUAL.md` orphan branch documentation with safe algorithm
32. `ISSUE-028` -> Fix relative link in `templates/issues.md`
33. `ISSUE-029` -> Correct structural mapping tree in `templates/architecture.md`
34. `ISSUE-030` -> Update `templates/AGENTS.md` comment reference from `AAPP-INIT` to `aapp init`
35. `ISSUE-031` -> Wire `call_guard_json` in `write-guard_test.sh` with absolute paths
36. `ISSUE-032` -> Update `write-guard_test.sh` assertions for valid PreToolUse response schema
37. `ISSUE-033` -> Remove dead stdin call in `write-guard_test.sh`
38. `ISSUE-034` -> Add regression test coverage for deletions, fallback init, and subdirectories
39. `ISSUE-039` -> Rename `example_plan_unified_install_and_upgrade.md` to `kebab-case` and modernize
40. `ISSUE-040` -> Add test coverage in `pre-commit_test.sh` for backticked `NEW FILE` markers
