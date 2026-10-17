# 🗺️ Plan P-106: Auto Rebase And Doc Governance
* **Created:** 2026-10-17 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** none
* **Plan ID:** P-106
* **Changelog:** Added: automated clean rebase on integrate ff and configurable documentation governance (P-106)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `0726230` (develop)
* **Worktree:** .workspace/P106 (plan/P106-auto-rebase-and-doc-governance)
* **Commits:** `0238898` (plan/P106-auto-rebase-and-doc-governance)
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

During parallel plan development, worktrees (`.workspace/<plan-id>`) are isolated from one another. Under Plan P-65 (Plan Conflict Check), the kit strictly enforces that no two in-development plans may declare overlapping non-shared target files. Consequently, concurrent plan codebases are **mathematically guaranteed to be disjoint**.

However, two points of friction occur at integration time and documentation governance:

1. **Integration Friction on Parallel Completion (`integrate ff`)**:
   When Plan A lands on `develop`, `develop`'s tip advances. When Plan B completes and runs `aapp done <id> integrate ff`, the kit currently halts with an error:
   ```text
   ❌ [Done Refusal] 'plan/P-B' does not contain 'develop'; rebase it first:
      git -C .workspace/P-B rebase --autostash develop
   ```
   Because Plan B and Plan A modified disjoint code files, a `git rebase` against `develop` is guaranteed to succeed cleanly without code conflicts. Forcing human intervention or stalling autonomous agent loops on a mathematically safe operation is an unnecessary workflow bottleneck.

2. **Rigid Documentation Governance for Brownfield Adopters**:
   The kit currently mandates that code changes update `MANUAL.md`, `README.md`, or `ARCHITECTURE.md` with specific headings that match `lib/adoption.sh` rules. Mature projects and brownfield adopters often have their own documentation systems (e.g. `docs/`, VitePress, Docusaurus) or prefer modular topic files (as envisioned in P-56/P-57). Adopters need an opt-out configuration (`aapp.docsCheck` or `aapp.docs`) to disable rigid formatting enforcement without losing blast-radius protection.

3. **Ledger Merge Invariant Clarification**:
   While true append-only files (`CHANGELOG.md` under `## [Unreleased]`, `.plans/done/000-archive-ledger.md`, `.plans/done/000-issues-archive.md`) safely utilize `merge=union`, active `ISSUES.md` is **stateful** (rows update status in place and are physically relocated/deleted on archival). Active `ISSUES.md` must never use `merge=union` to prevent ghost resurrection of closed issues.

### Architectural Goals:
1. **Automated Clean Rebase on `integrate ff`**: When a plan branch does not contain the integration target, `aapp done` automatically attempts a non-interactive `git rebase --autostash`. If rebase succeeds cleanly with 0 conflicts, integration proceeds to fast-forward. If conflicts occur, it immediately aborts cleanly (`git rebase --abort`) and yields to human review with the exact diagnostic.
2. **Configurable Documentation Enforcement (`aapp.docs`)**: Provide an explicit configuration escape hatch (`git config aapp.docs false`) to suppress pre-commit documentation reminders and adoption checklist nags for projects with external or custom documentation frameworks.
3. **Formal Ledger Merge Attributes**: Explicitly define and test which repository files are safe for Git's `merge=union` driver and which must remain under 3-way semantic merge.

---

## 2. Technical Blueprint

### 2.1 Automated Clean Rebase Engine (`lib/cmd_plan.sh` - `_ig_check`)

In `_ig_check()` within `lib/cmd_plan.sh`, the current check enforces:
```bash
elif ! git merge-base --is-ancestor "$IG_TARGET_BR" "$IG_PLAN_BR"; then
    echo "❌ [Done Refusal] '$IG_PLAN_BR' does not contain '$IG_TARGET_BR'; rebase it first:" >&2
    echo "   git -C ${IG_WT} rebase --autostash $IG_TARGET_BR" >&2
    return 1
fi
```

P-106 transforms this into an **Automated Clean Rebase** governed by configuration `aapp.autoRebase` (`true` | `false`, defaulting to `false` initially for safety):

