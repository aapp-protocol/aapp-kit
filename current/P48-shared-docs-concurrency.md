# 🗺️ Plan P-48: Shared Docs Concurrency: Collision Exemption, Plan-Declared Changelog, Union Merge
* **Created:** 2026-10-03 | **Last Refined:** 2026-10-03
* **Target Issue / Milestone:** #96 *(supersedes #96 upon completion)*
* **Plan ID:** P-48
* **Changelog:** Added: Shared docs never block concurrent plans; one plan-declared changelog entry per plan (`aapp.changelogMode`); union merge for CHANGELOG.md
* **Status:** 🔷 Frozen
* **Base:** `1755e68` (develop)
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

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

## 🎯 1. Context & Architectural Goal

### Problem Statement
When two or more plans are `⚡ In Development`, the shared documentation files (`CHANGELOG.md`, `CODEMAP.md`, `ARCHITECTURE.md`, `MANUAL.md`, …) cause three problems:

1. **False collisions.** Every plan lists the shared docs in `### 📂 Target Files`, so two plans "collide" on them although the pre-commit hook always allows them. Two checks block or flag this: the `aapp start` activation gate (`check_disjointness_activation_gate`, `lib/cmd_plan.sh`) refuses to start the second plan, and Pair 7 (`check_pair7_inflight_boundary_collision`, `lib/planning_health.sh`) reports a violation.
2. **Changelog pollution and lost updates.** The pre-commit hook demands a `CHANGELOG.md` change in every commit that touches code, so a plan built in several commits ends up with several bullets for one capability, or forces an invented bullet per step. Agents also edit the file by hand, often minutes before committing: a chore (wrong section, over-long bullet, missing plan reference) and a race with parallel edits. A CLI cannot tell which commit completes a plan, so it cannot decide the entry from the commit alone.
3. **Merge conflicts.** Branches from separate worktrees each add a bullet at the top of `## [Unreleased]`; merging them conflicts on adjacent lines.

### Architectural Goal
1. **One shared docs definition, exempt from collision checks.** The gate and Pair 7 treat shared docs as notices, never blocks; real code files still collide.
2. **The plan declares its changelog entry.** One entry per plan, written into `CHANGELOG.md` by `aapp commit` on the plan's first code commit. Every later code commit for that plan passes the hook once the entry is present, on any branch. Repositories that want a bullet per commit opt in with `aapp.changelogMode = commit`.
3. **Union merge for `CHANGELOG.md`.** Bullets from both branches are kept automatically at merge time.

Coordinating integration across many agents (a queue that merges finished plans one at a time) is out of scope; it belongs to the *Work Dispatch Queue* pickup idea.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Shared docs definition (`lib/aapp-lib.sh`)
- `AAPP_SHARED_DOCS_REGEX` lists the shared documentation files: `CHANGELOG.md`, `README.md`, `MANUAL.md`, `CHEATSHEET.md`, `CODEMAP.md`, `ARCHITECTURE.md`, `ISSUES.md` (matched as a basename, so `.agents/CODEMAP.md` qualifies).
- `aapp_is_shared_doc <path>` returns 0 for a match.
- `templates/aapp-pre-commit` builds its `ALWAYS_ALLOWED_REGEX` from `AAPP_SHARED_DOCS_REGEX` plus its dependency manifests (`package.json`, lockfiles, …), so the list is defined once. Dependency manifests stay always-allowed for commits but are **not** shared docs: two plans editing them is a real collision.
- `lib/aapp-lib.sh` already ships into `.githooks/` via `aapp init`, so the hook and the CLI read the same definition.

### 2.2 Collision checks
- `check_disjointness_activation_gate` (`lib/cmd_plan.sh`) and `check_pair7_inflight_boundary_collision` (`lib/planning_health.sh`) skip paths where `aapp_is_shared_doc` matches, and print a notice instead:
  ```text
  ℹ️  [Shared Doc] P-46 and P-48 both update 'CHANGELOG.md' (shared docs never block; see union merge).
  ```
