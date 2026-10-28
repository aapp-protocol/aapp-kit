# 🗺️ Plan P-119: Perl Plan Lifecycle
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-119
* **Changelog:** Changed: Port plan lifecycle and query commands directly under noun-first 'aapp plan' (lib/AAPP/Runner/Plan/) with reserved words, one module per word, and structured log event telemetry, absorbing P-139
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-119` is the fourteenth member of group `P-111` (*Perl Port Of The Kit*), absorbing `P-139` (*Plan Noun*). It ports the entire Plan Lane (`lib/cmd_plan.sh`, 4,495 lines — the largest file in the repository) and group documentation stamper/applier (`lib/group_docs.sh`, 139 lines) directly into the noun-first CLI command hierarchy under `lib/AAPP/Runner/Plan.pm` and `lib/AAPP/Runner/Plan/<Word>.pm`, supported by core modules `lib/AAPP/Plan.pm` and `lib/AAPP/GroupDocs.pm`.

In bash, every lifecycle transition (`draft -> refine -> tdd -> freeze -> start -> done`) re-runs multi-pass `awk` over `state_matrix.md`, `ISSUES.md`, and every `.plans/current/P*.md` file, and `cmd_plan.sh` embeds the entire worktree (`_wt_*`), squash (`_sq_*`), and lock-based parent branch integration (`_ig_*`) engines. In Perl, `AAPP::GroupDocs`, `AAPP::Plan`, and `AAPP::Runner::Plan::*` mutate the parsed plan AST and `state_matrix.md` rows in memory via `AAPP::State`, run `AAPP::Health` in-process, and commit `.plans` atomically via `AAPP::CommitEngine`.

**Strict Noun-First Clean Break:** All legacy top-level verbs (`aapp draft`, `aapp tdd`, `aapp freeze`, `aapp start`, `aapp freeze-start`, `aapp done`, `aapp active`, `aapp plan-status`, `aapp matrix`) and plan-editing forms of `aapp refine` leave the kit; each command is ported directly as `aapp plan <word>` under `lib/AAPP/Runner/Plan/<Word>.pm` with a single public `run` method.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/GroupDocs.pm`, `lib/AAPP/Plan.pm`, `lib/AAPP/Runner/Plan.pm`, `lib/AAPP/Runner/Plan/*.pm`, `lib/cmd_plan.sh`, `lib/group_docs.sh`, `aapp`) plus switching `t/core/group_docs.t` from bash `source` wrappers to direct `AAPP::GroupDocs` calls per `P-111`'s core-wrapper rule. (`t/core/integrate.t` redesign is owned exclusively by `P-135`).

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§4.5 `plan` lifecycle verbs):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (Epochs E1, E2, E4, E6 lifecycle verbs):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epochs E1, E2, E4, E6, Actions A010–A039, A051–A084):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 The Noun Runner (`lib/AAPP/Runner/Plan.pm`)
- `lib/AAPP/Runner/Plan.pm` (`AAPP::Runner::Plan`): reads one parameter, the word, and calls `AAPP::Runner::Plan::<Word>->run(@rest)` through the delegate step in `AAPP::Runner`; a hyphenated word joins its parts (`freeze-start` → `FreezeStart`).
- Bare `aapp plan [query]`: the planning switchboard, keeping its query. The first parameter is a word when it is one of §2.2 (they are reserved, §2.3); anything else is the query.
- An unknown word is refused, naming every registered word of §2.2.
- `aapp help plan` lists the words; `aapp help plan <word>` prints one word's arguments, `full` its refusals and effects.

### 2.2 The Words & Module Layout (`lib/AAPP/Runner/Plan/<Word>.pm`)
Each word module implements a single public `sub run`:

