# 🗺️ Plan: P-14 AI Attribution Suite, Safe-by-Default Protocol & Historical Scrubber
* **Created:** 2026-09-15 | **Last Refined:** 2026-09-15
* **Target Issue / Milestone:** #66
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED
     The pre-commit hook reads this line. A plan whose Status says BLOCKED grants no
     commit rights at all — its Blast Radius stops admitting files until you clear it. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Engine Rule**: No email addresses in AI attribution in any mode. `Co-authored-by:` is permanently rejected. Attribution is configured via `git config aapp.aiAttribution` (`none` | `commit` | `notes`).
> 4. **Pair 5 Invariant**: Target Files must never declare Section 2 protected files (`.githooks/*`, `.agents/skills/*`, `.claude/settings*`, `.cursor/rules/*`, `.git/config`).
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal

The legacy AI attribution model in AAPP inherited human git pair-programming conventions (`Co-authored-by: <Agent> <email>`). This model introduced severe architectural defects identified by red team review:
1. **GitHub Identity Hijacking**: When public git servers encounter `Co-authored-by: Antigravity <antigravity@google.com>`, GitHub scans its global user database, matches an unrelated user who verified that email (`shimonenator`), and irrevocably attributes commits and repository contributor badges to that individual. Mandating synthetic, no-reply, or `.invalid` emails is also rejected — an organisation running an in-house model may want a real identifier, but human email trailers force GitHub account matching. A dedicated, email-less custom trailer key is the required design.
2. **Configuration Erasure Vulnerability (B2)**: Storing the active attribution mode inside `.agents/AGENTS.md` is broken because `lib/cmd_init.sh:sync_agent_rules()` overwrites the entire protocol block on every `aapp init` or `upgrade`. Configuration must live in `git config aapp.aiAttribution`, following the established `aapp.allowPath` and `aapp.hookTimeout` pattern.
3. **Missing Enforcement Hook (B3)**: `pre-commit` never receives the commit message; git passes commit messages strictly to `commit-msg`. Validating attribution trailers and commit message shape requires a dedicated `templates/aapp-commit-msg` hook and dispatcher.
4. **Scrubber SHA Referencing & Worktree Orphanage (B4)**: Rewriting history with `filter-branch` alters commit SHAs referenced across `.plans/done/000-archive-ledger.md`, `.plans/done/000-issues-archive.md`, `.plans/ISSUES.md`, and `CHANGELOG.md` (14 distinct SHAs across 61 occurrences), and breaks extra worktrees. The rewrite must execute via a disciplined sequence: dismantle worktrees, rehearse on mirror, rewrite, map old→new 40-char SHAs, repair references, and enforce resolution via a new Planning Health check (Pair 6: Recorded SHA Integrity).
5. **Multi-Vendor Benchmarking & Asymmetry (G3)**: Developers need historical auditability to compare how different AI agents perform over time. `ai-commit` (trailers) is the primary durable, public record visible on GitHub and git log; `ai-notes` is an opt-in alternative for pristine commits, subject to transport and visibility limitations.

### Architectural Objectives:
- **Safe-by-Default**: `aapp init` defaults `aapp.aiAttribution` to `none`. Zero unexpected trailers, zero email leaks.
- **Dedicated CLI Switchboard**:
  - `aapp ai-status`: Reports current attribution mode and configuration.
  - `aapp ai-commit`: Activates semantic, email-less trailers (`AI-Agent: <Agent>`, `AI-Vendor: <Vendor>`, `AI-Model: <Model>`).
  - `aapp ai-notes`: Activates structured git-notes attribution with safe push refspecs (`+refs/heads/*:refs/heads/*` and `+refs/notes/*:refs/notes/*`) and `cat_sort_uniq` merge strategy.
  - `aapp ai-off`: Resets `aapp.aiAttribution` to `none`.
- **Commit-Msg Enforcement Engine**: Introduce `templates/aapp-commit-msg` to enforce attribution rules (ignoring `git revert` false positives per G2) and numeric subject length (`aapp.subjectMaxLen`, default 72 chars per G4).
- **Planning Health Pair 6**: Add `check_recorded_sha_integrity` to `lib/planning_health.sh` to ensure all recorded SHAs in archive ledgers and active backlogs resolve against `git cat-file -e <sha>^{commit}`.
- **Historical Scrubbing & Conversion**: Provide `scripts/scrub-attribution.sh` to convert all 110 legacy `Co-authored-by: Antigravity <antigravity@google.com>` trailers into `AI-Agent: Antigravity` + `AI-Vendor: Google`, preserving original timestamps to the exact second, repairing all ledger SHAs, and restoring worktrees cleanly.

