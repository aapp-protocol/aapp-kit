# 🐛 Issues: Active Technical Backlog

> **Active Backlog Only:** Every row below is an unresolved defect or gap. When resolved, issues are relocated to `.plans/done/000-issues-archive.md` and pruned from `issues_road_map.md`.

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #49 | `Critical` | `CORE` | 2026-09-10 | `lib/cmd_upgrade.sh:19` | `aapp upgrade` clones default branch, but `main` trails `develop`; downgrades Layer 1. | Publish `develop` to `main`, check upstream version. | 🟡 `Incubated` |
| #58 | `Low` | `CLI` | 2026-09-10 | `aapp:9` | `AAPP_VERSION` stayed 1.0.0 without release tags, so protocol block still stamps `v1.0.0` after upgrade. | Bump `AAPP_VERSION` per formal release, tag release, and surface in status. | 🟡 `Incubated` |
| #59 | `Medium` | `CLI` | 2026-09-10 | `lib/cmd_status.sh:93` | `sort -z` is GNU/newer-BSD only and fails on older macOS `sort`, breaking the Plans pillar of briefing. | Iterate `find -print0` stream unsorted or probe `sort -z` with fallback. | 🟡 `Incubated` |
| #60 | `Medium` | `HOOK` | 2026-09-10 | `templates/blast-radius-guard.sh:124` | `ACTIVE_PLANS=$(ls -1 ...)` breaks on plan filenames with newlines; last non-NUL-safe path in engine. | Use `find .plans/current -maxdepth 1 -name '*.md' -print0` with NUL-delimited read. | 🟡 `Incubated` |
| #63 | `Medium` | `TEST` | 2026-09-10 | `tests/` | No CI runs test suites (102 test cases) and no release gate blocks publishing `main` trailing `develop`. | Add a GitHub Actions workflow running all three suites plus branch-parity check. | 🟡 `Incubated` |
| #67 | `Low` | `CORE` | 2026-09-16 | `lib/cmd_ai.sh:287` | AI credits generator derives roster from commit trailers and cannot mechanically extract agents that contributed review without committing. | Await adversarial-review plugin to produce structured plan review provenance, then extend ai-credits to ingest reviewer records (§E.9). | 🟡 `Incubated` |
| #73 | `Medium` | `CLI` | 2026-09-20 | `lib/cmd_init.sh` (`copy_guarded`) | `copy_guarded` returns early whenever the destination exists, so `aapp init` never refreshes guarded files. Stale templates persist in worktrees, while blunt overwrites erase project particulars. | [P-25](current/P25-template-sync-and-document-governance.md) | 🔵 `Planned` |
| #74 | `High` | `TEST` | 2026-09-21 | `tests/*`, `.githooks/*` | Tests hardcode throwaway credentials (`T <t@t>`) without sandbox guards; relative `core.hooksPath` blinds linked worktrees (`.plans`, `.agents`). | [P-26](current/P26-test-harness-isolation-and-worktree-hooks.md) | 🔵 `Planned` |
| #75 | `Medium` | `CLI` | 2026-09-21 | `CHEATSHEET.md`, `lib/cmd_help.sh`, `aapp` | Flat 36-verb catalog causes discovery fatigue for beginners; cheatsheet drifted to 44% coverage (16/36 verbs) missing core lifecycle. | [P-27](current/P27-tiered-cli-discovery-and-cheatsheet-sync.md) | 🔵 `Planned` |
| #76 | `Low` | `HOOK` | 2026-09-21 | `templates/aapp-pre-commit`, `templates/aapp-commit-msg` | Unbounded changelog bullet length and commit body verbosity cause context briefing blowup and git log bloat. | [P-28](current/P28-conciseness-enforcement-and-changelog-governance.md) | 🔵 `Planned` |
| #77 | `Medium` | `CLI` | 2026-09-22 | `lib/cmd_plan.sh:571` | `aapp done` moves plan to `done/` without updating header status, leaving archived plans marked `⚡ In Development`. | Stamp `* **Status:** ✅ Done` on destination blueprint during `cmd_done`. | 🟠 `In Progress` |

