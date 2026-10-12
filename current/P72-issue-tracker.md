# 🧩 Group Plan P-72: Issue Tracker
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Plan ID:** P-72
* **Changelog:** Added: issue ledger behind one module, and the `aapp-issue-tracker` provider at every issue step (P-72)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Feature Branch:** none
* **Members:** P-73, P-74, P-75, P-77, P-78
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-72` (or `aapp refine <id> group P-72`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
Issues read and written through one module, and an `aapp-issue-tracker` provider that sees the whole issue at every step. A provider can keep issues and their notes anywhere (a local file, a team database); issues it brings in have the same rights as local ones: they block plans and show in `status`, `issue list`, `draft` and `next-blocker`.

Merge criterion: both members archived and the pre-done gate green on the feature branch.

## 2. Shared Decisions
- **One accessor.** Nothing outside the ledger module reads or writes `ISSUES.md`, `done/000-issues-archive.md` or `issues_road_map.md`; a test fails on any new direct access. Path names in permission lists (guard, pre-commit allow-lists) are not access.
- **The ledger rows are the kit's.** `ISSUES.md` rows are always written by the kit; a provider receives them and may mirror them anywhere.
- **Wrapper points.** Six: `log` (new rows), `refine` (changed rows), `fix`, `abort`, `close`, `list`. Each sends the whole issue (all cells, note, plan link, commit, summary, the step's own data) in the Plugin Payload Standard envelope.
- **The plugin decides.** Its answer's `handled` names what it took care of; the kit does everything it does not name (the answer protocol is P-77). No provider means the kit's internals.
- **Notes** are never in the ledger. Without a provider, the kit keeps them outside the repository, under `~/.local/state/aapp/<project>/`.
- **Remote issues** are kept in a cache next to the notes; the module's readers merge it with the ledger. Hooks read only local data and the cache, never the network.
- **One ledger view.** The module's readers merge every source (`.plans/` ledgers, the remote cache, the `.offline` ledgers), each row marked with its source; no caller reads a source directly.
- **Offline is opt-in by configuration.** With `aapp.offlineEnabled=false`, nothing is staged offline and a provider failure refuses.
- **Failures.** A provider failure falls back to the kit for that step and warns; numbering stays provider-authoritative and refuses, as today.

## 3. Members & Order
1. P-73 (ledger module): first; no behaviour change.
2. P-77 (plugin answer protocol): independent of P-73; may run alongside it.
3. P-78 (issue branch): after P-73; issues carry the branch their fix lands on.
4. P-74 (provider wrapper): after P-73, P-77 and P-78; it adds the wrapper over the ledger functions and answers in the P-77 protocol.
5. P-75 (offline worktree): after P-74; its ledgers are a source of the module and its fallback is the wrapper's failure path.

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
* [ ] **Question 1:** The Architecture & Codemap sections are written once P-73's research has fixed the module's functions; until then both stay `No changes.`.

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Group drafted.
