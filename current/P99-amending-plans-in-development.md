# 🗺️ Plan P-99: Amending Plans In Development
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** none
* **Plan ID:** P-99
* **Changelog:** Added: a plan in development is amended only from its own checkout; `refine` fires `pre-refine`, `on-refine` and `post-refine` (P-99)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-103
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
Several sessions work the plans at once. A plan in development belongs to the session implementing it, yet any session can change it: `aapp refine` refuses only §2/§4 edits of a frozen plan (the pre-commit design lock, `templates/aapp-pre-commit` §2b). The risk is an accident out of good will, not malice: a helpful session elsewhere amends a plan under its owner's feet. A group's `## Architecture & Codemap` section also stays editable after the group starts.

Goal: a plan in development is amended only from its own checkout, and a refusal tells the agent what to do instead; a group's `## Architecture & Codemap` is final once the group is frozen; the design lock accepts the one change an amendments member needs (P-101); every `refine` can be observed, gated or carried elsewhere by hooks. Review: `.plans/pickup/p103-group-lifecycle-rfc.md` (C11, C19, C21, C23, C26, A8; user decisions in its §4; settled 2026-10-17).

---

## 2. Technical Blueprint

### 2.1 Decisions
- **D1 — The checkout is the owner.** A `refine` that edits a plan in development (⚡) runs only from its owning checkout: its recorded worktree (`* **Worktree:**`); a plan without one, the checkout whose active-plan buffer holds it. A plan in development takes no amendments from other sessions: the agents working on it would miss them or be confused by them. A second session in the same checkout cannot be told apart from the owner; `templates/AGENTS.md` covers it (D2), not the kit (D6). In a group in development every plan of the group counts as in development, started or not: an unstarted member and the group plan are refined only from a checkout bound to a plan of that group (a member's or the amendments member's worktree, or the checkout holding the group). A change wanted from elsewhere goes to the developer, who stops the group's session and instructs it. Nothing is held by the agent: no ID, token or process; reboots and lost session memory change nothing.
- **D2 — The refusal redirects.** Exit 1, nothing committed; the message names the plan, the checkout it is in development in, that only that checkout amends it, and what to do instead: tell the developer, `aapp issue log`, or a line in `pickup.md`. `templates/AGENTS.md` carries the same rule: never amend a plan in development from another checkout.
- **D3 — Verb-written fields stay open.** Verbs that write defined fields of a plan in development run from any checkout: `commit` (SHAs), `issue hotfix` / `issue close` (blocked, unblocked), `refine … closes`, a group's `* **Members:**` (`draft … group <id>`, `refine <id> group`), `done`, and P-101's `request`, `approve`, `refuse` on an amendments member. They are not free-form edits.
- **D4 — Design lock** (`templates/aapp-pre-commit` §2b), for a plan whose committed Status is 🔷 Frozen or ⚡ In Development:
  - a group plan's `## Architecture & Codemap` is locked like §2 and §4 (read by heading; `extract_plan_section` reads numbered sections only), with one exception: a change to it is accepted in a commit that also adds a line to the `## Decisions` of the group's amendments member naming each changed heading (P-101 writes both). Base lines are stamped by `refine` when a section is first written; a corrected section keeps its base line;
  - a plan with `* **Kind:** amendments` may change §4 by added `### 📂 Target Files` lines only, nothing else in §2 or §4. P-101 writes those lines.
- **D5 — Hook events `pre-refine`, `on-refine`, `post-refine`**, fired by every `refine`, with the kit's existing meanings: `pre-` vetoes before the plans commit (gate); `on-` acts inside the transaction, a failure refuses the refine and nothing is committed; `post-` observes after the commit (notify). Payload: `plan_id` (empty for `pickup` / `issues`), `kind` (`message`, `file`, `request`, `approve`, `refuse`, `decision`, `group`, `slug`, `blocked`, `unblocked`, `closes`, `pickup`, `issues`), `args`, `files` (the plans files it changes), and `commit` for `post-refine`. P-101 adds its kinds. Registered like every event (`aapp hook-hash`); listed wherever events are listed.
- **D6 — Enforcement level.** An agent can type any command; the kit stops the accident and records what was done (layer 0). A deployment that wants more registers a `pre-refine` gate.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Failing tests
- [ ] Task 1.1: Declare the failing tests (`aapp tdd`): owner check and refusal (`tests/verbs/refine.sh`), the two lock rules (`tests/pre-commit_test.sh`), the three events (`tests/hooks_test.sh`).

### Phase 2: Core Implementation
- [ ] Task 2.1: The owner check and the refusal in `refine` (D1, D2); verb-written fields exempt (D3).
- [ ] Task 2.2: The design lock: the group section, the amendments member's added Target Files lines (D4).
- [ ] Task 2.3: `pre-refine`, `on-refine`, `post-refine` in `refine`; the event list in `lib/cmd_hook.sh` and the registry template (D5).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `lib/docs/verbs/refine.md` (refusal, events, tests); `MANUAL.md` (ownership, the events table); `CHEATSHEET.md` (the events row); `templates/AGENTS.md` (D2).
- [ ] Task 3.2: `./aapp test strict quiet`.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> `refine`: the owner check, the refusal, the three events.
- [ ] `lib/cmd_hook.sh` -> the three events in the event list and its help.
- [ ] `templates/skills/aapp-hooks/registry.tsv` -> the three events in the registry's event list.
- [ ] `templates/aapp-pre-commit` -> the group section lock and the amendments member's added Target Files lines.
- [ ] `templates/AGENTS.md` -> never amend a plan in development from another checkout.
- [ ] `lib/docs/verbs/refine.md` -> the refusal, the events, the tests.
- [ ] `tests/verbs/refine.sh` -> the owner check and the refusal.
- [ ] `tests/pre-commit_test.sh` -> the two lock rules and the group section's exception.
- [ ] `tests/hooks_test.sh` -> the three events.
- [ ] `MANUAL.md` -> ownership of plans in development; the events table.
- [ ] `CHEATSHEET.md` -> the events row.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> the write guard stays as it is.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted with initial findings F1–F5; design open.
* **2026-10-17:** Refined from the settled review (`.plans/pickup/p103-group-lifecycle-rfc.md`): protection only (members are never widened; the narrow add moves to P-101's amendments member), the redirecting refusal, the group section lock, the amendments lock rule, `pre-refine` / `on-refine` / `post-refine`. Questions 1, 3, 4 answered by the review; Question 2 answered by the developer: no session outside the group refines its plans, started or not; the developer instructs the group's session (D1). Question 5 answered by the developer: a plan in development takes no amendments from other sessions; a second session in the same checkout is the agent rule's to cover (D1). The group section's lock accepts a correction carried with a `Decisions` line (D4).
