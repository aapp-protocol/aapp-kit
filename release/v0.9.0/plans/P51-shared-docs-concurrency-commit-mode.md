# 🗺️ Plan P-51: Shared Docs Concurrency, Part 2 (P-48 Extension): Commit Mode & Plan-Recorded Modes
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-04
* **Target Issue / Milestone:** None (extension of P-48; should have shipped with it)
* **Plan ID:** P-51
* **Changelog:** Added: `aapp.commitMode` (atomic by default) and plans recording the commit and changelog modes they were built with
* **Status:** ✅ Done
* **Base:** `13adeb2` (develop)
* **Commits:** `6cce830` (develop)
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

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

P-48 shipped `aapp.changelogMode` (one changelog entry per plan, or one per commit). Two pieces discussed with it did not ship and belong to the same design:

1. **Commit mode.** The developer's preferred style is one commit per plan, but some weeks call for several commits per plan. Nothing expresses or enforces either; a plan can quietly end up with many commits.
2. **A record of how each plan was built.** Both modes are repository config and change over time (one week atomic, the next microcommits). Once the config changes, nothing tells how an earlier plan was actually done.

**Goal:**
- A second config, `aapp.commitMode` (`atomic` | `microcommits`, default `atomic`), next to `aapp.changelogMode`. **All checks read the config.**
- Every plan **carries the record** of the modes in effect while it was implemented, in its header. The record is data only: nothing enforces or reads it to decide anything.

---

## 2. Technical Blueprint

### 2.1 Config (`lib/cmd_init.sh`)
- `aapp.commitMode`: `atomic` (default) or `microcommits`, seeded by `aapp init` only when absent, like `aapp.changelogMode`.
- The two configs are independent; they will often move together (`atomic` + `plan`), but nothing ties them.

### 2.2 Plan header record (`templates/plan-template.md`, `lib/cmd_plan.sh`, `lib/cmd_commit.sh`)
```markdown
* **Commit Mode:** atomic
* **Changelog Mode:** plan
```
- `aapp draft` writes both from the current config, so a new plan shows the modes it will be built under.
- Every `aapp commit` for the plan re-stamps both from the config in effect at that commit, in the plan file it already commits (`plan(record): …`). When a value differs from the plan's previous record, it also appends a dated line to §6: `Commit Mode switched to microcommits (config) for <sha>.` The finished plan therefore shows the modes it ended with, and §6 shows any switch on the way.
- Plans without the fields (drafted before this plan) get them on their next `aapp commit`.
- `aapp freeze` and every other check ignore the fields: they are a record, not a setting.

### 2.3 Commit mode enforcement — reads `aapp.commitMode`
- **`atomic`:**
  - `aapp commit` (without `amend`) refuses a code commit when the active plan's `**Commits:**` header already records a commit: `❌ [Commit Refusal] aapp.commitMode=atomic: P-51 already has commit <sha>. Fold changes in with 'aapp commit amend', or set aapp.commitMode=microcommits.`
  - The pre-commit hook refuses a raw `git commit` of code for an active plan whose header already records a commit, with the same hint. Commits made by the helper (`AAPP_COMMIT_HELPER=1`) skip this hook check because the helper already decided.
  - `aapp commit amend` is always allowed: it replaces the recorded commit, keeping the plan at one. A raw `git commit --amend` of code is refused like any raw commit (pre-commit cannot tell an amend from a new commit); `aapp commit amend` is the path, and it keeps the plan's record right where a raw amend would orphan it. `aapp commit adopt` is not affected (it records commits that already exist).
- **`microcommits`:** any number of commits, as today.
- Commits with no active plan (direct fixes) are not affected by commit mode.

