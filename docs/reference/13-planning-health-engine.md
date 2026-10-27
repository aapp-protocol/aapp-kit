---
title: Planning Health Engine Reference
description: The planning ledger and plan integrity checks in lib/planning_health.sh, what each one refuses, and which verbs run them.
---

# 🩺 Planning Health Engine Reference

The planning health engine (`lib/planning_health.sh`) checks that the planning records agree with each other: the issue ledger, its archive, the work queue, the pickup list, the plans and the commits they record. Verbs run the checks they need before they commit; the full set can be run at any time.

---

## 1. Where the Checks Run

| When | Checks |
| :--- | :--- |
| `aapp refine issues "<msg>"` | Issue table shape, fix cells, Pair 1, Pair 8, Pair 2 and the work queue's sections; a row added by hand is refused. Nothing is committed on a failure. |
| `aapp refine pickup "<msg>"` | Every line of `pickup.md` |
| `aapp status` | Pair 2: a work-queue entry with no issue row is reported as drift |
| `aapp resume` | The full set; a failure is reported as a warning and the resume goes on |
| By hand | The full set: `bash "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib/planning_health.sh" [<repo>]` (in the kit's own clone, `bash lib/planning_health.sh`). Exit 0 when every check passes, 1 otherwise. |

---

## 2. The Full Set

| Check | Records | Refuses |
| :--- | :--- | :--- |
| **Pair 1** | `ISSUES.md` ↔ `.plans/done/000-issues-archive.md` | An issue in both; a resolved row left in the active ledger |
| **Pair 2** | `issues_road_map.md` ↔ `ISSUES.md` | A work-queue entry whose issue has no row; a work queue with sections other than `## 🧱 Plan Blockers` and `## 📋 Queued` |
| **Pair 3** | `pickup.md` ↔ the issue ledgers | Warns (never fails) about a pickup line that names an issue already logged |
| **Pair 4** | Plans in `current/` and `done/` | Two plans with one Plan ID; a header Plan ID that differs from the file name's |
| **Pair 5** | Target Files of plans in `current/` | A target among the kit's protected paths (§3) |
| **Pair 6** | Archive ledger, issue archive(s), `ISSUES.md`, `CHANGELOG.md` | A recorded commit hash that does not resolve in Git |
| **Pair 7** | Plans `⚡ In Development` | Two plans in development that share a Target File |
| **Pair 8** | `ISSUES.md`, the archive | An issue id that appears twice within one ledger |
| **Fix cells** | `ISSUES.md` | A *Target Plan / Fix* cell holding anything but nothing or a link written by a verb |
| **Schema** | `ISSUES.md` | A `Type` that is not an uppercase token (`^[A-Z0-9_-]+$`); a Severity other than Critical, High, Medium or Low is a warning |

`aapp refine pickup` checks each line on its own: a `- [ ] ` or `- [x] ` entry; an open entry written `- [ ] <title>: <text>`, with a title of at most `aapp.pickupTitleMax` characters ([Plans & worktrees settings](03-configuration-matrix.md#plans--worktrees)) and every `.plans/pickup/` file it names present.

---

## 3. Protected Paths (Pair 5)

No plan may list these in its Target Files; the write guard refuses edits to them whatever a plan says ([02. Blast Radius Engine](../concepts/02-blast-radius-engine.md)):

- `.githooks/*`, `.git/hooks/*`
- `.agents/skills/aapp-*`, `.agents/claude/*`
- `.claude/settings.json`, `.claude/settings.local.json`, `.claude/skills/aapp-*`
- `.cursor/rules/*`

The kit's hooks, skills and agent settings change through `aapp init` / `aapp upgrade`, not through a plan.

---

## 4. Fixing a Failure

Each failure names the file, the line or id, and the rule. Fix the record, then run the verb again; nothing was committed.

- **Issue rows:** edit `ISSUES.md` and commit with `aapp refine issues "<msg>"`; a new row is logged with `aapp issue log`, never added by hand.
- **Work queue:** the queue is written by `aapp issue queue` and `aapp issue hotfix` only; a stray line is removed with `aapp issue queue <num> remove`.
- **Plan IDs:** plans are drafted with `aapp draft`, which takes the next id; a file renamed by hand is put back, or renamed with `aapp refine <id> slug <new-slug>`.
- **Recorded commits:** `aapp commit adopt <sha>` records a commit made with raw `git commit`.
- **Overlapping plans in development:** the second plan's `aapp start` is refused; finish or re-scope one of them.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Matrix](03-configuration-matrix.md)
- 🏠 [Repository Overview](../../README.md)
