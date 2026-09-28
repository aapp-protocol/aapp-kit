# 🗺️ Plan P-39: Plan Bound Commit Helper
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #81 (with P-40) — also resolves the `done` verification-commit divergence in `lib/docs/verbs/done.md`
* **Plan ID:** P-39
* **Status:** 🔷 Frozen
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

Commits are also composed in five places by hand: `draft`, `freeze`, `start`, `freeze-start` and
`done` each run `git add … || true; git commit … || true` against the whole shared `.plans` index —
capturing other agents' staged files (RFC C4) and hiding every failure (#81). Attribution modes are
redesigned in **P-40** (`none | lax | strict | notes`); this plan builds on them.

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
6. **One commit engine** for every `.plans` commit — `aapp commit` and all lifecycle verbs — with
   standard subjects, path-limited commits, retry, attribution through P-40's layer, and loud failures.
   With P-40, this closes #81.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. `done` stops reading `HEAD`; a plan with no recorded
  commits is refused, not archived with a guessed SHA. Plans already in development when this ships
  record their commits with `aapp commit adopt` (§2.7b) before `done`.

### 2.1 Verb Surface (bare tokens, no `--flags`)

| Invocation | Effect |
| :--- | :--- |
| `aapp commit "<message>"` | Commit what is staged; record the new SHA and branch in the active plan |
| `aapp commit amend ["<message>"]` | Amend the last commit (message kept when omitted); replace its recorded SHA in the header |
| `aapp commit adopt <sha>…` | Repair: record existing commits made outside the helper; no code commit |

`aapp commit` commits only what is already staged, like `git commit`; it never stages for the agent,
so the blast-radius decision stays with the agent and the pre-commit hook. All git hooks run as for a
normal commit — the helper adds no bypass.

### 2.2 Plan Resolution
The plan is the one bound in the **current worktree's** active buffer
(`$(git rev-parse --git-path aapp_active_plan)`), which is per worktree: a linked worktree's buffer is
`.git/worktrees/<name>/aapp_active_plan`. With no buffer, the single `⚡ In Development` plan is used;
with none or several, the verb refuses, names the choices, and prints the fix: `aapp active <id>`. The plan must be `⚡ In Development`
(status registry, as `done` since #89).

### 2.3 Code Commit & Attribution (P-40's layer)
The code commit runs in the current worktree. Attribution is **not** composed here: the helper calls
P-40's `lib/attribution.sh` — `resolve_ai_identity` (parameters → `AAPP_AGENT_*` → per-worktree
config → converted `Co-Authored-By` with a warning; never repository config), `attribution_decorate`
(trailers per mode; `strict` without identity exits 1) and `attribution_note` (`notes` mode; text
without identity exits 1 with stderr, identity alone passes).

The verb exposes P-40's inputs as bare tokens:

```text
aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]
```

| Mode (P-40) | Code commit | Plan commit (`plan(record)`) |
| :--- | :--- | :--- |
| `none` | message as given | standard subject |
| `lax` | trailers when an identity resolved; none otherwise (human) | same rule |
| `strict` | trailers required; missing identity refused in pre-flight | trailers required |
| `notes` | no trailers; note attached when an identity resolved | no note (bookkeeping) |

**Pre-flight, before anything is committed:** in `strict` the identity resolves; the plan is
`⚡ In Development`; no other worktree binds it; the plan file is writable. The common failures
therefore happen with nothing committed. Pre-flight cannot make the two commits atomic — the `.plans`
hooks may still refuse the plan commit after the code commit lands, and a lock free during pre-flight
can be taken a moment later — so the retry (§2.6) and `adopt` (§2.7b) remain the backstop.

A rejected code commit (any hook) exits non-zero with the hook's output and records nothing.

### 2.4 Recording in the Plan
The template gains one header line, parsed by a new pure function in `lib/aapp-lib.sh`:

```markdown
* **Commits:** `bca7d9a` (develop), `8c0c103` (feat/parser)
```

An empty plan reads `* **Commits:** none`. The branch is recorded because a SHA means little without
it: work may live on an experiment branch or in another worktree. A commit made on a detached
`HEAD` is recorded as `` `sha` (detached) ``; `done` then requires some branch to contain it (§2.7).