### 2.4 Interplay with P-48
- `aapp.changelogMode` behaviour is unchanged; it now also gets recorded in the plan (2.2).
- `atomic` + `plan` is the natural pair: one commit, one entry. `microcommits` + `plan` still yields one entry per plan (P-48).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Default `atomic` applies to existing repositories after `aapp init`: a plan in development that already has a recorded commit needs `aapp.commitMode=microcommits` (or `amend`) for further commits. Release note states this. The kit's own test sandboxes that make several commits per plan (`tests/verbs/commit.sh`, `tests/verbs/done.sh`) opt into `microcommits` the same way.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/commit.sh`: `atomic` refuses a second code commit with the amend hint; `amend` passes and keeps one recorded commit; `microcommits` allows a second commit; each commit re-stamps the plan's two fields, and a config switch adds the §6 line.
- [ ] Task 1.2: `tests/pre-commit_test.sh`: `atomic` refuses a raw code commit for a plan with a recorded commit; `microcommits` and no-plan commits pass; helper commits skip the check.
- [ ] Task 1.3: `tests/verbs/draft.sh`: a drafted plan carries both fields from the config; `tests/install_test.sh`: `aapp.commitMode=atomic` seeded only when absent.
- [ ] Task 1.4: `tests/verbs/commit.sh` (existing sections) and `tests/verbs/done.sh`: sandboxes whose fixtures make several commits, or raw amends, per plan set `aapp.commitMode=microcommits`.

### Phase 2: Implementation
- [ ] Task 2.1: Seed `aapp.commitMode` in `lib/cmd_init.sh`.
- [ ] Task 2.2: Template fields; `aapp draft` writes them from config (`lib/cmd_plan.sh`).
- [ ] Task 2.3: Atomic check and field re-stamping in `lib/cmd_commit.sh`; shared helpers in `lib/aapp-lib.sh`.
- [ ] Task 2.4: Atomic check in `templates/aapp-pre-commit`.
- [ ] Task 2.5: Contracts `lib/docs/verbs/commit.md`, `lib/docs/verbs/draft.md`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: `templates/skills/aapp-start/SKILL.md`: in `atomic` mode the plan is one commit, fixes go through `aapp commit amend`; `templates/AGENTS.md` and `.agents/AGENTS.md`: the commit-mode rule next to the changelog rule.
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md` (config row), `.agents/CODEMAP.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_init.sh` -> Seed `aapp.commitMode`.
- [ ] `templates/plan-template.md` -> `**Commit Mode:**` and `**Changelog Mode:**` header fields.
- [ ] `lib/cmd_plan.sh` -> `aapp draft` writes both fields from config.
- [ ] `lib/cmd_commit.sh` -> Atomic check; re-stamp fields; §6 switch line.
- [ ] `lib/aapp-lib.sh` -> Helpers to read and write the two fields.
- [ ] `templates/aapp-pre-commit` -> Atomic check for raw commits.
- [ ] `lib/docs/verbs/commit.md` -> Contract: atomic refusal, record stamping.
- [ ] `lib/docs/verbs/draft.md` -> Contract: fields from config.
- [ ] `tests/verbs/commit.sh` -> Commit mode and stamping tests.
- [ ] `tests/pre-commit_test.sh` -> Hook atomic tests.
- [ ] `tests/verbs/draft.sh` -> Field pre-fill test.
- [ ] `tests/install_test.sh` -> Seed test.
- [ ] `tests/verbs/done.sh` -> Sandbox opts into `microcommits`: its fixtures record a commit, then make raw commits and amends.
- [ ] `templates/skills/aapp-start/SKILL.md` -> One commit per plan in atomic mode.
- [ ] `templates/AGENTS.md` -> Commit-mode rule.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Commit mode and the plan record.
- [ ] `CHEATSHEET.md` -> `aapp.commitMode` row.
- [ ] `.agents/CODEMAP.md` -> Helpers and checks.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified.)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Plan implementation completed and archived to done/.
* **2026-10-07:** Plan activated into ⚡ In Development via start.
* **2026-10-07:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-07:** Plan activated into ⚡ In Development via start.
* **2026-10-07:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-07:** Refined during implementation (developer: round trip, to keep the logs clean): `tests/verbs/done.sh` added to the targets (its fixtures record a commit, then make raw commits and amends); a raw `git commit --amend` is refused in atomic mode like any raw commit, `aapp commit amend` being the path; `adopt` is unaffected.
* **2026-10-04:** Drafted as the extension of P-48 (should have shipped with it): `aapp.commitMode` config (atomic default); all checks read the configs; each plan records the commit and changelog modes it was built with, re-stamped on every `aapp commit`, with switches logged in §6.
