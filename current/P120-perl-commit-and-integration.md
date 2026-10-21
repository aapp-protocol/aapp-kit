# 🗺️ Plan P-120: Perl Commit And Integration
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-120
* **Changelog:** Changed: Port commit, branch integration, note, and AI attribution verbs (`commit`, `note`, `ai`) and shared integration engine to `AAPP::Integrate`, `AAPP::Cmd::Commit`, `AAPP::Cmd::Note`, and `AAPP::Cmd::Ai`.
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-120` is the eighth member of group `P-111` (*Perl Port Of The Kit*). It ports the plan-bound commit helper (`lib/cmd_commit.sh`, 567 lines), developer/AI Git notes manager (`lib/cmd_note.sh`, 386 lines), and AI attribution switchboard (`lib/cmd_ai.sh`, 374 lines) into `lib/AAPP/Cmd/Commit.pm`, `lib/AAPP/Cmd/Note.pm`, and `lib/AAPP/Cmd/Ai.pm`.

In bash, `aapp commit` and `aapp note stage` shell out to `shasum`/`sha256sum` and `awk` to stage pending notes, splice `CHANGELOG.md` under `## [Unreleased]`, and rewrite `* **Commits:**` in the active plan. In Perl, `Digest::SHA::sha256_hex` computes note buffer hashes in-process, `AAPP::State` / `AAPP::Plan` update `CHANGELOG.md` and `* **Commits:**` directly, and `aapp commit land` calls `AAPP::Plan`'s `_ig_preflight` and fast-forward integration engine (`P-119`).

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Cmd/*.pm`, `lib/cmd_commit.sh`, `lib/cmd_note.sh`, `lib/cmd_ai.sh`, `aapp`). `tests/AAPP/*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Cmd::Commit` (`lib/AAPP/Cmd/Commit.pm`) — `aapp commit` (`lib/cmd_commit.sh`, 567 lines)
Ports `cmd_commit` from `lib/cmd_commit.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help commit full` and `lib/docs/verbs/commit.md` (standard plan-bound commit, `amend`, `adopt`, `land`, trailers, staged notes, and changelog splicing), verified under unchanged `tests/AAPP/Verb/Commit.pm`.
- Uses `AAPP::State` (`P-115`), `AAPP::Attribution` (`P-116`), `AAPP::CommitEngine` (`P-115`), `Digest::SHA::sha256_hex` (for `$(git rev-parse --git-path aapp_pending_note).<sha256>`), and `AAPP::Plan`'s `_ig_*` engine (`P-119`) for `land`.

### 2.2 `AAPP::Cmd::Note` (`lib/AAPP/Cmd/Note.pm`) — `aapp note` (`lib/cmd_note.sh`, 386 lines)
Ports `cmd_note` from `lib/cmd_note.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help note full` and `lib/docs/verbs/note.md` (`status`, `stage`, `push`, `pull`), verified under unchanged `tests/AAPP/Verb/Note.pm`.

### 2.3 `AAPP::Cmd::Ai` (`lib/AAPP/Cmd/Ai.pm`) — `aapp ai` (`lib/cmd_ai.sh`, 374 lines)
Ports `cmd_ai` from `lib/cmd_ai.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help ai full` and `lib/docs/verbs/ai.md` (`status`, `none`, `lax`, `strict`, `notes`, `credits`), verified under unchanged `tests/AAPP/Verb/Ai.pm`.

### 🔄 Migration & Compatibility Strategy
- **Transitional Coexistence (`P-120` → `P-122`):** While `commit`, `note`, and `ai` route directly to `AAPP::Cmd::Commit`, `AAPP::Cmd::Note`, and `AAPP::Cmd::Ai` from `aapp`, `lib/cmd_commit.sh`, `lib/cmd_note.sh`, and `lib/cmd_ai.sh` remain as thin shims until `P-122` removes all `lib/*.sh` files.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Commit, Note & AI Verbs (`AAPP::Cmd::Commit`, `Note`, `Ai`)
- [ ] Task 1.1: Implement `lib/AAPP/Cmd/Commit.pm` covering standard plan-bound commits, `amend`, `adopt`, `land` (via `AAPP::Plan`), automatic `CHANGELOG.md` splice, trailer assembly, and `Digest::SHA` staged note buffers.
- [ ] Task 1.2: Implement `lib/AAPP/Cmd/Note.pm` (`status`, `stage`, `push`, `pull`) and `lib/AAPP/Cmd/Ai.pm` (`status`, `none`, `lax`, `strict`, `notes [on|off]`, `credits`).
- [ ] Task 1.3: Wire `commit`, `note`, and `ai` in `./aapp` and slim `lib/cmd_commit.sh`, `lib/cmd_note.sh`, and `lib/cmd_ai.sh` to thin transitional shims.

### Phase 2: Verification & Documentation
- [ ] Task 2.1: Run `./aapp test commit note ai` and full `./aapp test` (`tests/verb_commit_test.sh`, `tests/verb_note_test.sh`, `tests/verb_ai_test.sh`) to verify 100% pass rate against the locked test suites.
- [ ] Task 2.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 2.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Commit.pm` -> `aapp commit` (`amend`, `adopt`, `land`, changelog splice, trailers, staged notes).
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Note.pm` -> `aapp note` (`status`, `stage`, `push`, `pull`) developer and AI Git notes management.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Ai.pm` -> `aapp ai` (`status`, `none`, `lax`, `strict`, `notes`, `credits`) attribution switchboard.
- [ ] `aapp` -> Dispatch `commit`, `note`, and `ai` directly to `AAPP::Cmd::*`.
- [ ] `lib/cmd_commit.sh` -> Transitional shim delegating to `AAPP::Cmd::Commit` until `P-122`.
- [ ] `lib/cmd_note.sh` -> Transitional shim delegating to `AAPP::Cmd::Note` until `P-122`.
- [ ] `lib/cmd_ai.sh` -> Transitional shim delegating to `AAPP::Cmd::Ai` until `P-122`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/AAPP/Tests.pm` -> Test harness and all `tests/AAPP/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_commit.sh`, `lib/cmd_note.sh`, and `lib/cmd_ai.sh` contracts.

