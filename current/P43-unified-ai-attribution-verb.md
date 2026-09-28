# 🗺️ Plan P-43: Unified AI Attribution Verb & Init Flag
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

During the implementation of Milestone 1.0 (P-40), AI attribution modes were introduced alongside seven dedicated top-level verbs:
`ai-lax`, `ai-strict`, `ai-notes`, `ai-off`, `ai-status`, `ai-note`, and `ai-credits`.

While this provided immediate discoverability, it introduced substantial **CLI verb sprawl** (consuming 7 rows in `lib/verbs.tsv` and `aapp help`) for policy choices that are primarily configured once during repository setup and rarely toggled day-to-day. Furthermore, initializing a repository with a non-default attribution policy required a multi-step sequence (`aapp init` followed by `aapp ai-lax` or `git config`).

**Goal:**
Consolidate the seven fragmented `ai-*` verbs into a single, clean polymorphic verb:
```text
aapp ai [status | off | none | lax | strict | notes | note | credits]
```
Additionally, provide frictionless setup by adding `--ai=<mode>` to `aapp init`, allowing adopters and CI pipelines to configure the policy in a single command (`aapp init --ai=lax`).

This reduces top-level CLI surface area by 6 verbs, simplifies cognitive load for both humans and AI agents, retains 100% of underlying attribution security and verification, and provides clear discovery via `aapp ai` status output.

---

## 2. Technical Blueprint

### 1. Polymorphic CLI Interface: `aapp ai`
The single entry point `aapp ai` will handle discovery, status, mode switching, note staging, and credits generation:

- **Status / Discovery (`aapp ai` or `aapp ai status`)**:
  - Displays current mode (`none`, `lax`, `strict`, `notes`).
  - Displays brief mode description and whether AI trailers/notes are currently enforced.
  - Lists pending note buffers if any exist.
  - Shows helpful usage syntax: `aapp ai [off|lax|strict|notes|note|credits]`.

- **Mode Switching**:
  - `aapp ai off` or `aapp ai none`: Disables attribution (`aapp.aiAttribution = none`). Pure human authoring.
  - `aapp ai lax`: Mixed human/AI mode (`aapp.aiAttribution = lax`). Validates emailless trailers when present; human commits pass.
  - `aapp ai strict`: Autonomous trace mode (`aapp.aiAttribution = strict`). Enforces valid emailless trailers on every commit.
  - `aapp ai notes`: Local-first mode (`aapp.aiAttribution = notes`). Stores metadata in `refs/notes/commits`.

- **Subcommands**:
  - `aapp ai note [args]`: Pre-stages customizable note buffer for next commit (delegates to `cmd_ai_note`).
  - `aapp ai credits`: Generates or updates AI Contributors block in `README.md` (delegates to `cmd_ai_credits`).

- **Help / Diagnostics (`aapp ai help` or unknown subcommands)**:
  - Fails closed on invalid mode with exit code 1:
    `❌ Unknown AI mode or command: '<input>'. Valid: status, off, none, lax, strict, notes, note, credits.`

### 2. Frictionless Repository Setup: `aapp init --ai=<mode>`
Update `lib/cmd_init.sh` to accept optional `--ai=<mode>` (e.g. `--ai=lax`, `--ai=strict`, `--ai=notes`, `--ai=none`):
- Validates the requested mode against allowed set (`none`, `lax`, `strict`, `notes`).
- Fails closed immediately if an invalid mode is supplied (`❌ Error: Invalid AI attribution mode: '<val>'. Allowed: none, lax, strict, notes`).
- Configures `aapp.aiAttribution` to the specified mode during init (defaulting to `none` if omitted).
- Reflects the configured mode in the init completion summary banner.

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
- [ ] Task 1.2: Create verb test suite `tests/verbs/ai.sh` and update `tests/ai_attribution_test.sh` to exercise `aapp ai [mode]` and `aapp init --ai=<mode>`.

### Phase 2: Core Implementation
- [ ] Task 2.1: Update `lib/cmd_ai.sh` to refine `aapp ai` dispatching, status output, help text, and error handling.
- [ ] Task 2.2: Update `lib/cmd_init.sh` to parse, validate, and set `--ai=<mode>`.
- [ ] Task 2.3: Update `aapp` top-level dispatcher to route `ai` cleanly and provide migration guidance for legacy hyphenated verbs.
- [ ] Task 2.4: Update `lib/verbs.tsv` to replace 7 legacy rows with single `ai` verb entry.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `aapp test verb ai` and `aapp test ai_attribution_test.sh`.
- [ ] Task 3.2: Run full test suite (`aapp test strict quiet`) ensuring all 25 suites pass.
- [ ] Task 3.3: Update `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md` to reflect unified `aapp ai` command and `aapp init --ai=<mode>`.
- [ ] Task 3.4: Update `CHANGELOG.md` under `## [Unreleased] -> ### Changed`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_ai.sh` -> Consolidate switchboard handler, usage text, and subcommand dispatching.
- [ ] `lib/cmd_init.sh` -> Add `--ai=<mode>` argument parsing, validation, and configuration.
- [ ] `aapp` -> Route `ai` verb and add clean-break advisory for legacy `ai-*` forms.
- [ ] `lib/verbs.tsv` -> Replace 7 legacy entries with unified `ai` entry.
- [ ] `lib/docs/verbs/ai.md` -> NEW FILE -> Verb behavior contract documentation for `aapp ai`.
- [ ] `tests/verbs/ai.sh` -> NEW FILE -> Derived contract test suite for `aapp ai`.
- [ ] `tests/ai_attribution_test.sh` -> Update test cases to exercise `aapp ai` syntax and `init --ai`.
- [ ] `CHEATSHEET.md` -> Update AI attribution section to document `aapp ai [mode]` and `init --ai`.
- [ ] `ARCHITECTURE.md` -> Update architectural rule and description of AI attribution subsystem.
- [ ] `CHANGELOG.md` -> Document verb consolidation and init flag under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Hook binaries are frozen; Layer 2 pre-commit and commit-msg logic remains unchanged.
- [ ] `lib/cmd_commit.sh` -> Plan-bound commit helper is frozen.
- [ ] `.plans/current/P42-*` -> P-42 blueprint remains in its active refinement phase.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan scaffolded and refined to consolidate 7 legacy `ai-*` verbs into polymorphic `aapp ai` and introduce `aapp init --ai=<mode>`.