**The helper owns the plan file.** The agent never stages it: `aapp commit` writes the header line
and commits the file by path. After the code commit the helper rewrites that line and commits the
plan file **alone**:
`git -C <plans> commit -- current/<plan>.md`, never the whole index (§2.6), with the subject
`plan(record): record <short-sha> for P-NN` (`adopt`: `plan(record): adopt <n> commit(s) for P-NN`),
matching the existing `plan(draft|freeze|start|done):` subjects. The header is not
design-locked (only §2 and §4 are), so this is allowed while `⚡ In Development`.

**Partial failure is loud.** If the code commit lands but the plan commit fails, the code commit
cannot be undone safely. The helper exits non-zero, prints the recorded line it could not commit and
the one command that repairs it (`adopt`, §2.7b), and never swallows the failure (#81 pattern).

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
`aapp commit amend` runs `git commit --amend`; with no message it keeps the existing one
(`--no-edit`). Attribution trailers are completed, never duplicated: missing ones are added, present
ones left alone. When the amended SHA was recorded, it is replaced in the header and the plan is
committed. Amending a commit that is not recorded amends only. Amend before pushing: amending a pushed
commit rewrites shared history and leaves the old SHA on the remote.

### 2.6 Concurrency: Several Agents, Plans and Worktrees
Verified 2026-09-27 with a linked worktree:

| Mechanism | Today | Consequence |
| :--- | :--- | :--- |
| Active buffer | Per worktree | Each agent's helper records into its own plan |
| `.plans` checkout | **One shared checkout** in the primary worktree; linked worktrees resolve it via `--git-common-dir` | Concurrent helpers share one `plans` index |
| Target overlap | Pair 7 + `start` gate refuse shared Target Files among `⚡` plans | Two agents never commit the same code under different plans |

**One plan, one worktree.** A plan is bound in at most one worktree's buffer; a second binding is a
defect, not a supported mode. `start`, `freeze-start` and `active <id>` read the other worktrees'
buffers (`git worktree list` → each `aapp_active_plan`) and refuse with exit 1 naming the worktree that
holds the plan. This rules out two helpers rewriting the same plan header at once, so no AAPP lock is
needed.

Two hazards follow from the shared index, and the helper must handle both:
1. **Cross-plan capture.** A whole-index commit would sweep another agent's staged plan into this
   plan's commit. Pathspec-limited commits (§2.4) prevent it. The existing lifecycle verbs commit the
   whole index and share this hazard; aligning them is out of scope here.
2. **`index.lock` contention.** Two simultaneous plan commits collide on Git's lock
   (`.git/worktrees/.plans/index.lock`, held while the `.plans` hooks run). The helper retries on a
   short fixed schedule — about five attempts over a few seconds — printing each wait. When the
   schedule is exhausted it fails loudly, naming the lock file and whether it looks held or stale.
   Retrying is preferred to failing at once: the code commit has already landed, so an immediate
   failure leaves unrecorded work that needs repair.

### 2.7 `done` Reads the Record
`done` replaces `rev-parse HEAD` with the header:
- **Empty list** → exit 1, listing candidate commits — `git log --branches ^<base> -- <targets>`,
  every branch's commits after the recorded base that touched a Target File (`parse_plan_target_paths`)
  — and the command that records them.
- **Each SHA** must still be part of history, checked in order:
  1. its recorded branch still exists → `git merge-base --is-ancestor <sha> <branch>`;
  2. the branch is gone, or the SHA was recorded `(detached)` → some ref must contain it
     (`git for-each-ref --contains <sha> refs/heads refs/remotes`);
  3. no ref contains it → exit 1 naming it (amended or rebased away).
  Object existence alone (`git cat-file -e`) is never enough: an amended-away commit still exists
  until `gc`. The check never depends on the branch `done` runs from.
- **Squash merges:** run `done` on the working branch *before* squash-merging. If the squash already
  happened and the recorded SHAs are gone, record the squash commit with `aapp commit adopt <sha>`
  and run `done` again.
- **Ledger**: the Verification Commit column takes the last recorded SHA; the plan header keeps the
  full list.
- **`pre-done` is dispatched** before anything moves, with `{"plan_id", "plan_file", "commits": [...]}`.
  A non-zero exit vetoes: `done` exits 1 and the plan, ledger and matrix are unchanged. The event is
  catalogued today but never fired; P-39 fires it so a review hook — or a human — checks exactly what
  `done` will archive, and can stop it. P-23 may refine pre-hook timing (watchdog, sequencing) later
  without changing this contract.
- **`on-done`** keeps firing after the archive and also gains `"commits": [...]`.

### 2.7b Repair: `adopt`
`aapp commit adopt <sha>…` records commits that were made with a raw `git commit`:
- each SHA must be a commit contained by some branch (`git for-each-ref --contains`); the recorded
  branch is the current worktree's branch when it contains the SHA, otherwise the first containing branch;
- SHAs already recorded are skipped, not duplicated;
- the plan file is committed by path, as in §2.4, with the same attribution;
- it always prints a **warning**: the adopted commits did not pass through the helper, so their
  attribution trailers were not completed by it.

`done`'s empty-list refusal prints the candidate SHAs as one ready `aapp commit adopt …` line.

### 2.8 Discipline, Not Enforcement
- `templates/plan-template.md` gains an execution invariant that teaches the complete form, so the
  first commit succeeds without pre-exported variables: *commit implementation with
  `aapp commit "<msg>" agent <Agent> vendor <Vendor> model <Model>` (or set `AAPP_AGENT_*`) so the
  plan records its commits; never stage or commit the plan file yourself; `aapp done` archives only
  recorded work.* Agents read that block before writing code; no skill wraps the verb.
- Forgetting is cheap to repair (`adopt`, §2.7b). No hook refuses a raw `git commit`.
- **Reminder, never a refusal.** When a code commit is made in a worktree whose buffer binds a `⚡`
  plan, and the helper did not make it (it exports a marker for its own `git commit`), the pre-commit
  hook prints one line and lets the commit through: *"💡 P-NN is active: record this commit with
  `aapp commit adopt <sha>` (or commit through `aapp commit`)."* Commits inside the planning worktrees
  are never reminded.
- **System rules anchor (`templates/AGENTS.md`, `.agents/AGENTS.md`):** To ensure agent root system
  prompts reinforce the discipline before touching code, `AGENTS.md` adds a concise clause under
  `## 🛡️ Git Commit & Workflow Rule` stating: *When executing an active plan (⚡ In Development),
  agents should use the plan-bound commit helper (`aapp commit`) rather than raw `git commit` to ensure
  trailer compliance and plan ledger integrity.*

### 2.9 One Commit Engine for Every `.plans` Commit (RFC C23, C35, C38)
`lib/commit_engine.sh` (sourced; functions only) holds `plans_commit "<subject>" <path>…`: stage
**exactly** the given paths (needed for new files and moves), commit only them
(`git commit -- <paths>`), attribute through P-40's layer, retry on the index lock (§2.6), and fail
loudly — no `|| true` anywhere on the commit path. `aapp commit`'s `plan(record)` commit and every
lifecycle verb use it:

| Verb | Standard subject | Paths |
| :--- | :--- | :--- |
| `aapp commit` / `adopt` | `plan(record): record <sha> for P-NN` / `plan(record): adopt <n> commit(s) for P-NN` | the plan |
| `draft` | `plan(draft): scaffold P-NN <slug>` | new plan, `state_matrix.md` |
| `freeze` | `plan(freeze): lock blast radius and greenlight P-NN` | plan, `state_matrix.md` |
| `start` | `plan(start): activate P-NN into development` | plan, `state_matrix.md` |
| `freeze-start` | `plan(start): freeze and activate P-NN into development` | plan, `state_matrix.md` |
| `done` | `plan(done): archive P-NN to done/ and update state matrix` | old and new plan path, ledger, `state_matrix.md` |

Lifecycle commits carry no authorship to trace (C35): in `none`/`lax`/`notes` they need no identity;
in `strict` the agent's environment supplies it and the hook enforces it like any commit — no
exemption (C26). A human running `aapp freeze` in a terminal commits normally in `lax`.

A lifecycle verb whose commit fails now exits non-zero with the hook's or Git's output; the file
changes it made stay in place for the user to inspect.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Failure-first: the declared tests are written and confirmed Red 🔴 before the code they cover.*

### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/aapp_lib_test.sh::test_parse_plan_commits` -> `sha (branch)` and `sha (detached)` entries parse from a comma-separated header line; `none`, prose, a missing branch and an unbackticked SHA yield nothing
- [ ] `tests/verbs/commit.sh::test_records_sha_and_branch` -> the code commit's SHA and branch appear in the plan header, and the plan is committed
- [ ] `tests/verbs/commit.sh::test_plan_commit_is_pathspec_limited` -> another plan staged in `.plans` is not swept into the commit
- [ ] `tests/verbs/commit.sh::test_refuses_without_active_plan` -> no `⚡` plan: exit 1, no commit; with several `⚡` plans the refusal prints `aapp active <id>`
- [ ] `tests/verbs/commit.sh::test_preflight_fails_before_code_commit` -> missing identity in `strict` mode: exit 1 and the code branch has no new commit
- [ ] `tests/verbs/commit.sh::test_detached_head_recorded` -> a commit on a detached `HEAD` is recorded as `(detached)`
- [ ] `tests/verbs/commit.sh::test_refuses_nothing_staged` -> empty index: exit 1, no commit, header unchanged
- [ ] `tests/verbs/commit.sh::test_rejected_commit_records_nothing` -> a refusing hook: exit non-zero, header unchanged
- [ ] `tests/verbs/commit.sh::test_amend_replaces_recorded_sha` -> `amend` swaps the old SHA for the new one in the header; with no message the message is kept and trailers are not duplicated
- [ ] `tests/verbs/commit.sh::test_strict_attributes_both_commits` -> `strict`: trailers on the code *and* the plan commit; missing identity refused in pre-flight with nothing committed
- [ ] `tests/verbs/commit.sh::test_lax_human_commit_needs_no_identity` -> `lax`, no identity: both commits land without trailers
- [ ] `tests/verbs/commit.sh::test_note_token_attached_in_notes_mode` -> `notes`: `note "<text>"` with an identity lands as a git note on the code commit
- [ ] `tests/verbs/commit.sh::test_linked_worktree_records_its_own_plan` -> two worktrees bound to two plans each record into their own plan
- [ ] `tests/verbs/commit.sh::test_adopt_records_existing_commit` -> a raw commit is adopted with its branch, the plan is committed, and a warning is printed
- [ ] `tests/verbs/commit.sh::test_adopt_refuses_unknown_sha` -> an unknown or branchless SHA: exit 1, header unchanged
- [ ] `tests/verbs/commit.sh::test_adopt_skips_recorded_sha` -> adopting an already-recorded SHA leaves one entry
- [ ] `tests/pre-commit_test.sh::test_reminder_outside_helper_is_warning_only` -> a raw code commit with an active plan prints the reminder and succeeds; a helper commit prints nothing
- [ ] `tests/verbs/done.sh::test_ledger_uses_recorded_commit` -> an unrelated later commit is not recorded; the ledger takes the last recorded SHA
- [ ] `tests/verbs/done.sh::test_refuses_empty_commit_list` -> no recorded commits: exit 1, candidates and the repair command printed, nothing moves
- [ ] `tests/verbs/done.sh::test_refuses_unreachable_commit` -> a recorded SHA amended away: exit 1 naming it, although the object still exists
- [ ] `tests/verbs/done.sh::test_accepts_commit_on_deleted_branch` -> recorded branch deleted, SHA contained by another branch: accepted
- [ ] `tests/verbs/done.sh::test_detached_commit_needs_a_branch` -> a `(detached)` SHA no branch contains: exit 1; once a branch contains it: accepted
- [ ] `tests/verbs/start.sh::test_records_base_sha_and_branch` -> `start` fills `* **Base:**` with the worktree's `HEAD` and branch
- [ ] `tests/verbs/start.sh::test_refuses_from_planning_worktree` -> `start` run inside `.plans/`: exit 1, no buffer bound, plan unchanged
- [ ] `tests/verbs/start.sh::test_restart_keeps_first_base` -> re-running `start` on a `⚡` plan leaves `Base` unchanged
- [ ] `tests/verbs/freeze-start.sh::test_records_base_sha_and_branch` -> `freeze-start` fills `Base` the same way
- [ ] `tests/verbs/active.sh::test_refuses_plan_bound_in_other_worktree` -> binding a plan already bound in a linked worktree: exit 1 naming it, buffer unchanged
- [ ] `tests/verbs/start.sh::test_refuses_plan_bound_in_other_worktree` -> `start` on a plan bound elsewhere: exit 1, plan and buffer unchanged
- [ ] `tests/verbs/draft.sh::test_commit_takes_only_its_paths` -> another file staged in `.plans` is not swept into the draft commit (C4)
- [ ] `tests/verbs/freeze.sh::test_commit_failure_is_loud` -> a refusing `.plans` hook: `freeze` exits non-zero and says why (#81)
- [ ] `tests/verbs/freeze.sh::test_human_freeze_commits_in_lax` -> `lax`, no identity: the freeze commit lands (#81)
- [ ] `tests/verbs/done.sh::test_commit_takes_only_its_paths` -> the archive commit contains only the move, ledger and matrix
- [ ] `tests/verbs/done.sh::test_pre_done_veto_blocks_archive` -> a `pre-done` handler exiting non-zero: `done` exits 1, nothing moves; the payload carries the recorded commits

### Phase 1: Contract & Red Tests
- [ ] Task 1.1: Author `lib/docs/verbs/commit.md` (P-34 shape) and update `lib/docs/verbs/done.md` (recorded commits replace `HEAD`); add the `commit` row to `lib/verbs.tsv`.
- [ ] Task 1.2: Write the Required Tests above; confirm Red 🔴.

### Phase 2: Library & Template
- [ ] Task 2.1: `parse_plan_commits` and the header-line writer in `lib/aapp-lib.sh`.
- [ ] Task 2.2: `* **Base:** none` and `* **Commits:** none` header lines and the execution invariant in `templates/plan-template.md`; system rules anchor in `templates/AGENTS.md` and `.agents/AGENTS.md`.

### Phase 3: Verb & `done`
- [ ] Task 3.1: `lib/cmd_commit.sh`: resolution (§2.2), attribution (§2.3), recording and pathspec plan commit (§2.4), `amend` (§2.5), loud partial failure, lock handling (§2.6).
- [ ] Task 3.2: Dispatcher case in `aapp`.
- [ ] Task 3.2b: `cmd_start` / `cmd_freeze_start` record the base (§2.4b), refuse planning worktrees, keep the first base on re-run.
- [ ] Task 3.2c: One plan, one worktree (§2.6): `start`, `freeze-start` and `active <id>` refuse a plan bound in another worktree's buffer.
- [ ] Task 3.3: `cmd_done` reads the record (§2.7), dispatches `pre-done` before any mutation (non-zero vetoes), and `on-done` gains `commits`.
- [ ] Task 3.3b: `lib/commit_engine.sh` `plans_commit` (§2.9); `aapp commit` uses it.
- [ ] Task 3.4: `adopt` (§2.7b) and the warning-only pre-commit reminder (§2.8); remaining §5 answers (squash, detached).
- [ ] Task 3.4b: Migrate `draft`, `freeze`, `start`, `freeze-start`, `done` to `plans_commit` with standard subjects; remove every `|| true` on their commit path (§2.9).
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
- [ ] `NEW FILE` -> `lib/commit_engine.sh` -> plans_commit: path-limited, attributed, retried, loud
- [ ] `NEW FILE` -> `lib/docs/verbs/commit.md` -> Behaviour contract for commit
- [ ] `aapp` -> Dispatcher case for commit
- [ ] `lib/verbs.tsv` -> Daily row with contract path
- [ ] `lib/aapp-lib.sh` -> Commits header parser and writer
- [ ] `lib/cmd_plan.sh` -> done reads the recorded commits; start and freeze-start record the base
- [ ] `lib/docs/verbs/done.md` -> Recorded commits replace HEAD
- [ ] `lib/docs/verbs/start.md` -> Base recording and planning-worktree refusal
- [ ] `lib/docs/verbs/freeze-start.md` -> Base recording
- [ ] `lib/docs/verbs/active.md` -> One plan, one worktree refusal
- [ ] `lib/docs/verbs/draft.md` -> Standard commit via plans_commit; #81 divergence resolved
- [ ] `lib/docs/verbs/freeze.md` -> Standard commit via plans_commit; #81 divergence resolved
- [ ] `templates/plan-template.md` -> Commits header line and execution invariant
- [ ] `templates/AGENTS.md` -> Rule anchor for plan-bound commit helper
- [ ] `.agents/AGENTS.md` -> Workspace rule anchor for plan-bound commit helper
- [ ] `templates/aapp-pre-commit` -> Warning-only reminder for commits made outside the helper
- [ ] `tests/pre-commit_test.sh` -> Reminder test
- [ ] `ARCHITECTURE.md` -> Plan-bound commit rule
- [ ] `.agents/CODEMAP.md` -> Name the verb's owner module
- [ ] `MANUAL.md` -> Document the verb
- [ ] `CHEATSHEET.md` -> Quick reference row
- [ ] `CHANGELOG.md` -> Record under Added and Fixed
- [ ] `tests/install_test.sh` -> Test 60 records commit before aapp done
- [ ] `tests/verbs/tdd.sh` -> Test 12 adopts commit before aapp done

### 🧪 Required Test Files
> Test files that prove this plan's failure cases. Frozen with the blast radius; per-test identifiers are tracked in §3.
- `NEW FILE` -> `tests/verbs/commit.sh`
- `tests/verbs/done.sh`
- `tests/verbs/start.sh`
- `tests/verbs/freeze-start.sh`
- `tests/verbs/active.sh`
- `tests/verbs/draft.sh`
- `tests/verbs/freeze.sh`
- `tests/aapp_lib_test.sh`
- `tests/pre-commit_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Installed engines; `aapp init` propagates template changes.
- [ ] `templates/skills/*` -> No skill wraps the verb (decision: discipline via the plan template).
- [ ] `lib/plan_states.sh` -> Status registry is consumed, not changed.
- [ ] `lib/attribution.sh` -> P-40's attribution layer is called, not changed.
- [ ] `templates/aapp-commit-msg` -> Attribution enforcement belongs to P-40.
- [ ] `lib/cmd_ai.sh` -> Setup verbs belong to P-40.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Repair and reminder.** RESOLVED (user): both — `aapp commit adopt` (§2.7b, itself warning) and the warning-only pre-commit reminder (§2.8). Original question: Refusing `done` on an empty list pushes cleanup onto whoever forgot. Proposed: (a) `aapp commit adopt <sha>…` records existing commits without committing code, and `done`'s refusal prints it with the candidate SHAs; (b) pre-commit prints a one-line *warning* (never a refusal) when a code commit is made during an active plan outside the helper, detected by a marker the helper sets. Adopt both, one, or neither?
* [x] **Question 2 — Squash merges.** RESOLVED (user, RFC recommendation): `done` before squash-merging; afterwards, `aapp commit adopt <squash-sha>` (§2.7). Original question: A squash merge replaces the recorded SHAs and the branch may be deleted. Require `done` before merging, accept "recorded branch was merged" as reachable, or record the squash SHA via the repair path?
* [x] **Question 3 — Detached `HEAD`.** RESOLVED (user, RFC recommendation): record `(detached)`; `done` requires some ref to contain it (§2.4, §2.7). Original question: Refuse the commit, or record `(detached)` and let `done` check reachability from any branch?
* [x] **Question 4 — Agent identity for `commit` mode.** RESOLVED (user, RFC): parameters, then environment, then per-worktree config (with caution); a vendor `Co-Authored-By` with email is converted with a warning; plain repository config never. Implemented in P-40 (`resolve_ai_identity`); this plan passes the tokens (§2.3). Original question: Only the agent knows its name, vendor and model. Source: environment (`AAPP_AGENT_NAME` / `AAPP_AGENT_VENDOR` / `AAPP_AGENT_MODEL`; `ai-note` already reads the first), bare tokens on the verb, or per-worktree git config?

### Dependencies & Sequencing
- **After `P-40`** (user decision, RFC C28): attribution modes and `lib/attribution.sh` exist first; this plan calls them.
- **After `P-35`**: P-35 is ⚡ In Development on `lib/cmd_plan.sh`, a target here (Pair 7).
- **Closes #81 with P-40**: P-40 lets human and lifecycle commits through in `lax`; this plan attributes lifecycle commits in `strict` and removes `|| true`. At `done`, #81's archive entry records it as superseded by P-40 + P-39; the issue row itself is not edited.
- **After `P-34`** (done): uses the verb-contract shape, `tests/verbs/`, and the status registry gate (#89).
- **After `P-37`** (done): Target Files for `done`'s candidate list come from `parse_plan_target_paths`.
- **Closes RFC C4**: every `.plans` commit is path-limited through `plans_commit`.
- **Related, unplanned:** the double-dash sweep (bare tokens only; `amend` follows it).

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-28:** Plan activated into ⚡ In Development via start.
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-09-28:** Realigned after the RFC split (C28: P-40 first). Attribution delegated to P-40's `lib/attribution.sh` (identity, decoration, notes); the verb passes `agent … vendor … model …` and `note "<text>"` tokens. New §2.9: one commit engine (`plans_commit`) for `aapp commit` and all five lifecycle verbs, standard subjects, path-limited, no `|| true` — closes C4 and, with P-40, #81. Identity tests moved to P-40; eight tests added or replaced. Depends on P-40 and P-35.
* **2026-09-27:** User decision: anchor the plan-bound commit discipline with a rule in `templates/AGENTS.md` and `.agents/AGENTS.md`, pairing root system prompt guidance with the plan-template execution invariant. Added both files to Target Files and Task 2.2.
* **2026-09-27:** User decisions (Q2, Q3) take the RFC recommendations. Refinements from RFC review: pre-flight before the code commit (A9/C20), `plan(record):` subjects (A11/C22), full command form in the invariant (A8/C19), `amend` keeps the message without duplicating trailers (A10/C21) and is for unpushed commits (C5), refusal prints `aapp active <id>` (C6), three-step reachability with no reliance on object existence (C8), stricter commit-line parsing (C10). Seven tests added or sharpened.
* **2026-09-27:** User decision (Q1): `aapp commit adopt <sha>…` as the repair, warning on every use, printed ready-made by `done`'s refusal; plus a warning-only pre-commit reminder for commits made outside the helper. Reminder targets kept (RFC C7).
* **2026-09-27:** User decision (Q4): identity from parameters, environment, then per-worktree config; vendor `Co-Authored-By` converted with a warning; never plain repository config. Plan commits carry the trailers too (RFC C2).
* **2026-09-27:** User decision (RFC C16): one plan, one worktree — a second binding is a defect, refused by `start`/`freeze-start`/`active`; no AAPP lock. §2.4 states that `aapp commit` owns the plan file and the agent never stages it.
* **2026-09-27:** User decision (RFC A4): bounded, printed retry on the `.plans` index lock replaces "fail at once".
* **2026-09-27:** User decision (RFC C15): `start`/`freeze-start` record `* **Base:**` from the worktree running them; planning worktrees refused; first base kept on re-run; detached recorded as such. `done`'s candidate search uses it. Added `start`/`freeze-start` contracts and suites to the blast radius.
* **2026-09-27:** User decision (RFC C1/C14): `done` fires `pre-done` with the recorded commits before any mutation; a non-zero exit vetoes. Declared `test_pre_done_veto_blocks_archive`.
* **2026-09-27:** Drafted from a design discussion on `done` recording the newest commit. Settled with the user: a CLI helper used by discipline, taught through a plan-template invariant rather than a skill; attribution completed by the helper; `amend` as a bare token; a header list tolerant of one or many commits (one per plan is the user's preference, not a rule); the plan committed right after each code commit so hooks can read it; `done` refuses an empty list. Branch recorded beside each SHA (work may live on other branches or worktrees). Concurrency verified against a linked worktree: per-worktree buffers, one shared `.plans` index — hence pathspec-limited plan commits and loud lock failures.