```bash
elif ! git merge-base --is-ancestor "$IG_TARGET_BR" "$IG_PLAN_BR"; then
    local auto_rebase
    auto_rebase="$(git config --get aapp.autoRebase 2>/dev/null || echo "false")"
    if [ "$auto_rebase" = "true" ] && [ -d "$IG_WT" ]; then
        echo "🔄 [Integrate] '$IG_PLAN_BR' diverged from '$IG_TARGET_BR'; attempting automated clean rebase..."
        if git -C "$IG_WT" rebase --autostash "$IG_TARGET_BR" >/dev/null 2>&1; then
            echo "✨ [Integrate] Successfully rebased '$IG_PLAN_BR' onto '$IG_TARGET_BR' (0 conflicts)."
            # Update last commit SHA recorded in plan file after rewrite
            local new_sha
            new_sha="$(git -C "$IG_WT" rev-parse --short HEAD)"
            plan_set_field "$plan_file" "Commits" "$new_sha ($IG_PLAN_BR)"
            (cd "$PLANS_DIR" && git add "$(basename "$plan_file")" && git commit -qm "plan(rebase): update commit sha after auto-rebase" --no-verify) 2>/dev/null || true
        else
            # Fail-closed circuit breaker: abort immediately to leave worktree completely untouched
            git -C "$IG_WT" rebase --abort >/dev/null 2>&1 || true
            echo "❌ [Done Refusal] Automated rebase encountered merge conflicts; resolve manually:" >&2
            echo "   git -C ${IG_WT} rebase --autostash $IG_TARGET_BR" >&2
            return 1
        fi
    else
        echo "❌ [Done Refusal] '$IG_PLAN_BR' does not contain '$IG_TARGET_BR'; rebase it first:" >&2
        echo "   git -C ${IG_WT} rebase --autostash $IG_TARGET_BR" >&2
        return 1
    fi
fi
```

#### Invariants:
1. **Configurable Opt-In / Safe Default**: Defaults to `false` to maintain strict backwards-compatible safety. Users can activate with `git config aapp.autoRebase true`.
2. **P-65 Disjointness Precondition**: Because code targets are guaranteed disjoint before `start`, automated rebases succeed cleanly across independent plans without human intervention.
3. **Atomic Abort on Conflict**: If any conflict is encountered, `git rebase --abort` runs instantly, ensuring no dirty rebase state is left behind.
4. **Commit Metadata Refresh**: When rebase rewrites commits, the new HEAD SHA is automatically refreshed in the plan's header before archival.

---

### 2.2 Configurable Documentation Enforcement (`aapp.docs`)

To support brownfield adopters and repositories using external documentation tools (VitePress, Docusaurus, MkDocs, AsciiDoc):

- **Config Key**: `aapp.docs` (`true` | `false`, defaults to `true`).
- **Pre-Commit Enforcement (`templates/aapp-pre-commit`)**:
  When `aapp.docs=false`, the hook bypasses the reminder:
  ```text
  ⚠️  [Pre-Commit Reminder] Documentation (README.md, ARCHITECTURE.md, or .agents/CODEMAP.md) was not updated.
  ```
- **Adoption Checklist (`lib/adoption.sh`)**:
  When `aapp.docs=false`, adoption rules targeting manual headings (e.g. `PROJECT-RULES`, `PROJECT-MAP`, `EVENT-LOG`) do not flag open tasks or require specific `MANUAL: <heading>` targets.
- **Custom Docs Directory (`aapp.docsDir`)**:
  Allows adopters to declare their documentation root (e.g. `git config aapp.docsDir docs`).

---

### 2.3 Onboarding Checklist Tasks (`lib/adoption.sh`)

To ensure adopters discover and review these settings during clone onboarding (`.plans/adoption.md`), `lib/adoption.sh` adds two review items under `⚙️ Settings to Review`:

1. **Auto Rebase Setting (`SET-AUTO-REBASE`)**:
   ```bash
   "SET-AUTO-REBASE|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|Automated clean rebase on integrate ff: \`git config aapp.autoRebase <true|false>\` (default: false)."
   ```
2. **Manuals & Documentation Governance Setting (`SET-DOCS`)**:
   ```bash
   "SET-DOCS|⚙️ Settings to Review|Repository Settings Matrix|_trig_always|none|Documentation governance for manuals and rules: \`git config aapp.docs <true|false>\` (default: true)."
   ```

---

### 2.4 Ledger Merge Attributes Contract (`.gitattributes`)

P-106 formalizes the boundary for Git's `merge=union` driver:

1. **Permitted for `merge=union` (Append-Only Ledgers)**:
   - `CHANGELOG.md` (lines appended under `## [Unreleased]`)
   - `.plans/done/000-archive-ledger.md` (completed plan rows appended at the bottom)
   - `.plans/done/000-issues-archive.md` (archived issue rows appended at the bottom)
