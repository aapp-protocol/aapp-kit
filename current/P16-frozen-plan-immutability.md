# 🗺️ Plan: P-16 Frozen Plan Immutability & Design-Lock Enforcement
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-16
* **Target Issue / Milestone:** `#68`
* **Plan ID:** P-16
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md`. Run syntax checks and tests *before* updating the changelog.
> 3. **Pair 5 Invariant**: Target Files must never declare Section 2 protected paths (`.githooks/*`, `.agents/skills/*`, `.claude/settings*`, `.cursor/rules/*`, `.git/config`).
> 4. **Engine copies are write-protected**: edit `templates/aapp-pre-commit` and run `aapp init` to propagate. Never edit `.githooks/` directly.
> 5. **Mid-Execution Bugs**: *non-blocking* → log in `.plans/ISSUES.md` and continue. *Blocking & small* → add under `### 🚨 Emergency Hotfix Extensions`. *Blocking & substantial* → set `🚫 BLOCKED`, stop, ask.

---

## 1. Context & Architectural Goal

**What.** Make a frozen (🟢) blueprint's **design** immutable while leaving its **execution progress** freely writable. A greenlit plan must accept task checkboxes and change-log entries, and refuse edits to its Technical Blueprint and Blast Radius, until it is explicitly unfrozen.

**Why.** `.plans/*` is unconditionally always-allowed in the write guard (`templates/blast-radius-guard.sh:227`), so a plan document is fully editable at every status — draft, frozen, or archived. Nothing prevents an agent from rewriting the specification underneath in-flight execution.

**This is not theoretical.** On 2026-09-16 an agent amended `P14-ai-attribution-suite.md` after it was frozen (`7f26ae5`) and after Phases 1–3 had shipped against the locked specification, changing the attribution model from an exclusive enum to composable channels. No layer flagged it — not the write guard, not the pre-commit hook, not planning-health. It was caught only because the human noticed, and recovery required a hard reset because the edits had meanwhile been absorbed into an unrelated commit.

**Why `#64` did not cover this.** `#64` (resolved, `2ff5a86`) governs what a plan **authorises** — plans marked 🔴/🟡 are now excluded from `ACTIVE_PLANS` so drafts grant no write rights. This issue is the orthogonal question of whether the plan **itself** is immutable once greenlit. Fixing one could never have fixed the other.

**Core invariant.** *Freeze locks the design, not the document.* A frozen plan is a contract between the human who greenlit it and the agent executing it; progress may be recorded against that contract, but its terms may not change while it is in force.

---

## 2. Technical Blueprint

### A. Why This Cannot Live in the Write Guard

`blast-radius-guard` is **path-based**. It receives a file path from a `PreToolUse` payload and answers allow/deny; it never sees *what* changed. Two consequences:

1. It cannot distinguish a task checkbox tick from a rewritten Blast Radius — both are "a write to the same path".
2. A blanket deny on frozen plans would break execution outright, since ticking checkboxes and appending to §6 are required parts of executing a plan.

Enforcement therefore belongs in **`templates/aapp-pre-commit`**, which already reads the staged set (`git diff --cached --name-only -z`, line 25) and can read staged hunks. The write guard is deliberately left unchanged — see Open Question 4 for whether it gains an advisory warning.

### B. The Mutability Contract for a 🟢 Plan

| Region | Frozen plan | Rationale |
| :--- | :--- | :--- |
| Task checkboxes (`- [ ]` → `- [x]`) | **permitted** | Recording progress is the point of executing |
| `## 6. Change Log & Refinement History` | **permitted** | Execution notes and verification records belong here |
| `## 2.` Technical Blueprint | **refused** | Changing the design under in-flight execution |
| `## 4.` Blast Radius & System Boundaries | **refused** | Changing what the agent may write, post-greenlight |
| `**Status:**` line | see Open Question 2 | The unfreeze path must not be self-blocking |
| `## 1.`, `## 3.` prose, `## 5.` | see Open Question 3 | Genuinely ambiguous — needs a human decision |

Rejection must name the section and point at the unfreeze path, in the style of the existing blast-radius refusal message.

### C. Implementation Notes

* **Reuse `parse_plan_section`** (`templates/aapp-pre-commit:148`) rather than adding a second markdown parser. It already extracts a delimited region and is exercised by the existing suite.
* **Key on section *number*, never title.** Headings vary in wording and emoji across plans — `## 2. Technical Blueprint` in `P-14` versus `## 2. Settled Ground` in `P-15` — but the numbering is stable. Match `^## (.*[[:space:]])?2\.` and `^## (.*[[:space:]])?4\.`.
* **Detect changed regions from staged hunks**, e.g. `git diff --cached -U0 -- "$plan"`, mapping changed line numbers onto section ranges. Do not diff rendered text.
* Applies to `.plans/current/*.md` only; `000-*` index files are excluded, matching the existing `ACTIVE_PLANS` loop.
* Must be POSIX-portable and fast — this runs on every commit. No `python3` requirement.

### D. Unfreeze Path

Amending a frozen plan is legitimate; doing it silently is not. Whatever mechanism Open Question 2 selects must be **explicit, visible in git history, and human-initiated** — consistent with `/aapp-freeze` and `/aapp-done` carrying `disable-model-invocation: true`.

### E. Archived Plans

`.plans/done/*.md` is equally editable today (verified: the guard returns ALLOW for archived plans). An archived blueprint is the permanent record that the archive ledger and Pair 6 SHA references point at, so silent edits there are arguably worse than edits to a frozen plan. Scope decision deferred to Open Question 1.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Contract Definition & Test Harness
- [ ] Task 1.1: Add failing regression cases to `tests/pre-commit_test.sh`: checkbox tick on a 🟢 plan ALLOWED; §6 append ALLOWED; §2 edit BLOCKED; §4 edit BLOCKED; all four operations ALLOWED on a 🔴 plan.
- [ ] Task 1.2: Record the current suite pass count as the regression baseline before any engine change.

### Phase 2: Enforcement Engine
- [ ] Task 2.1: Implement the section-range mapper in `templates/aapp-pre-commit`, reusing `parse_plan_section` and matching section *numbers*.
- [ ] Task 2.2: Implement the design-lock check: for each staged `.plans/current/*.md` whose Status is 🟢, refuse when changed lines fall inside a protected section; emit a refusal naming the section and the unfreeze path.
- [ ] Task 2.3: Implement the unfreeze path selected in Open Question 2.
- [ ] Task 2.4: Run `aapp init` to propagate into `.githooks/`, then re-run the suite against the Phase 1 baseline.

### Phase 3: Documentation & Verification
- [ ] Task 3.1: Document the mutability contract in `templates/AGENTS.md` beside the existing freeze/execution rules.
- [ ] Task 3.2: Document the contract and the unfreeze path in `MANUAL.md`.
- [ ] Task 3.3: Run all suites; report actual counts against the Phase 1 baseline. Do not assert a target number in advance.
- [ ] Task 3.4: Update `CHANGELOG.md` under `## [Unreleased]`, citing `#68`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — incubator draft, confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/aapp-pre-commit` -> Section-range mapper, design-lock check for 🟢 plans, unfreeze path.
- [ ] `tests/pre-commit_test.sh` -> Regression coverage for permitted and refused regions at each plan status.
- [ ] `templates/AGENTS.md` -> Document the frozen-plan mutability contract.
- [ ] `MANUAL.md` -> Document the contract and the unfreeze procedure.
- [ ] `CHANGELOG.md` -> Unreleased entry citing `#68`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection. Propagated from `templates/` via `aapp init`.
- [ ] `templates/blast-radius-guard.sh` -> Deliberately unchanged: it is path-based and structurally cannot make this distinction (§2.A). Revisit only if Open Question 4 is answered "yes".
- [ ] `lib/planning_health.sh` -> Only in scope if Open Question 1 selects a health-check approach.
- [ ] `lib/plan_resolver.sh`, `lib/cmd_status.sh` -> Unrelated surfaces.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 — Archived plans.** Should `.plans/done/*.md` be immutable too? It is the permanent record that the archive ledger and Pair 6 SHA references depend on, so silent edits are arguably worse there than in `current/`. Against: legitimate corrections (a broken link, a typo in an Impact Summary) would need the same unfreeze ceremony. A softer option is a planning-health warning rather than a pre-commit refusal.
* [ ] **Question 2 — How is a plan unfrozen?** Editing the `**Status:**` line is itself a write to the file being protected, so the mechanism must not be self-blocking. Options: (a) always permit a change that touches *only* the Status line; (b) add an `aapp unfreeze <plan>` verb; (c) require `SKIP_BLAST_RADIUS=1` as a deliberate override. Option (a) is the least machinery; (b) is the most visible in history.
* [ ] **Question 3 — Which sections beyond §2 and §4?** §5 Open Questions arguably *should* stay editable, since resolving a question during execution is normal. §1 Context and §3 task text arguably should not drift. Needs a human call on where design ends and bookkeeping begins.
* [ ] **Question 4 — Should the write guard warn?** It cannot enforce this, but it could emit a non-blocking notice when an agent writes to a 🟢 plan — feedback at edit time rather than at commit time. Against: the guard's contract is binary allow/deny, and a warning channel would be new surface.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Plan scaffolded from `#68` via `/aapp-digest`. Established that enforcement must live in `aapp-pre-commit` rather than the write guard, since the guard is path-based and a frozen plan must remain writable for progress updates. Defined the mutability contract (checkboxes and §6 permitted; §2 and §4 refused), recorded the live incident that produced the issue, and separated the four genuine design decisions into Open Questions rather than pre-empting them.
