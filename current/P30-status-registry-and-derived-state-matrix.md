# 🗺️ Plan P-30: Status Registry & Derived State Matrix
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-22
* **Target Issue / Milestone:** Planning Brain Integrity
* **Plan ID:** P-30
* **Status:** ⚡ In Development
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement

`.plans/state_matrix.md` is the Planning Brain: the file every agent reads to recover project state. Today it is a **hand-maintained denormalized cache** of data the plan files already own, and nothing reconciles the two.

Every Incubator row carries a plan ID, filename, title, and status emoji. All four already exist inside the plan file itself. When they disagree, nothing detects it and agents reason from stale state — the precise failure the kit exists to prevent.

Three concrete defects follow from this:

1. **Heading-anchored parsing is already broken.** `lib/cmd_status.sh` locates matrix sections with awk patterns hardcoded to emoji-and-number headings (`cmd_status.sh:72,326,327`, e.g. `/## 🔷 2\. Frozen/`). These match this repo's live matrix but **do not match the shipped template**: `templates/state_matrix.md` says `## 🔷 2b. Frozen Backlog (Approved Specifications)` while `.plans/state_matrix.md` says `## 🔷 2. Frozen & Ready for Coding (The Greenlight Zone)`, and the template's `## ⚡ 2a. In Development` / `## 🚫 2c. Blocked` sections are absent from the live file entirely. Because `copy_guarded` returns early when the destination exists (`cmd_init.sh:193-195`), the template never reaches an initialized repo, so **every adopter's matrix diverges permanently from the day they ran `aapp init`**. The awk reads do not error on mismatch — they return empty and the Next Action footer silently falls through to a less useful branch.

2. **Status literals are scattered and unextensible.** The enum `🔴|🟡|🟣|🔷|📝` appears as a raw literal in `cmd_plan.sh:380,461,525`, with further hardcoded matchers at `cmd_plan.sh:115,500,704,808,810`. Adding or renaming a status means hunting every site. Users cannot define custom statuses at all.

3. **Unrecognized statuses vanish silently.** `cmd_plan.sh:808-813` already buckets `current/*.md` by Status line, but its `else` branch lumps everything unmatched into Incubator. A plan with a typo'd or unknown status is silently miscategorized — invisible in the one file agents trust for state.

### Architectural Goal

Invert the relationship. **Plan `Status:` lines in `.plans/current/*.md` become the single source of truth; the matrix is derived from them.**

1. **Status Registry (`lib/plan_states.sh`)**: One sourced module declaring every status — emoji, canonical name, generated section heading, and sort rank. Kit defaults ship in the module; adopters extend via `git config aapp.planState.<slug>`. All call sites source the registry instead of carrying literals.
2. **Derived Matrix (`aapp matrix`)**: A single command that checks and auto-syncs. It walks `current/*.md`, reads each Status line, buckets by registry lookup, and rewrites the matrix. Sections emit in registry rank order.
3. **No Silent Loss**: Plans whose status matches no registry entry land in a visible *Unrecognized Status* section rather than being miscategorized or dropped.
4. **Eliminate heading parsing**: `cmd_status.sh` resolves plan state from `current/*.md` via the registry, retiring the three awk heading reads and the drift class they belong to.

### Explicit Boundary vs. Plan P-25

P-25 (*Delimited Template Sync & Tiered Document Governance*) classifies `.plans/state_matrix.md` as **Tier 3 — Pure Project Domain Data, seeded once and never overwritten by template sync**. P-25 therefore explicitly declines to manage matrix *content*. P-30 owns matrix content reconciliation; P-25 owns template file synchronization. The two do not overlap, and P-30 does not modify the template-sync engine.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Design Principle: Derive, Don't Parse

| Concern | Source of Truth | Derived Artifact |
| :--- | :--- | :--- |
| A plan's current state | `Status:` line in `.plans/current/P<n>-<slug>.md` | Matrix row emoji; matrix section placement |
| Which statuses exist | `lib/plan_states.sh` + `git config aapp.planState.*` | Matrix section headings and their order |
| Plan ID, filename, title | The plan file itself | Matrix row text up to the `—` |
| Human priority ordering | `## 🚦 Recommended Implementation Roadmap` | *(not derived — human-owned)* |
| Per-row annotations | Text after the `—` on a matrix row | *(not derived — human-owned, preserved verbatim)* |