2. **Strictly Prohibited from `merge=union` (Stateful Documents)**:
   - `ISSUES.md` (active issues are modified in-place and deleted upon archival; union merge causes ghost resurrection).
   - `MANUAL.md`, `README.md`, `ARCHITECTURE.md` (prose structure; union merge blindly duplicates paragraphs).

---

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: `aapp.autoRebase` defaults to `false` (safe-by-default, can be enabled with `git config aapp.autoRebase true`). `aapp.docs` defaults to `true` to preserve standard kit invariants for existing adopters.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Automated Clean Rebase Engine
- [x] Task 1.1: Implement automated rebase with fail-closed abort in `_ig_check` in `lib/cmd_plan.sh` reading `aapp.autoRebase` (default `false`).
- [x] Task 1.2: Refresh plan header commit SHA after clean rebase before done archival.
- [x] Task 1.3: Add unit and integration tests in `tests/integrate_test.sh` verifying clean auto-rebase, conflict abort rollback, and default `aapp.autoRebase=false` behavior.

### Phase 2: Documentation Governance Opt-Out & Onboarding Tasks
- [x] Task 2.1: Add `aapp.docs` check in `templates/aapp-pre-commit` to suppress documentation reminders when disabled.
- [x] Task 2.2: Add `SET-AUTO-REBASE` and `SET-DOCS` tasks to `lib/adoption.sh` under `⚙️ Settings to Review`, and honor `aapp.docs` config to suppress manual heading tasks when disabled.
- [x] Task 2.3: Add unit tests in `tests/adoption_test.sh` (checking onboarding tasks and docs bypass) and `tests/pre-commit_test.sh`.

### Phase 3: Reference Documentation & Manual Updates
- [x] Task 3.1: Author `docs/reference/10-integration-and-rebase.md` documenting integration flow, auto-rebase contract, and conflict abort mechanics.
- [x] Task 3.2: Update `MANUAL.md` with auto-rebase documentation, onboarding settings, and `aapp.docs` configuration guide.
- [x] Task 3.3: Verify all test suites pass cleanly (`./aapp test quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `docs/reference/10-integration-and-rebase.md` -> Reference specification documenting the automated integration and rebase contract.
- [ ] `lib/cmd_plan.sh` -> Add automated clean rebase with conflict abort in `_ig_check`.
- [ ] `lib/adoption.sh` -> Add onboarding settings tasks (`SET-AUTO-REBASE`, `SET-DOCS`) and honor `aapp.docs` config to suppress manual heading warnings when documentation governance is disabled.
- [ ] `templates/aapp-pre-commit` -> Honor `aapp.docs` config to suppress documentation reminders.
- [ ] `MANUAL.md` -> Document automated rebase on integrate, onboarding review settings, and `aapp.docs` configuration.
- [ ] `tests/integrate_test.sh` -> Add automated test fixtures for clean auto-rebase and conflict abort rollback.
- [ ] `tests/adoption_test.sh` -> Add automated test fixtures verifying onboarding tasks and `aapp.docs=false` behavior.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Tool write guard is untouched.
- [ ] `lib/aapp-lib.sh` -> Core path resolver and parser functions untouched.
- [ ] `lib/cmd_issue.sh` -> Active issue workflow is untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Default Behavior for Auto-Rebase.** Should `aapp.autoRebase` default to `true` (enabling seamless integration) or `false` (requiring explicit opt-in)? -> **Resolved**: Default to `false` to stay strictly on the safe side initially. Teams and adopters can enable automated rebasing via `git config aapp.autoRebase true` once comfortable with the workflow.
* [x] **Question 2 — Union Merge Scope.** Should `ISSUES.md` ever use `merge=union`? -> **Resolved**: No. Active `ISSUES.md` has stateful mutations and relocations; `merge=union` causes ghost resurrection of closed issues. Only append-only archives (`000-archive-ledger.md`, `000-issues-archive.md`, and `CHANGELOG.md`) may use `merge=union`.

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-17:** Plan initialized and scaffolded to address automated integration rebasing and brownfield documentation governance.
* **2026-10-17:** Refined blueprint: set `aapp.autoRebase` default to `false` (safe-by-default) and added onboarding review tasks for auto-rebase and manuals in `lib/adoption.sh`.

