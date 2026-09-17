# 🗺️ Plan: P-16 Frozen Plan Immutability & Design-Lock Enforcement
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-17
* **Target Issue / Milestone:** `#68`
* **Plan ID:** P-16
* **Status:** 🟢 Ready for Execution
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

Enforcement therefore belongs in **`templates/aapp-pre-commit`**, which already reads the staged set (`git diff --cached --name-only -z`, line 25) and can read staged hunks. The write guard is deliberately left unchanged.

### B. The Mutability Contract for a 🟢 Plan

| Region | Frozen plan | Rationale |
| :--- | :--- | :--- |
| Task checkboxes (`- [ ]` → `- [x]`) | **permitted** | Recording progress is the point of executing |
| `## 6. Change Log & Refinement History` | **permitted** | Execution notes and verification records belong here |
| `## 5. Open Questions` | **permitted** | Resolving and documenting decisions during execution |
| `## 2.` Technical Blueprint | **refused** | Changing the design under in-flight execution |
| `## 4.` Blast Radius & System Boundaries | **refused** | Changing what the agent may write, post-greenlight |
| `**Status:**` unfreeze transition | **permitted** | Reverting status to `🟡 Refining` without altering §2/§4 |

Rejection must name the section and point at the unfreeze path, in the style of the existing blast-radius refusal message:
```text
❌ [Pre-Commit Design Lock Violation] Cannot edit locked design sections of a frozen plan!
   Staged plan : .plans/current/P16-frozen-plan-immutability.md
   Violation   : Attempted modifications to '## 2. Technical Blueprint' or '## 4. Blast Radius'
   Status      : 🟢 Frozen (Design Locked)

   👉 To resolve this:
      1. Revert changes to Section 2 and Section 4.
      2. Or unfreeze the plan by changing status back to '🟡 Refining' before amending the design.
```

### C. Implementation Mechanics in Pre-Commit Hook

1. **Extract Section Content from HEAD vs Index**:
   Use `awk` to extract Section 2 and Section 4 content:
   - Section 2 pattern: `^## ([^0-9]*[[:space:]])?2\.` up to next `^## ([^0-9]*[[:space:]])?[0-9]+\.`
   - Section 4 pattern: `^## ([^0-9]*[[:space:]])?4\.` up to next `^## ([^0-9]*[[:space:]])?[0-9]+\.`
2. **Detection Logic**:
   For every staged plan file matching `*(.plans/)current/*.md` or `current/*.md`:
   - Check status in `HEAD:"$STAGED"`:
     If `HEAD` status is `🟢` (or `Ready for Execution` or `Frozen`):
     - Compare `HEAD` Section 2 vs staged (`:$STAGED`) Section 2. If different: **BLOCK**.
     - Compare `HEAD` Section 4 vs staged (`:$STAGED`) Section 4. If different: **BLOCK**.
3. **Unfreeze Path**:
   If a plan's status in `:$STAGED` is changed from `🟢` to `🟡 Refining`, the commit is permitted **provided Section 2 and Section 4 are unchanged in that same commit**. To alter Section 2 or Section 4, the unfreeze must be committed first (or status must not be 🟢).
4. **POSIX-pure and Fast**:
   Runs in pure POSIX awk/bash without requiring external python3 runtimes.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Contract Definition & Test Harness
- [ ] Task 1.1: Add failing regression cases to `tests/pre-commit_test.sh`:
  - Checkbox tick (`- [ ]` -> `- [x]`) on a 🟢 plan ALLOWED.
  - §6 Change Log append on a 🟢 plan ALLOWED.
  - §5 Open Questions update on a 🟢 plan ALLOWED.
  - §2 Technical Blueprint edit on a 🟢 plan BLOCKED.
  - §4 Blast Radius edit on a 🟢 plan BLOCKED.
  - §2 / §4 edits on a 🔴/🟡 plan ALLOWED.
  - Unfreeze commit (status revert to 🟡 with unchanged §2/§4) ALLOWED.
  - Smuggled unfreeze (status revert to 🟡 with modified §2) BLOCKED.