| Word | Syntax | Module (`lib/AAPP/Runner/Plan/…`) | Purpose |
|---|---|---|---|
| `draft` | `aapp plan draft [slug] [issue <num> \| group [<id>]]` | `Draft.pm` | Scaffolds plan/group/member, registers in `state_matrix.md`, commits `plan(draft):`. |
| `tdd` | `aapp plan tdd <id>` | `Tdd.pm` | Failure-first tests validation (§3 IDs, §4 files) and `plan(tdd):` commit. |
| `freeze` | `aapp plan freeze <id>` | `Freeze.pm` | Locks blast radius, validates §5, moves to Greenlight Zone, commits `plan(freeze):`. |
| `start` | `aapp plan start <id> [worktree <path> [branch <name>]] \| <group> [base <branch>]` | `Start.pm` | Provisions worktree/branch, binds `aapp_active_plan`, sets `⚡ In Development`. |
| `freeze-start` | `aapp plan freeze-start <id> [worktree <path> [branch <name>]]` | `FreezeStart.pm` | Atomic freeze and start combination. |
| `done` | `aapp plan done <id> [integrate … \| no-integrate]` | `Done.pm` | Verifies checklist, squashes, CAS fast-forward merges, archives to `done/`, cleans matrix. |
| `active` | `aapp plan active [<id> \| swap \| clear]` | `Active.pm` | Inspects, sets, swaps, or clears the active plan buffer. |
| `status` | `aapp plan status [<id>]` | `Status.pm` | Detailed plan inspection (formerly top-level `plan-status`). |
| `matrix` | `aapp plan matrix [check]` | `Matrix.pm` | State matrix rendering and integrity check (formerly top-level `matrix`). |
| `commit` | `aapp plan commit <id> "<what changed>"` | `Commit.pm` | Commits plan text edits with `plan(refine): <id> <what changed>` (distinguished from `aapp commit`). |
| `rename` | `aapp plan rename <id> <new-slug>` | `Rename.pm` | Renames plan slug and updates all cross-references in ledgers. |
| `block` | `aapp plan block <id> <num>` | `Block.pm` | Marks plan blocked on issue `#<num>`. |
| `unblock` | `aapp plan unblock <id> <num>` | `Unblock.pm` | Unblocks plan from issue `#<num>`. |
| `closes` | `aapp plan closes add <id> <num>` / `closes remove <id> <num>` | `Closes.pm` | Adds or removes secondary closed issues (`* **Also Closes:**`). |
| `join` | `aapp plan join <id> <group>` | `Join.pm` | Enrolls plan into group's `* **Members:**`. |
| `leave` | `aapp plan leave <id>` | `Leave.pm` | Removes plan from its group. |
| `amend` | `aapp plan amend <request\|approve\|refuse\|decision> <amend-id> …` | `Amend.pm` | Group amendment ledger management. |
| `abort` | `aapp plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]` | `Abort.pm` | Abandons plan, moves to `aborted/`, logs to `000-aborted-ledger.md`. |
| `conflict-check` | `aapp plan conflict-check <id> <id>… [json]` | `ConflictCheck.pm` | Detects pairwise Target Files overlaps across plans. |
| `conflict-free` | `aapp plan conflict-free [<id> \| <group>] [json]` | `ConflictFree.pm` | Computes conflict-free execution waves. |

### 2.3 Reserved Words & Disambiguation
- Every word listed in §2.2 is reserved following `aapp plan`.
- The plan resolver refuses a slug matching any reserved word (`a plan named like a plan word is named by its id: P-<n>`), ensuring `aapp plan status` is never parsed as a plan titled `status`.
- Disambiguation between `aapp plan commit` (plan text commit, prefix `plan(refine):`) and `aapp commit` (workspace code commit) is enforced in command parsing and error messages.

### 2.4 Shared Core Engines in `lib/AAPP/`
- **`AAPP::Plan` (`lib/AAPP/Plan.pm`):**
  - Plan ID allocation & scaffolding via `AAPP::State::allocate_plan_id`.
  - Worktree management (`_wt_*`), squashing (`_sq_*`), CAS headless parent-locked integration (`_ig_*`).
  - Target files conflict calculation.
- **`AAPP::GroupDocs` (`lib/AAPP/GroupDocs.pm`):**
  - Section hashing (`Digest::SHA::sha256_hex`), stamping `<!-- aapp-base: <sha256> -->`, verification on freeze, and section replacement on group completion.

### 2.5 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §4.5, all plan lifecycle actions emit structured telemetry to `.git/aapp.log`:
- `post-draft`, `post-refine`, `post-tdd`, `post-freeze`, `post-start`, `post-done`, `post-active`, `post-abort`, `group.docs`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: GroupDocs & Shared Plan Engine (`AAPP::GroupDocs`, `AAPP::Plan`)
- [ ] Task 1.1: Implement `lib/AAPP/GroupDocs.pm` (`lib/group_docs.sh`) with `group.docs` event telemetry, and switch `t/core/group_docs.t` to direct `AAPP::GroupDocs` calls.
- [ ] Task 1.2: Implement `lib/AAPP/Plan.pm` covering template rendering (`plan-template.md`, `group-template.md`, `amendments-template.md`), `_wt_*` worktree management, `_sq_*` branch squashing, `_ig_*` parent-locked integration, and conflict analysis.

