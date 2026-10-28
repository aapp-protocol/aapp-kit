# 🗺️ Plan P-145: Plan Restore
* **Created:** 2026-10-28 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-145
* **Changelog:** Added: `aapp plan restore <id> [reason "<text>"] [group <group-id>]` to recover aborted plans back to `.plans/current/` with state matrix re-entry and ledger accounting
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A member of group P-111 (*Perl Port Of The Kit*). Today, `aapp plan abort <id>` archives an abandoned plan or group to `.plans/aborted/` and records the abandonment in `000-aborted-ledger.md`. However, the protocol lacks a symmetrical restore procedure. When an aborted blueprint needs to be revived (e.g. premature abandonment, architectural re-evaluation, or reassignment), it currently requires brittle manual file moves, state matrix surgery, and ledger edits.

This plan introduces `aapp plan restore` as a first-class lifecycle word under `lib/AAPP/Runner/Plan/Restore.pm` and `AAPP::Plan::plan_restore`, providing a deterministic, validated recovery pipeline before bash decoupling (`P-122`).

---

## 2. Technical Blueprint

### 2.1 The Word & Syntax
```
aapp plan restore <id> [reason "<text>"] [group <group-id>]
```
- `<id>`: Plan identifier (`P-47`, `47`, slug, or filename).
- `reason "<text>"`: Optional reason for revival (default: `Restored from aborted archive`).
- `group <group-id>`: Optional group enrollment; when provided, reassigns the restored plan's `* **Group:**` header and enrolls it into `<group-id>`.

### 2.2 Preflight Validation & Refusals
1. **Not Found in Aborted**: Refused with exit 1 if no matching blueprint exists in `.plans/aborted/P<id>-*.md`.
2. **Active Collision**: Refused with exit 1 if `<id>` or `<slug>` matches an existing plan in `.plans/current/` or an active entry in `.plans/state_matrix.md`.
3. **Target Group Inactive**: If `group <group-id>` is given, refused if `<group-id>` is not an active group in `.plans/current/`.
4. **Dirty Workspace**: Refused if `.plans` worktree has unstaged or uncommitted changes.

### 2.3 Execution Pipeline (`AAPP::Plan::plan_restore`)
1. **Header Cleanup & Status Reset**:
   - Strips `* **Status:** ❌ Aborted`.
   - Strips `* **Aborted:** <date> | **Reason:** <reason>`.
   - Sets `* **Status:** 🟣 Under Review` (or `📝 Refining`).
   - Updates `* **Last Refined:** <YYYY-MM-DD>`.
   - If `group <group-id>` is given, updates `* **Group:** <group-id>`.
   - Appends entry under `## 6. Change Log & Refinement History`: `* **<date>:** Restored from aborted archive: <reason>`.
2. **File Relocation**:
   - Moves file from `.plans/aborted/P<id>-<slug>.md` back to `.plans/current/P<id>-<slug>.md`.
3. **State Matrix Registration**:
   - Re-registers the plan entry under `## 🧠 Human Thought & Refinement (The Incubator)` in `.plans/state_matrix.md`:
     `- 🟣 **P-<id>**: [\`P<id>-<slug>.md\`](current/P<id>-<slug>.md) — <Title>`.
4. **Aborted Ledger Accounting**:
   - Updates `.plans/aborted/000-aborted-ledger.md`: removes the row corresponding to `<id>` (or appends a `(Restored <date>: <reason>)` annotation).
5. **Target Group Enrollment**:
   - If `group <group-id>` is specified, appends `P-<id>` to the group's `* **Members:**` header line.
6. **Target Issue Relink**:
   - If the plan specifies `* **Target Issue / Milestone:** #<num>`, scans `.plans/ISSUES.md`: repoints the fix cell from `aborted/` back to `current/` and updates issue status back to `🔵 Planned`.
7. **Telemetry**:
   - Emits structured event `post-restore`: `id => $id`, `slug => $slug`, `restored_from => $path`, `reason => $reason`, `group => $grp`.
8. **Git Commit**:
   - Commits the plans worktree with prefix `plan(restore): restore P-<id> from aborted/`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Engine (`AAPP::Plan::plan_restore`)
- [ ] Task 1.1: Implement `plan_restore` in `lib/AAPP/Plan.pm` with preflight collision checks, header mutation, matrix re-entry, and ledger accounting.

### Phase 2: Word Runner (`AAPP::Runner::Plan::Restore`)
- [ ] Task 2.1: Implement `lib/AAPP/Runner/Plan/Restore.pm` with CLI argument parsing, diagnostics, and structured `post-restore` telemetry.
- [ ] Task 2.2: Register `restore` in `lib/AAPP/Runner/Plan.pm` reserved words and word dispatch table.

### Phase 3: Contract & Test Suite
- [ ] Task 3.1: Update `lib/docs/verbs/plan.md` documenting `aapp plan restore` syntax, preflight refusals, and side effects.
- [ ] Task 3.2: Add unit and integration tests in `t/verb/plan.t` verifying clean restoration, collision refusals, issue re-linking, and ledger updates.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Restore.pm` -> `aapp plan restore` word runner.
- [ ] `lib/AAPP/Plan.pm` -> Core `plan_restore` engine (preflight collision check, file move, matrix re-entry, ledger sync).
- [ ] `lib/AAPP/Runner/Plan.pm` -> Word dispatch and reserved words table registration.
- [ ] `lib/docs/verbs/plan.md` -> Contract specification for `aapp plan restore`.
- [ ] `t/verb/plan.t` -> Test suite coverage for `aapp plan restore`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine remains untouched.
- [ ] `ARCHITECTURE.md` & `.agents/CODEMAP.md` -> Managed by group plan `P-111`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Drafted blueprint P-145 for canonical `aapp plan restore` command under `lib/AAPP/Runner/Plan/Restore.pm` in Group P-111.