Matrix population is **strictly `.plans/current/*.md`**. A plan that has left `current/` (archived to `done/`, moved to `aborted/`, renamed, or deleted) has no place in the matrix; the archive ledger takes over. Orphan rows are therefore deleted outright — no prompting, no `.orphan` quarantine.

### 2.2 Status Registry Module (`lib/plan_states.sh`)

A pure, side-effect-free module safe to source from any command (following the `hook_dispatcher.sh` precedent, which exists as a separate file precisely because `cmd_hook.sh` carries a top-level dispatcher).

Each status declares four fields:

| Field | Purpose |
| :--- | :--- |
| `emoji` | The glyph written into plan Status lines and matrix rows |
| `name` | Canonical name matched against the Status line (e.g. `In Development`) |
| `heading` | Section heading this status generates in the matrix |
| `rank` | Integer ordering sections within the matrix |

Kit defaults (matching the enum in `templates/plan-template.md`):

| Slug | Emoji | Name | Heading | Rank |
| :--- | :--- | :--- | :--- | :--- |
| `under-review` | 🟣 | Under Review | `🧠 Human Thought & Refinement (The Incubator)` | 10 |
| `refining` | 📝 | Refining | `🧠 Human Thought & Refinement (The Incubator)` | 10 |
| `frozen` | 🔷 | Frozen | `🔷 Frozen & Ready for Coding (The Greenlight Zone)` | 20 |
| `in-development` | ⚡ | In Development | `⚡ In Development (Active Implementation Context)` | 30 |
| `blocked` | 🟥 | BLOCKED | `🟥 Blocked (Halted on an Issue)` | 40 |

Note that `under-review` and `refining` deliberately share a heading and rank: two statuses, one section. The registry must support many-to-one status→section mapping.

Required interface:

- `plan_states_load()` — populates the registry from kit defaults, then merges adopter overrides. Idempotent.
- `plan_state_for_status_line(line)` — given a raw `Status:` line, returns the matching slug, or empty if unrecognized.
- `plan_state_field(slug, field)` — accessor for `emoji` / `name` / `heading` / `rank`.
- `plan_state_sections()` — unique headings in rank order, for matrix emission.
- `plan_state_emoji_class()` — the alternation (e.g. `🔴|🟡|🟣|🔷|📝`) that `cmd_plan.sh` sed expressions currently hardcode.

**Matching is by canonical name, not emoji.** Emoji are display; the name in the Status line is the semantic key. Matching must tolerate the existing line shapes already handled at `cmd_plan.sh:115` and `:808` (leading `*`/`-`, bold markers, variable whitespace).

Bash 3.2 compatibility (macOS default) rules out associative arrays; use parallel arrays or delimited strings.

### 2.3 Adopter-Defined Custom Statuses (`git config`)

Custom statuses live in git config, consistent with how the kit stores repo-scoped settings (`aapp.planId`, `aapp.aiAttribution`, `aapp.templateSync`). TSV files are reserved for cross-checked registries such as the hook registry.

Because a status needs four fields, each entry is one key carrying a delimited tuple, keeping `--get-regexp` viable as the enumeration path:

```bash
git config aapp.planState.<slug> "<emoji>|<name>|<heading>|<rank>"

# Example:
git config aapp.planState.awaiting-review "👀|Awaiting Review|👀 Awaiting External Review|25"
```

Enumerated with `git config --get-regexp '^aapp\.planState\.'`. Resolution rules:

- A config entry whose slug matches a kit default **overrides** it (letting adopters reword a heading without forking the module).
- A config entry with a new slug **adds** a status.
- A malformed tuple (wrong field count, non-integer rank) is **skipped with a warning to stderr**, never fatal — a bad config entry must not brick `aapp status`.
- A manifest row is added to `config.tsv` if the `aapp config` pickup idea ships; P-30 does not depend on it.

### 2.4 `aapp matrix` — One Command, Check and Sync

A single verb with no lifecycle coupling. Not wired into `aapp status`, not invoked from hooks. If enforcement is wanted later, the pre-commit hook can call `aapp matrix --check`, but that is a separate decision.

