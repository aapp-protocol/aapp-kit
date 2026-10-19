---
title: Worktree Architecture & Orphan Branch Mechanics
description: Deep dive on orphan branches, worktree mounts, directory ownership, and multi-workstation synchronization in AAPP.
---

# 🌳 Worktree Architecture & Orphan Branch Mechanics

## The Problem: Context Pollution and Agent Drift

Modern AI coding assistants (Antigravity, Claude Code, Cursor, Copilot) are exceptionally capable at generating code. However, when pair-programming without deterministic boundaries, three systemic failure modes emerge:

1. **Agent Drift & Scope Creep**: An agent tasked with editing a single module discovers a helper function, decides to "clean up" the codebase, refactors working code, and touches 15 unrelated files without human consent.
2. **Context & History Pollution**: Scratchpad notes, architectural thoughts, planning files, and agent conversation artifacts get committed directly to your `main` or feature branches. This pollutes `git log`, creates merge conflicts across feature branches, and confuses release tooling.
3. **Fragile Invariants**: Prompt instructions alone are probabilistic. An agent instructed "do not touch file X" will eventually touch file X if token context compresses or context shifts.

## The Core Primitive: Git Worktrees on Orphan Branches

AAPP solves this structurally through native Git plumbing: **Git Worktrees mounted on isolated Orphan Branches**.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MAIN REPOSITORY TREE                            │
│           (Pure application source code, e.g. src/, tests/)             │
└───────┬──────────────────────────┬───────────────────────────┬─────────┘
        │                          │                           │
        ▼                          ▼                           ▼
┌──────────────────┐      ┌──────────────────┐       ┌───────────────────┐
│     .plans/      │      │     .agents/     │       │     .githooks/    │
│  (orphan branch: │      │  (orphan branch: │       │  (orphan branch:  │
│     'plans')     │      │     'agents')    │       │    'githooks')    │
├──────────────────┤      ├──────────────────┤       ├───────────────────┤
│ • current/*.md   │      │ • AGENTS.md      │       │ • pre-commit      │
│ • done/*.md      │      │ • PROJECT.MD     │       │ • aapp-pre-commit │
│ • pickup.md      │      │ • rules/*.md     │       │ • blast-radius-   │
│ • issues_road_   │      │                  │       │   guard           │
│   map.md         │      │                  │       │                   │
│ • state_matrix.md│      │                  │       │                   │
└──────────────────┘      └──────────────────┘       └───────────────────┘
```

By decoupling these concerns into independent Git worktrees:
- Planning notes, task checklists, and architectural matrices **never appear in your application git history**.
- You can switch, rebase, cherry-pick, or reset feature branches in your application code **without losing your active planning scratchpads or agent state**.
- All AI assistants share the exact same ground truth on disk.

## Directory Map and Ownership Model

| Directory / File | Mount Type | Canonical Purpose |
| :--- | :--- | :--- |
| `README.md` | Repo Root | Public overview, installation, and user-facing entrypoint. |
| `CHANGELOG.md` | Repo Root *(or `.plans/`)* | Keep-a-Changelog record of user-facing changes (enforced on code commits; dual-location supported). |
| `COOKBOOK.md` | Repo Root | Curated index and catalog for task-oriented how-to recipes. |
| `MANUAL.md` | Repo Root | Executive navigation portal and core system axioms. |
| `ARCHITECTURE.md` | Repo Root *(or `.agents/`)* | Public technical design rules, system constraints, and core abstractions. |
| `.agents/CODEMAP.md` | `agents` worktree *(or root)* | Canonical directory ownership, module boundaries, and entrypoints. |
| `.agents/AGENTS.md` | `agents` worktree | Agent behavioral contracts, protocol rules, and slash command bindings. |
| `.agents/PROJECT.MD` | `agents` worktree | Project-specific personas, milestones, and high-level architectural rules. |
| `.agents/claude/` | `agents` worktree | Canonical Claude Code configuration (`settings.json`). |
| `.agents/skills/` | `agents` worktree | Canonical Universal AAPP Skills (`aapp-*/SKILL.md`). |
| `.claude/` | Gitignored Bridge | Granular symlinks to canonical settings and skills in `.agents/`. |
| `.plans/ISSUES.md` | `plans` worktree *(or root)* | Active flat technical backlog & defect ledger (Relocation Invariant). |
| `.plans/done/000-issues-archive.md` | `plans` worktree | Master historical archive ledger of verified and resolved issues. |
| `.plans/` | `plans` worktree | Active blueprints (`current/`), historical archives (`done/000-archive-ledger.md` & `done/000-issues-archive.md`), scratchpad (`pickup.md`), the work queue (`issues_road_map.md`), and state matrix (`state_matrix.md`). |
| `.githooks/` | `githooks` worktree | Dual-layer blast radius enforcement scripts (`aapp-pre-commit`, `pre-commit`, `blast-radius-guard`). |

## Git Plumbing Under the Hood

An **orphan branch** in Git is a branch that has no parent commits and shares no common history with the main branch. A **worktree** allows a single repository to have multiple working trees attached simultaneously.

When `aapp init` sets up a worktree (for example `.plans`), it executes a safe, non-destructive Git plumbing algorithm:

```bash
# 1. Check if the orphan branch already exists locally or remotely
if git rev-parse --verify plans >/dev/null 2>&1; then
    # Local branch exists: add worktree attached to it
    git worktree add .plans plans
elif git rev-parse --verify origin/plans >/dev/null 2>&1; then
    # Remote tracking branch exists: track it
    git worktree add --track -b plans .plans origin/plans
else
    # Create new detached worktree and root orphan commit without touching main index
    git worktree add --detach .plans
    (
        cd .plans
        EMPTY_TREE="$(git hash-object -t tree /dev/null 2>/dev/null || echo "4b825dc642cb6eb9a060e54bf8d69288fbee4904")"
        INITIAL_COMMIT="$(git commit-tree "$EMPTY_TREE" -m "chore: initialize plans worktree")"
        git checkout -b plans "$INITIAL_COMMIT" --quiet
    )
fi
```

## Remote Synchronization & Multi-Workstation Setup

Because worktrees are attached to regular Git branches, they can be pushed and pulled to any remote (GitHub, GitLab, self-hosted Git server).

### Pushing Worktrees to Remote (Shared or Dedicated Repository)

```bash
# Push to origin (default):
aapp push origin      # or: git -C .plans push origin plans

# Push worktrees to a dedicated separate remote (e.g. private planning repo):
git remote add plans-remote git@github.com:your-org/private-plans.git
git -C .plans push -u plans-remote plans:main   # binds upstream tracking
git config aapp.remote plans-remote             # default target for aapp push/pull
```

### Cloning onto a Second Workstation or CI

When cloning a repository for the first time on a new machine:

```bash
git clone git@github.com:your-org/your-repo.git
cd your-repo

# Initialize AAPP — automatically detects remote orphan branches and mounts worktrees
aapp init
```

`aapp init` detects `origin/plans`, `origin/agents`, and `origin/githooks` and mounts tracking worktrees without generating conflict warnings.

### Re-Attaching and Repairing Worktrees

If a worktree directory is accidentally deleted (`rm -rf .plans`), Git may retain internal reference metadata in `.git/worktrees/plans`. To repair:

```bash
# 1. Prune dead worktree metadata
git worktree prune

# 2. Re-add worktree pointing to existing local branch
git worktree add .plans plans
```

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
