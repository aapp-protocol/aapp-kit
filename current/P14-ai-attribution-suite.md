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
> 3. **Attribution Trailer**: Respect the active attribution setting in `AGENTS.md`. If disabled, do NOT add co-author trailers.
> 4. **Pair 5 Invariant**: Target Files must never declare Section 2 protected files (`.githooks/*`, `.agents/skills/*`, `.claude/settings*`, `.cursor/rules/*`, `.git/config`).
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal

The legacy AI attribution model in AAPP inherited human git pair-programming conventions (`Co-authored-by: <Agent> <email>`). This model introduced serious architectural and operational vulnerabilities:
1. **GitHub Identity Hijacking**: When public git servers encounter `Co-authored-by: Antigravity <antigravity@google.com>`, GitHub scans its global user database, finds an unrelated user who verified that email (`shimonenator`), and irrevocably attributes commits and repository contributor badges to that individual.
2. **Missing Opt-In Boundary**: Initializing AAPP enabled attribution by default with synthetic vendor emails, exposing developers to unexpected third-party linkages upon pushing to public remotes.
3. **Multi-Vendor Benchmarking Gaps**: Developers need historical auditability to compare how different AI agents/vendors perform across complex tasks over time, but human email trailers fail to provide structured, machine-queryable metadata.

### Architectural Objectives:
- **Safe-by-Default**: `aapp init` sets AI attribution to completely `DISABLED` out of the box. Zero unexpected trailers, zero email leaks.
- **Ergonomic CLI Switchboard**: Introduce dedicated low-friction commands:
  - `aapp ai-status`: Reports current attribution state (`Disabled`, `Commit Trailers`, or `Git Notes`).
  - `aapp ai-commit`: Activates semantic, unhijackable commit trailers (`AI-Agent: <Vendor>/<Agent>`).
  - `aapp ai-notes`: Activates structured git notes attribution and auto-configures git remote refspecs for seamless push/fetch sync.
  - `aapp ai-off`: Disables attribution entirely.
- **Historical Scrubbing Engine**: Provide an idempotent migration script that rewrites historical commit messages across all branches (`main`, `develop`, `plans`, `agents`, `githooks`), stripping old fragile vendor trailers while **strictly preserving original author and committer timestamps down to the second**.

---

## 2. Technical Blueprint

### A. Attribution Modes & Specification

```
                          ┌────────────────────────┐
                          │   aapp ai switchboard   │
                          └───────────┬────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │ (default)                  │                            │
         ▼                            ▼                            ▼
   [ aapp ai-off ]           [ aapp ai-commit ]           [ aapp ai-notes ]
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ AGENTS.md: DISABLED │    │ AGENTS.md: ENABLED  │    │ AGENTS.md: ENABLED  │
│ Zero commit trailers│    │ Semantic Trailers:  │    │ Mode: Git Notes     │
│ Zero git notes      │    │ AI-Agent: Vendor/Id │    │ git notes push/pull │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

1. **`DISABLED` (Default)**:
   - Commits contain strictly human author & committer metadata. No trailers or notes added.

2. **`COMMIT` Mode (`aapp ai-commit`)**:
   - Commits append standardized RFC 822 trailers:
     ```text
     feat(guard): implement external path allowlist

     AI-Agent: Google/Antigravity
     AI-Model: gemini-3.8-flash-high
     ```
   - Eliminates email addresses completely, preventing GitHub user matching.
   - Machine-queryable via native Git:
     ```bash
     git log --format="%h | %(trailers:key=AI-Agent,valueonly=true) | %s"
     ```

3. **`NOTES` Mode (`aapp ai-notes`)**:
   - Keeps commit messages clean and human-only.
   - Attaches structured YAML metadata to `refs/notes/commits`:
     ```yaml
     agent: Antigravity
     vendor: Google
     model: gemini-3.8-flash-high
     ```
   - Automatically executes git configuration to resolve the git notes transport limitation:
     ```bash
     git config --add remote.origin.push "refs/notes/*:refs/notes/*"
     git config --add remote.origin.fetch "refs/notes/*:refs/notes/*"
     git config notes.rewriteMode concatenate
     ```

### B. CLI Engine (`lib/cmd_ai.sh`)

- Implements dispatcher for `aapp ai-commit`, `aapp ai-notes`, `aapp ai-off`, and `aapp ai-status`.
- Directly inspects and rewrites the `### ✍️ Agent Attribution` block in `.agents/AGENTS.md` (and propagates to worktrees).
- Validates repository state before applying git config.

