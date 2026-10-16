# 🗺️ Plan P-99: Amending Plans In Development
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-99
* **Changelog:** Added: only the owning checkout amends a plan in development; `refine <id> file` adds a Target File (P-99)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
> **Early draft.** The design may change drastically before implementation. §2 holds initial
> findings as a starting point, not decisions.

Several sessions work the plans at once. A plan in development belongs to the session implementing
it, yet any session can change it: `aapp refine` refuses only §2/§4 edits of a frozen plan (the
pre-commit design lock, `templates/aapp-pre-commit` §2b). An amendment from a foreign session lands
under the owner's feet.

The owner itself has a legitimate, frequent need: adding a file to Target Files mid-implementation,
the most common amendment met while developing the kit. Today that means unfreezing by hand (Status
back to Refining, commit, edit §4, freeze and start again): several steps, a hand-edited Status line,
open to any session. Mini plans already have a narrow path for the same need: `aapp issue fix <num>
file <path>`.

Goal: make the legitimate amendment one narrow, recorded step, so that everything outside it can be
refused.

---

## 2. Technical Blueprint

### 2.1 Initial findings (starting points)
- **F1 — Narrow amendment.** `aapp refine <id> file <path> "<reason>"` (bare token on an existing
  verb, shaped like `issue fix … file`): adds one Target Files line to §4 and the reason to §6. The
  design lock accepts exactly that §4 diff (added target lines only).
- **F2 — Owner only.** Free-form `refine` of a plan in development, and F1, run only from the
  owning checkout: the plan's worktree (`* **Worktree:**`), or in single-checkout mode the checkout
  whose active-plan buffer holds the plan. Refused elsewhere, naming the owner.
- **F3 — Verb-written fields stay open.** `commit` (SHAs), `issue hotfix`/`close` (blocked,
  unblocked), `refine … closes`, `done` write defined fields of plans in development from any
  checkout; they are not free-form edits.
- **F4 — Visibility.** `aapp status` flags Target Files added after start, so each widening is seen.
- **F5 — Enforcement level.** An agent can type any token; the kit proves intent and records it
  (layer 0). Stronger confirmation is the deployment's job unless decided otherwise (Q1).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: ...
- [ ] Task 1.2: ...

### Phase 2: Core Implementation
- [ ] Task 2.1: ...
- [ ] Task 2.2: ...

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
*Tentative; follows the design.*
- [ ] `lib/cmd_plan.sh` -> `refine … file`, the owner check.
- [ ] `templates/aapp-pre-commit` -> the design lock accepts an added Target Files line.
- [ ] `lib/cmd_status.sh` -> the flag for files added after start.
- [ ] `lib/docs/verbs/refine.md` -> the token, its refusals and tests.
- [ ] `tests/verbs/refine.sh` -> the tests.
- [ ] `tests/pre-commit_test.sh` -> the design lock tests.
- [ ] `ARCHITECTURE.md` -> ownership of plans in development.
- [ ] `CHEATSHEET.md` -> `refine … file`.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Human approval.** Is a recorded reason plus the status flag (F4, F5) enough, or is a stronger confirmation wanted for widening a plan in development?
* [ ] **Question 2 — Unstarted members of a group in development.** Refuse edits from sessions other than the group's, or allow them (planning continues during development, but the group's session may pick the member up next)?
* [ ] **Question 3 — Removing a Target File.** Through the same narrow path, or adding only?
* [ ] **Question 4 — Other amendments.** Which further mid-implementation changes need a narrow path (a §3 task, a required test, an Out of Bounds line), and which keep the unfreeze cycle?
* [ ] **Question 5 — Ownership in single-checkout mode.** Is the active-plan buffer a reliable owner mark when two sessions share one checkout?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted with initial findings F1–F5; design open.
