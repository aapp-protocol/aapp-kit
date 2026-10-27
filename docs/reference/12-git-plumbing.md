---
title: Git Plumbing & Worktree Mechanics
description: Deep dive into orphan branches, detached tree commit algorithms, remote sync, and worktree repair in AAPP.
---

# 🔧 Git Plumbing & Worktree Mechanics

AAPP relies on native Git plumbing to isolate governance, agent instructions, and planning scratchpads from application code.

---

## Under the Hood: Orphan Branches & Worktrees

An **orphan branch** in Git is an independent history line with no parent commits. A **worktree** allows a single Git repository to mount multiple branches across different working tree directories simultaneously.

When `aapp init` sets up a worktree (such as `.plans`, `.agents`, or `.githooks`), it executes a deterministic, non-destructive plumbing algorithm:

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

### The Empty Tree SHA Invariant
Git has a well-known canonical hash for an empty directory tree: `4b825dc642cb6eb9a060e54bf8d69288fbee4904`. By committing this empty tree object directly with `git commit-tree`, AAPP creates the initial root commit without altering the current Git index or working files.

---

## Remote Synchronization & Multi-Workstation Setup

Because worktrees are attached to standard Git branches, they can be synchronized to remotes (GitHub, GitLab, private Git remotes).

### Pushing Worktrees to Remote

```bash
# Push to origin (default):
aapp push origin      # or: git -C .plans push origin plans

# Push worktrees to a dedicated separate remote (e.g. private planning repo):
git remote add plans-remote git@github.com:your-org/private-plans.git
git -C .plans push -u plans-remote plans:main   # binds upstream tracking
git config aapp.remote plans-remote             # default target for aapp push/pull
```

### Push, Pull and Sync

```bash
aapp push [remote] [strategy]   # push every planning worktree; sets upstream tracking on the first push
aapp pull [remote] [strategy]   # pull every planning worktree, fast-forward only
aapp sync [remote] [strategy]   # pull, then push
```

- **Which worktrees:** those in `aapp.syncWorktrees` (default `plans agents githooks`); `.offline` never travels. Git notes travel too when `aapp.notesRemote` is set.
- **Clean first:** before `pull` or `sync`, every planning worktree must be clean. One with uncommitted changes stops the whole run before any branch is touched, so drafts are never caught in a merge.
- **Fast-forward only:** pulls run with `--ff-only` (`aapp.pullStrategy`). A worktree that cannot fast-forward stops the pull for you to inspect it there.
- **Transport:** `builtin` (the kit runs Git itself) or `hook` (an `on-sync` handler does the transport). The strategy comes from the command's argument, else `aapp.syncStrategy`, which `aapp init` sets to `hook` when the committed registry has an `on-sync` handler and to `builtin` otherwise. `hook` without a registered handler is refused, never skipped.

Settings: [Branches, Remote & Sync](03-configuration-matrix.md#branches-remote--sync).

### Cloning onto a Second Workstation or CI

When cloning a repository on a new machine:

```bash
git clone git@github.com:your-org/your-repo.git
cd your-repo

# Initialize AAPP — automatically detects remote orphan branches and mounts worktrees
aapp init
```

`aapp init` detects `origin/plans`, `origin/agents`, and `origin/githooks` and mounts tracking worktrees without generating conflict warnings.

---

## Re-Attaching and Repairing Worktrees

If a worktree directory is accidentally removed from disk (`rm -rf .plans`), Git may retain internal reference metadata in `.git/worktrees/plans`. To repair:

```bash
# 1. Prune dead worktree metadata
git worktree prune

# 2. Re-add worktree pointing to existing local branch
git worktree add .plans plans
```

---

## Plan Worktrees (`aapp.planWorktrees`)

With `git config aapp.planWorktrees on`, `aapp start` (and `freeze-start`) creates an isolated branch and worktree under `.workspace/{id}`:
- **Base Branch**: Branches off the first candidate development branch (`aapp.devBranch`, e.g. `develop`), falling back to the default branch.
- **Detached Session**: Runs an optional session command (`aapp.planSession`, e.g. `tmux new-window -c {path} claude`) without blocking the CLI.
- **Fail-Closed Isolation**: Symlinks `.githooks`, `.agents`, and `.plans` into the worktree; refuses startup if links fail.

**Settings on this page:** [Attribution & Notes](03-configuration-matrix.md#attribution--notes) · [Plans & Worktrees](03-configuration-matrix.md#plans--worktrees) · [Branches, Remote & Sync](03-configuration-matrix.md#branches-remote--sync)

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