| Invocation | Behavior | Exit |
| :--- | :--- | :--- |
| `aapp matrix` | Check, report drift, auto-sync if needed | 0 on success |
| `aapp matrix --check` | Read-only; report drift without writing | 0 clean, 1 drifted |

Sync algorithm:

1. `plan_states_load()`.
2. Walk `.plans/current/*.md`, skipping `000-*` (consistent with `cmd_plan.sh:802`). For each: extract Plan ID, filename, title, and Status line; resolve the slug via the registry.
3. Bucket by resolved heading. Unresolved → *Unrecognized Status* bucket.
4. Parse the existing matrix to harvest **human-owned content**: the Roadmap section verbatim, and per-row trailing annotations keyed by plan ID.
5. Re-emit the matrix: preamble, Roadmap section (verbatim), then one section per heading in rank order, then the Unrecognized section if non-empty, then the Archival Ledger pointer.
6. Rows not backed by a file in `current/` are simply absent from the regenerated output — deletion is a consequence of derivation, not a special case.

### 2.5 Annotation Preservation Contract

A matrix row has a generated prefix and a human-owned suffix, split on the first ` — ` (space em-dash space):

```
- 🟣 **P-15**: [`P15-adversarial-review-plugin.md`](current/P15-adversarial-review-plugin.md) — ✏️ **SKETCH — do not refine** — Adversarial Review Packet…
  └─────────────── generated ───────────────┘   └──────────── preserved verbatim ────────────┘
```

Rules:

