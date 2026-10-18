---
title: Integration and Automated Rebase
description: Branch integration strategies, automated clean rebase mechanics, fail-closed conflict circuit breakers, and documentation governance.
category: reference
---

# Integration and Automated Rebase

When an active plan blueprint finishes implementation, `aapp done <id> [integrate [manual|squash|ff|hook]]` verifies worktree invariants, archives the plan into `.plans/done/`, and integrates the plan branch into its designated parent branch (e.g. `develop` or a module branch).

During parallel multi-plan execution, multiple plan branches branch from the same parent base. Because Plan P-65 (Disjointness Activation Gate) mathematically guarantees that concurrent active plans touch non-overlapping target files, code conflicts between independent plan branches are structurally impossible.

However, as plans land sequentially on the parent branch, subsequent plan branches diverge from the tip of the parent branch. This reference documents the integration strategies, automated clean rebase engine, fail-closed conflict circuit breaker, and documentation governance.

---

## 1. Integration Modes (`aapp.integrate`)

The integration mode determines how `aapp done` merges code from the plan's branch into its target parent branch:

| Mode | Trigger / Flag | Behavior |
| :--- | :--- | :--- |
| `manual` | `aapp done <id> integrate manual` | Default. Archives the plan and leaves the branch and worktree intact for manual merging. |
| `squash` | `aapp done <id> integrate squash` | Squashes plan commits into a single commit with structured `Plan-ID:` and `Plan-Parent:` trailers, fast-forwards parent, and cleans up worktree and branch. |
| `ff` | `aapp done <id> integrate ff` | Fast-forwards the parent branch, preserving individual microcommits. Deletes branch and worktree upon success. |
| `hook` | `aapp done <id> integrate hook` | Delegates merge execution to a registered `on-integrate` hook. |

---

## 2. Automated Clean Rebase Engine (`aapp.autoRebase`)

When integrating via fast-forward (`integrate ff`) or squash (`integrate squash`), the plan branch must contain the target parent branch (`git merge-base --is-ancestor <parent> <plan-branch>`).

If the parent branch moved forward while the plan was in development, the branches diverge:

### Configuration (`aapp.autoRebase`)
- **Key**: `aapp.autoRebase` (`true` | `false`)
- **Default**: `false` (Safe-by-default, requiring explicit opt-in).
- **Opt-in**: `git config aapp.autoRebase true`

### Execution Flow:
1. **Divergence Detection**: `_ig_preflight` checks whether `IG_TARGET_BR` is an ancestor of `IG_PLAN_BR`.
2. **Opt-In Check**:
   - If `aapp.autoRebase` is `false` (default): Integration immediately halts with a refusal message directing the developer or agent to rebase manually:
     ```text
     ❌ [Done Refusal] 'plan/P-B' does not contain 'develop'; rebase it first:
        git -C .workspace/P-B rebase --autostash develop
     ```
   - If `aapp.autoRebase` is `true`: The engine attempts non-interactive automated rebase:
     ```bash
     git -C "$IG_WT" rebase --autostash "$IG_TARGET_BR"
     ```
3. **Success Path (0 Conflicts)**:
   - Rebase cleanly reapplies the plan's commits on top of the parent branch.
   - Commit SHAs rewritten during rebase are discovered via `git log --reverse --format="%h" "$IG_TARGET_BR..$IG_PLAN_BR"`.
   - The plan's `* **Commits:**` header line in the blueprint is updated with the new commit SHAs.
   - Integration proceeds directly to fast-forward without requiring manual intervention.
4. **Fail-Closed Circuit Breaker (Conflict Encountered)**:
   - If git encounters any conflict during rebase (e.g. concurrent documentation edits), the engine **immediately aborts** the rebase:
     ```bash
     git -C "$IG_WT" rebase --abort
     ```
   - The worktree is restored to its exact pre-integration state without leaving detached heads, unmerged files, or index conflicts.
   - Integration halts with a diagnostic refusal message:
     ```text
     ❌ [Done Refusal] Automated rebase encountered merge conflicts; resolve manually:
        git -C .workspace/P-B rebase --autostash develop
     ```

---

## 3. Documentation Governance (`aapp.docs`)