---

## 2. Technical Blueprint

### A. Attribution Modes & Git Configuration Schema

Active attribution state is held strictly in Git configuration, **never** in `AGENTS.md`:
- `git config aapp.aiAttribution` -> enum: `none` (default), `commit`, `notes`
- `git config aapp.subjectMaxLen` -> integer: default `72` (max subject line length)

```
                            ┌────────────────────────────────────────┐
                            │    git config aapp.aiAttribution       │
                            └───────────────────┬────────────────────┘
                                                │
         ┌──────────────────────────────────────┼──────────────────────────────────────┐
         │ (default: unset or "none")           │ "commit"                             │ "notes"
         ▼                                      ▼                                      ▼
   [ aapp ai-off ]                     [ aapp ai-commit ]                     [ aapp ai-notes ]
┌──────────────────────────────┐    ┌──────────────────────────────┐    ┌──────────────────────────────┐
│ git config: none             │    │ git config: commit           │    │ git config: notes            │
│ Zero commit trailers         │    │ Semantic RFC 822 trailers:   │    │ Mode: Git Notes              │
│ Zero git notes               │    │ AI-Agent: <Name>             │    │ Push refspecs: heads + notes │
│ Human-only commit identity   │    │ AI-Vendor: <Vendor>          │    │ notes.mergeStrategy:         │
│                              │    │ AI-Model: <Model>            │    │ cat_sort_uniq                │
└──────────────────────────────┘    └──────────────────────────────┘    └──────────────────────────────┘
```

1. **`DISABLED` / `none` (Default)**:
   - Commits contain strictly human author & committer metadata. No trailers or notes added.
   - Verified by `aapp-commit-msg`: blocks legacy `Co-authored-by:` agent emails.

2. **`COMMIT` Mode (`aapp ai-commit`)**:
   - Commits append standardized email-less RFC 822 trailers:
     ```text
     feat(guard): implement external path allowlist

     AI-Agent: Antigravity
     AI-Vendor: Google
     AI-Model: gemini-3.8-flash-high
     ```
   - Eliminates email addresses completely, preventing GitHub user matching and account hijacking.
   - Separate keys (`AI-Agent`, `AI-Vendor`, `AI-Model`) allow direct querying without string splitting:
     ```bash
     git log --format="%h | %(trailers:key=AI-Vendor,valueonly=true) | %(trailers:key=AI-Agent,valueonly=true) | %s"
     ```

3. **`NOTES` Mode (`aapp ai-notes`)**:
   - Keeps commit messages clean and human-only.
   - Attaches structured YAML metadata to `refs/notes/commits`:
     ```yaml
     agent: Antigravity
     vendor: Google
     model: gemini-3.8-flash-high
     ```
   - Configures push refspecs idempotently with `--replace-all` and includes heads so branch pushes remain intact (G1):
     ```bash
     git config --replace-all remote.origin.push "+refs/heads/*:refs/heads/*"
     git config --add remote.origin.push "+refs/notes/*:refs/notes/*"
     git config --replace-all remote.origin.fetch "+refs/heads/*:refs/heads/*"
     git config --add remote.origin.fetch "+refs/notes/*:refs/notes/*"
     git config notes.mergeStrategy cat_sort_uniq
     git config notes.rewriteMode concatenate
     ```

### B. Commit-Msg Enforcement Hook (`templates/aapp-commit-msg`)

Git passes the path to the commit message buffer to `commit-msg` (`$1`).
`templates/aapp-commit-msg` evaluates two check pairs:

1. **Check 1: Subject Length & Shape (G4)**:
   - Reads `git config aapp.subjectMaxLen` (default 72).
   - Reads the first non-comment line. If length > max, refuses commit with actionable advice.
   - Enforces the Commit Conciseness Invariant.
2. **Check 2: Attribution Policy & Revert Safety (G2)**:
   - Reads `git config aapp.aiAttribution` (`none`, `commit`, `notes`).
   - Ignores revert commits (lines matching `^This reverts commit [0-9a-f]+` or quoted block `^>`).
   - Parses the trailer block (final paragraph of message).
   - If `aapp.aiAttribution == commit`: requires valid `AI-Agent:` trailer. Blocks any `Co-authored-by:` carrying synthetic/vendor emails.
   - If `aapp.aiAttribution == none`: verifies no AI attribution trailers are present.

### C. Planning Health Pair 6: Recorded SHA Integrity (`lib/planning_health.sh`)

