# 🗺️ Plan P-43: Consolidated AI Attribution Verb (`aapp ai`)
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Milestone 1.1 / UX Ergonomics
* **Plan ID:** P-43
* **Status:** 📝 Refining
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

During Milestone 1.0 (P-40), AI attribution modes were introduced alongside multiple dedicated top-level verbs:
`ai-lax`, `ai-strict`, `ai-notes`, `ai-off`, `ai-status`, `ai-note`, and `ai-credits`.

While functional, this introduced substantial **CLI verb sprawl** (consuming 7 rows in `lib/verbs.tsv` and `aapp help`) for policy choices that are toggled infrequently. Furthermore, subordinating Git Notes under AI attribution conflated two distinct concerns.

**Design Simplification & Invariants:**
1. **Consolidated Verb**: Collapse the fragmented `ai-*` verbs into a single polymorphic verb:
   ```text
   aapp ai [status | none | off | lax | strict | notes | credits]
   ```
2. **Init & Upgrade Immutability Invariant**:
   - `aapp init` sets `aapp.aiAttribution = none` (opt-in developer choice) **strictly when unset**.
   - Repeat `aapp init` and `aapp upgrade` **NEVER** modify, overwrite, or reset an existing `aapp.aiAttribution` configuration.
   - We explicitly do **not** add `--ai` flags to `aapp init`; setup remains clean and unburdened.
3. **Decoupled Notes Subsystem**:
   - General-purpose Git Notes infrastructure (staging, arbitrary annotations, push sync, hooks) is cleanly separated and delegated to Plan [P-44](P44-general-purpose-git-notes-infrastructure.md) (`aapp note`).
   - Legacy `ai-note` is dropped from the attribution catalog.

---

## 2. Technical Blueprint

### 1. Polymorphic CLI Interface: `aapp ai`
The single entry point `aapp ai` handles discovery, status, mode switching, and credits generation:

- **Status / Discovery (`aapp ai` or `aapp ai status`)**:
  - Displays current mode (`none`, `lax`, `strict`, `notes`).
  - Displays brief mode description and whether AI trailers/notes are currently enforced.
  - Shows helpful usage syntax: `aapp ai [status|off|none|lax|strict|notes|credits]`.

- **Mode Switching**:
  - `aapp ai off` or `aapp ai none`: Disables attribution (`aapp.aiAttribution = none`). Pure human authoring.
  - `aapp ai lax`: Mixed human/AI mode (`aapp.aiAttribution = lax`). Validates emailless trailers when present; human commits pass.
  - `aapp ai strict`: Autonomous trace mode (`aapp.aiAttribution = strict`). Enforces valid emailless trailers on every commit.
  - `aapp ai notes`: Local-first attribution mode (`aapp.aiAttribution = notes`). Stores attribution metadata in `refs/notes/commits`.

- **Subcommands**:
  - `aapp ai credits`: Generates or updates AI Contributors block in `README.md` (delegates to `cmd_ai_credits`).

- **Decoupled Notes Handoff (Clean Break to P-44)**:
  - Arbitrary note creation, staging, editing, and push sync are decoupled from AI attribution and delegated to Plan [P-44](P44-general-purpose-git-notes-infrastructure.md) (`aapp note`).
  - Legacy `ai-note` is dropped; users and agents will use `aapp note stage "<text>"` under P-44.

- **Help / Diagnostics (`aapp ai help` or unknown subcommands)**:
  - Fails closed on invalid mode with exit code 1:
    `❌ Unknown AI mode or command: '<input>'. Valid: status, off, none, lax, strict, notes, credits.`

### 2. Init & Upgrade Immutability Invariant
`cmd_init.sh` already enforces:
```bash
if [ -z "$(git config --get aapp.aiAttribution 2>/dev/null || true)" ]; then
    git config aapp.aiAttribution none
fi
```
This ensures that repeat `init` and future `upgrade` runs preserve the developer's chosen attribution policy without alteration.