- Any other shared path (e.g. `lib/cmd_hook.sh`) keeps today's hard refusal/violation.

### 2.3 Plan-declared changelog entry
A CLI cannot know which commit completes a plan, but the plan knows what it delivers. The entry is declared once, in the plan, and every commit can look it up.

**Plan header field** (`templates/plan-template.md`, pre-filled by `aapp draft` from the plan title):
```markdown
* **Changelog:** Changed: Shared Docs Concurrency
```
- Format `<Added|Changed|Fixed>: <text>`; single line; the rendered bullet `- <text> (\`<plan-id>\`)` must fit `aapp.changelogMaxLen`.
- `aapp draft` writes `Changed: <Title>`, so every plan has a valid entry from birth. The author rewords it and picks the right section while refining (the `aapp-digest` / `aapp-plan` skills say so); it is reviewed with the rest of the plan before freeze.
- `aapp freeze` refuses a plan whose `**Changelog:**` field is missing, empty, malformed or too long (fail closed at freeze, not at commit time). Rewording later goes through the plan and is committed with `aapp refine`.

**Repository setting `aapp.changelogMode`** (seeded by `aapp init` when absent, never overwritten):
| Mode | Code commit for an active plan passes the hook when … |
| :--- | :--- |
| `plan` (default) | the committed `CHANGELOG.md` contains a bullet with `(\`<plan-id>\`)` under `## [Unreleased]` |
| `commit` (opt-in) | `CHANGELOG.md` changes in that commit (today's rule) |

**`aapp commit` (`lib/cmd_commit.sh`)**, in `plan` mode:
- No plan bullet yet → inserts the declared entry as the first bullet of its section under `## [Unreleased]` (creating the section heading if missing) and stages `CHANGELOG.md` with the code.
- Plan bullet present but worded differently from the declaration → replaces that one line.
- Plan bullet present and current → leaves `CHANGELOG.md` alone.
- No `changelog` token exists: the plan is the single source of the entry.

**Pre-commit hook (`templates/aapp-pre-commit`)** when code is staged:
- Resolves the commit's plan the way the blast-radius check already does (active plan buffer, else the single in-development plan).
- `plan` mode: checks the **staged** `CHANGELOG.md` (`git show :CHANGELOG.md`, not only the diff) for the plan's bullet, matched by plan ID, so rewording never breaks it.
- No active plan (a direct fix), or `commit` mode: today's rule — `CHANGELOG.md` must change in the commit. Nothing becomes lax.
- Refusal names the fix: `aapp commit` writes the declared entry, or `aapp refine` declares it.

### 2.4 Union merge for `CHANGELOG.md`
- `aapp init` ensures `.gitattributes` contains `CHANGELOG.md merge=union`: appends that one line when absent, never rewrites other lines, and reports `ℹ️ Added 'CHANGELOG.md merge=union' to .gitattributes`. Running it again changes nothing (Q1).
- Two plans on two branches each add their one entry; union merge keeps both. `CODEMAP.md` and `ARCHITECTURE.md` are not union-merged (their conflicts are real overlaps a human should resolve).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Plans already in the backlog without a `**Changelog:**` field are refused at freeze until it is added. Archived plans are untouched.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: Gate and Pair 7: two in-development plans sharing only shared docs start and pass with a notice; sharing a code file is still refused (`tests/verbs/start.sh`, `tests/plan_resolver_test.sh`).
- [ ] Task 1.2: `tests/verbs/commit.sh` (`plan` mode): the first code commit inserts the declared entry `- <text> (\`P-x\`)` in its section and commits it with the code; a second code commit leaves `CHANGELOG.md` untouched and passes; a reworded declaration replaces the one plan line; no duplicate bullets.
- [ ] Task 1.3: `tests/pre-commit_test.sh`: `plan` mode passes a code commit when the staged `CHANGELOG.md` holds the plan's bullet and refuses when it does not; no active plan and `commit` mode keep today's rule.
- [ ] Task 1.4: `tests/verbs/freeze.sh`: freeze refuses a missing, malformed or over-long `**Changelog:**` field; `tests/verbs/draft.sh`: a drafted plan carries `**Changelog:** Changed: <Title>`.
- [ ] Task 1.5: `aapp init` adds `CHANGELOG.md merge=union` once, keeps existing `.gitattributes` lines, and seeds `aapp.changelogMode=plan` only when absent (`tests/install_test.sh`).

### Phase 2: Implementation
- [ ] Task 2.1: `AAPP_SHARED_DOCS_REGEX` and `aapp_is_shared_doc` in `lib/aapp-lib.sh`; `templates/aapp-pre-commit` builds `ALWAYS_ALLOWED_REGEX` from it.
- [ ] Task 2.2: Shared-doc exemption in the activation gate and Pair 7.
- [ ] Task 2.3: `**Changelog:**` field in `templates/plan-template.md`; `aapp draft` pre-fills it from the title and the freeze check, both in `lib/cmd_plan.sh`.
- [ ] Task 2.4: Declared-entry insert/replace in `lib/cmd_commit.sh`; update `lib/docs/verbs/commit.md` and `lib/docs/verbs/freeze.md`.
- [ ] Task 2.5: `aapp.changelogMode` check in `templates/aapp-pre-commit`.
- [ ] Task 2.6: `.gitattributes` union line and `aapp.changelogMode` seed in `lib/cmd_init.sh`.

### Phase 3: Skills, Docs & Verification
- [ ] Task 3.1: `templates/skills/aapp-digest/SKILL.md` and `aapp-plan`: author the `**Changelog:**` field with the plan; `templates/skills/aapp-start/SKILL.md`: `aapp commit` writes the entry, never edit `CHANGELOG.md` by hand; AGENTS.md (both copies): changelog rule and CLI Reference row for `aapp commit`.
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md`, `.agents/CODEMAP.md`, `ARCHITECTURE.md`; `CHANGELOG.md` under `## [Unreleased]`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Shared docs regex and `aapp_is_shared_doc`.
- [ ] `templates/aapp-pre-commit` -> Shared definition; `aapp.changelogMode` plan-entry check.
- [ ] `templates/plan-template.md` -> `**Changelog:**` header field.
- [ ] `lib/cmd_plan.sh` -> Activation gate exempts shared docs; `aapp draft` pre-fills and freeze requires the `**Changelog:**` field.
- [ ] `lib/docs/verbs/draft.md` -> Contract: pre-filled `**Changelog:**` field.
- [ ] `lib/planning_health.sh` -> Pair 7 exempts shared docs.
- [ ] `lib/cmd_commit.sh` -> Insert or replace the plan's declared entry.
- [ ] `lib/docs/verbs/commit.md` -> Contract for the declared entry.
- [ ] `lib/docs/verbs/freeze.md` -> Contract for the `**Changelog:**` refusal.
- [ ] `lib/cmd_init.sh` -> `.gitattributes` union line; seed `aapp.changelogMode`.
- [ ] `tests/verbs/start.sh` -> Gate exemption tests.
- [ ] `tests/plan_resolver_test.sh` -> Pair 7 exemption tests.
- [ ] `tests/verbs/commit.sh` -> Declared-entry tests.
- [ ] `tests/verbs/freeze.sh` -> `**Changelog:**` field refusal tests.
- [ ] `tests/verbs/draft.sh` -> Drafted plan carries the pre-filled `**Changelog:**` field.
- [ ] `tests/pre-commit_test.sh` -> `plan` / `commit` mode hook tests.
- [ ] `tests/install_test.sh` -> `.gitattributes` and mode seed tests.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Author the `**Changelog:**` field.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Author the `**Changelog:**` field.
- [ ] `templates/skills/aapp-start/SKILL.md` -> `aapp commit` writes the entry.
- [ ] `templates/AGENTS.md` -> Changelog rule; CLI Reference row for `aapp commit`.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Shared docs, plan-declared changelog, `aapp.changelogMode`, union merge.
- [ ] `CHEATSHEET.md` -> `aapp.changelogMode` setting row.
- [ ] `.agents/CODEMAP.md` -> Shared docs definition, declared entry flow.
- [ ] `ARCHITECTURE.md` -> Shared docs concurrency model.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard engine self-protection; refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Governance skills self-protection; refreshed from `templates/skills/` by `aapp init`.
- [ ] `.plans/ISSUES.md` -> Managed via issue lifecycle.
- [ ] `.plans/state_matrix.md` -> Managed via state transitions.

---

## ❓ 5. Open Questions & Settled Decisions

* [x] **Settled (developer, 2026-10-03): no lock engine.** A lock serializes edits but cannot prevent cross-branch merge conflicts and would add a manual acquire/release chore. Integration ordering across agents (an integration queue) moves to the *Work Dispatch Queue* pickup idea.
* [x] **Settled (developer, 2026-10-03): one changelog entry per plan, declared in the plan.** A CLI cannot know which commit completes a plan, so the entry comes from the plan's `**Changelog:**` field. Per-commit bullets are opt-in via `aapp.changelogMode = commit`. No `changelog` token in `aapp commit` (single source). The hook never becomes lax: direct fixes and `commit` mode keep today's rule.
* [x] **Question 1 — Does `aapp init` write the union line into `.gitattributes`? → RESOLVED (developer, 2026-10-03): yes, option (a).** Appended once when absent, reported, never rewriting other lines.

---

## 📦 6. Change Log & Refinement History
* **2026-10-03:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-03:** Plan activated into ⚡ In Development via start.
* **2026-10-03:** Plan locked and frozen into 🔷 Frozen via freeze.

* **2026-10-03 (Pre-filled field):** `aapp draft` pre-fills `**Changelog:** Changed: <Title>`; freeze refuses only missing, malformed or over-long fields. Chosen as the natural fit: every plan has its entry from birth, and the 10 test suites that freeze drafted plans keep working unchanged (the strict placeholder rule would have touched them all for setup only). Revisit if it doesn't feel right in use.
* **2026-10-03 (Pre-freeze):** Plan bullet matched by "contains `(\`<plan-id>\`)`" (existing bullets carry the reference mid-line); P-48 declares its own `**Changelog:**` entry; shared helpers (parse declaration, find bullet, render bullet) live in `lib/aapp-lib.sh`, loaded by both the hook and the CLI.
* **2026-10-03 (Rename):** File renamed from `P48-shared-file-semaphore-and-concurrency.md` to `P48-shared-docs-concurrency.md` to match what it ships; the #96 link cell updated (lifecycle-cell exception; done by hand until `aapp rename` exists).
* **2026-10-03 (Plan-declared changelog):** Replaced the `changelog "<text>"` token with a `**Changelog:**` plan header field: `aapp commit` writes/updates the plan's single entry, the hook passes later commits once the entry is present (`aapp.changelogMode = plan`, default; `commit` keeps today's rule), freeze refuses a missing field. Q1 resolved (a). File name kept: the #96 issue row links to it.
* **2026-10-03 (Rework):** Lock engine dropped (cannot prevent cross-branch conflicts; adds an acquire/release chore). Replaced by: one shared docs definition exempted in both the `aapp start` gate and Pair 7 (the gate was missing from the draft); optional `aapp commit … changelog "<text>"` written by the helper; union merge for `CHANGELOG.md`. Integration queue moved to the Work Dispatch Queue pickup idea. Previous Q1 (lease timeout) and Q2 (fragment queue) are void with the lock gone.
* **2026-10-03 (Refinement):** Settled decisions for Q1 (adopted 300s default lease with `aapp.lockLeaseTimeout` override) and Q2 (rejected `aapp done` changelog deferral; re-affirmed strict commit-time changelog requirement synchronized via atomic file semaphore).
* **2026-10-03:** Blueprint drafted from Issue #96 analysis. Established POSIX atomic `mkdir` semaphore engine, Pair 7 invariant filtering, and commit engine lease acquisition.
