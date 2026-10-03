# 🗺️ Plan P-50: Plan Links, Issue Promotion & Ledger Commits
* **Created:** 2026-10-03 | **Last Refined:** 2026-10-03
* **Target Issue / Milestone:** None (follow-up to P-32, P-47 and P-49 Q1)
* **Plan ID:** P-50
* **Changelog:** Added: Plan rename with issue-link repair, issue promotion in `aapp draft`, and pickup/issue commits without raw git
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
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

Four `.plans` chores are still done by hand, each with a known failure:

1. **Renaming a plan breaks links.** Issue rows link plans by file path (`[P-48](current/P48-….md)` in *Target Plan / Fix*). Renaming the file means editing the row, the matrix row and the file by hand — done once for P-48, three files and a stale matrix description.
2. **`aapp done` breaks links.** Moving a plan from `current/` to `done/` leaves every other open issue that links it pointing at a dead path.
3. **Promotion is manual.** Promoting issue `#N` to a plan means `aapp draft`, then hand-setting the plan's `Target Issue`, the row's Status (`🔵 Planned`) and the row's link, then a raw git commit for the row.
4. **Ledger commits need raw git.** Adding a pickup idea or logging an issue ends in `git -C .plans commit`, which AGENTS.md forbids agents (P-47); there is no verb for it.

The developer's rule for issue rows (2026-10-03) allows exactly these edits: observation cells never change; lifecycle cells change at promotion (Status → Planned, link added) and on plan rename/archive (link path only), **by a verb, never by hand**.

**Goal:** every one of these happens inside an existing verb, in that verb's single commit, with no new verbs (developer, 2026-10-03: "verbs are getting way too many").

---

## 2. Technical Blueprint

### 2.1 Shared link helper (`lib/cmd_issue.sh`)
`issue_relink <old-rel-path> <new-rel-path>` rewrites only the link target inside `ISSUES.md` *Target Plan / Fix* cells and `issues_road_map.md` lines that link `<old-rel-path>`. Observation cells and link labels never change. Prints how many links it rewrote; returns non-zero only on a write failure.

### 2.2 Rename: `aapp refine <id> slug <new-slug>` (`lib/cmd_plan.sh`)
- Normalises `<new-slug>` like `aapp draft` does; the file becomes `current/P<num>-<new-slug>.md` (the `P<num>-` prefix and Plan ID never change).
- Refuses: plan not in `current/`, empty slug after normalisation, target file already exists, uncommitted edits in the plan file (commit them with plain `aapp refine` first, so the rename commit is only a rename).
- In one `plans_commit`: `git mv` of the plan, `issue_relink`, re-derived `state_matrix.md`, and a dated change-log line in the plan (`File renamed from <old> to <new>`). The active buffer is updated when it named the old file.
- The title line is content, not renamed: reword it with a normal `aapp refine`.
- Output: `📝 [Refine] P-48 renamed to P48-shared-docs-concurrency.md (<sha>); 1 issue link repaired`.

### 2.3 Link repair in `aapp done` (`lib/cmd_plan.sh`)
After moving the plan to `done/`, `cmd_done` runs `issue_relink current/<file> done/<file>` and adds the touched ledgers to its existing single commit. The plan's own Target Issue is already archived by P-32's close; this covers other open issues that link the plan.

### 2.4 Promotion: `aapp draft <slug> issue <num>` (`lib/cmd_plan.sh`, `lib/cmd_issue.sh`)
- `<num>` is bare (`98`; `#98` is a shell comment). Refuses when `#<num>` is not an active row in `ISSUES.md` (archived or unknown).
- Scaffolds as today, then: plan header `Target Issue / Milestone:` → `#<num>`; issue row Status cell → `` 🔵 `Planned` ``; *Target Plan / Fix* cell → `[P-<id>](current/<file>)`. The road map line is untouched.
- All in `draft`'s single commit. Without the token, `aapp draft` is unchanged.