### 3. Dispatcher & Verb Catalog Consolidation
- **`lib/verbs.tsv`**:
  - Remove entries for `ai-lax`, `ai-strict`, `ai-notes`, `ai-off`, `ai-credits`, `ai-status`, `ai-note`.
  - Add single entry:
    `ai	ai	yes	Configure or inspect AI attribution mode and credits	lib/docs/verbs/ai.md`
- **`aapp` Dispatcher**:
  - Update `aapp` case statement: dispatch `ai` to `lib/cmd_ai.sh "$@"`.
  - Clean break: intercepted legacy verbs `ai-status|ai-lax|ai-strict|ai-notes|ai-off|ai-credits|ai-note` fail closed with an explicit migration advisory:
    `❌ [AAPP] 'aapp ai-<cmd>' has been consolidated into 'aapp ai <cmd>'.`
    `   Run: aapp ai "$@"`
- **Verb Contract Documentation**:
  - Create `lib/docs/verbs/ai.md` detailing the contract for `aapp ai`.
  - Add derived verb test suite `tests/verbs/ai.sh`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
  - Legacy `ai-<cmd>` standalone verbs are retired from the primary catalog.
  - The dispatcher provides a fast-fail helpful error pointing to `aapp ai <subcommand>`, ensuring no silent failures occur.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Foundation & TDD Assertions
- [ ] Task 1.1: Declare verb contract in `lib/docs/verbs/ai.md`.
- [ ] Task 1.2: Create verb test suite `tests/verbs/ai.sh` and update `tests/ai_attribution_test.sh` to exercise `aapp ai [mode]`.

### Phase 2: Core Implementation
- [ ] Task 2.1: Update `lib/cmd_ai.sh` to refine `aapp ai` dispatching, status output, help text, and error handling.
- [ ] Task 2.2: Update `aapp` top-level dispatcher to route `ai` cleanly and provide migration guidance for legacy hyphenated verbs.
- [ ] Task 2.3: Update `lib/verbs.tsv` to replace 7 legacy rows with single `ai` verb entry.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `aapp test verb ai` and `aapp test ai_attribution_test.sh`.
- [ ] Task 3.2: Run full test suite (`aapp test strict quiet`) ensuring all 25 suites pass.
- [ ] Task 3.3: Update `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md` to reflect unified `aapp ai` command.
- [ ] Task 3.4: Update `CHANGELOG.md` under `## [Unreleased] -> ### Changed`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_ai.sh` -> Consolidate switchboard handler, usage text, and subcommand dispatching.
- [ ] `aapp` -> Route `ai` verb and add clean-break advisory for legacy `ai-*` forms.
- [ ] `lib/verbs.tsv` -> Replace 7 legacy entries with unified `ai` entry.
- [ ] `lib/docs/verbs/ai.md` -> NEW FILE -> Verb behavior contract documentation for `aapp ai`.
- [ ] `tests/verbs/ai.sh` -> NEW FILE -> Derived contract test suite for `aapp ai`.
- [ ] `tests/ai_attribution_test.sh` -> Update test cases to exercise `aapp ai` syntax.
- [ ] `CHEATSHEET.md` -> Update AI attribution section to document `aapp ai [mode]`.
- [ ] `ARCHITECTURE.md` -> Update architectural rule and description of AI attribution subsystem.
- [ ] `CHANGELOG.md` -> Document verb consolidation under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Hook binaries are frozen; Layer 2 pre-commit and commit-msg logic remains unchanged.
- [ ] `lib/cmd_commit.sh` -> Plan-bound commit helper is frozen.
- [ ] `lib/cmd_init.sh` -> Init remains untouched; existing attribution configuration is immutable.
- [ ] `.plans/current/P44-*` -> P-44 Git Notes blueprint remains in its active refinement phase.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan scaffolded and refined to consolidate 7 legacy `ai-*` verbs into polymorphic `aapp ai`. Dropped `aapp init --ai` to keep init unburdened and strictly preserve existing attribution settings on repeat init and upgrade. Decoupled Git Notes engine to Plan P-44.
