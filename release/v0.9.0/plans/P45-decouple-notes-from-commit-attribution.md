# 🗺️ Plan P-45: Decouple Git Notes from Commit Attribution

* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Milestone 1.2 / Metadata Architecture
* **Plan ID:** P-45
* **Status:** ✅ Done
* **Base:** `6833e91` (develop)
* **Commits:** `88aae65` (develop)

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

During earlier refactoring (P-43 and P-44), Git Notes were inadvertently coupled to AI attribution in an artificial either/or dichotomy:
- In `templates/aapp-commit-msg`, having notes mode active forbade AI commit trailers with a fatal error.
- In `lib/cmd_commit.sh`, `aapp commit ... note "<text>"` strictly ignored note attachment unless attribution mode was set to `notes`.
- In `lib/attribution.sh`, providing note text without an AI identity in notes mode was refused rather than routing to general notes.

This violated the core requirement: **transparency during this transition period requires that public commit trailers and out-of-band Git notes operate either hand-in-hand or independently.**

An adopter working on sensitive software may want:
1. **Hand-in-Hand**: Enforce public commit trailers (`strict` or `lax`) for public transparency **AND** record detailed audit, benchmark, or review notes in `refs/notes/ai`.
2. **Private-Only Compliance**: Keep public commit messages human-only (`none`) while recording an internal audit trail in `refs/notes/ai` (local-first or pushed to an internal private remote).
3. **Independent Notes**: Attach review notes, benchmark scores, or developer context to commits via `aapp commit ... note "<text>"` without AI trailers or restrictions.

### Architectural Goal
Decouple Git Notes from commit message trailers into two orthogonal dimensions:
1. `aapp.aiAttribution`: Governs **commit message trailers** (`none | lax | strict`).
2. `aapp.aiNotes`: Governs **automatic AI note recording** (`true | false`, opt-in).
3. `aapp commit ... note "<text>"`: Attaches notes across **all** modes non-destructively, routing to `refs/notes/ai` when identity is present and `refs/notes/commits` otherwise.

---

## 2. Technical Blueprint

### 1. Orthogonal Configuration Model

| Concern | Setting | Scope | Allowed Values | Default |
| :--- | :--- | :--- | :--- | :--- |
| **Commit Trailers** | `aapp.aiAttribution` | Public commit message body | `none`, `lax`, `strict`, `notes` (alias for `none` + notes) | `none` |
| **AI Git Notes** | `aapp.aiNotes` | Out-of-band `refs/notes/ai` | `true`, `false` | `false` |

### 2. Lifiting Artificial Barriers in Commit & Hooks

- **`lib/cmd_commit.sh`**:
  - Lift the `[ "$attr_mode" = "notes" ]` gate on line 319.
  - If `note "<text>"` is passed to `aapp commit`, attach the note unconditionally across all modes (`strict`, `lax`, `none`, `notes`).
  - If `identity` is resolved and `aapp.aiNotes = true` (or mode is `notes`), automatically record the AI audit trace to `refs/notes/ai` even if `note_text` is empty.
  - In `strict` or `lax` mode, commit messages receive public trailers **and** notes are attached in parallel.

- **`lib/attribution.sh` (`attribution_note`)**:
  - Lift the refusal when `identity` is empty and `text` is present.
  - Route content: if identity is present, route to `refs/notes/ai` (and `refs/notes/commits` if in legacy `notes` mode); if identity is absent, route to `refs/notes/commits`.

- **`templates/aapp-commit-msg`**:
  - In `notes` mode, treat it as `none` (human-only commit message), but do not reject commits with notes attached.
  - In `strict` and `lax` modes, validate trailers as usual without blocking staged notes or note attachments.

- **`lib/cmd_ai.sh`**:
  - Add `aapp ai notes [on|off]` to enable/disable `aapp.aiNotes`.
  - Update `aapp ai status` to display both Commit Attribution Policy (`aapp.aiAttribution`) and AI Git Notes Policy (`aapp.aiNotes`).
  - Keep `aapp ai notes` (bare) as a backward-compatible preset that enables `aapp.aiNotes = true` and guides the user.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**:
  - `aapp.aiAttribution = notes`: Retained as a recognized configuration representing private-only attribution (equivalent to `aiAttribution=none` with `aiNotes=true`).
  - Existing scripts and invocations continue to work without disruption.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Engine & Helper Decoupling
- [x] Task 1.1: Update `lib/cmd_commit.sh` to allow note attachment across all modes and auto-attach AI trace when `aapp.aiNotes=true`.
- [x] Task 1.2: Refactor `lib/attribution.sh` (`attribution_note`) to route non-identity notes cleanly to `refs/notes/commits`.
- [x] Task 1.3: Update `templates/aapp-commit-msg` to ensure trailers and notes do not conflict.

### Phase 2: CLI Ingress & Status
- [x] Task 2.1: Update `lib/cmd_ai.sh` with `aapp ai notes [on|off]` toggle and unified status display.
- [x] Task 2.2: Update `lib/docs/verbs/ai.md` and `lib/docs/verbs/commit.md` contracts.
- [x] Task 2.3: Update `templates/AGENTS.md` and `MANUAL.md`.

### Phase 3: Contract Verification & Tests
- [x] Task 3.1: Add parallel tests in `tests/verbs/commit.sh` verifying `strict` + note, `lax` + note, and `none` + note.
- [x] Task 3.2: Add tests in `tests/verbs/ai.sh` verifying `aapp ai notes [on|off]` and status reporting.
- [x] Task 3.3: Run full test suite (`./aapp test strict quiet`) ensuring all 28+ test suites pass.
- [x] Task 3.4: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_commit.sh` -> Allow note attachment across all attribution modes and auto-record AI note when aapp.aiNotes is true.
- [ ] `lib/attribution.sh` -> Route non-identity notes to refs/notes/commits and preserve AI traces in refs/notes/ai.
- [ ] `templates/aapp-commit-msg` -> Allow notes and trailers to coexist without conflict.
- [ ] `lib/cmd_ai.sh` -> Add aapp ai notes on/off and display dual status in aapp ai status.
- [ ] `lib/docs/verbs/ai.md` -> Update contract for aapp ai to include notes toggling.
- [ ] `lib/docs/verbs/commit.md` -> Update contract for aapp commit to document parallel trailers and notes.
- [ ] `templates/AGENTS.md` -> Update attribution matrix documentation.
- [ ] `MANUAL.md` -> Update user manual for parallel notes and commit attribution.
- [ ] `tests/verbs/commit.sh` -> Add tests for parallel trailers and notes attachment.
- [ ] `tests/verbs/ai.sh` -> Add tests for aapp ai notes on/off.
- [ ] `tests/ai_attribution_test.sh` -> Verify parallel trailer and note execution.
- [ ] `CHANGELOG.md` -> Document decoupling under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Managed hook copies.
- [ ] `lib/cmd_note.sh` -> Notes subsystem engine is settled (P-44).
- [ ] `templates/aapp-pre-commit` -> Pre-commit guard logic is settled.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan implementation completed and archived to done/.
* **2026-09-28:** Plan activated into ⚡ In Development via start.
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-28:** Blueprint initialized to decouple Git notes from commit attribution into orthogonal, parallel dimensions.