### 2.5 Ledger commits without raw git
Pickup and issue-triage edits get a commit path on an existing verb (see Q1). Whatever the form: it commits only the named ledger files (`pickup.md`; or `ISSUES.md` + `issues_road_map.md`), with attribution, under the existing conventions (`pickup: <msg>`, `issue(triage): <msg>`), checks the subject length like P-49, and prints one confirmation line.

### 2.6 Agent-facing text
- `AGENTS.md` (both copies): promotion steps use `aapp draft <slug> issue <num>`; the CLI Reference rows for `draft` and `refine` show the new tokens; logging an issue ends with the ledger commit form from 2.5.
- Skills: `aapp-digest` (promotion and ledger commits), `aapp-plan` (defect logging commit), `aapp-pause` (logging while paused).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Existing links that already point at dead `current/` paths are not repaired retroactively; only moves made from now on are.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/refine.sh`: `slug` renames, repairs the issue link and road-map link, re-derives the matrix, logs the rename, one commit; refusals (archived plan, existing target, dirty plan file, empty slug).
- [ ] Task 1.2: `tests/verbs/done.sh`: another open issue linking the plan points at `done/` after `aapp done`, in the same commit.
- [ ] Task 1.3: `tests/verbs/draft.sh`: `issue <num>` sets the plan's Target Issue, the row's `🔵 Planned` and link, in the draft commit; refusals (archived or unknown issue).
- [ ] Task 1.4: Ledger commit tests for the Q1 form (commits only the ledger files, conventions, subject check).

### Phase 2: Implementation
- [ ] Task 2.1: `issue_relink` in `lib/cmd_issue.sh`.
- [ ] Task 2.2: `slug` token in `cmd_refine`; link repair in `cmd_done`; `issue` token in `cmd_draft` (`lib/cmd_plan.sh`).
- [ ] Task 2.3: Ledger commit path (Q1).
- [ ] Task 2.4: Contracts: `lib/docs/verbs/refine.md`, `done.md`, `draft.md` (and the Q1 verb's contract).

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: `templates/AGENTS.md`, `.agents/AGENTS.md`, and the three skills (2.6).
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md`, `.agents/CODEMAP.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_issue.sh` -> `issue_relink`; promotion row edit.
- [ ] `lib/cmd_plan.sh` -> `refine … slug`, `done` link repair, `draft … issue`, ledger commit path (if on `refine`).
- [ ] `lib/docs/verbs/refine.md` -> Contract: `slug` (and ledger targets, per Q1).
- [ ] `lib/docs/verbs/done.md` -> Contract: link repair.
- [ ] `lib/docs/verbs/draft.md` -> Contract: `issue <num>`.
- [ ] `tests/verbs/refine.sh` -> Rename (and ledger commit) tests.
- [ ] `tests/verbs/done.sh` -> Link repair test.
- [ ] `tests/verbs/draft.sh` -> Promotion tests.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Promotion via `draft … issue`; ledger commits.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Defect logging commit.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Logging commit while paused.
- [ ] `templates/AGENTS.md` -> Promotion steps, CLI Reference rows, logging commit.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Rename, link repair, promotion, ledger commits.
- [ ] `CHEATSHEET.md` -> New tokens.
- [ ] `.agents/CODEMAP.md` -> `issue_relink` and the new tokens.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/done/000-issues-archive.md` -> Archive rows are terminal; no link repair there.
- [ ] `.plans/done/000-archive-ledger.md` -> Terminal ledger.
- [ ] `.githooks/*` -> Guard engine self-protection.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 — Which existing verb commits pickup and issue-triage edits?** Options: (a) `aapp refine pickup "<msg>"` and `aapp refine issues "<msg>"`: `refine` already means "commit an edit I made in `.plans`", so a target word fits; (b) `aapp issue log "<msg>"` for issue rows plus a pickup form elsewhere: closer to the issue verb, but splits one chore across two verbs and still needs a home for pickup. Recommendation: (a), one verb for every hand-made `.plans` edit.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-03:** Drafted from the pickup idea "Plan rename & link repair", P-49 Q1, and the promotion discussion: no new verbs (rename on `refine`, repair inside `done`, promotion on `draft`), only link paths and lifecycle cells of issue rows change.
