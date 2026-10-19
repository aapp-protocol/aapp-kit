---
title: Agent Skills & Slash Commands Reference
description: Reference catalog of built-in AAPP agent skills, slash commands, operational workflows, and automation hooks.
---

# 🤖 Agent Skills & Slash Commands Reference

AAPP provides specialized agent skills located in `.agents/skills/` (and packaged under `templates/skills/`) to guide AI coding assistants through precise protocol workflows.

---

## 1. Core Skills Catalog

| Skill Name | Invocation Path | Workflow Purpose |
| :--- | :--- | :--- |
| **`aapp`** | `.agents/skills/aapp/SKILL.md` | Session bootstrap. Reads full protocol rules, runs status briefings, and prepares context for work. |
| **`aapp-status`** | `.agents/skills/aapp-status/SKILL.md` | Context recovery upon returning to a repository. Scans the 4 pillars (Shipped, Issues, Plans, Pickup) and generates briefings. |
| **`aapp-plan`** | `.agents/skills/aapp-plan/SKILL.md` | Canonical blueprint drafting in `.plans/current/`. Enforces structured planning over ephemeral scratchpads. |
| **`aapp-digest`** | `.agents/skills/aapp-digest/SKILL.md` | Incubator intake. Ingests raw ideas from `pickup.md` or issues from `ISSUES.md` and generates structured plan blueprints. |
| **`aapp-tdd`** | `.agents/skills/aapp-tdd/SKILL.md` | Test declaration helper. Sets failure-first test specifications in Section 3 and maps target files in Section 4. |
| **`aapp-freeze`** | `.agents/skills/aapp-freeze/SKILL.md` | Blueprint locking. Verifies open questions, locks blast radius, and moves plan into Greenlight Zone. |
| **`aapp-start`** | `.agents/skills/aapp-start/SKILL.md` | Development activation. Initializes worktrees (`.workspace/<plan-slug>`), binds tracking pointers, and begins coding. |
| **`aapp-fix`** | `.agents/skills/aapp-fix/SKILL.md` | Issue Fast Lane. Spawns isolated fix worktree (`.workspace/fix-<num>`), applies fix, amends changelog, and archives issue. |
| **`aapp-pause`** | `.agents/skills/aapp-pause/SKILL.md` | Emergency brake. Safely stashes in-flight worktree modifications and halts autonomous actions. |
| **`aapp-release`** | `.agents/skills/aapp-release/SKILL.md` | Release execution runbook. Verifies branch parity, runs test suites, rolls changelogs, tags release, and bundles milestones. |
| **`aapp-done`** | `.agents/skills/aapp-done/SKILL.md` | Lifecycle completion. Archives completed blueprint to `.plans/done/`, cleans state matrix, and archives resolved issues. |

---

## 2. Interactive Slash Commands

In supported AI development environments (such as Antigravity, Claude Code, or Cursor), slash commands provide rapid triggers for agent skills:

| Command | Backing Skill | Recommended Usage |
| :--- | :--- | :--- |
| `/aapp` | `aapp` | Run at the start of every session to establish baseline context. |
| `/aapp-status` | `aapp-status` | Run when returning to the editor after a break or switching tasks. |
| `/aapp-plan <slug>` | `aapp-plan` | Scaffolds a new blueprint draft for a feature or major refactor. |
| `/aapp-freeze <id>` | `aapp-freeze` | Seals a blueprint's technical design and blast radius before coding begins. |
| `/aapp-start <id>` | `aapp-start` | Starts active development in an isolated worktree. |
| `/aapp-fix <num>` | `aapp-fix` | Immediately claims and resolves a bug listed in `.plans/issues_road_map.md`. |
| `/aapp-done <id>` | `aapp-done` | Archives an active plan after verification and testing are complete. |

---

## 3. Customizing Skills for Your Organization

Skills are modular Markdown documents containing YAML frontmatter and step-by-step agent instructions:

```markdown
---
name: aapp-custom-lint
description: Executes corporate security scanners and attaches findings to the active plan.
---

# Instructions
1. Run `./scripts/corp-security-scan.sh` against declared Target Files.
2. If vulnerabilities are detected, log an issue via `aapp issue log SEC ...`.
3. If clean, record scan certification in Section 6 (Change Log).
```

Custom skills should be placed in `.agents/skills/<skill-name>/SKILL.md` to be automatically discovered by agents.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Options](16-configuration-options.md)
- 🩺 [Planning Health Engine](13-planning-health-engine.md)
- 🏠 [Repository Overview](../../README.md)
