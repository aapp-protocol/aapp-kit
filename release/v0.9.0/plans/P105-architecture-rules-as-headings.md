# 🗺️ Plan P-105: Architecture Rules As Headings
* **Created:** 2026-10-17 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** #166
* **Plan ID:** P-105
* **Changelog:** Changed: `ARCHITECTURE.md`'s invariant rules are headings grouped by topic, without numbers; Plan Groups points to the group lifecycle; history wording removed (P-105)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `9def1ad` (develop)
* **Worktree:** .workspace/P105 (plan/P105-architecture-rules-as-headings)
* **Commits:** `414e5f9` (develop)
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
`ARCHITECTURE.md`'s `## 🚦 4. Invariant Architectural Rules` is one numbered list of 30 rules. A group's `done` replaces sections by heading, so it cannot change one rule: rule 23 ("Plan Groups (P-64)") still describes the group `done` order of docs commit before the gate, which `## Group Lifecycle: Ownership, Amendments, Done (P-103)` replaced. Numbers also get in the way of removing a rule in the middle.

Goal: every rule its own heading, grouped by topic, no numbers; rule 23 brought up to date.

---

## 2. Technical Blueprint
- **Shape.** `## 🚦 4. Invariant Architectural Rules` keeps its heading; under it a `###` heading per topic and a `####` heading per rule (its bold title without the number and colon, e.g. `#### Plan Groups (P-64)`), the rule's text below as a paragraph, unchanged. A group's `done` can then replace one rule: a section runs up to the next heading of the same or a higher level.
- **Topics**, in this order:
  - `### Code & Paths`: Zero Reinvention; Path Resolution Single Source of Truth; Front-Door Repository Assertion & Fail-Closed Roots; Runtime Reachability & Inspection-Only Invariant; Shared Hook Library & Parser Boundaries (P-37)
  - `### Hooks & Enforcement`: Never Edit Hook Targets Directly; Linked Worktree Hook Defense-in-Depth; Hook Security, Integrity & Trust Model
  - `### Documentation & Contracts`: Documentation Synchronization; Verb Behaviour Contracts (P-34); Three-Tier Document Governance & Delimited Template Sync (P-25); Continuous Documentation Navigation Invariant
  - `### Testing`: Test Harness Sandbox Confinement; Opt-In Failure Test Declaration & TDD Gate (P-35)
  - `### Plans`: Frozen Plan Immutability; Plan Worktrees (P-54); Plan Groups (P-64); Plan Conflict Audit (P-65); Plan Abort (P-69); A Plan Closes Further Issues (P-86)
  - `### Commits & Integration`: Attribution Policy Tiers & Single Identity Layer (P-40); Plan-Bound Commit Helper & Unified Lifecycle Commit Engine (P-39); General-Purpose Git Notes Subsystem (P-44); The Squash on the Plan Branch (P-84); Milestone Release Bundling & Tag Ledgers (P-38)
  - `### Issues`: Two-Lane Boundary; Issue Fixes, Hotfixes & Plans Held Elsewhere (P-52); Issue Abort (P-76); One Commit per Fix (P-85); The Issue Work Queue (P-89)
- **Cross-references.** The one in-file reference, "(Rule 2)" in Front-Door Repository Assertion, names the rule instead: "(*Path Resolution Single Source of Truth*)". `CHANGELOG.md` lines citing rule numbers are released history and stay.
- **Plan Groups (P-64)** becomes: A group plan (`# 🧩 Group Plan P-<n>:`, the one marker verbs read) is a planning container for several member plans (`* **Group:**`, listed in its `* **Members:**`, its amendments member last). `ARCHITECTURE.md` and `CODEMAP.md` changes live whole in the group plan and are applied by heading (`lib/group_docs.sh`), guarded by checksum base lines; members never edit them. Groups do not nest. Fixes stay on the development branch, except group-caused ones (`issue fix … group`), which land on the feature branch. Its lifecycle (feature branch, members, ownership, the amendments member, `done`) is *Group Lifecycle: Ownership, Amendments, Done (P-103)*.
- No rule's text changes otherwise; no rule is added or dropped (30 before, 30 after).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

- [x] Task 1: Rewrite `## 🚦 4.` as topic and rule headings (§2); update Plan Groups and the one cross-reference.
- [x] Task 2: Check: 30 rules before and after, each rule's text unchanged except the two in §2 (diff of the rule bodies).
- [x] Task 3: `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `ARCHITECTURE.md` -> `## 🚦 4. Invariant Architectural Rules` as topic and rule headings.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-17:** Plan implementation completed and archived to done/.
* **2026-10-17:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-17:** File renamed from P105-architecture-rule-23-pointer.md to P105-architecture-rules-as-headings.md.
*Tracks how the plan evolved across sessions.*
* **2026-10-17:** Drafted from #166. Widened (developer): every rule its own heading, grouped by topic, numbers removed.
* **2026-10-17:** Widened (developer): history wording removed from the whole file (Plan State, Plan Identity, Concurrent Plans, Adoption); the architecture describes the present, Git and the archived plans hold the history. Blank lines before three headings.
