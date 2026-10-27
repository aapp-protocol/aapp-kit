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
* **Members:** P-139, P-142, P-144, P-141
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
- **Everything that is a CLI command lives under `lib/AAPP/Runner/`; every other module stays a single module in `lib/AAPP/`.**
  - Top-level verb: `lib/AAPP/Runner/<Verb>.pm` (`aapp status` → `AAPP::Runner::Status`).
  - Noun: `lib/AAPP/Runner/<Noun>.pm` (its own layer, and the bare `aapp <noun>`), with its words in `lib/AAPP/Runner/<Noun>/<Word>.pm` (`aapp plan freeze-start` → `AAPP::Runner::Plan::FreezeStart`; a hyphenated word joins its parts).
  - One file per command, so each is maintained, extended and tested alone. A word with actions (`closes add|remove`, `amend request|approve|refuse|decision`) is one module.
- **One parameter per layer:** `AAPP::Runner` reads only the first parameter and calls `AAPP::Runner::<Name>->run(@rest)`; a noun module reads only its first parameter (the word) and calls `AAPP::Runner::<Noun>::<Word>->run(@rest)`; with no word it runs its own bare form (the switchboard for `plan`) or lists its words. The step "read one token, find the module, call its `run` with the rest, refuse an unknown token naming what exists" is written once, in `AAPP::Runner`, and every layer calls it.
- **One public sub per command module, `run`:** every other sub in it is private (`_name`). A word with actions branches inside its own `run`.
- **Shared code is a single module in `lib/AAPP/`, named for what it is, never for a command:** `AAPP::Pickup` (the `pickup.md` line), `AAPP::Rfc` (the RFC file), `AAPP::Review` (a plan's §7/§8); never copied.
- **Built by P-138** (the first noun in Perl); P-139 adds the `plan` noun.
- **Reserved words:** the words of a noun are reserved after it; a plan whose slug equals a `plan` word is named by its id (`P-<n>`). Each noun's member lists its words.
- **One action per word:** every subcommand names exactly what it does, so a cheat sheet reads without descriptions; no subcommand carries a second meaning through tokens. `refine` leaves the kit: its plan forms become `plan` words (P-139), `refine pickup` becomes `pickup commit` (P-142), `refine issues` becomes `issue commit`, `issue branch`, `issue note` (P-144).
- **`aapp plan commit` is not `aapp commit`:** `aapp plan commit <id> "<msg>"` commits an edit of the plan's text in `.plans/`; `aapp commit "<msg>"` commits code for the active plan. `aapp help`, the CHEATSHEET, the rules and every skill that names either one say this next to it.
- **Events of a noun:** a noun without lifecycle events of its own fires one pair for all its words, `pre-<noun>` (a gate, before the word reads or writes anything) and `post-<noun>` (an observer, after the word's effect). Payload: `data.command` the noun, `data.event` the word, `args` as typed, and on `post-` what the word produced. `issue` (P-144) and `pickup` (P-142) follow it; the `plan` words keep their lifecycle events (`pre-freeze`, `post-done`, …, P-139). Handlers may do anything with the payload; the kit ignores their result and guards no loops.

The `plan` words are P-139's, the `pickup` words P-142's, the issue-ledger words (`issue commit`, `branch`, `note`) P-144's. Unchanged by the group: `status` (all four pillars), `commit` (code), `review` (P-138), `note`, `ai`, `offline`, `companion`, `test`, the setup, sync and hook verbs.

## 3. Members & Order
1. **P-139** (`P139-plan-noun.md`): every plan command under `aapp plan`: the noun, all its words (lifecycle, read-only, the plan forms of `refine`, `amend`), the reserved words and the clean break of the old verbs.
2. **P-142** (`P142-pickup-commands.md`): the `aapp pickup` noun and the three-field pickup line. Independent of P-139; can run in parallel with it.
3. **P-144** (`P144-issue-ledger-words.md`): `refine issues` and its `branch` / `note` tokens become `issue commit`, `issue branch`, `issue note`. Independent of P-139 and P-142.
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
* **2026-10-27:** `pickup` becomes its own noun (P-142); `aapp refine pickup` becomes `aapp pickup commit`.
* **2026-10-27:** The plan words moved to P-139 and the pickup words to P-142: the group keeps the shared rules; the issue words wait here for their member.
* **2026-10-27:** The issue-ledger words moved to their member, P-144.