- Split on the **first** ` — ` only. Annotations may themselves contain em-dashes (P-15's does) and must survive intact.
- Annotations are keyed by **Plan ID**, not row position, so a plan changing section keeps its annotation.
- A plan with no prior row gets its title from the plan file's H1 as the initial suffix.
- The em-dash separator is emitted by `cmd_plan.sh:306` today; the sync must produce byte-identical framing so a fresh scaffold followed by a sync is a no-op.

### 2.6 Retiring Heading-Anchored Parsing in `cmd_status.sh`

Replace the three awk heading reads with registry-driven resolution over `current/*.md`:

- `cmd_status.sh:326` (`FROZEN_PLAN`) → first plan whose resolved slug is `frozen`.
- `cmd_status.sh:327` (`INCUBATOR_PLAN`) → first plan whose slug maps to the Incubator heading.
- `cmd_status.sh:72` (`ROADMAP_PLANS`) → **retained as-is.** The Roadmap is human-owned prose, not derived state; it has no plan-file equivalent and must still be read from the matrix.

Ordering within a status bucket follows matrix row order where a prior row exists, falling back to plan ID ascending, so the footer's "first frozen plan" stays stable across syncs.

### 2.7 Call-Site Consolidation in `cmd_plan.sh`

Replace hardcoded literals with registry accessors. Verified sites:

| Site | Current | After |
| :--- | :--- | :--- |
| `cmd_plan.sh:380,461,525` | `sed "/$plan_id/s/🔴\|🟡\|🟣\|🔷\|📝/⚡/g"` | Alternation from `plan_state_emoji_class()`, **live statuses only** — the retired `🔴`/`🟡` drop out per §2.8 |
| `cmd_plan.sh:115,704` | Inline `⚡ In Development` regex | `plan_state_for_status_line()` |
| `cmd_plan.sh:500` | `🔷 Frozen\|⚡ In Development` regex | Registry slug comparison |
| `cmd_plan.sh:808-813` | Three-way if/elif/else bucketing | Registry-driven bucketing; unrecognized reported distinctly, not folded into Incubator |
| `cmd_plan.sh:306` | Heading-anchored `sed` insert for new rows | Unchanged (it `grep -q`s first and fails safe); `aapp matrix` reconciles regardless |

The `sed`-based status rewrites at `:380,461,525` are **left functional but registry-fed**. Rewriting matrix rows in place remains correct; `aapp matrix` is the reconciler, not a replacement for lifecycle writes.

### 2.8 Accessibility Invariant: The Status Glyph Set Is Colour-Blind Safe

The current enum (`🟣 Under Review`, `📝 Refining`, `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`) is **deliberately colour-blind friendly**, and this is a hard design constraint, not incidental styling. Purple/blue/red-square/lightning are distinguishable under the common colour-vision deficiencies; the retired `🔴`/`🟡` pair is exactly the red/green-family combination that is not.

Two consequences bind the implementation:

1. **No legacy aliases.** `🔴` and `🟡` are dropped outright rather than carried as hidden registry entries. Per the Clean Break Invariant, retaining them as unlisted fallbacks would be a protocol violation. `plan_state_emoji_class()` therefore returns the live set only. A plan or matrix row still carrying a retired glyph resolves as unrecognized and surfaces in the Unrecognized Status section, where it is visible and gets cleaned up — which is the desired outcome, not a regression.

2. **Custom statuses inherit the constraint.** `MANUAL.md` must state that adopter-defined glyphs should remain distinguishable without colour perception — prefer shape- or symbol-distinct emoji over hue-distinct ones. This is documented guidance, not mechanical enforcement; the registry does not validate glyph accessibility.

### 2.9 Pause Interaction: Sync Normally, Warn That the Commit Is Deferred

Verified against `templates/aapp-pre-commit:104-126`: while the project is paused, the circuit breaker permits staging only `pickup*`, `ISSUES.md`, `issues*`, and `current/*` (matched with or without the `.plans/` prefix depending on worktree root). **`.plans/state_matrix.md` sits at `.plans/` root and matches none of these patterns**, so a matrix write made while paused cannot be committed until `aapp resume`.

**The write still happens.** Pause permits reflection — editing plans in `current/`, triaging issues, queuing pickup ideas — and that reflection is exactly what moves plans between statuses. Suppressing the sync would mean the matrix silently lags the work the developer is allowed to do, and the person returning to the desk would have no visible record of how the board changed while paused. The resulting uncommitted diff is **information, not mess**: it is the ledger of what reflection did, reviewable on resume.

Behavior while paused:

- `aapp matrix` derives and writes `state_matrix.md` normally.
- It then prints a clear advisory: the matrix is updated on disk but **cannot be committed until `aapp resume`**, because the pause allowlist excludes `.plans/state_matrix.md`. The advisory names the file and the resume command so the state is never surprising.
- The advisory fires only when the sync actually changed the file — a no-op sync in a paused repo stays silent rather than nagging.
- `aapp matrix --check` is unaffected — it never writes and needs no advisory.
- Pause detection reuses the existing probe (`$GIT_COMMON_DIR/aapp_paused` or `.plans/PAUSED.md`) already implemented in `cmd_status.sh`, rather than introducing a second detection path.

This deliberately leaves a dirty working tree in a paused repo. That is the accepted trade: a visible, reviewable diff is worth more than a clean tree that has quietly lost track of the board.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)` — explicitly including the retired `🔴`/`🟡` status glyphs, which are dropped with no alias, shim, or hidden registry entry (§2.8).
- Existing divergent matrices are healed by the first `aapp matrix` run: sections are re-emitted from the registry, so template-vs-live heading drift resolves without touching `copy_guarded` or P-25's engine.
- No CLI verb is removed. `aapp matrix` is additive.
- Adopters who hand-edited section headings lose those headings on first sync — the registry becomes authoritative. This is the intended clean break and must be called out in `MANUAL.md`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Status Registry Foundation
- [x] Task 1.1: Create `lib/plan_states.sh` with kit defaults, the five accessors from §2.2, and Bash 3.2-safe storage. Pure module, no top-level side effects.
- [x] Task 1.2: Implement `git config aapp.planState.*` merge per §2.3, including override-by-slug and non-fatal skip-with-warning on malformed tuples.
- [x] Task 1.3: Create `tests/plan_states_test.sh` covering default resolution, name-based matching across the Status line shapes at `cmd_plan.sh:115` and `:808`, custom status add, kit-default override, malformed tuple rejection, and many-to-one status→section mapping.

### Phase 2: Matrix Derivation Engine
- [ ] Task 2.1: Create `lib/cmd_matrix.sh` implementing the §2.4 walk, bucket, and re-emit algorithm.
- [ ] Task 2.2: Implement §2.5 annotation harvesting and reattachment, keyed by Plan ID, splitting on the first ` — ` only.
- [ ] Task 2.3: Implement the Unrecognized Status section, emitted only when non-empty.
- [ ] Task 2.4: Implement `--check` as read-only with exit code 1 on drift.
- [ ] Task 2.5: Implement the §2.9 pause advisory: sync normally while paused, then warn that `.plans/state_matrix.md` cannot be committed until `aapp resume`. Fire the warning only when the sync changed the file; reuse the existing pause probe from `cmd_status.sh`.

### Phase 3: CLI Wiring
- [ ] Task 3.1: Wire `matrix` into the `aapp` router.
- [ ] Task 3.2: Register `matrix` in `lib/cmd_help.sh`.

### Phase 4: Call-Site Consolidation
- [ ] Task 4.1: Source the registry in `lib/cmd_plan.sh` and replace the literals at `:115,380,461,500,525,704` per §2.7.
- [ ] Task 4.2: Replace the `:808-813` bucketing with registry-driven bucketing, reporting unrecognized statuses distinctly.
- [ ] Task 4.3: Replace the awk heading reads at `lib/cmd_status.sh:326,327` with registry resolution over `current/*.md`. Leave `:72` (Roadmap) intact.

### Phase 5: Verification & Documentation
- [ ] Task 5.1: Create `tests/matrix_test.sh` covering: full derivation from a fixture `current/`; orphan row deletion; annotation preservation through a section change; unrecognized status bucketing (including a plan carrying a retired `🔴`/`🟡` glyph); Roadmap preservation; `--check` exit codes; **pause advisory** (paused repo still writes the synced matrix, emits the deferred-commit warning naming `aapp resume`, and stays silent when the sync is a no-op); and **idempotency** (scaffold → sync → sync produces a byte-identical file).
- [ ] Task 5.2: Run `tests/install_test.sh` and the full suite; verify zero regressions, particularly the Test 42 drift assertions.
- [ ] Task 5.3: Document `aapp matrix`, the status registry, and `aapp.planState.<slug>` in `MANUAL.md` and `CHEATSHEET.md`, including the clean-break note on hand-edited headings from §2.7, the colour-blind glyph guidance for custom statuses from §2.8, and the paused-repo behavior from §2.9.
- [ ] Task 5.4: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with the registry module, matrix engine, and the derived-state contract.
- [ ] Task 5.5: Update `CHANGELOG.md` and run syntax checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `NEW FILE` -> `lib/plan_states.sh` -> Status registry: kit defaults, git config merge, accessors.
- [ ] `NEW FILE` -> `lib/cmd_matrix.sh` -> Matrix derivation and sync engine.
- [ ] `NEW FILE` -> `tests/plan_states_test.sh` -> Registry resolution, custom status, and malformed-config tests.
- [ ] `NEW FILE` -> `tests/matrix_test.sh` -> Derivation, orphan deletion, annotation preservation, idempotency tests.
- [ ] `aapp` -> Wire the `matrix` verb into the command router.
- [ ] `lib/cmd_help.sh` -> Register `matrix` in help output.
- [ ] `lib/cmd_plan.sh` -> Source registry; replace status literals at `:115,380,461,500,525,704` and bucketing at `:808-813`.
- [ ] `lib/cmd_status.sh` -> Replace awk heading reads at `:326,327` with registry resolution; leave `:72` Roadmap read intact.
- [ ] `MANUAL.md` -> Document `aapp matrix`, the registry, and `aapp.planState.<slug>`.
- [ ] `CHEATSHEET.md` -> Add `aapp matrix` to the command table.
- [ ] `ARCHITECTURE.md` -> Record the derived-state contract and registry module.
- [ ] `.agents/CODEMAP.md` -> Map the two new `lib/` modules.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🚨 Emergency Hotfix Extensions
> Added mid-execution per Critical Execution Invariant #4 (*blocking & small*). Task 3.2 was drafted against stale information: it names `lib/cmd_help.sh` as the registration point, but P-27 made help output manifest-driven from `lib/verbs.tsv`, with `tests/install_test.sh` Tests 56/59 asserting manifest-to-help and manifest-to-cheatsheet parity. Registering the `matrix` verb therefore requires a manifest row and the matching cheatsheet entry; without them the verb ships invisible to `aapp help`, violating documentation invariant #5. The plan's intent is unchanged — only the mechanism moved.
- [ ] `lib/verbs.tsv` -> Add the `matrix` verb row (tier, standalone flag, description) so tiered help renders it.
- [ ] `CHEATSHEET.md` -> Add the matching `matrix` entry required by Test 59 manifest-to-cheatsheet parity.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_init.sh` -> `copy_guarded` and template provisioning are owned by P-25.
- [ ] `lib/cmd_sync_templates.sh` -> P-25's engine; P-30 must not pre-empt it.
- [ ] `templates/state_matrix.md` -> Seed template only; heading reconciliation is solved by derivation, not by editing the seed.
- [ ] `lib/plan_resolver.sh` -> Plan ID allocation is stable and out of scope.
- [ ] `lib/hook_dispatcher.sh` -> Hook engine is out of scope.
- [ ] `.githooks/*` -> No lifecycle enforcement in this plan; `--check` wiring is a later decision.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Should retired statuses be declarable? → RESOLVED (developer, 2026-09-22): drop `🔴`/`🟡` entirely; no legacy aliases.** The current enum (`🟣 🔷 ⚡ 🟥 📝`) is deliberately colour-blind friendly and is the accessibility baseline the kit commits to; the retired `🔴`/`🟡` glyphs are precisely the red/green-family pair that fails for colour-blind readers. Per the Clean Break Invariant, no legacy aliases are retained: `plan_state_emoji_class()` returns live statuses only, and any plan still carrying a retired glyph resolves as unrecognized and surfaces in the Unrecognized Status section for cleanup. See §2.8.

* [x] **Question 2 — Should `aapp matrix` write when the repo is paused? → RESOLVED (developer, 2026-09-22): yes, sync normally and warn that the commit is deferred.** The pause allowlist (`templates/aapp-pre-commit:104-126`) permits only `pickup*`, `ISSUES.md`, `issues*`, and `current/*`; `.plans/state_matrix.md` matches none of them, so a paused sync cannot be committed until `aapp resume`. It is still the right behavior to write: pause explicitly permits the reflection that moves plans between statuses, and the resulting diff records what changed on the board while paused — information the developer wants on return. Suppressing the write would silently desynchronize the matrix from permitted work. Resolution in §2.9: sync normally, emit a deferred-commit advisory naming the file and `aapp resume`, and stay silent when the sync is a no-op. `--check` is unaffected (read-only).

---

## 📦 6. Change Log & Refinement History
* **2026-09-22:** Plan activated into ⚡ In Development via start.
* **2026-09-22:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-09-22 (refinement 1):** **Both open questions resolved on developer direction; accessibility invariant recorded.**
  1. **Retired glyphs dropped with no aliases (Q1)** — Added §2.8 recording that the current status glyph set is deliberately colour-blind friendly and is a hard design constraint. The retired `🔴`/`🟡` pair is the red/green-family combination that fails colour-vision deficiency and is dropped outright; per the Clean Break Invariant no legacy alias or hidden registry entry is retained, so `plan_state_emoji_class()` returns live statuses only and stale glyphs surface in the Unrecognized Status section. `MANUAL.md` must carry glyph-accessibility guidance for adopter-defined statuses.
  2. **Paused sync writes and warns (Q2)** — Verified against `templates/aapp-pre-commit:104-126` that the pause allowlist covers only `pickup*`, `ISSUES.md`, `issues*`, and `current/*`, so `.plans/state_matrix.md` cannot be committed while paused. Developer direction: sync anyway and warn, because pause permits the reflection that moves plans between statuses and the resulting diff is the visible record of what changed on the board — suppressing the write would silently desynchronize the matrix from permitted work. Added §2.9 (write, then emit a deferred-commit advisory naming `aapp resume`, silent on no-op), Task 2.5, and advisory test coverage in Task 5.1.
* **2026-09-22:** Blueprint scaffolded from the `pickup.md` entry on developer direction. Establishes plan `Status:` lines as the single source of truth, a sourced status registry (`lib/plan_states.sh`) with `git config aapp.planState.<slug>` extension for custom statuses, and a single `aapp matrix` check-and-sync verb deriving the matrix from `.plans/current/*.md`. Records the explicit boundary against P-25 (which classifies `state_matrix.md` as Tier 3, never touched by template sync), documents the already-live template-vs-adopter heading divergence as the motivating defect, and specifies orphan-row deletion, the Unrecognized Status bucket, and the annotation preservation contract.
