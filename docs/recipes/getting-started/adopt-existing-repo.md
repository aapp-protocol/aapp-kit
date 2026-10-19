---
title: "Adopting an Existing Repository"
description: "Step-by-step guide to onboarding an existing codebase into the AAPP planning and blast-radius protocol."
category: "getting-started"
difficulty: "beginner"
tags: [adoption, init, setup, onboarding]
---

# 🍳 Recipe: Adopting an Existing Repository

## 🎯 Goal
Equip an active, existing Git repository with the Agent-Assisted Planning Protocol (AAPP) without breaking existing Git workflows, CI/CD pipelines, or active branches.

## 📋 Prerequisites
- A clean or committed Git repository (`git status` clean recommended).
- Git 2.30+ installed.
- Antigravity, Claude Code, or another AI coding assistant.
- The `aapp` CLI installed globally (`curl ... | bash` or local clone).

## 🛠️ Step-by-Step Instructions

### 1. Initialize AAPP in the Repository
Navigate to the root of your existing repository and run:
```bash
aapp init
```
This command performs the following non-destructive actions:
1. Creates the isolated `.plans/` directory worktree (or mounts the `plans` orphan branch if configured).
2. Seeds `.agents/` configuration including `.agents/AGENTS.md` and `.agents/CODEMAP.md`.
3. Installs Layer 1 and Layer 2 protection hooks into `.githooks/` (`blast-radius-guard.sh` and `aapp-pre-commit`).
4. Configures `core.hooksPath` to `.githooks`.

### 2. Configure Baseline Versioning & Identity
Set your project's attribution and versioning preferences:
```bash
# Choose attribution mode (none | lax | strict | notes)
git config aapp.aiAttribution lax

# If your repo has no tags yet, define an initial baseline version
git config aapp.initialVersion "0.1.0"
```

### 3. Verify Adoption Health
Run the adoption status audit:
```bash
aapp status
```
Inspect the output to ensure:
- The four pillars (Shipped, Issues, Plans, Pickup) are recognized.
- No planning health violations are reported.

### 4. Seed the Project Codemap
Open `.agents/CODEMAP.md` and map your repository's primary architectural domains:
```markdown
# Repository Codemap

### Core Domain (`src/core/`)
- Canonical owner for business logic and data processing.

### API Layer (`src/api/`)
- HTTP endpoints and route handlers.
```
This map serves as the authoritative source of truth for AI agents deciding where concerns live.

## ⚠️ Critical Invariants & Gotchas
- **Hook Manager Coexistence**: If your repository already uses Husky, Lefthook, or pre-commit, do not overwrite `core.hooksPath` indiscriminately. Consult [Pairing AAPP with Husky](../integrations/husky-git-hooks.md) or [Pairing AAPP with Lefthook](../integrations/lefthook-git-hooks.md).
- **Zero Machine Paths**: Never commit absolute machine paths (such as user home directories or local file schemes) into `.plans/` or `.agents/`. All paths must remain repository-relative.
- **Portability**: All configuration stored in `.agents/` is checked into version control to provide consistent boundaries across all developer checkouts and CI environments.

## 🔗 Related References
- 📖 [Technical Manual: Initialization & Adoption](../../../MANUAL.md#initialization--setup-aapp-init)
- 🍳 [Recipe: Solo Developer Workflow](solo-developer-workflow.md)
- 🍳 [Recipe: Pairing with Husky](../integrations/husky-git-hooks.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