- Scans `.plans/done/000-archive-ledger.md`, `.plans/done/000-issues-archive.md`, `.plans/ISSUES.md`, and `CHANGELOG.md` for 7–40 character commit hashes.
- For each hash, executes:
  ```bash
  git cat-file -e "${sha}^{commit}" 2>/dev/null
  ```
- Flags any dangling or unresolvable SHAs. Blocks commit / freeze until all references resolve.

### D. Historical Scrubber Runbook (`scripts/scrub-attribution.sh`)

Because rewriting history invalidates existing worktrees and modifies SHAs across the repository, the scrubber follows an airtight, disciplined workflow:

1. **Pre-flight & Backup**:
   - Rehearse execution on a mirror clone (`/tmp/aapp-kit-rehearsal`).
   - Confirm zero uncommitted changes across all worktrees.
   - Record current commit SHAs across `main`, `develop`, `plans`, `agents`, and `githooks`.
2. **Worktree Teardown**:
   - Remove extra worktrees (`git worktree remove .plans`, `.agents`, `.githooks`).
3. **Conversion Rewrite**:
   - Run `git filter-branch --msg-filter` over `--all` replacing:
     ```text
     Co-authored-by: Antigravity <antigravity@google.com>
     ```
     with:
     ```text
     AI-Agent: Antigravity
     AI-Vendor: Google
     ```
   - Retain exact `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.
4. **Ledger Reference Repair**:
   - Read `.git/filter-branch/map/` (old full SHA → new full SHA mapping).
   - In a single post-filter commit across all branches containing ledgers:
     - Replace each old full/short SHA with the new corresponding SHA.
     - Re-abbreviate to standard 7 characters where appropriate.
5. **Verification & Worktree Reconstruction**:
   - Run `planning_health.sh` with Pair 6 to verify 100% SHA resolution.
   - Recreate worktrees (`git worktree add .plans plans`, etc.).
   - Force-push branches with lease: `git push --force-with-lease --all origin`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Planning Health Pair 6 & Test Baseline
- [ ] Task 1.1: Author `check_recorded_sha_integrity()` (Pair 6) in `lib/planning_health.sh`.
- [ ] Task 1.2: Add unit tests for Pair 6 in `tests/planning_health_test.sh` verifying that both valid and dangling SHAs are correctly evaluated.

### Phase 2: Template Specifications & Hook Infrastructure
- [ ] Task 2.1: Update `templates/AGENTS.md` to specify:
  - Configuration source: `git config aapp.aiAttribution` (`none` | `commit` | `notes`).
  - Semantic trailer standard (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`).
  - Numeric Commit Conciseness Invariant (subject <= 72 chars, imperative mood).
  - Explicit asymmetry: trailers are primary; notes are opt-in and local-first.
- [ ] Task 2.2: Create `templates/aapp-commit-msg` implementing subject length validation and attribution policy checks with revert exemption.
- [ ] Task 2.3: Create thin runner `templates/commit-msg` dispatching to `.githooks/aapp-commit-msg "$1"`.
- [ ] Task 2.4: Update `lib/cmd_init.sh` to install `templates/commit-msg` and `templates/aapp-commit-msg` to `.githooks/` and set `aapp.aiAttribution=none` by default.

### Phase 3: CLI Switchboard Implementation
- [ ] Task 3.1: Author `lib/cmd_ai.sh` supporting `ai-status`, `ai-commit`, `ai-notes`, and `ai-off`.
- [ ] Task 3.2: Implement safe, idempotent git-notes refspec management in `ai-notes` (`+refs/heads/*:refs/heads/*` + `+refs/notes/*:refs/notes/*` with `--replace-all` and `notes.mergeStrategy=cat_sort_uniq`).
- [ ] Task 3.3: Register `ai-status`, `ai-commit`, `ai-notes`, and `ai-off` in `./aapp` command dispatcher and help output (`lib/cmd_help.sh`).
- [ ] Task 3.4: Update `lib/cmd_install.sh` to install `lib/cmd_ai.sh` and hook templates.

### Phase 4: Automated Test Suite
- [ ] Task 4.1: Create `tests/ai_attribution_test.sh` testing:
  - Default `none` state from `aapp init`.
  - State switching via `aapp ai-commit`, `aapp ai-notes`, and `aapp ai-off`.
  - Commit message validation in `aapp-commit-msg` (subject length overflow, missing trailer in commit mode, revert bypass).
  - Refspec idempotency during repeated `aapp ai-notes` invocations.
