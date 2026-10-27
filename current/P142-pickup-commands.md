# 🗺️ Plan P-142: Pickup Commands
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Target Issue / Milestone:** none
* **Plan ID:** P-142
* **Changelog:** Added: `aapp pickup list | add | edit | refine` and a three-field pickup line (`Title : file : description`) for listing and editing ideas from the CLI or a web view
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-140
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log <sev> <type> "<symptom>" file <path>…`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A member of group P-140 (noun-first commands). Pickup ideas have no noun today: `aapp status` lists the first five, the rest are read in `.plans/pickup.md`, ideas are added by hand and committed with `aapp refine pickup`. A web view and agents need to list every idea and edit one by a stable key. This plan gives pickup its own noun, `aapp pickup`, and one line format that splits without guessing.

---

## 2. Technical Blueprint

### 2.1 The line
```
- [ ] <Title> : <file> : <description>
```
- Three fields, split on the first two colons by position (`index` / `substr`, no regex); spaces around a field are trimmed. Everything after the second colon is the description, kept as written: it may hold colons, URLs and repository paths.
- **Title:** required, no colon, unique in the file (it is the key for `edit`); at most `aapp.pickupTitleMax` characters.
- **File:** a plain file name in `.plans/pickup/` (no `/`, no colon) holding more detail, which may link anywhere; empty when there is none (`- [ ] Title :  : description`). `pickup/` is local and ignored: `add` / `edit` check the file exists; `list` shows a missing one as `file_missing`, never refuses.
- **Description:** free text, required, one line: no line breaks (an idea is exactly one line of `pickup.md`; longer detail goes in its file).
- One parser (`AAPP::Pickup::Line`) serves every reader: `list`, `status`, `draft`, the health checks.

### 2.2 Commands
| Command | Effect |
|---|---|
| `aapp pickup list [json]` | every open idea in file order: title, file (`file_missing` when absent), description |
| `aapp pickup add "<title>" "<description>" [file <name>]` | writes the line and commits it (`refine pickup` is no longer needed for a new idea) |
| `aapp pickup edit "<title>" [title "<new>"] [file <name> \| file none] [text "<description>"]` | changes the named fields of that line and commits |
| `aapp pickup refine "<msg>"` | commits a hand edit of `pickup.md` after checking every line (`aapp refine pickup` leaves the kit) |

Refusals (exit 1, nothing written): a title with a colon, empty, too long or already used; a file name with `/` or a colon, or not in `.plans/pickup/`; an empty description, or one with a line break (in any field); `edit` of a title that is not there; `refine` with a malformed line (each named).

### 2.3 Conversion
`.plans/pickup.md` is converted once to the three-field line (title, file named in today's text when it is one in `pickup/`, else empty, description); the old `<title>: <text>` form leaves every parser. `templates/pickup.md`, `templates/AGENTS.md` (the pickup rule) and the digest skill show the new line.

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
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
*(Details come in refinement. Today's readers of the line: `lib/AAPP/Text.pm`, `lib/AAPP/Health.pm`, and in bash `lib/aapp-lib.sh`, `lib/cmd_plan.sh`, `lib/cmd_status.sh`, `lib/planning_health.sh`; contracts `lib/docs/verbs/draft.md`, `lib/docs/verbs/refine.md`, `lib/docs/core/aapp_lib.md`; `templates/pickup.md`, `templates/AGENTS.md`.)*

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None yet — details come in refinement.)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-27:** Drafted as the pickup member of P-140; line format and commands settled in chat.
