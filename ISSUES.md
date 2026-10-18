# 🐛 Issues: Active Technical Backlog

> **Active Backlog Only:** Every row below is an unresolved defect or gap. When resolved, issues are relocated to `.plans/done/000-issues-archive.md` and pruned from `issues_road_map.md`.

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #159 | `Medium` | `HOOK` | 2026-10-16 | `templates/aapp-pre-commit` | The pre-commit hook blocks commits on an adopter's own files with language checks (`bash -n`, Python syntax, `php -l`, JSON under `schema/`); adopter checks belong in the local hook (`templates/pre-commit`). |  | 🟡 `Incubated` |
| #146 | `Low` | `CLI` | 2026-10-13 | `lib/cmd_init.sh` | `aapp init` deletes and recreates every skill directory and its `.claude/skills` link, even when unchanged: an open IDE drops the skills from its prompt until it is reloaded. |  | 🟡 `Incubated` |
| #143 | `Low` | `CORE` | 2026-10-13 | `templates/blast-radius-guard.sh`, `lib/planning_health.sh` | Guard self-protection covers `.agents/skills/aapp-*` only: the `aapp` start skill (P-87) in `.agents/skills/aapp/` and `.claude/skills/aapp/` is not protected. |  | 🟡 `Incubated` |
| #130 | `Low` | `CORE` | 2026-10-12 | `lib/adoption.sh:333-341`, `lib/cmd_init.sh:358` | Two setup advisories read `.plans/ISSUES.md` directly to tell whether it still holds a table, outside the ledger functions of `lib/aapp-lib.sh`. |  | 🟡 `Incubated` |
| #129 | `Medium` | `CLI` | 2026-10-12 | `lib/cmd_init.sh` | `aapp init` has no guard for a repository rooted at the home directory: where `$HOME` is itself a git repository, `init` run from any folder under it that is not in another repository mounts `.plans`, `.agents` and `.githooks` in `$HOME`, writes `ARCHITECTURE.md` and `CHANGELOG.md` there and sets `core.hooksPath`. |  | 🟡 `Incubated` |
| #128 | `Low` | `DOCS` | 2026-10-12 | `MANUAL.md` (§13 settings matrix) | The settings matrix omits keys the code reads: `aapp.protectedBranches`, `aapp.templateSync`, `aapp.testCommand`, `aapp.notesRemote`, `aapp.aiNotes`, `aapp.aiNotesGuard`, `aapp.aiAlias`, `aapp.noteTTL`. |  | 🟡 `Incubated` |
| #127 | `Medium` | `CLI` | 2026-10-12 | `lib/cmd_install.sh` | `aapp install` copies `lib`, `templates`, `tests` and `examples` only: `MANUAL.md` and `CHEATSHEET.md` are not installed, so an installed kit has no manual to open or link to. |  | 🟡 `Incubated` |
| #125 | `Low` | `CORE` | 2026-10-11 | `templates/blast-radius-guard.sh` | The write guard refuses `.agents/CODEMAP.md` when it is addressed through a plan worktree's `.agents` link (`.workspace/P<n>/.agents/CODEMAP.md`); the same file by its main-checkout path is accepted. |  | 🟡 `Incubated` |
| #99 | `Medium` | `CORE` | 2026-10-05 | `lib/*.sh`, `templates/aapp-*` (each `git config aapp.*` read), `lib/cmd_init.sh` (seeding), `MANUAL.md:352,1751` | ~27 `aapp.*` keys have no single source of truth: each read site hardcodes its own default (e.g. `subjectMaxLen` 72 in `lib/cmd_ai.sh` and `templates/aapp-commit-msg`), init seeds some, and the manual documents `aapp.devBranch` two ways. New keys (P-52/P-54) make it worse. |  | 🟡 `Incubated` |
| #86 | `Low` | `CORE` | 2026-09-27 | `lib/planning_health.sh:396` (Pair 5) | Fifth Target Files parser (bash) left outside the P-37 library; skips only `NEW FILE\|MODIFY\|DELETE`. |  | 🟡 `Incubated` |
| #49 | `Critical` | `CORE` | 2026-09-10 | `lib/cmd_upgrade.sh:19` | `aapp upgrade` clones default branch, but `main` trails `develop`; downgrades Layer 1. |  | 🟡 `Incubated` |
| #58 | `Low` | `CLI` | 2026-09-10 | `aapp:9` | `AAPP_VERSION` stayed 1.0.0 without release tags, so protocol block still stamps `v1.0.0` after upgrade. | [P-59](current/P59-kit-release-hook.md) | 🔵 `Planned` |
| #59 | `Medium` | `CLI` | 2026-09-10 | `lib/cmd_status.sh:93` | `sort -z` is GNU/newer-BSD only and fails on older macOS `sort`, breaking the Plans pillar of briefing. |  | 🟡 `Incubated` |
| #60 | `Medium` | `HOOK` | 2026-09-10 | `templates/blast-radius-guard.sh:124` | `ACTIVE_PLANS=$(ls -1 ...)` breaks on plan filenames with newlines; last non-NUL-safe path in engine. |  | 🟡 `Incubated` |
| #63 | `Medium` | `TEST` | 2026-09-10 | `tests/` | No CI runs test suites (102 test cases) and no release gate blocks publishing `main` trailing `develop`. |  | 🟡 `Incubated` |
| #67 | `Low` | `CORE` | 2026-09-16 | `lib/cmd_ai.sh:287` | AI credits generator derives roster from commit trailers and cannot mechanically extract agents that contributed review without committing. |  | 🟡 `Incubated` |

