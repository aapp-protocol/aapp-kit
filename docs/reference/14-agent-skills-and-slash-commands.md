---
title: Agent Skills & Slash Commands Reference
description: The kit's agent skills, their slash commands and CLI actions, how they reach each agent, custom skills, context efficiency and the guardrails agents work under.
---

# 🤖 Agent Skills & Slash Commands Reference

AAPP gives coding agents (Claude Code, Antigravity, Cursor, Codex, OpenCode and others) a set of skills: Markdown instructions that walk an agent through one protocol workflow. Each skill drives the same CLI verbs a person would type, so an agent and a person reach the same result.

---

## 1. Skills Catalog

The kit ships 11 skills and one alias in `templates/skills/`; `aapp init` and `aapp upgrade` copy them into the project's `.agents/skills/`:

| Skill | Path | Purpose |
| :--- | :--- | :--- |
| **`aapp`** | `.agents/skills/aapp/SKILL.md` | Session start: reads `.agents/AGENTS.md` in full, runs `aapp status` and shows the briefing. Run it again after a conversation was summarised. |
| **`aapp-status`** | `.agents/skills/aapp-status/SKILL.md` | Context recovery later in a session: the four-pillar briefing (Shipped, Issues, Plans, Pickup) alone. |
| **`aapp-plan`** | `.agents/skills/aapp-plan/SKILL.md` | Canonical planning and lane routing: a durable blueprint in `.plans/current/` instead of an IDE scratchpad. |
| **`plan`** | `.agents/skills/plan/SKILL.md` | Alias of `aapp-plan`, so an agent's built-in `/plan` lands in the same workflow. |
| **`aapp-digest`** | `.agents/skills/aapp-digest/SKILL.md` | Takes one idea from `pickup.md` or one issue from `ISSUES.md` and works it toward a blueprint in the Incubator. |
| **`aapp-tdd`** | `.agents/skills/aapp-tdd/SKILL.md` | Declares a plan's failure-first tests (§3 identifiers, §4 test files) before freeze. |
| **`aapp-freeze`** | `.agents/skills/aapp-freeze/SKILL.md` | Locks a plan's design and Blast Radius: checks open questions, then `aapp freeze`. |
| **`aapp-start`** | `.agents/skills/aapp-start/SKILL.md` | Starts a frozen plan (`⚡ In Development`), in its own worktree when `aapp.planWorktrees` is on, and begins its §3. |
| **`aapp-fix`** | `.agents/skills/aapp-fix/SKILL.md` | Fixes one queued issue (or the next plan blocker) through a temporary mini plan in `.workspace/fix-<num>`. |
| **`aapp-done`** | `.agents/skills/aapp-done/SKILL.md` | Archives an implemented plan: moves it to `.plans/done/`, appends the archive ledger, closes its issue. |
| **`aapp-pause`** | `.agents/skills/aapp-pause/SKILL.md` | Emergency brake: quarantines in-flight work per worktree into stashes, shows the pause state, resumes. |
| **`aapp-release`** | `.agents/skills/aapp-release/SKILL.md` | Release run: pre-flight checks, changelog rollup and versioning through `aapp release`. |

`.agents/skills/aapp-hooks/` is not a skill: it holds the project's hook registry, `registry.tsv` ([04. Plugin & Hook Engine](04-plugin-and-hook-engine.md)). Sync keeps that file when it refreshes the skills.

---

## 2. Slash Commands and the CLI

An agent that supports skills exposes each one as a slash command. The skill then runs the CLI verb shown here:

| Slash command | Skill | CLI action |
| :--- | :--- | :--- |
| `/aapp` | `aapp` | reads the rules, then `aapp status` |
| `/aapp-status` | `aapp-status` | `aapp status` |
| `/aapp-plan [slug]`, `/plan` | `aapp-plan` | `aapp draft <slug>` |
| `/aapp-digest [idea \| #<num>]` | `aapp-digest` | `aapp draft <slug>` or `aapp draft <slug> issue <num>` |
| `/aapp-tdd <id>` | `aapp-tdd` | `aapp tdd <id>` |
| `/aapp-freeze <id>` | `aapp-freeze` | `aapp freeze <id>` |
| `/aapp-start <id>` | `aapp-start` | `aapp start <id>` |
| `/aapp-fix [#<num>]` | `aapp-fix` | `aapp issue fix <num>` (or `next-blocker`), `aapp commit`, `aapp issue close <num>` |
| `/aapp-done <id>` | `aapp-done` | `aapp done <id>` |
| `/aapp-pause [reason]` | `aapp-pause` | `aapp pause [shared] [reason]`, `aapp resume` |
| `/aapp-release <ver>` | `aapp-release` | `aapp release <version-or-bump>` |