- [ ] Task 4.2: Verify all test suites pass (146+ tests + new attribution & health tests).

### Phase 5: Historical Scrubber Script & Documentation
- [ ] Task 5.1: Author `scripts/scrub-attribution.sh` with `--dry-run`, timestamp preservation, SHA map parsing, and ledger rewriting.
- [ ] Task 5.2: Update `MANUAL.md` and `README.md` documenting the AI attribution suite, benchmarking workflows, and the commit-msg hook.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> Note: In accordance with Pair 5 self-protection, files installed into `.githooks/` are updated exclusively via `lib/cmd_init.sh` from source templates in `templates/`.

- [ ] `aapp` -> Register `ai-commit`, `ai-notes`, `ai-off`, and `ai-status` in root CLI dispatcher.
- [ ] `lib/cmd_help.sh` -> Document AI attribution command family in help text.
- [ ] `NEW FILE` -> `lib/cmd_ai.sh` -> Core attribution switchboard and git config manager.
- [ ] `templates/AGENTS.md` -> Document git config attribution model, semantic trailers, and subject conciseness invariant.
- [ ] `NEW FILE` -> `templates/commit-msg` -> Thin hook dispatcher for commit-msg event.
- [ ] `NEW FILE` -> `templates/aapp-commit-msg` -> Attribution and subject-length enforcement engine.
- [ ] `lib/cmd_init.sh` -> Install commit-msg hooks and initialize safe-by-default git config.
- [ ] `lib/cmd_install.sh` -> Ensure `lib/cmd_ai.sh` and hook templates are packaged during installation.
- [ ] `lib/planning_health.sh` -> Add Pair 6 (Recorded SHA Integrity) validator.
- [ ] `NEW FILE` -> `tests/ai_attribution_test.sh` -> Automated test suite for AI attribution switchboard & hooks.
- [ ] `tests/planning_health_test.sh` -> Add test coverage for Pair 6 SHA integrity verification.
- [ ] `NEW FILE` -> `scripts/scrub-attribution.sh` -> Historical conversion scrubber and ledger SHA repair utility.
- [ ] `README.md` -> Document AI attribution commands and safe-by-default behavior.
- [ ] `MANUAL.md` -> Document multi-vendor benchmarking, git notes caveats, and commit shape rules.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Tool interception write-guard is frozen.
- [ ] `templates/aapp-pre-commit` -> Staged file pre-commit engine is frozen.
- [ ] `lib/plan_resolver.sh` -> Shorthand resolver is stable.
- [ ] `lib/cmd_uninstall.sh` -> Uninstaller is stable.

---

## ❓ 5. Open Questions & Settled Decisions

### Settled Decisions (Do Not Re-Open):
- **Email-less Trailers**: No email addresses in AI attribution in any mode. `Co-authored-by:` is permanently rejected.
- **Dedicated Keys**: Separate keys are adopted: `AI-Agent: <Agent>`, `AI-Vendor: <Vendor>`, `AI-Model: <Model>`.
- **History Scrubbing**: Proceeds by converting legacy `Co-authored-by: Antigravity <antigravity@google.com>` trailers into `AI-Agent: Antigravity` + `AI-Vendor: Google`.
- **Configuration Source**: Mode is stored in `git config aapp.aiAttribution` to prevent erasure by `sync_agent_rules()`.

### Open Questions for Execution:
* [ ] **Question 1:** Should `scripts/scrub-attribution.sh` be executed immediately following test suite verification within the P-14 execution cycle, or rehearsed and executed in an isolated standalone session?

---

## 📦 6. Change Log & Refinement History
* **2026-09-15:** Plan refined following adversarial red-team review:
  - Corrected root dispatcher path to `aapp` (B1).
  - Shifted configuration storage from `AGENTS.md` to `git config aapp.aiAttribution` to prevent `cmd_init` overwrite (B2).
  - Specified `templates/commit-msg` and `templates/aapp-commit-msg` for message-time enforcement (B3).
  - Designed disciplined scrubber sequence with SHA mapping, ledger repair, and Planning Health Pair 6 (B4).
  - Fixed push refspec override by combining heads + notes and set `notes.mergeStrategy=cat_sort_uniq` (G1).
  - Added revert exemption to attribution checker (G2).
  - Documented durable trailers vs local notes asymmetry (G3).
  - Added subject length check (`aapp.subjectMaxLen`) and numeric Commit Conciseness Invariant (G4).
  - Settled on separate trailer keys and history conversion.
* **2026-09-15:** Plan initialized from Issue #66 as a draft in the Incubator.
