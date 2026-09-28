# 🗺️ Plan P-44: General-Purpose Git Notes Infrastructure & Worktree Hooks
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Milestone 1.2 / Metadata Architecture
* **Plan ID:** P-44
* **Status:** 🟣 Under Review
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

Git Notes (`refs/notes/...`) are an out-of-band metadata store natively supported by Git, allowing arbitrary structured text (extended descriptions, review feedback, CI benchmark metrics, audit signatures, issue links, AI provenance) to be attached to commit objects without rewriting commit SHAs or dirtying commit messages.

In Milestone 1.0 (P-40), notes were introduced exclusively as a local-first AI attribution mechanism (`ai-notes` / `ai-note`). Subordinating Git Notes to AI attribution conflated two distinct architectural concerns:
1. **AI Governance**: A policy choice (`none`, `lax`, `strict`) regarding AI commit trailers.
2. **Metadata Infrastructure**: A general mechanism for annotating commits with arbitrary metadata, controlling remote push/pull sync, and triggering lifecycle hooks.

**Goal:**
Elevate Git Notes into a first-class, general-purpose kit subsystem governed by `aapp note`. Decouple note management from AI attribution completely, provide granular remote push/pull controls (`aapp.notesPush`), and wire lifecycle hooks (`on-note`, `post-commit` note integration) for team workflows and external audit piping.

Under this architecture:
- Teams and developers can attach arbitrary commit notes (benchmarks, reviews, descriptions) at will.
- AI attribution (`P-43`) becomes simply one specialized consumer of the generic note engine when `aapp.aiAttribution = notes`.

---

## 2. Technical Blueprint

### 1. General Note Switchboard: `aapp note`
Introduce a dedicated verb and library `lib/cmd_note.sh` managing commit notes:

```text
aapp note [show | add | edit | rm | list | stage | push | pull]
```

- **Inspect Notes (`aapp note show [commit]` or `aapp note [commit]`)**:
  Displays notes attached to the target commit (defaults to `HEAD`). Shows note ref (`refs/notes/commits`) and content.
- **Add / Attach Notes (`aapp note add "<text>" [commit]`)**:
  Attaches `<text>` to target commit using `git notes add` (or appends via `-m`).
- **Edit Notes (`aapp note edit [commit]`)**:
  Opens `$EDITOR` via `git notes edit`.
- **Remove Notes (`aapp note rm [commit]`)**:
  Removes note attached to commit via `git notes remove`.
- **Pre-Stage Buffer (`aapp note stage "<text>"`)**:
  Pre-stages note text in `.git/aapp_pending_note.<sha256>` to be automatically attached to the next commit by `aapp-post-commit`.
- **Status & List (`aapp note list`)**:
  Lists all commits carrying notes, showing commit SHA, subject, and note summary.

### 2. Push & Sync Governance: Local-First with Explicit Remote Sync
By default in Git, `git push` does NOT push notes (`refs/notes/*`). P-44 provides robust, explicit sync governance:

- **Repository Configuration**:
  - `git config aapp.notesPush true|false` (default: `false` — local-first).
  - `git config aapp.notesRef refs/notes/commits` (default standard ref).
- **Direct Remote Commands**:
  - `aapp note push [remote]` -> Executes `git push <remote> "refs/notes/*:refs/notes/*"`.
  - `aapp note pull [remote]` -> Executes `git fetch <remote> "refs/notes/*:refs/notes/*"`.
- **Sync Integration (`lib/cmd_sync.sh`)**:
  - When `aapp push` or `aapp sync` runs: if `aapp.notesPush` is `true`, it automatically synchronizes notes alongside branch worktrees.

### 3. Worktree & Lifecycle Hook Integration
- **`post-commit` Note Attachment**:
  - Generalize `aapp-post-commit` to inspect staged note buffers regardless of whether the note contains AI metadata or arbitrary user descriptions.
  - Automatically match the commit message SHA256 and attach the note via `git notes add -f -F`.
- **`on-note` Hook Dispatcher Event**:
  - When a note is added or updated, dispatch the `on-note` event through `lib/hook_dispatcher.sh`.
  - Allows team plugins to forward commit notes to webhooks (Slack, GitHub PR comments, internal audit collectors).

