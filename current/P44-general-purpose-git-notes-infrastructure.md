# 🗺️ Plan P-44: General-Purpose Git Notes Infrastructure & Worktree Hooks
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Milestone 1.2 / Metadata Architecture
* **Plan ID:** P-44
* **Status:** 🔷 Frozen
* **Base:** none
* **Commits:** none

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 1. Context & Architectural Goal

Git Notes (`refs/notes/...`) are an out-of-band metadata store natively supported by Git, allowing arbitrary structured text (extended descriptions, review feedback, CI benchmark metrics, audit signatures, AI provenance) to be attached to commit objects without rewriting commit SHAs or dirtying commit messages.

Previously in Milestone 1.0 (P-40), notes were coupled exclusively to AI attribution (`ai-notes` / `ai-note`) with destructive refspec configurations (`remote.origin.push/fetch` overwritten with `+refs/heads/*`), overwriting note writers (`git notes add -f`), and silent error suppression.

**Settled Architecture & Scope (RFC Consensus):**
1. **Decoupled Engine with Two Fixed Refs**:
   - `refs/notes/commits`: General developer notes, code reviews, benchmark data, descriptions.
   - `refs/notes/ai`: Immutable AI attribution and agent trace records.
   - Isolation: A developer editing or removing a review note on `refs/notes/commits` cannot delete or tamper with the AI audit trail on `refs/notes/ai`.
   - Visibility: `notes.displayRef = refs/notes/ai` is configured once during setup so standard `git log` displays both refs natively.
2. **Adopter Choice with Safe Defaults**:
   - Merge strategy: Defaults to `union` (preserving multi-line blocks; `cat_sort_uniq` is rejected as default because line-sorting scrambles markdown/text).
   - Rewrite mode: Defaults to `concatenate` (explicitly verified and enforced under `enforce`).
   - Write mode: Defaults to `append` via `aapp.noteWrite = append` (in code).
   - Native Git settings (`notes.rewriteRef`, `notes.ai.mergeStrategy union`) are written strictly **when unset in effective scope** (`git config --get`). Adopter overrides across local, global, or system configs are always respected.
3. **Audit Guard (`aapp.aiNotesGuard = warn | enforce`, code default: `warn`)**:
   - `warn`: Surfaces advisory warnings in `status` if an adopter's custom configuration uses a lossy strategy (`ours`, `theirs`, `cat_sort_uniq`, rewrite `ignore`) on `refs/notes/ai`.
   - `enforce`: For sensitive benchmarks, guarantees lossless operations on `refs/notes/ai` and audits environment variable overrides (`GIT_NOTES_REWRITE_MODE`, `GIT_NOTES_REWRITE_REF`).
4. **Push / Sync Governance**:
   - Config key: `aapp.notesRemote=<remote>` (code default: unset / local-first).
   - Notes are local by default. If `aapp.notesRemote` is set, `aapp note push` pushes explicit refs without force, and `aapp note pull` fetches into `refs/notes/remote/<remote>/*` and safely merges.
   - If Git's `manual` merge strategy encounters a conflict, `aapp pull`/`sync` fails closed with diagnostic instructions naming `git notes merge --commit` and `git notes merge --abort`.
5. **Focused CLI Ingress**:
   - `aapp note [status | stage "<text>" [agent <A> vendor <V> model <M>] | push | pull]`
   - Identity tokens route notes to `refs/notes/ai`; omitting identity routes to `refs/notes/commits`.

---

## 2. Technical Blueprint

### 1. Dedicated Note Switchboard: `lib/cmd_note.sh`
Consolidate note operations into a focused command:
```text
aapp note [status | stage "<text>" [agent <A> vendor <V> model <M>] | push | pull]
```
- **`status` (default)**:
  - Displays configured notes remote (`aapp.notesRemote` or `local only`).
  - Displays active merge strategies and rewrite settings for `refs/notes/commits` and `refs/notes/ai`.
  - Evaluates `aapp.aiNotesGuard` and prints warnings if lossy settings are detected on `refs/notes/ai`.
  - Lists pending staged note buffers in `.git/`.
- **`stage "<text>" [agent <A> vendor <V> model <M>]`**:
  - Pre-stages a note buffer in `.git/aapp_pending_note.<hash>`.
  - If identity tokens are supplied, formats standard semantic headers (`AI-Agent:`, etc.) targeted for `refs/notes/ai`.
  - If no identity is supplied, formats general note targeted for `refs/notes/commits`.
- **`push [remote]`**:
  - Uses specified remote, falling back to `aapp.notesRemote`. If unset, refuses push (local-first).
  - Executes `git push <remote> refs/notes/commits refs/notes/ai` without force.
- **`pull [remote]`**:
  - Fetches remote notes into `refs/notes/remote/<remote>/commits` and `refs/notes/remote/<remote>/ai`.
  - Merges into local refs using effective merge strategies (`union` by default).
  - Fails closed on `manual` merge conflicts with instructions to run `git notes merge --commit` or `--abort`.

### 2. Post-Commit Hook & Attachment Engine (`templates/aapp-post-commit`)
- Update `templates/aapp-post-commit` to inspect staged note buffers:
  - Reads target ref from the buffer (or infers `refs/notes/ai` vs `refs/notes/commits`).
  - Appends to the note non-destructively: uses `git notes --ref=<ref> append -F <buffer> HEAD`.
  - Fails loudly with diagnostic warnings if attachment fails; never silently reaps unattached notes without warning.

