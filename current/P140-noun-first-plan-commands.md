# 🧩 Group Plan P-140: Noun First Plan Commands
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Plan ID:** P-140
* **Changelog:** Changed: plan commands move under `aapp plan` (`aapp plan draft`, `aapp plan refine`, `aapp plan freeze`, …) and issue-ledger edits under `aapp issue refine`; the old top-level verbs are removed
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Feature Branch:** none
* **Members:** P-139, P-141
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-140` (or `aapp refine <id> group P-140`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

> **Read this whole plan before starting or resuming any member.** §1 says why the group exists and how its success is measured; §2 holds the decisions every member keeps; `## Architecture & Codemap` is the target architecture. A member's own plan is read against them.

---

## 1. Goal
A noun-first CLI, as `aapp issue …` already is: every command that acts on a plan moves under `aapp plan`, so people and agents find the plan commands in one place and each subcommand says exactly what it does. Starts after the Perl port (group P-111) is done. Merge criterion: every member archived and the pre-done gate green on the feature branch.

## 2. Shared Decisions
- **Clean break:** the old top-level verbs leave the kit; no aliases, nothing names them.
- **Modules:** one module per subcommand under `lib/AAPP/Plan/`; `AAPP::Cmd::Plan` parses tokens and dispatches only.
- **Reserved words:** after `aapp plan` the subcommand words below are reserved; a plan whose slug equals one is named by its id (`P-<n>`).

### Verb conversion
| Today | After | Module |
|---|---|---|
| `aapp draft [slug] [issue <num> \| group [<id>]]` | `aapp plan draft …` | `AAPP::Plan::Draft` |
| `aapp refine <id> "<msg>"` and its plan tokens (`blocked`, `unblocked`, `slug`, `closes`, `group`) | `aapp plan refine <id> …` | `AAPP::Plan::Refine` |
| `aapp refine <amend-id> request \| approve \| refuse \| decision …` | `aapp plan amend request \| approve \| refuse \| decision …` | `AAPP::Plan::Amend` |
| `aapp refine issues "<msg>" …` | `aapp issue refine "<msg>" …` | the issue lane's module |
| `aapp tdd <id>` | `aapp plan tdd <id>` | `AAPP::Plan::Tdd` |
| `aapp freeze <id>` | `aapp plan freeze <id>` | `AAPP::Plan::Freeze` |
| `aapp start <id>` | `aapp plan start <id>` | `AAPP::Plan::Start` |
| `aapp freeze-start <id>` | `aapp plan freeze-start <id>` | `AAPP::Plan::Freeze` + `AAPP::Plan::Start` |
| `aapp done <id>` | `aapp plan done <id>` | `AAPP::Plan::Done` |
| `aapp active [<id> \| clear]` | `aapp plan active [<id> \| clear]` | `AAPP::Plan::Active` |
| `aapp plan-status [<id>]` | `aapp plan status [<id>]` | `AAPP::Plan::Status` |
| `aapp matrix [check]` | `aapp plan matrix [check]` | `AAPP::Plan::Matrix` |
| `aapp plan abort <id> …` | unchanged | `AAPP::Plan::Abort` |
| `aapp plan conflict-check \| conflict-free …` | unchanged | `AAPP::Plan::Conflict` |
| `aapp plan [query]` | `aapp plan` (bare: the switchboard) | `AAPP::Cmd::Plan` |

Unchanged: `status` (all four pillars), `commit` (code), `review` (P-138), `issue` (gains `refine`), `note`, `ai`, `offline`, `companion`, `test`, the setup, sync and hook verbs.

## 3. Members & Order
1. **P-139** (`P139-noun-first-plan-commands.md`): `AAPP::Cmd::Plan` (dispatcher, switchboard, reserved words). First; every other member plugs into it.
2. Further members are drafted per area once P-139's dispatcher is settled; they can run in parallel: lifecycle subcommands (`draft`, `refine`, `tdd`, `freeze`, `start`, `done`, `active`), read-only subcommands (`status`, `matrix`), `amend`, `issue refine` and the pickup edit, docs/skills/templates/rules.
3. **P-141** (amendments member): last.

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
No changes.

### .agents/CODEMAP.md
No changes.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** `aapp refine pickup "<msg>"` does not act on a plan: where does it go (`aapp pickup …`, or another noun)?
---

## 📦 6. Change Log & Refinement History
* **2026-10-27:** Group drafted with the verb conversion; P-139 is its first member. Details come in refinement.
