---
title: "Adopting an Existing Repository"
description: "The whole path to using AAPP in a project: install, aapp init in an existing repository, cloning a repository that already uses AAPP, the first session, existing hook managers, the adoption checklist and upgrades."
category: "getting-started"
difficulty: "beginner"
tags: [adoption, init, setup, onboarding, upgrade]
---

# 🍳 Recipe: Adopting an Existing Repository

## 🎯 Goal
Bring an existing Git repository under AAPP without breaking its workflows, CI or branches, and keep it current as the kit evolves.

## 📋 Prerequisites
- Git, Bash and Perl 5.26 or later ([Platform Verification](../../reference/19-platform-verification.md) lists what is tested).
- A repository with a clean working tree.
- An AI coding agent: Claude Code and Antigravity are wired in; others read `.agents/AGENTS.md` ([Agent Skills](../../reference/14-agent-skills-and-slash-commands.md#3-how-skills-reach-each-agent)).

## 🛠️ Steps

### 1. Install the kit (once per machine, no root needed)
```bash
git clone https://github.com/aapp-protocol/aapp-kit.git
./aapp-kit/aapp install
```
`aapp` goes to `~/.local/bin`, its files to `${XDG_DATA_HOME:-~/.local/share}/aapp-kit/`. The installer then deletes the `aapp-kit/` clone it ran from; it was only a download. If `~/.local/bin` is not on your `PATH`, it offers to add it.

### 2. Run `aapp init` in your repository
```bash
cd your-project
aapp init
```
`init` is safe to run on an existing project and safe to run again:
1. It creates the three planning worktrees on their own branches: `.plans/` (plans, issues, pickup), `.agents/` (rules, skills, agent settings) and `.githooks/` (hooks). Your code branches are not touched. ([Worktree Architecture](../../concepts/01-worktree-architecture.md))
2. It seeds `.agents/AGENTS.md`, `.agents/PROJECT.MD`, `.agents/CODEMAP.md` and `ARCHITECTURE.md` with starter text. An existing `AGENTS.md` keeps your rules: the kit adds its protocol block between `<!-- AAPP-PROTOCOL:START -->` and `<!-- AAPP-PROTOCOL:END -->` and only ever rewrites that block. A root-level `AGENTS.md` is moved into `.agents/`.
3. It installs the write guard and the commit hooks into `.githooks/` and sets `core.hooksPath` to `.githooks`, unless you already use a hook manager (step 5).
4. It wires Claude Code: skills linked into `.claude/skills/`, and the guard merged into `.claude/settings.json` without removing your own settings or hooks.
5. It writes the defaults of the main settings into `.git/config` (`aapp.commitMode`, `aapp.changelogMode`, `aapp.integrate`, …) and seeds the Plan ID counter from any plans already there.

Commit the files `init` wrote on your code branch (`.gitignore` entries, `ARCHITECTURE.md`): plan worktrees are cut from that branch.

### 3. Your first session
In your agent's chat:
```text
/aapp
/aapp-digest Onboarding
```
1. `/aapp` loads the rules and prints the briefing (`aapp status`). An `Onboarding` idea waits under Pickup.
2. `/aapp-digest Onboarding` drafts a plan whose Blast Radius is `.agents/CODEMAP.md`, `ARCHITECTURE.md` and `.agents/PROJECT.MD` only.
3. Review it, then `/aapp-freeze <id>` and `/aapp-start <id>` (or `aapp freeze-start <id>`): the agent reads your directory layout, build manifests, dependencies and entry points, and replaces the starter text with your real modules and rules.
4. `/aapp-done <id>` archives it. Your repository is mapped and governed.

### 4. Work through the adoption checklist
`aapp status` ends with `📋 Adoption: <n> open task(s) in .plans/adoption.md`. `init` writes that local, untracked list from what it finds in your repository: a development branch to name, protected branches, a remote to set, files to commit, a hook manager to wire, a test gate for `aapp done`, build tools that might pick up `.workspace/`, and the settings worth a decision. Each task links to the page that explains it. Tick a task by hand when it is done; a rerun of `init` ticks the ones it can check and never undoes your edits. `aapp.docs false` leaves out the documentation tasks.

Settings to review first ([Configuration Reference](../../reference/03-configuration-matrix.md)):
```bash
git config aapp.aiAttribution lax        # record which agent wrote a commit
git config aapp.planWorktrees on         # one branch and worktree per plan
git config aapp.integrate squash         # how done lands a plan's branch
git config aapp.devBranch develop        # your development branch
git config aapp.initialVersion 0.1.0     # first release, when there are no tags yet
```

### 5. Existing hook managers (Husky, Lefthook, a native hook)
When `core.hooksPath` already points elsewhere, or `.git/hooks/pre-commit` exists, `init` leaves your hook configuration alone and prints one line to add to your pre-commit script:
```sh
"$(cd "$(git rev-parse --git-common-dir 2>/dev/null || echo .git)/.." && pwd)/.githooks/aapp-pre-commit" || exit 1
```
Run it as a subprocess, as shown, not with `source` or `exec`: its exit code then stops your hook, and `SKIP_BLAST_RADIUS=1` passes through. The adoption checklist keeps a `[HOOK-WIRING]` task open until it is wired. Step by step: [Husky](../integrations/husky-git-hooks.md), [Lefthook](../integrations/lefthook-git-hooks.md).

## 👥 Cloning a Repository That Already Uses AAPP
A teammate or contributor installs the kit (step 1), clones the repository as usual, then:
```bash
aapp init     # mounts .plans, .agents and .githooks from the remote's branches
```
- **Until `aapp init` has run,** a fresh clone has no AAPP hooks: Git configuration is not cloned. Run it before the first commit.
- **A checkout whose kit was later removed** is **inspection-only**: code and plans can be read, and the pre-commit hook refuses every commit with the install command, so nothing unguarded enters the history. Installing the kit again unlocks it.

Settings live in `.git/config` and are never pushed: agree the team's values and set them in every clone, or put the policy keys in a user or system `main.conf` ([Configuration Hierarchy](../../reference/15-configuration-hierarchy.md)). A team also needs a shared Plan ID provider ([Plan ID Allocation](../../reference/18-plan-id-allocation.md)).

## 🔄 Upgrading
```bash
aapp upgrade          # fetches the latest kit and reinstalls it (from AAPP_UPSTREAM_URL)
cd your-project
aapp init             # brings this project to the new protocol
```
`init` refreshes the kit's protocol blocks and leaves your text outside them; hooks and kit skills are replaced with the new versions; your ledgers, plans and state matrix are never overwritten. How a template that you changed outside its protocol block is treated (kept with a `.new` copy beside it, overwritten, or left alone) is `aapp.templateSync` ([Release & Templates](../../reference/03-configuration-matrix.md#release--templates)); the adoption checklist lists such drift as `[TEMPLATE-DRIFT]`.

## ⚠️ Gotchas
- **Machine paths:** never commit absolute paths (home directories, `file://` links) into `.plans/` or `.agents/`; the pre-commit hook refuses them.
- **`.workspace/` and build tools:** plan worktrees live in `.workspace/` (or your `aapp.planWorktreePath`); keep build tools from walking into them. Nx (`nx.json`): add `/.workspace` to `.nxignore`. Bazel (`WORKSPACE` or `MODULE.bazel`): add `.workspace` to `.bazelignore`. The adoption checklist names these two when it finds them; Turborepo, pnpm and TypeScript are listed in [Platform Verification](../../reference/19-platform-verification.md#build-tools-that-may-not-see-workspace).
- **One test gate:** to require green tests before `aapp done`, register a `pre-done` gate hook ([Requiring Green Tests](../../reference/04-plugin-and-hook-engine.md#7-requiring-green-tests-on-done-test-gate)).

## 🔗 Related
- 🍳 [Solo Developer Workflow](solo-developer-workflow.md)
- 📖 [Lifecycle State Machine](../../reference/01-lifecycle-state-machine.md)
- 🧩 [Document Governance](../../reference/11-document-governance.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