### 4. Decoupling & Clean Separation with Plan P-43
```text
┌─────────────────────────────────────────────────────────────┐
│ P-43: AI Attribution Policy (aapp ai)                       │
├─────────────────────────────────────────────────────────────┤
│ Governs policy: none | lax | strict | notes                 │
│ If mode == notes: formats semantic note buffer              │
└──────────────────────────────┬──────────────────────────────┘
                               │ delegates buffer to
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ P-44: General Git Notes Infrastructure (aapp note)          │
├─────────────────────────────────────────────────────────────┤
│ • Staged note buffers (.git/aapp_pending_note)             │
│ • Commit attachment via aapp-post-commit                    │
│ • Local-first storage (refs/notes/commits)                  │
│ • Push/pull refspecs (aapp.notesPush)                       │
│ • Team lifecycle hooks (on-note)                            │
└─────────────────────────────────────────────────────────────┘
```

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
  - Legacy `aapp ai-note` is completely retired in favor of `aapp note stage "<text>"`.
  - Legacy `aapp ai-notes` mode toggle lives under `aapp ai notes`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Engine & CLI Verb (`aapp note`)
- [ ] Task 1.1: Implement `lib/cmd_note.sh` with subcommands: `show`, `add`, `stage`, `edit`, `rm`, `list`, `push`, `pull`.
- [ ] Task 1.2: Register `note` verb in `lib/verbs.tsv` under the `sync` or `daily` tier with contract `lib/docs/verbs/note.md`.
- [ ] Task 1.3: Update `aapp` dispatcher to route `note` to `lib/cmd_note.sh`.

### Phase 2: Post-Commit Hook & Buffer Generalization
- [ ] Task 2.1: Update `templates/aapp-post-commit` to process generic note buffers without AI-specific coupling.
- [ ] Task 2.2: Add `on-note` hook event to `lib/hook_dispatcher.sh` and dispatch when notes are recorded.

### Phase 3: Push/Pull Sync Integration & Config
- [ ] Task 3.1: Add `aapp.notesPush` setting in `lib/cmd_sync.sh` and sync routines.
- [ ] Task 3.2: Implement `aapp note push` and `aapp note pull` with standard refspecs.

### Phase 4: Test Coverage & Verification
- [ ] Task 4.1: Create dedicated test suite `tests/notes_test.sh` testing:
  - Staging and auto-attachment of arbitrary notes.
  - Adding, editing, showing, and removing notes via `aapp note`.
  - Push/pull behavior based on `aapp.notesPush`.
  - Hook dispatch on note attachment.
- [ ] Task 4.2: Update `tests/verbs/note.sh` for contract verification.
- [ ] Task 4.3: Verify integration with P-43 AI notes mode.

### Phase 5: Documentation & Changelog
- [ ] Task 5.1: Create `lib/docs/verbs/note.md`.
- [ ] Task 5.2: Update `MANUAL.md`, `CHEATSHEET.md`, and `ARCHITECTURE.md`.
- [ ] Task 5.3: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_note.sh` -> NEW FILE -> Core Git Notes CLI implementation.
- [ ] `lib/docs/verbs/note.md` -> NEW FILE -> Verb contract documentation for aapp note.
- [ ] `tests/verbs/note.sh` -> NEW FILE -> Contract test suite for aapp note.
- [ ] `tests/notes_test.sh` -> NEW FILE -> Integration test suite for notes subsystem.
- [ ] `templates/aapp-post-commit` -> Generalize staged note attachment logic.
- [ ] `lib/cmd_sync.sh` -> Add notes push/pull sync integration when configured.
- [ ] `lib/hook_dispatcher.sh` -> Add on-note hook event dispatching.
- [ ] `lib/verbs.tsv` -> Register note verb entry.
- [ ] `aapp` -> Route note command in dispatcher.
- [ ] `MANUAL.md` -> Document general-purpose notes usage, config, and team workflows.
- [ ] `CHEATSHEET.md` -> Add aapp note commands and options.
- [ ] `ARCHITECTURE.md` -> Document Git Notes architectural boundary and sync model.
- [ ] `CHANGELOG.md` -> Record general notes subsystem under Added.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_ai.sh` -> Governed by P-43; only interfaces via standard note buffer.
- [ ] `.plans/current/P43-*` -> P-43 remains isolated in its refinement phase.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Ref Namespace):** Should `aapp note` operate strictly on `refs/notes/commits`, or allow arbitrary custom namespaces via `--ref=<name>` (e.g. `refs/notes/reviews`, `refs/notes/metrics`)?
* [ ] **Question 2 (Remote Push Refspec):** When `aapp.notesPush=true`, should `aapp push` use force-with-lease (`+refs/notes/*:refs/notes/*`) or standard fetch-and-merge (`cat_sort_uniq`) to avoid clobbering upstream notes?

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Scaffolded blueprint to establish general-purpose Git Notes subsystem and decoupled from P-43 AI attribution.
