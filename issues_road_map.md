# 🗺️ Issue Priority Board

> **Role:** Sequences all 40 issues recorded in [ISSUES.md](ISSUES.md) into implementation priority bands.
>
> **Status:** All 40 audited defects and documentation drift items across Batches 1–4 are ✅ `Resolved`.

---

## 🔴 Batch 1: Critical Layer 1 Enforcement & Target Parser Fixes
1. `ISSUE-001` -> Deny payload schema and non-blocking exit code fix in `blast-radius-guard.sh` ✅ `Resolved`
2. `ISSUE-002` -> Absolute path normalization (`$REPO_ROOT`) in `blast-radius-guard.sh` ✅ `Resolved`
3. `ISSUE-003` -> Safe detached worktree creation replacing destructive `git rm -rf .` fallback in `cmd_init.sh` ✅ `Resolved`
4. `ISSUE-035` -> Backticked `NEW FILE` marker parsing in `blast-radius-guard.sh` and `aapp-pre-commit` ✅ `Resolved`

## 🟠 Batch 2: Pre-Commit & Bypass Fixes
5. `ISSUE-004` -> Subdirectory cwd-relative robustness (`git rev-parse --show-toplevel`) ✅ `Resolved`
6. `ISSUE-005` -> Deletion (`D`) diff-filter enforcement in `aapp-pre-commit` ✅ `Resolved`
7. `ISSUE-006` -> Quoting `$CURRENT_PLANS` in `cmd_status.sh` for spaced plan names ✅ `Resolved`
8. `ISSUE-007` -> `.claude/settings.json` matcher schema alignment ✅ `Resolved`
9. `ISSUE-008` -> `SKIP_BLAST_RADIUS=1` bypass evaluation order before CHANGELOG check ✅ `Resolved`
10. `ISSUE-036` -> `CORE_CODE_REGEX` extension inclusion (`sh|bash|zsh` & CLI binaries) ✅ `Resolved`

## 🟡 Batch 3: CLI, Init, Status & Reliability Fixes
11. `ISSUE-009` -> Pure-POSIX fallback when `python3` is missing in `blast-radius-guard.sh` ✅ `Resolved`
12. `ISSUE-010` -> Warning when `.claude/settings.json` merge is skipped without `python3` ✅ `Resolved`
13. `ISSUE-011` -> Read both `ISSUES.md` and `issues_road_map.md` in `cmd_status.sh` ✅ `Resolved`
14. `ISSUE-012` -> Skip bracketed placeholder lines in `pickup.md` parser ✅ `Resolved`
15. `ISSUE-013` -> Export `AAPP_VERSION` outside subshell in `cmd_upgrade.sh` ✅ `Resolved`
16. `ISSUE-014` -> Protect `aapp-develop-kit` and `agent-planning-kit` from self-consumption ✅ `Resolved`
17. `ISSUE-015` -> Target repository detection in drop-in mode ✅ `Resolved`
18. `ISSUE-016` -> Dynamic version stamping in `templates/AGENTS.md` markers ✅ `Resolved`
19. `ISSUE-017` -> Safeguard for missing `<!-- AAPP-PROTOCOL:END -->` tag ✅ `Resolved`
20. `ISSUE-018` -> Remove unused dead variables `IS_RESTORE` and `AAPP_IS_DROP_IN` ✅ `Resolved`
21. `ISSUE-019` -> Soften `README.md` claims regarding direct shell file redirection ✅ `Resolved`
22. `ISSUE-037` -> `ISSUES.md` table regex supporting bold markdown and `Resolved` status in `cmd_status.sh` ✅ `Resolved`
23. `ISSUE-038` -> Hook manager warning when non-shell `.githooks/pre-commit` is detected ✅ `Resolved`

## 🟢 Batch 4: Documentation Drift, Templates & Test Suite Gaps
24. `ISSUE-020` -> Regenerate `README.md` Table of Contents and fix broken anchors ✅ `Resolved`
25. `ISSUE-021` -> Harmonize `aapp-pre-commit` wiring recommendation across code & docs ✅ `Resolved`
26. `ISSUE-022` -> Update test count across docs (80 total) ✅ `Resolved`
27. `ISSUE-023` -> Synchronize slash commands lifecycle table (`/status`, `/digest`, `/freeze`, `/done`, `/release`) ✅ `Resolved`
28. `ISSUE-024` -> Fix `MANUAL.md` broken TOC anchors and add missing sections ✅ `Resolved`
29. `ISSUE-025` -> Correct `MANUAL.md` claims regarding syntax checks (Python, PHP, JSON) ✅ `Resolved`
30. `ISSUE-026` -> Clarify No-Plan Grace Period description in `MANUAL.md` ✅ `Resolved`
31. `ISSUE-027` -> Align `MANUAL.md` orphan branch documentation with safe algorithm ✅ `Resolved`
32. `ISSUE-028` -> Fix relative link in `templates/issues.md` ✅ `Resolved`
33. `ISSUE-029` -> Correct structural mapping tree in `templates/architecture.md` ✅ `Resolved`
34. `ISSUE-030` -> Update `templates/AGENTS.md` comment reference from `AAPP-INIT` to `aapp init` ✅ `Resolved`
35. `ISSUE-031` -> Wire `call_guard_json` in `write-guard_test.sh` with absolute paths ✅ `Resolved`
36. `ISSUE-032` -> Update `write-guard_test.sh` assertions for valid PreToolUse response schema ✅ `Resolved`
37. `ISSUE-033` -> Clean up helper assertions in `write-guard_test.sh` ✅ `Resolved`
38. `ISSUE-034` -> Add regression test coverage for deletions, fallback init, and subdirectories ✅ `Resolved`
39. `ISSUE-039` -> Rename `example_plan_unified_install_and_upgrade.md` to `kebab-case` and modernize ✅ `Resolved`
40. `ISSUE-040` -> Add test coverage in `pre-commit_test.sh` for backticked `NEW FILE` markers ✅ `Resolved`

## 🔴 Batch 5: Edge Cases, Security & Portability Hardening
41. `ISSUE-041` -> Stream JSON stdin in `blast-radius-guard.sh` avoiding `ARG_MAX` crash on large files 🟡 `Incubated`
42. `ISSUE-042` -> Filter resolved/done items in `cmd_status.sh` `issues_road_map.md` parser 🟡 `Incubated`
43. `ISSUE-043` -> Unlink `$SHARE_DIR` symlink before install to prevent deleting repo files 🟡 `Incubated`
44. `ISSUE-044` -> Replace BSD `sed -i` in `cmd_init.sh` with portable awk version stamping 🟡 `Incubated`
45. `ISSUE-045` -> Clean up broken symlinks in `cmd_uninstall.sh` using `[ -e ] || [ -L ]` 🟡 `Incubated`
46. `ISSUE-046` -> Update deprecated `head -1` to `head -n 1` and quote `$REPO_ROOT` in `blast-radius-guard.sh` 🟡 `Incubated`
47. `ISSUE-047` -> Flexible plan status bullet matching and pickup queue count trimming in `cmd_status.sh` 🟡 `Incubated`
48. `ISSUE-048` -> Run `aapp-pre-commit` via shell in `pre-commit` and specify UTF-8 encoding in schema check 🟡 `Incubated`
