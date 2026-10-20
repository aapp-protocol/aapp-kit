# 🗺️ Plan P-112: Perl Port Of The Kit Amendments
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Plan ID:** P-112
* **Kind:** amendments
* **Changelog:** Changed: Perl Port Of The Kit Amendments
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- A group's amendments member (P-101): drafted with its group, started by the group's `start`, archived
     last. It takes what development finds: members request (`aapp refine <id> request`), an approver grants
     (`approve` / `refuse`), it implements and lands on the feature branch (`aapp commit … land`), members
     rebase. Its Target Files grow only by approved requests. Corrections of the group's text go into the
     group plan with a line under `## Decisions` (`aapp refine <id> decision`). Only verbs write the three
     sections at the end. -->
* **Status:** ⚡ In Development
* **Base:** `fa3a42e` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P112 (plan/P112-perl-port-of-the-kit-amendments)
* **Group:** P-111
* **Commits:** `41e579d` (plan/P112-perl-port-of-the-kit-amendments)
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
The group's amendments member: the one place where what the group's development finds is requested, approved, recorded and made. Members are never amended after start. Typical requests: a test outside a member that asserts the behaviour the member changes (landed here, the member rebases and turns it green); a file two members need; a correction of the group's text.

---

## 2. Technical Blueprint
Each request is implemented as its approval describes; corrections of the group's text are recorded under `## Decisions`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
- [ ] Task 1: Implement each approved request; land it (`aapp commit … land`).
- [ ] Task 2: Leave no request pending or approved without landing before the group's members are archived.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
<!-- Grows only by approved requests (aapp refine <id> approve <n>; or file, when approval is not required). -->
- [ ] `lib/AAPP/Logger.pm` -> R1 Logger opens the log file with :encoding(UTF-8) (use utf8 port-wide)

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan activated into ⚡ In Development via start.
* **2026-10-19:** Drafted with its group.

---

## Scope Requests
- **R1** 2026-10-20 · P-115 · `lib/AAPP/Logger.pm` · Logger opens the log file with :encoding(UTF-8) (use utf8 port-wide) — landed `41e579d`

## Decisions

## Follow-ups