The AAPP protocol emphasizes strict documentation synchronization (`README.md`, `MANUAL.md`, `ARCHITECTURE.md`, `.agents/CODEMAP.md`). For mature projects, microservices, or brownfield adopters utilizing external documentation tools (VitePress, Docusaurus, MkDocs, AsciiDoc), rigid built-in documentation checks can create friction.

### Configuration (`aapp.docs`)
- **Key**: `aapp.docs` (`true` | `false`)
- **Default**: `true` (Documentation governance enabled).
- **Opt-Out**: `git config aapp.docs false`

### Governance Behavior:
- **Pre-Commit Hook**: When `aapp.docs=false`, the pre-commit reminder (`⚠️ [Pre-Commit Reminder] Documentation was not updated`) is suppressed.
- **Adoption Checklist**: When `aapp.docs=false`, onboarding rules requiring manual template headings (`[PROJECT-RULES]`, `[PROJECT-MAP]`) do not trigger in `.plans/adoption.md`.

---

## 4. Ledger Merge Driver Boundary

Repository ledgers operate under strict merge safety boundaries:

| Document | Merge Driver | Reason |
| :--- | :--- | :--- |
| `CHANGELOG.md` | `merge=union` (under `## [Unreleased]`) | Purely append-only bullet additions. |
| `.plans/done/000-archive-ledger.md` | `merge=union` | Purely append-only archive records. |
| `.plans/done/000-issues-archive.md` | `merge=union` | Purely append-only resolved issue records. |
| `.plans/ISSUES.md` | 3-way semantic merge (**never** union) | **Stateful**: rows are edited in-place (status transitions) and physically removed upon resolution. Union merge causes ghost resurrection. |
| `MANUAL.md`, `README.md`, `ARCHITECTURE.md` | 3-way semantic merge (**never** union) | Prose documents with hierarchical sections. Union merge causes duplicate paragraphs. |

---

## 5. Parent-Branch Integration Lock & CAS Landing (P-107)

During parallel development across multiple worktrees, concurrent integrations into the same parent branch could previously encounter Time-of-Check to Time-of-Use (TOCTOU) race conditions if the parent branch advanced between preflight checks and landing. Plan P-107 eliminates this concurrency window through per-parent locking and Compare-and-Swap (CAS) landing:

### 5.1 Per-Parent Lock Scoping
- **Scoped by Target**: Integration locks are keyed specifically to the target parent branch (`integrate/<parent>`), resolving to `aapp_integrate_<parent>.lock` in the git common dir.
- **Concurrent Isolation**: Integrations targeting distinct parent branches (e.g. `module/auth` vs `develop`) proceed concurrently with zero contention.
- **Configurable Wait (`aapp.integrateWait`)**: Wait duration is configurable via `git config aapp.integrateWait <seconds>` (default `15` seconds, bounded between 10s and 600s, stepping in 2s increments).
- **Stale Takeover**: Locks carry PID metadata (`pid` and `info`). If the holding process exits or crashes, stale locks are automatically detected and taken over after a 5s grace window.

### 5.2 Headless Fast-Forward via Compare-and-Swap (CAS)
- **Zero Primary Worktree Switching**: Integration fast-forwards the parent ref headlessly via `git update-ref refs/heads/<parent> <new_sha> <old_sha>` (or `git merge --ff-only` within the specific worktree checking out the parent, if any). The main repository root (`PRIMARY_ROOT`) is never switched or dirtied.
- **CAS Mismatch Protection**: If an external process moves the parent ref during execution, `git update-ref` atomically rejects the update, preventing silent overwrites or divergent histories.

### 5.3 Option i Atomic Landing & Rollback
- **Landing Order**: The parent branch is fast-forwarded via CAS **before** committing the plan archival to `.plans/done/`.
- **Fail-Closed Rollback**: If the plan archive commit in `.plans` fails, the parent branch is automatically rolled back to its previous SHA (`<old_sha>`) while the parent lock remains held. Active plan buffers in `.workspace/` are preserved (resolving #124).
- **Issue Fix Protection**: `aapp issue close` acquires `integrate/<parent>` when landing fixes via `_issue_land_fix`.
- **Pre-Commit Raw Commit Boundary**: The pre-commit hook verifies `aapp_lock_path "integrate/<branch>"`. Direct raw commits to a parent branch currently undergoing active integration are rejected.
- **Standalone Re-Gate**: Retrying integration on an archived plan (`aapp done <id> integrate`) re-executes the `pre-done` test gate whenever an automated rebase takes place.