### Phase 2: Noun Runner & Word Modules (`lib/AAPP/Runner/Plan/`)
- [ ] Task 2.1: Implement `lib/AAPP/Runner/Plan.pm` (bare switchboard, word dispatch, reserved-word guard).
- [ ] Task 2.2: Implement read-only words: `Status.pm`, `Matrix.pm`, `ConflictCheck.pm`, `ConflictFree.pm`.
- [ ] Task 2.3: Implement lifecycle words: `Draft.pm`, `Tdd.pm`, `Freeze.pm`, `Start.pm`, `FreezeStart.pm`, `Done.pm`, `Active.pm`, `Abort.pm`.
- [ ] Task 2.4: Implement plan-editing words: `Commit.pm`, `Rename.pm`, `Block.pm`, `Unblock.pm`, `Closes.pm`, `Join.pm`, `Leave.pm`, `Amend.pm`.
- [ ] Task 2.5: Wire `aapp plan` in CLI entrypoint `./aapp`.

### Phase 3: Verification & Clean Break
- [ ] Task 3.1: Run `prove -l t/core/group_docs.t` and syntax check `perl -c` across all new `lib/AAPP/Runner/Plan/*.pm` modules.
- [ ] Task 3.2: Verify `./aapp plan status` and `./aapp plan matrix` report cleanly over current repository state.
- [ ] Task 3.3: Verify `CHANGELOG.md` updates.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/GroupDocs.pm` -> Group `ARCHITECTURE.md` and `CODEMAP.md` base hash stamping, checking, and replacement with `group.docs` telemetry.
- [ ] `NEW FILE` -> `lib/AAPP/Plan.pm` -> Shared plan scaffolding, worktree (`_wt_*`), squash (`_sq_*`), parent-locked integration (`_ig_*`), and conflict analysis engine.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan.pm` -> Noun dispatcher, bare switchboard, and reserved words guard.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Draft.pm` -> `aapp plan draft` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Tdd.pm` -> `aapp plan tdd` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Freeze.pm` -> `aapp plan freeze` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Start.pm` -> `aapp plan start` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/FreezeStart.pm` -> `aapp plan freeze-start` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Done.pm` -> `aapp plan done` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Active.pm` -> `aapp plan active` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Status.pm` -> `aapp plan status` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Matrix.pm` -> `aapp plan matrix` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Commit.pm` -> `aapp plan commit` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Rename.pm` -> `aapp plan rename` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Block.pm` -> `aapp plan block` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Unblock.pm` -> `aapp plan unblock` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Closes.pm` -> `aapp plan closes` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Join.pm` -> `aapp plan join` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Leave.pm` -> `aapp plan leave` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Amend.pm` -> `aapp plan amend` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/Abort.pm` -> `aapp plan abort` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/ConflictCheck.pm` -> `aapp plan conflict-check` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan/ConflictFree.pm` -> `aapp plan conflict-free` word runner.
- [ ] `aapp` -> Dispatch `plan` and plan lifecycle words directly to `AAPP::Runner::Plan`.
- [ ] `lib/cmd_plan.sh` -> Retained for remaining callers until `P-120` or delegated to `AAPP::Plan` until `P-122`.
- [ ] `lib/group_docs.sh` -> Transitional shim delegating to `AAPP::GroupDocs` until `P-122`.
- [ ] `t/core/group_docs.t` -> Switch from bash `source` wrappers to direct `AAPP::GroupDocs` calls.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine and test files in `t/` (except declared target `t/core/group_docs.t`) stay out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` remain out of bounds during code port.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Absorbed P-139 (Plan Noun) into P-119; restructured CLI implementation directly under `lib/AAPP/Runner/Plan.pm` and `lib/AAPP/Runner/Plan/<Word>.pm` with clean-break noun-first syntax.
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`post-*` lifecycle events, `group.docs`), and execution checklist with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_plan.sh` (4,495 lines) and `lib/group_docs.sh` (139 lines) contracts.
