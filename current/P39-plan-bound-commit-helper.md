# 🗺️ Plan P-39: Plan Bound Commit Helper
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** None — resolves the `done` verification-commit divergence recorded in `lib/docs/verbs/done.md`
* **Plan ID:** P-39
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

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

## 1. Context & Architectural Goal

### Problem Statement
`aapp done` records the code repository's `HEAD` at invocation as a plan's verification commit
(`lib/cmd_plan.sh`, `cmd_done`). Nothing links a commit to the plan it implements, so:

1. **Intermediate commits are recorded instead.** Closing `P-37`, the ledger took `e65bc45` (a
   platform-docs commit made afterwards) instead of the implementation `416e115`, and was fixed by hand.
2. **Multi-commit plans have no truthful single value.** `P-34` is `bca7d9a` plus `8c0c103`.
3. **The worktree is wrong.** `HEAD` is read from the *current* worktree root, so `done` run from
   `.plans/` records a `plans`-branch commit.
4. **Nothing between the last commit and `done` has a reference.** A review hook before `done`, or a
   human double-checking the work, cannot ask "which commits are this plan?"

Agents also compose commits by hand: attribution trailers are guessed and rejected
(`Co-Authored-By` in `commit` mode), and lifecycle commits are wrapped in `|| true` (#81).

### Architectural Goal
A plan-bound commit helper that agents use **by discipline, not enforcement**:

1. `aapp commit "<message>"` commits the staged code in the current worktree, adds the attribution
   trailers the repository's mode requires, and records `sha (branch)` in the active plan's header.
2. The plan file is committed immediately after, alone, so the record travels with the plan and
   hooks can read it.
3. `aapp done` reads the recorded commits, verifies them, and refuses when there are none — never
   falling back to `HEAD`.
4. Agents learn the tool from a plan-template execution invariant, not from a skill; it is an agent
   convenience, not a human workflow.
5. Several agents on several plans in several worktrees at once stay correct.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. `done` stops reading `HEAD`; a plan with no recorded
  commits is refused, not archived with a guessed SHA. Plans already in development when this ships
  record their commits with the recovery path (§5 Q1) before `done`.

### 2.1 Verb Surface (bare tokens, no `--flags`)

| Invocation | Effect |
| :--- | :--- |
| `aapp commit "<message>"` | Commit what is staged; record the new SHA and branch in the active plan |
| `aapp commit amend ["<message>"]` | Amend the last commit; replace its recorded SHA in the header |

`aapp commit` commits only what is already staged, like `git commit`; it never stages for the agent,
so the blast-radius decision stays with the agent and the pre-commit hook. All git hooks run as for a
normal commit — the helper adds no bypass.

### 2.2 Plan Resolution
The plan is the one bound in the **current worktree's** active buffer
(`$(git rev-parse --git-path aapp_active_plan)`), which is per worktree: a linked worktree's buffer is
`.git/worktrees/<name>/aapp_active_plan`. With no buffer, the single `⚡ In Development` plan is used;
with none or several, the verb refuses and names the choices. The plan must be `⚡ In Development`
(status registry, as `done` since #89).

### 2.3 Code Commit & Attribution
The code commit runs in the current worktree. The message is completed per
`git config aapp.aiAttribution`:

| Mode | Helper behaviour |
| :--- | :--- |
| `commit` | Appends `AI-Agent:` / `AI-Vendor:` / `AI-Model:` from the agent's identity (§5 Q4); refuses with the exact fix when identity is missing |
| `notes` | Stages the note as `aapp ai-note` does; no trailers in the message |
| `none` | Message unchanged |

A rejected code commit (any hook) exits non-zero with the hook's output and records nothing.

### 2.4 Recording in the Plan
The template gains one header line, parsed by a new pure function in `lib/aapp-lib.sh`:

```markdown
* **Commits:** `bca7d9a` (develop), `8c0c103` (feat/parser)
```

An empty plan reads `* **Commits:** none`. The branch is recorded because a SHA means little without
it: work may live on an experiment branch or in another worktree. Detached `HEAD`: §5 Q3.

After the code commit the helper rewrites that line and commits the plan file **alone**:
`git -C <plans> commit -- current/<plan>.md`, never the whole index (§2.6). The header is not
design-locked (only §2 and §4 are), so this is allowed while `⚡ In Development`.

**Partial failure is loud.** If the code commit lands but the plan commit fails, the code commit
cannot be undone safely. The helper exits non-zero, prints the recorded line it could not commit and
the one command that repairs it (§5 Q1), and never swallows the failure (#81 pattern).

### 2.4b Base Recorded at `start`
`start` and `freeze-start` record where the plan began, in the same form, on its own header line so
`Commits` stays a pure list:

```markdown
* **Base:** `52c2c01` (develop)
```

- **Which branch:** the `HEAD` of the worktree running `start` — the same worktree whose active
  buffer `start` binds and whose `aapp commit` records into the plan, so base and commits share one
  origin.
- **Work may move branches.** The base only marks where the plan started. Work done on `feat/x` or an
  experiment branch cut from it still descends from the base; each commit records its own branch.
- **Planning worktrees are refused.** `start` from `.plans/`, `.agents/` or `.githooks/` (orphan
  branches) exits 1: *run `start` from a code worktree*. This also stops today's latent bind of the
  active buffer into the plans worktree, where no code is committed.
- **Re-running `start`** on a `⚡` plan keeps the first base; overwriting it would hide earlier work.
- **Detached `HEAD`** records `(detached)`; a base is only a starting point, so no branch is needed.
- The template carries `* **Base:** none` until `start` fills it.

### 2.5 Amend
`aapp commit amend` runs `git commit --amend` (message optional) and, when the amended SHA was
recorded, replaces it in the header and commits the plan. Amending a commit that is not recorded
amends only.

### 2.6 Concurrency: Several Agents, Plans and Worktrees
Verified 2026-09-27 with a linked worktree:

| Mechanism | Today | Consequence |
| :--- | :--- | :--- |
| Active buffer | Per worktree | Each agent's helper records into its own plan |
| `.plans` checkout | **One shared checkout** in the primary worktree; linked worktrees resolve it via `--git-common-dir` | Concurrent helpers share one `plans` index |
| Target overlap | Pair 7 + `start` gate refuse shared Target Files among `⚡` plans | Two agents never commit the same code under different plans |

Two hazards follow from the shared index, and the helper must handle both:
1. **Cross-plan capture.** A whole-index commit would sweep another agent's staged plan into this
   plan's commit. Pathspec-limited commits (§2.4) prevent it. The existing lifecycle verbs commit the
   whole index and share this hazard; aligning them is out of scope here.
2. **`index.lock` contention.** Two simultaneous plan commits collide on Git's lock. The helper fails
   loudly with a retry instruction; it does not wait, retry silently, or `|| true`.

### 2.7 `done` Reads the Record
`done` replaces `rev-parse HEAD` with the header:
- **Empty list** → exit 1, listing candidate commits — `git log --branches ^<base> -- <targets>`,
  every branch's commits after the recorded base that touched a Target File (`parse_plan_target_paths`)
  — and the command that records them.
- **Each SHA** must still be reachable from its recorded branch (`git merge-base --is-ancestor`);
  otherwise exit 1 naming it (amended or rebased away). Squash merges: §5 Q2.
- **Ledger**: the Verification Commit column takes the last recorded SHA; the plan header keeps the
  full list.
- **`pre-done` is dispatched** before anything moves, with `{"plan_id", "plan_file", "commits": [...]}`.
  A non-zero exit vetoes: `done` exits 1 and the plan, ledger and matrix are unchanged. The event is
  catalogued today but never fired; P-39 fires it so a review hook — or a human — checks exactly what
  `done` will archive, and can stop it. P-23 may refine pre-hook timing (watchdog, sequencing) later
  without changing this contract.
- **`on-done`** keeps firing after the archive and also gains `"commits": [...]`.

### 2.8 Discipline, Not Enforcement
- `templates/plan-template.md` gains an execution invariant: *commit implementation through
  `aapp commit` so the plan records its commits; `aapp done` archives only recorded work.* Agents read
  that block before writing code; no skill wraps the verb.
- Forgetting is cheap to repair (§5 Q1). No hook refuses a raw `git commit`.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Failure-first: the declared tests are written and confirmed Red 🔴 before the code they cover.*

### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/aapp_lib_test.sh::test_parse_plan_commits` -> `sha (branch)` pairs parse from the header; `none`, prose and a malformed entry yield nothing
- [ ] `tests/verbs/commit.sh::test_records_sha_and_branch` -> the code commit's SHA and branch appear in the plan header, and the plan is committed
- [ ] `tests/verbs/commit.sh::test_plan_commit_is_pathspec_limited` -> another plan staged in `.plans` is not swept into the commit
- [ ] `tests/verbs/commit.sh::test_refuses_without_active_plan` -> no `⚡` plan: exit 1, no commit
- [ ] `tests/verbs/commit.sh::test_refuses_nothing_staged` -> empty index: exit 1, no commit, header unchanged
- [ ] `tests/verbs/commit.sh::test_rejected_commit_records_nothing` -> a refusing hook: exit non-zero, header unchanged
- [ ] `tests/verbs/commit.sh::test_amend_replaces_recorded_sha` -> `amend` swaps the old SHA for the new one in the header
- [ ] `tests/verbs/commit.sh::test_commit_mode_adds_trailers` -> `commit` attribution: the three trailers present; missing identity refused with the fix
- [ ] `tests/verbs/commit.sh::test_linked_worktree_records_its_own_plan` -> two worktrees bound to two plans each record into their own plan
- [ ] `tests/verbs/done.sh::test_ledger_uses_recorded_commit` -> an unrelated later commit is not recorded; the ledger takes the last recorded SHA
- [ ] `tests/verbs/done.sh::test_refuses_empty_commit_list` -> no recorded commits: exit 1, candidates and the repair command printed, nothing moves
- [ ] `tests/verbs/done.sh::test_refuses_unreachable_commit` -> a recorded SHA amended away: exit 1 naming it
- [ ] `tests/verbs/start.sh::test_records_base_sha_and_branch` -> `start` fills `* **Base:**` with the worktree's `HEAD` and branch
- [ ] `tests/verbs/start.sh::test_refuses_from_planning_worktree` -> `start` run inside `.plans/`: exit 1, no buffer bound, plan unchanged
- [ ] `tests/verbs/start.sh::test_restart_keeps_first_base` -> re-running `start` on a `⚡` plan leaves `Base` unchanged
- [ ] `tests/verbs/freeze-start.sh::test_records_base_sha_and_branch` -> `freeze-start` fills `Base` the same way
- [ ] `tests/verbs/done.sh::test_pre_done_veto_blocks_archive` -> a `pre-done` handler exiting non-zero: `done` exits 1, nothing moves; the payload carries the recorded commits

### Phase 1: Contract & Red Tests
- [ ] Task 1.1: Author `lib/docs/verbs/commit.md` (P-34 shape) and update `lib/docs/verbs/done.md` (recorded commits replace `HEAD`); add the `commit` row to `lib/verbs.tsv`.
- [ ] Task 1.2: Write the Required Tests above; confirm Red 🔴.

### Phase 2: Library & Template
- [ ] Task 2.1: `parse_plan_commits` and the header-line writer in `lib/aapp-lib.sh`.
- [ ] Task 2.2: `* **Base:** none` and `* **Commits:** none` header lines and the execution invariant in `templates/plan-template.md`.

### Phase 3: Verb & `done`
- [ ] Task 3.1: `lib/cmd_commit.sh`: resolution (§2.2), attribution (§2.3), recording and pathspec plan commit (§2.4), `amend` (§2.5), loud partial failure, lock handling (§2.6).
- [ ] Task 3.2: Dispatcher case in `aapp`.
- [ ] Task 3.2b: `cmd_start` / `cmd_freeze_start` record the base (§2.4b), refuse planning worktrees, keep the first base on re-run.
- [ ] Task 3.3: `cmd_done` reads the record (§2.7), dispatches `pre-done` before any mutation (non-zero vetoes), and `on-done` gains `commits`.
- [ ] Task 3.4: Resolved §5 answers (recovery, nudge, squash, detached, identity).
- [ ] Task 3.5: Required Tests Green 🟢: `aapp test verb commit`, `aapp test verb done`, `aapp test aapp_lib`.

### Phase 4: Regression & Docs
- [ ] Task 4.1: `aapp test strict quiet` before the commit.
- [ ] Task 4.2: `ARCHITECTURE.md`, `.agents/CODEMAP.md`, `MANUAL.md`, `CHEATSHEET.md`, `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/cmd_commit.sh` -> The commit helper verb
- [ ] `NEW FILE` -> `lib/docs/verbs/commit.md` -> Behaviour contract for commit
- [ ] `aapp` -> Dispatcher case for commit
- [ ] `lib/verbs.tsv` -> Daily row with contract path
- [ ] `lib/aapp-lib.sh` -> Commits header parser and writer
- [ ] `lib/cmd_plan.sh` -> done reads the recorded commits; start and freeze-start record the base
- [ ] `lib/docs/verbs/done.md` -> Recorded commits replace HEAD
- [ ] `lib/docs/verbs/start.md` -> Base recording and planning-worktree refusal
- [ ] `lib/docs/verbs/freeze-start.md` -> Base recording
- [ ] `templates/plan-template.md` -> Commits header line and execution invariant
- [ ] `templates/aapp-pre-commit` -> Non-blocking reminder, only if §5 Q1 adopts it
- [ ] `tests/pre-commit_test.sh` -> Reminder test, only if §5 Q1 adopts it
- [ ] `ARCHITECTURE.md` -> Plan-bound commit rule
- [ ] `.agents/CODEMAP.md` -> Name the verb's owner module
- [ ] `MANUAL.md` -> Document the verb
- [ ] `CHEATSHEET.md` -> Quick reference row
- [ ] `CHANGELOG.md` -> Record under Added and Fixed

### 🧪 Required Test Files
> Test files that prove this plan's failure cases. Frozen with the blast radius; per-test identifiers are tracked in §3.
- `NEW FILE` -> `tests/verbs/commit.sh`
- `tests/verbs/done.sh`
- `tests/verbs/start.sh`
- `tests/verbs/freeze-start.sh`
- `tests/aapp_lib_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Installed engines; `aapp init` propagates template changes.
- [ ] `templates/skills/*` -> No skill wraps the verb (decision: discipline via the plan template).
- [ ] `lib/plan_states.sh` -> Status registry is consumed, not changed.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 — Repair and reminder.** Refusing `done` on an empty list pushes cleanup onto whoever forgot. Proposed: (a) `aapp commit adopt <sha>…` records existing commits without committing code, and `done`'s refusal prints it with the candidate SHAs; (b) pre-commit prints a one-line *warning* (never a refusal) when a code commit is made during an active plan outside the helper, detected by a marker the helper sets. Adopt both, one, or neither?
* [ ] **Question 2 — Squash merges.** A squash merge replaces the recorded SHAs and the branch may be deleted. Require `done` before merging, accept "recorded branch was merged" as reachable, or record the squash SHA via the repair path?
* [ ] **Question 3 — Detached `HEAD`.** Refuse the commit, or record `(detached)` and let `done` check reachability from any branch?
* [ ] **Question 4 — Agent identity for `commit` mode.** Only the agent knows its name, vendor and model. Source: environment (`AAPP_AGENT_NAME` / `AAPP_AGENT_VENDOR` / `AAPP_AGENT_MODEL`; `ai-note` already reads the first), bare tokens on the verb, or per-worktree git config?

### Dependencies & Sequencing
- **After `P-34`** (done): uses the verb-contract shape, `tests/verbs/`, and the status registry gate (#89).
- **After `P-37`** (done): Target Files for `done`'s candidate list come from `parse_plan_target_paths`.
- **Touches #81's pattern:** the helper's own commits never use `|| true`; the existing lifecycle verbs are not changed here.
- **Related, unplanned:** the double-dash sweep (bare tokens only; `amend` follows it).

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-27:** User decision (RFC C15): `start`/`freeze-start` record `* **Base:**` from the worktree running them; planning worktrees refused; first base kept on re-run; detached recorded as such. `done`'s candidate search uses it. Added `start`/`freeze-start` contracts and suites to the blast radius.
* **2026-09-27:** User decision (RFC C1/C14): `done` fires `pre-done` with the recorded commits before any mutation; a non-zero exit vetoes. Declared `test_pre_done_veto_blocks_archive`.
* **2026-09-27:** Drafted from a design discussion on `done` recording the newest commit. Settled with the user: a CLI helper used by discipline, taught through a plan-template invariant rather than a skill; attribution completed by the helper; `amend` as a bare token; a header list tolerant of one or many commits (one per plan is the user's preference, not a rule); the plan committed right after each code commit so hooks can read it; `done` refuses an empty list. Branch recorded beside each SHA (work may live on other branches or worktrees). Concurrency verified against a linked worktree: per-worktree buffers, one shared `.plans` index — hence pathspec-limited plan commits and loud lock failures.
