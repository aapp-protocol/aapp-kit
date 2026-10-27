---
title: Companion Development Reference
description: Working on several repositories at once with aapp companion, its three topologies, how the write guard treats a companion, and the bounded status and push.
---

# 🔗 Companion Development Reference

A project often spans several repositories: an engine with its adapter, an SDK with a demo app, a kit with a site. `aapp companion` registers the other repositories as companions of the one you work in, so an agent can read and change them while each repository keeps its own Blast Radius.

---

## 1. Commands

```bash
aapp companion add <name> <path>             # an existing checkout, where it is
aapp companion add <name> <path> worktree    # a worktree of a non-AAPP repository
aapp companion add <name> <url>              # a clone of a remote repository
aapp companion list                          # every companion, its topology and branch
aapp companion status [name]                 # branch, uncommitted files, ahead/behind, last fetch
aapp companion push <name>                   # push the companion to its upstream
aapp companion remove <name> [force]         # unregister it
```

`<name>` is lowercase letters, digits, `-` and `_`, and unique. Each companion is recorded in `.git/config` (`aapp.companion.<name>.path` and `.mode`, [settings](03-configuration-matrix.md#companion)) and its path is added to `aapp.allowPath`.

---

## 2. Topologies

| Topology | Command | Where it lives | `remove` |
| :--- | :--- | :--- | :--- |
| **`checkout`** | `add <name> <path>` | The existing folder, in place (both repositories checked out side by side) | Unregisters it; the folder is never touched |
| **`worktree`** | `add <name> <path> worktree` | `.workspace/companion/<name>`, a worktree of `<path>` | Removes the worktree; refused with uncommitted files or unpushed commits unless `force` |
| **`clone`** | `add <name> <url>` | `.workspace/companion/<name>`, a fresh clone | Deletes the clone; refused with uncommitted files or unpushed commits unless `force` |

**An AAPP repository is never added as `worktree`.** A raw worktree would have none of the kit's hooks. Start the plan inside that repository instead (`aapp start <id>` there) and register the plan's worktree as a `checkout`.

`add <path>` refuses a folder that is not a Git repository, and a name already in use (naming its path).

---

## 3. The Write Guard and a Companion

When an agent writes to a file inside a companion:

- **The companion is an AAPP repository** (it has `.githooks/blast-radius-guard`): the decision is handed to the companion's own guard, which applies the plan active there. A write outside that plan's Target Files is refused as it would be in the companion itself.
- **The companion is not an AAPP repository:** the write is allowed, as for any path in `aapp.allowPath`.

Commits stay separate: a commit in your repository stages only its own files, and the companion's commits go through the companion's own hooks.

---

## 4. Status and Push

- **`status [name]`** works offline: it reports the branch, the number of uncommitted files, commits ahead of and behind the upstream as last fetched, and when it was last fetched. It never contacts a remote.
- **`push <name>`** runs `git -C <path> push` to the companion's upstream branch. It refuses a companion with uncommitted files or without an upstream, and never force-pushes or switches branches.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🛡️ [Blast Radius Engine](../concepts/02-blast-radius-engine.md)
- ⚙️ [Configuration Reference](03-configuration-matrix.md#companion)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