- [ ] Task 1.2: Record current test suite baseline (`45 passed, 0 failed`).

### Phase 2: Enforcement Engine
- [ ] Task 2.1: Implement section extraction and design-lock validation in `templates/aapp-pre-commit`.
- [ ] Task 2.2: Add refusal diagnostic message naming the modified section and unfreeze resolution.
- [ ] Task 2.3: Run `aapp init` to propagate into `.githooks/pre-commit`.
- [ ] Task 2.4: Run `tests/pre-commit_test.sh` and verify all new tests pass.

### Phase 3: Documentation & Verification
- [ ] Task 3.1: Document the frozen-plan mutability contract in `templates/AGENTS.md`.
- [ ] Task 3.2: Document the contract and unfreeze procedure in `MANUAL.md`.
- [ ] Task 3.3: Update `CHANGELOG.md` under `## [Unreleased]`, citing `#68`.
- [ ] Task 3.4: Run all test suites and verify 100% green.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **LOCKED** — Greenlit for implementation)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/aapp-pre-commit` -> Section extractor, design-lock check for 🟢 plans, unfreeze path.
- [ ] `tests/pre-commit_test.sh` -> Regression coverage for permitted and refused regions at each plan status.
- [ ] `templates/AGENTS.md` -> Document the frozen-plan mutability contract.
- [ ] `MANUAL.md` -> Document the contract and the unfreeze procedure.
- [ ] `CHANGELOG.md` -> Unreleased entry citing `#68`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection. Propagated from `templates/` via `aapp init`.
- [ ] `templates/blast-radius-guard.sh` -> Deliberately unchanged: it is path-based and structurally cannot make this distinction (§2.A).
- [ ] `lib/planning_health.sh` -> Planning health engine unchanged.
- [ ] `lib/plan_resolver.sh`, `lib/cmd_status.sh` -> Unrelated surfaces.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Archived plans.** Should `.plans/done/*.md` be immutable too?
  - *Resolution:* No pre-commit block on `done/`. Planning Health (Pair 6 SHA reference integrity) provides soft integrity checking. Pre-commit focuses strictly on active plans in `.plans/current/` to avoid friction when correcting historical typos, metadata, or documentation links in archived ledgers.

* [x] **Question 2 — How is a plan unfrozen?**
  - *Resolution:* Pre-commit permits commits that change the `**Status:**` line from `🟢` back to `🟡 Refining`, provided Section 2 and Section 4 are not modified in the same commit. This makes unfreezing an explicit, traceable step in Git history.

* [x] **Question 3 — Which sections beyond §2 and §4?**
  - *Resolution:* Strictly lock §2 (Technical Blueprint) and §4 (Blast Radius). Task checkboxes in §3 (`- [ ]` -> `- [x]`), §5 (Open Questions updates/resolutions), and §6 (Change Log appends) remain freely writable during execution.

* [x] **Question 4 — Should the write guard warn?**
  - *Resolution:* No. The write guard remains strictly binary allow/deny. Adding non-blocking warning channels creates noisy tool output; pre-commit is the authoritative gate.

---

## 📦 6. Change Log & Refinement History
* **2026-09-17:** Plan refined and frozen (`🟢 Ready for Execution`). Resolved all 4 Open Questions: locked §2 and §4 in pre-commit, allowed §3 checkboxes, §5 open questions, and §6 change log; permitted explicit status-only unfreezing; kept write guard binary without warning noise; locked Blast Radius to 5 target files.
* **2026-09-16:** Plan scaffolded from `#68` via `/aapp-digest`. Established that enforcement must live in `aapp-pre-commit` rather than the write guard, since the guard is path-based and a frozen plan must remain writable for progress updates. Defined the mutability contract (checkboxes and §6 permitted; §2 and §4 refused), recorded the live incident that produced the issue, and separated the four genuine design decisions into Open Questions rather than pre-empting them.
