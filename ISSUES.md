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
| #69 | `Low` | `CLI` | 2026-09-17 | `lib/plan_resolver.sh:267` | Unquoted backtick inside `[[ =~ ]]` is evaluated as command substitution at runtime in `get_next_plan_id`. | Store regex in variable or escape backtick delimiter. | 🟡 `Incubated` |
| #70 | `Medium` | `CLI` | 2026-09-17 | `templates/skills/*/SKILL.md` | `disable-model-invocation: true` suppresses skills in Antigravity IDE, hiding new slash commands from chat autocomplete. | Set `disable-model-invocation: false` across templates, update Test 42 drift control, and re-sync. | 🟡 `Incubated` |
| #71 | `Medium` | `HOOK` | 2026-09-18 | `templates/aapp-pre-commit` | AI agents bleed IDE chat `file:///` URIs into tracked markdown and docs, breaking links across clones and leaking local paths. | Add Portability Invariant rule to `AGENTS.md` and deterministic `file:///` validator in `aapp-pre-commit`. | 🟠 `In Progress` |

