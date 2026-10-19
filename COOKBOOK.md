# 🍳 The AAPP Cookbook

Welcome to the **Agent-Assisted Planning Protocol (AAPP) Cookbook**. While the [Technical Manual](MANUAL.md) serves as the authoritative architectural specification and command reference, the Cookbook provides practical, copy-pasteable, step-by-step solutions for real-world engineering workflows.

---

## 🗺️ Curated Learning Tracks

### 🟢 Track 1: Getting Started & Daily Operations
For developers and teams adopting AAPP for the first time:
1. [Adopting an Existing Repository](docs/recipes/getting-started/adopt-existing-repo.md) `Beginner`
   *Onboard an existing codebase into the AAPP planning and blast-radius protocol.*
2. [Solo Developer Workflow](docs/recipes/getting-started/solo-developer-workflow.md) `Beginner`
   *A fast, streamlined cycle for human solo developers leveraging AAPP with or without AI agents.*

### 🔵 Track 2: Tooling & CI/CD Integrations
Pairing AAPP with your existing developer toolchain:
1. [Pairing AAPP with Husky](docs/recipes/integrations/husky-git-hooks.md) `Beginner`
   *Integrate AAPP blast radius and commit verification hooks into projects using Husky.*
2. [Pairing AAPP with Lefthook](docs/recipes/integrations/lefthook-git-hooks.md) `Beginner`
   *Configure the fast polyglot hook manager Lefthook to execute AAPP verification engines.*
3. [CI Blast Radius Gates with GitHub Actions](docs/recipes/integrations/github-actions-ci.md) `Intermediate`
   *Enforce blast radius boundaries, planning health, and commit attribution in GitHub Actions CI.*

### 🟣 Track 3: Advanced Lifecycle Workflows
Disciplined execution techniques for complex codebases:
1. [Failure-First TDD Workflows (`aapp tdd`)](docs/recipes/workflows/tdd-failure-assertions.md) `Intermediate`
   *Declare failure-first assertions in your plan blueprint and verify red-green test execution.*
2. [Emergency Hotfixes & Issue Worktrees (`aapp issue fix`)](docs/recipes/workflows/emergency-hotfixes.md) `Intermediate`
   *Safely repair urgent bugs without disturbing active feature worktrees using mini-plans.*
3. [Multi-Agent Worktree Concurrency](docs/recipes/workflows/multi-agent-worktrees.md) `Advanced`
   *Orchestrate multiple AI agents working simultaneously across isolated Git worktrees.*
4. [Planning a Plan Group](docs/recipes/workflows/planning-a-plan-group.md) `Advanced`
   *Decompose large architectural initiatives into aligned, sequential or parallel plan groups.*

### 🟠 Track 4: Extensibility, Plugins & Lifecycle Hooks
Supercharge AAPP with project-specific automation:
1. [Continuous Deployment on Plan Done (`post-done` Hook)](docs/recipes/plugins-and-hooks/01-deploy-on-done-hook.md) `Intermediate`
   *Trigger automated preview or staging deployments immediately when a plan is archived.*
2. [Custom Pre-Gate Validation & Compliance (`pre-*` Hooks)](docs/recipes/plugins-and-hooks/02-custom-pre-gate-hooks.md) `Advanced`
   *Enforce automated quality, security, and compliance gates before blueprints freeze or archive.*
3. [GitHub Issues Tracker Provider Plugin](docs/recipes/plugins-and-hooks/03-github-issues-tracker-plugin.md) `Advanced`
   *Connect AAPP's issue lane to GitHub Issues using the issue tracker provider plugin protocol.*
4. [Authoring Custom Action Plugins (`aapp <command>`)](docs/recipes/plugins-and-hooks/04-authoring-custom-action-plugins.md) `Advanced`
   *Build custom CLI commands that extend AAPP, tap into internal helpers, and run automations.*

### 🔴 Track 5: Troubleshooting & Incident Recovery
Resolving operational hitches fast:
1. [Blast Radius Refusal Recovery](docs/recipes/troubleshooting/blast-radius-recovery.md) `Beginner`
   *Diagnose and resolve file write refusals from Layer 1 write-guard and Layer 2 pre-commit hooks.*
2. [Worktree Collision & Conflict Recovery](docs/recipes/troubleshooting/worktree-collision-recovery.md) `Intermediate`
   *Repair corrupted worktrees, resolve planning branch merge conflicts, and clean stale checkouts.*

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](MANUAL.md) — Comprehensive architectural specification & command reference
- ⚡ [CLI Cheatsheet](CHEATSHEET.md) — Quick command syntax reference
- 🏠 [Repository Overview](README.md) — Project homepage and philosophy