### 3. Commit-Msg Hook & Re-Keying (`templates/aapp-commit-msg`)
- Generalize note buffer re-keying:
  - When a commit message is edited in `$EDITOR`, re-keys the staged note buffer SHA256 across all attribution modes (`none`, `lax`, `strict`, `notes`), ensuring staged notes are never lost.

### 4. Single Unified Writer (`lib/attribution.sh` & `lib/cmd_note.sh`)
- Unify note writing across the kit:
  - Replace error-discarding `-f` in `attribution_note` with non-destructive appending.
  - Fail closed on write errors.
  - Lift the `[ "$mode" != "notes" ] && return 0` early return in `attribution_note` so `aapp commit ... note "<text>"` writes notes across all attribution modes (`none`, `lax`, `strict`, `notes`).
  - In `lax`/`strict`, trailers remain the public authoritative identity; notes provide private supplementary benchmark/audit details.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
  - Legacy `cmd_ai_notes` refspec overwriting is completely removed.
  - Legacy `aapp ai-note` is retired in favor of `aapp note stage`.
  - Existing notes in `refs/notes/commits` remain readable; setup ensures `refs/notes/ai` is also initialized.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Engine Implementation & Unified Writer
- [ ] Task 1.1: Implement `lib/cmd_note.sh` with subcommands: `status`, `stage`, `push`, `pull`.
- [ ] Task 1.2: Refactor `templates/aapp-post-commit` to attach notes using `git notes append` and route to `refs/notes/commits` vs `refs/notes/ai`.
- [ ] Task 1.3: Update `templates/aapp-commit-msg` to re-key note buffers on `$EDITOR` edit regardless of attribution mode.
- [ ] Task 1.4: Refactor `attribution_note` in `lib/attribution.sh` to remove silent error suppression (`>/dev/null`), lift the mode check to allow notes in any mode, and write to `refs/notes/ai` using `git notes append`.

### Phase 2: Setup, Sync & Guard Logic
- [ ] Task 2.1: Implement safe setup in `lib/cmd_note.sh`: write `notes.rewriteRef` (both refs) and `notes.displayRef = refs/notes/ai` strictly when unset.
- [ ] Task 2.2: Implement `aapp.aiNotesGuard` checks (`warn` vs `enforce`) in `cmd_note_status`, `aapp pull`/`sync`, and the post-commit writer (explicitly setting and auditing `notes.rewriteMode concatenate` under `enforce`).
- [ ] Task 2.3: Wire `aapp.notesRemote` into `lib/cmd_sync.sh` so `aapp push` and `aapp sync` include notes push/pull when remote is configured.

### Phase 3: CLI Catalog, Contracts & Tests
- [ ] Task 3.1: Register `note` in `lib/verbs.tsv` and dispatch in `aapp`.
- [ ] Task 3.2: Create contract document `lib/docs/verbs/note.md`.
- [ ] Task 3.3: Author contract test suite `tests/verbs/note.sh`.
- [ ] Task 3.4: Author comprehensive integration suite `tests/notes_test.sh` testing:
  - Two-ref isolation (`commits` vs `ai`).
  - Appending without data loss on amend.
  - `aapp.notesRemote` push and pull with `union` merge.
  - Fail closed on `manual` merge conflicts.
  - `aapp.aiNotesGuard` enforcement of lossless settings.
- [ ] Task 3.5: Run full test suite (`aapp test strict quiet`) ensuring all suites pass cleanly.

### Phase 4: Documentation Sync
- [ ] Task 4.1: Update `MANUAL.md` detailing Git Notes subsystem, `aapp.notesRemote`, and `aapp.aiNotesGuard`.
- [ ] Task 4.2: Update `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md`.
- [ ] Task 4.3: Update `CHANGELOG.md` under `## [Unreleased] -> ### Added`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_note.sh` -> NEW FILE -> Dedicated Git Notes engine and CLI handler.
- [ ] `lib/docs/verbs/note.md` -> NEW FILE -> Verb contract specification for aapp note.
- [ ] `tests/verbs/note.sh` -> NEW FILE -> Contract test suite for aapp note.
- [ ] `tests/notes_test.sh` -> NEW FILE -> Subsystem integration test suite for notes.
- [ ] `templates/aapp-post-commit` -> Non-destructive note attachment and two-ref routing.
- [ ] `templates/aapp-commit-msg` -> Buffer re-keying across all attribution modes.
- [ ] `lib/attribution.sh` -> Fail-closed appending note writer for attribution traces.
- [ ] `lib/cmd_sync.sh` -> Safe notes sync integration via aapp.notesRemote.
- [ ] `lib/verbs.tsv` -> Register note verb entry.
- [ ] `aapp` -> Route note verb in CLI dispatcher.
- [ ] `MANUAL.md` -> User documentation for Git Notes subsystem.
- [ ] `CHEATSHEET.md` -> Quick reference for aapp note commands and configs.
- [ ] `ARCHITECTURE.md` -> Subsystem architecture documentation.
- [ ] `CHANGELOG.md` -> Record general notes subsystem under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_ai.sh` -> Governed by P-43; only interfaces via standard note buffer.
- [ ] `.plans/current/P43-*` -> P-43 remains isolated in its refinement phase.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-28:** Plan scaffolded and refined per RFC consensus: settled on two fixed refs (`refs/notes/commits` + `refs/notes/ai`), `union` default merge, `aapp.aiNotesGuard=warn|enforce`, `aapp.notesRemote` sync, and fail-closed non-destructive appending writers.
