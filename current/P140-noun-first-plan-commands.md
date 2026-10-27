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
* **Members:** P-139, P-142, P-141
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
- **One action per word:** every subcommand names exactly what it does, so a cheat sheet reads without descriptions; no subcommand carries a second meaning through tokens. `refine` leaves the kit: its forms become the subcommands below.
- **`aapp plan commit` is not `aapp commit`:** `aapp plan commit <id> "<msg>"` commits an edit of the plan's text in `.plans/`; `aapp commit "<msg>"` commits code for the active plan. `aapp help`, the CHEATSHEET, the rules and every skill that names either one say this next to it.

### Verb conversion
| Today | After | Module |
|---|---|---|
| `aapp draft [slug] [issue <num> \| group [<id>]]` | `aapp plan draft …` | `AAPP::Plan::Draft` |
| `aapp refine <id> "<msg>"` | `aapp plan commit <id> "<msg>"` (plan text, not code) | `AAPP::Plan::Commit` |
| `aapp refine <id> slug <new>` | `aapp plan rename <id> <new-slug>` | `AAPP::Plan::Rename` |
| `aapp refine <id> blocked <num>` / `unblocked <num>` | `aapp plan block <id> <num>` / `aapp plan unblock <id> <num>` | `AAPP::Plan::Block` |
| `aapp refine <id> closes <num>` / `closes <num> remove` | `aapp plan closes add <id> <num>` / `aapp plan closes remove <id> <num>` | `AAPP::Plan::Closes` |
| `aapp refine <id> group <group>` / `group none` | `aapp plan join <id> <group>` / `aapp plan leave <id>` | `AAPP::Plan::Group` |
| `aapp refine <amend-id> request \| approve \| refuse \| decision …` | `aapp plan amend request \| approve \| refuse \| decision …` | `AAPP::Plan::Amend` |
| `aapp refine issues "<msg>"` | `aapp issue commit "<msg>"` | the issue lane's module |
| `aapp refine issues … branch <num> <name>` | `aapp issue branch <num> <name>` | the issue lane's module |
| `aapp refine issues … note <num> "<text>"` | `aapp issue note <num> "<text>"` | the issue lane's module |
| `aapp refine pickup "<msg>"` | `aapp pickup commit "<msg>"` | `AAPP::Pickup` (P-142) |
| *(none: `status` shows five, the rest by hand)* | `aapp pickup list [json]`, `aapp pickup add …`, `aapp pickup edit "<title>" …`, `aapp pickup delete "<title>"` | `AAPP::Pickup` (P-142) |
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

Unchanged: `status` (all four pillars), `commit` (code), `review` (P-138), `issue` (gains `commit`, `branch`, `note`), `pickup` (new noun, P-142), `note`, `ai`, `offline`, `companion`, `test`, the setup, sync and hook verbs.

## 3. Members & Order
1. **P-139** (`P139-plan-command-dispatcher.md`): `AAPP::Cmd::Plan` (dispatcher, switchboard, reserved words). First; every other member plugs into it.
2. **P-142** (`P142-pickup-commands.md`): the `aapp pickup` noun and the three-field pickup line. Independent of P-139; can run in parallel with it.
3. Further members are drafted per area once P-139's dispatcher is settled; they can run in parallel: lifecycle subcommands (`draft`, `tdd`, `freeze`, `start`, `done`, `active`), plan edits (`commit`, `rename`, `block` / `unblock`, `closes`, `join` / `leave`), read-only subcommands (`status`, `matrix`), `amend`, the issue lane's `commit` / `branch` / `note`, docs/skills/templates/rules.
4. **P-141** (amendments member): last.

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
*(None yet — details come in refinement.)*
---

## 📦 6. Change Log & Refinement History
* **2026-10-27:** Group drafted with the verb conversion; P-139 is its first member. Details come in refinement.
* **2026-10-27:** `pickup` becomes its own noun (P-142); `aapp refine pickup` becomes `aapp pickup refine`.