### C. Historical Scrubber (`scripts/scrub-attribution.sh`)

- Operates across all refs (`refs/heads/*`, `refs/worktrees/*`).
- Uses `git filter-branch` or a fast python/bash plumbing pipeline:
  - Parses each commit message.
  - Strips `Co-authored-by: Antigravity <antigravity@google.com>` and similar unverified vendor trailers.
  - Leaves everything else untouched.
  - **Invariant**: Strictly retains `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` from the original commit objects.
- Provides a `--dry-run` flag showing before/after diffs of commit messages prior to rewriting refs.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Templates & Safe-by-Default Protocol
- [ ] Task 1.1: Update `templates/AGENTS.md` to set `Agent Attribution: DISABLED` by default.
- [ ] Task 1.2: Redesign the attribution specification in `templates/AGENTS.md`: define `AI-Agent:` semantic trailer format and Git Notes protocol, replacing the legacy email table.
- [ ] Task 1.3: Update `lib/cmd_init.sh` to ensure initialization stamps attribution as disabled.

### Phase 2: CLI Switchboard Implementation
- [ ] Task 2.1: Author `lib/cmd_ai.sh` supporting `ai-commit`, `ai-notes`, `ai-off`, and `ai-status`.
- [ ] Task 2.2: Register `ai-commit`, `ai-notes`, `ai-off`, and `ai-status` in `bin/aapp` command dispatcher and help text.
- [ ] Task 2.3: Implement git-notes remote sync configuration (`remote.origin.push` / `remote.origin.fetch` / `notes.rewriteMode`) within `ai-notes`.

### Phase 3: Automated Test Suite
- [ ] Task 3.1: Create `tests/ai_attribution_test.sh` covering state transitions between `off`, `commit`, and `notes`.
- [ ] Task 3.2: Verify `git log` trailer extraction and git-notes creation across test commits.
- [ ] Task 3.3: Verify `aapp init` produces a clean repo with zero attribution trailers.

### Phase 4: Historical Scrubber & Documentation
- [ ] Task 4.1: Author `scripts/scrub-attribution.sh` with timestamp-preserving commit message filtering and `--dry-run` inspection.
- [ ] Task 4.2: Test scrubber on a mock cloned repository to guarantee zero timestamp drift and total removal of `antigravity@google.com`.
- [ ] Task 4.3: Document the AI attribution commands and benchmarking workflows in `MANUAL.md` and `README.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.

- [ ] `bin/aapp` -> Register `ai-commit`, `ai-notes`, `ai-off`, and `ai-status` subcommands.
- [ ] `NEW FILE` -> `lib/cmd_ai.sh` -> Core attribution switchboard logic and git config manager.
- [ ] `templates/AGENTS.md` -> Update attribution specification to safe-by-default with semantic trailers and git notes specs.
- [ ] `lib/cmd_init.sh` -> Ensure safe-by-default initialization without attribution trailers.
- [ ] `NEW FILE` -> `tests/ai_attribution_test.sh` -> Automated test suite for AI attribution switchboard.
- [ ] `NEW FILE` -> `scripts/scrub-attribution.sh` -> Idempotent history scrubber script with timestamp preservation.
- [ ] `README.md` -> Document `aapp ai-commit`, `aapp ai-notes`, and `aapp ai-off`.
- [ ] `MANUAL.md` -> Document multi-vendor benchmarking and AI attribution mechanics.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Guard engine is unchanged by attribution CLI.
- [ ] `templates/aapp-pre-commit` -> Pre-commit enforcement engine is unchanged.
- [ ] `lib/plan_resolver.sh` -> Shorthand resolver is stable.
- [ ] `lib/cmd_install.sh` / `lib/cmd_uninstall.sh` -> Package installation logic is out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** For `ai-commit` trailer mode, should the primary trailer key be `AI-Agent: Vendor/Agent` (single key, e.g. `AI-Agent: Google/Antigravity`) or separate keys (`AI-Vendor: Google` and `AI-Agent: Antigravity`)?
* [ ] **Question 2:** When running the history scrubber on the current repository, should existing commits be stripped of attribution completely (`ai-off` style) or converted to the new `AI-Agent: Google/Antigravity` semantic trailer?

---

## 📦 6. Change Log & Refinement History
* **2026-09-15:** Plan initialized from Issue #66 as a draft in the Incubator.
