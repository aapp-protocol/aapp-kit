# 🗺️ Plan P-128: Bash Commits Record Bare Hashes
* **Created:** 2026-10-21 | **Last Refined:** 2026-10-21
* **Target Issue / Milestone:** none
* **Plan ID:** P-128
* **Changelog:** Changed: a plan's `Commits:` line records bare commit hashes, without the branch (P-128)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
For the bash line of the kit (`develop` / `bashdev`); the Perl port already reads the hash only (P-115 `AAPP::State::plan_commits`).

Since P-39 the header records each commit as `` `sha` (branch) ``. Nothing reads the branch: every reader takes the hash, and since plan worktrees the branch is the plan's own `plan/P<n>-…`, deleted at `done`. The writers stop writing it; the reader takes the hash and ignores anything after it, so lines already written stay readable and nothing is migrated.
```markdown
* **Commits:** `8e51e53`, `3090f15`
```
`* **Base:**` keeps its branch: integration reads it.

---

## 2. Technical Blueprint

1. **Writers drop the branch** (one token each): `lib/cmd_commit.sh` commit/adopt (``"\`$short_s\`"``) and amend (``"\`$new_sha\`"``), `lib/cmd_plan.sh` auto-rebase (``"\`$c_sha\`"``) and squash (``"\`$SQ_NEW\`"``), `templates/aapp-post-rewrite` (``"\`$s\`"``).
2. **The reader takes the hash** (`parse_plan_commits`, `lib/aapp-lib.sh`): the item pattern becomes ``^`([0-9a-fA-F]+)` `` with anything after it ignored; it prints the hash alone. Callers already take the first field.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`: lines written before keep their `(branch)`; the reader ignores it, nothing is rewritten.

---

## 🔨 3. Implementation Steps & Execution Checklist

- [ ] Task 1.1: Tests first: `test_parse_plan_commits` prints the hash for `` `sha` `` and `` `sha` (branch) ``; `aapp commit` records `` `sha` `` with no branch.
- [ ] Task 1.2: §2 items 1 and 2; the contract lines of `commit.md` and `aapp_lib.md` name the bare form.
- [ ] Task 1.3: `./aapp test strict quiet` green.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/aapp-lib.sh` -> `parse_plan_commits` prints the hash only.
- [ ] `lib/cmd_commit.sh` -> Commit, adopt and amend write no branch.
- [ ] `lib/cmd_plan.sh` -> Auto-rebase and squash write no branch.
- [ ] `templates/aapp-post-rewrite` -> Rewritten hashes written without branch.
- [ ] `tests/aapp_lib_test.sh` -> Parser test.
- [ ] `tests/verbs/commit.sh` -> Recorded form after a commit.
- [ ] `lib/docs/verbs/commit.md` -> Records the hash.
- [ ] `lib/docs/core/aapp_lib.md` -> `parse_plan_commits` prints hashes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/` -> The Perl port reads the hash already (P-115).
- [ ] `.plans/` -> Lines already written stay as they are.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-21:** Drafted for the bash line: `Commits:` records bare hashes; the P-39 branch record was never read.