The agent rules (`.agents/AGENTS.md`) list the same workflows under *Skill Index*: an agent whose tool has no skills follows `.agents/skills/<name>/SKILL.md` by hand.

---

## 3. How Skills Reach Each Agent

- **Every agent:** `.agents/skills/<name>/SKILL.md` is the canonical copy, on the `agents` branch. `aapp init` and `aapp upgrade` replace each kit skill with the version in the installed kit and remove retired ones.
- **Claude Code:** each kit skill with a `SKILL.md` is linked into `.claude/skills/<name>` (a relative symlink; a copy where links are not possible). Claude Code's settings, including the `PreToolUse` hook that runs `.githooks/blast-radius-guard` on `Write`, `Edit`, `MultiEdit` and `NotebookEdit`, live in `.agents/claude/settings.json` and are linked as `.claude/settings.json`.
- **Antigravity:** reads `.agents/AGENTS.md`, `.agents/PROJECT.MD` and `.agents/skills/` from the workspace.
- **Cursor:** link or copy `.agents/AGENTS.md` to `.cursor/rules/aapp.mdc` (or `.cursorrules`).
- **GitHub Copilot, Gemini CLI and others:** add a workspace instruction that points to `.agents/AGENTS.md`.

`.claude/`, `.cursor/rules/` and the agent settings are protected paths: no plan may list them in its Target Files, and the write guard refuses edits to them ([02. Blast Radius Engine](../concepts/02-blast-radius-engine.md)).

---

## 4. Custom Skills

A skill is a Markdown file with YAML frontmatter and step-by-step instructions:

```markdown
---
name: corp-security-scan
description: Runs the company security scanner and logs its findings as issues.
---

# Instructions
1. Run `./scripts/corp-security-scan.sh` against the plan's Target Files.
2. For each finding, log an issue: `aapp issue log High SEC "<symptom>" file <path>`.
3. If clean, note the scan in the plan's §6 and commit it with `aapp refine <id> "<what changed>"`.
```

Put it in `.agents/skills/<name>/SKILL.md` under a name that does not start with `aapp`: sync replaces the kit's own `aapp*` and `plan` folders and leaves other names alone. Sync links only the kit's skills into `.claude/skills/`; for Claude Code, link a custom skill there yourself (`ln -s ../../.agents/skills/<name> .claude/skills/<name>`).

---

## 5. Context Efficiency

Agents work within a limited context window. The rules keep what they read small:

- **Active focus only:** in `.plans/state_matrix.md`, read the active sections (`Roadmap`, `1. The Incubator`, `2. The Greenlight Zone`).
- **Archives stay closed:** `.plans/done/` and `.plans/done/000-archive-ledger.md` are terminal records. A plan listed there is complete; agents do not re-read or re-verify it unless the user asks for a historical lookup.
- **Briefing first:** `aapp status` gives the four pillars in one screen; `aapp plan-status <id>` gives one plan's details without opening the file.
- **Syntax on demand:** `aapp help <verb>` prints one verb's arguments at the moment of use, instead of the whole catalog.

---

## 6. Chat vs. Workspace Boundary

Chat output may carry clickable absolute links for the person reading it; files in the repository never do:

1. **Relative paths only:** repository files, plans, commit messages and documentation use repository-relative paths (`docs/reference/...`) or backticked basenames.
2. **No machine paths:** absolute home paths (`/home/...`, `/Users/...`, `C:\...`) and `file://` URIs are not allowed in tracked files.
3. **Enforced:** the pre-commit hook scans staged content and refuses a commit that adds either.

---

## 7. Guardrails for Agents

- **Drafting is free:** an agent may draft a blueprint (`🟣 Under Review` / `📝 Refining`) at any time; a draft confers no right to change code.
- **Freeze is the gate:** a plan becomes executable only through `aapp freeze`, after a person accepts its §2 (design) and §4 (Blast Radius).
- **Fail-closed execution:** in development, an agent may change only the plan's `### 📂 Target Files`. The write guard refuses other edits before they reach disk, and the pre-commit hook refuses to commit them.
- **History is not rewritten:** issue rows and changelog entries are records of their date; closed issues move to the archive unchanged.

**Settings on this page:** [Plans & Worktrees](03-configuration-matrix.md#plans--worktrees)

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
