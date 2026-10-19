---
title: Agent Skills & Slash Commands Reference
description: Reference catalog for the 13 Universal AI Agent Skills, slash command routing, tool bindings, custom skills, and chat-vs-workspace disjointness invariants.
---

# 🤖 Agent Skills & Slash Commands Reference

AAPP equips autonomous coding assistants (Claude Code, Google Antigravity, Cursor, Codex, OpenCode) with high-discipline planning skills. These skills mirror the CLI capabilities while enforcing strict blast-radius isolation, atomic worktree commits, and failure-first TDD methodology.

---

## 1. Universal Skills Catalog

The system distributes 13 standardized skills under `.agents/skills/` (and synchronizes with platform-specific directories such as `.claude/skills/`):

| Skill Name | Canonical Path | Primary Responsibility |
| :--- | :--- | :--- |
| **`aapp`** | `.agents/skills/aapp/SKILL.md` | Session bootstrap. Reads full protocol rules, runs status briefings, and prepares context for work. |
| **`aapp-status`** | `.agents/skills/aapp-status/SKILL.md` | Context recovery upon returning to a repository. Scans the 4 pillars (Shipped, Issues, Plans, Pickup) and generates briefings. |
| **`aapp-plan`** | `.agents/skills/aapp-plan/SKILL.md` | Canonical blueprint planning in `.plans/current/` (replaces scratchpads). |
| **`aapp-digest`** | `.agents/skills/aapp-digest/SKILL.md` | Ingests raw ideas from `pickup.md` or issues from `ISSUES.md` into blueprints. |
| **`aapp-tdd`** | `.agents/skills/aapp-tdd/SKILL.md` | Injects failure-first test specifications into §3 and §4 before freeze. |
| **`aapp-freeze`** | `.agents/skills/aapp-freeze/SKILL.md` | Design lock and greenlight authorization (`🔷 Ready for Execution`). |
| **`aapp-start`** | `.agents/skills/aapp-start/SKILL.md` | Plan activation (`⚡ In Development`), disjointness audit, buffer binding. |
| **`aapp-commit`** | `.agents/skills/aapp-commit/SKILL.md` | Plan-bound commit helper with attribution trailers and SHA recording. |
| **`aapp-fix`** | `.agents/skills/aapp-fix/SKILL.md` | Worktree-isolated mini-plan execution for queued bug fixes (`#<num>`). |
| **`aapp-pause`** | `.agents/skills/aapp-pause/SKILL.md` | Emergency brake: halts writes and stashes active uncommitted work. |
| **`aapp-release`** | `.agents/skills/aapp-release/SKILL.md` | Milestone release orchestrator with preflight verification and bundling. |
| **`aapp-done`** | `.agents/skills/aapp-done/SKILL.md` | Post-implementation verification, archive relocation, matrix cleanup. |
| **`aapp-hooks`** | `.agents/skills/aapp-hooks/SKILL.md` | Validates, hashes, and dispatches extensible lifecycle events. |

---

## 2. Slash Commands & UI Dispatch

In supported AI development environments (such as Antigravity, Claude Code, or Cursor), slash commands provide rapid triggers for agent skills:

| Command | Backing Skill | CLI Action / Workflow Purpose |
| :--- | :--- | :--- |
| `/aapp` | `aapp` | Run at the start of every session to establish baseline context and load full rules. |
| `/aapp-status` | `aapp-status` | Run when returning to the editor after a break or switching tasks. |
| `/aapp-plan [slug]` | `aapp-plan` | Scaffolds a new canonical blueprint draft (`aapp draft <slug>`). |
| `/aapp-digest [id]` | `aapp-digest` | Digests an idea or issue into a structured blueprint (`aapp draft <slug> issue <id>`). |
| `/aapp-tdd <id>` | `aapp-tdd` | Injects failure-first test specifications into plan before freeze. |
| `/aapp-freeze <id>` | `aapp-freeze` | Seals a blueprint's technical design and blast radius (`aapp freeze <id>`). |
| `/aapp-start <id>` | `aapp-start` | Starts active development in an isolated worktree (`aapp start <id>`). |
| `/aapp-fix <num>` | `aapp-fix` | Immediately claims and resolves a bug listed in `.plans/issues_road_map.md`. |
| `/aapp-pause [reason]` | `aapp-pause` | Safely stashes in-flight worktree modifications and halts autonomous actions. |
| `/aapp-release <ver>` | `aapp-release` | Verifies branch parity, runs test suites, rolls changelog, and tags release. |
| `/aapp-done <id>` | `aapp-done` | Archives an active plan after verification and testing are complete. |

---

## 3. Chat vs. Workspace Boundary Invariant

To maintain repository portability across diverse developer environments and continuous integration runners, AAPP enforces a strict boundary between chat interactions and workspace storage:

```mermaid
flowchart TD
    subgraph Chat_Interface["Conversational Chat Output"]
        UI["Conversational Responses<br/>Avoid leaking machine-specific home paths"]
    end

    subgraph Tracked_Files["Tracked Repository Workspace Files"]
        REPO["Strictly Relative Paths Only<br/>Basename backticks (e.g., `lib/plan_resolver.sh`)"]
    end

    Chat_Interface -. "NEVER BLEEDS INTO" .-> Tracked_Files
```

### The Invariant Rules
1. **Relative Paths Invariant**: All repository files, plans, commit messages, and documentation must use repository-relative paths (e.g. `docs/reference/...`) or backticked basenames.
2. **Zero Machine Path Leaks**: Machine-specific absolute home directories (`/home/...`, `/Users/...`, `C:\...`) and absolute file URI schemes are strictly prohibited from tracked files to guarantee portability across developer environments.
3. **Mechanical Guard**: The pre-commit hook scans all staged content for machine-specific paths and absolute schemes. Any occurrence causes immediate commit refusal.

---

## 4. Human-in-the-Loop Governance & Autonomy Guardrails

AAPP balances AI agent speed with strict architectural control:

- **Free Drafting**: Agents may freely draft incubator blueprints (`📝 Refining`) to explore solutions or digest pickup ideas. Drafting incurs no risk and confers no code execution authority.
- **Human Greenlight**: A blueprint can only transition to `🔷 Ready for Execution` via human sign-off (`aapp freeze`). The human verifies that Section 2 (Technical Blueprint) and Section 4 (Blast Radius) are sound.
- **Fail-Closed Execution**: Once an agent begins execution (`⚡ In Development`), it is mechanically trapped within the declared `### 📂 Target Files`. Any tool call or shell write attempting to modify out-of-scope files is aborted.
- **Immutable Historical Records**: Agents may never rewrite closed issue logs or historical changelogs. Closed rows are strictly appended to archive ledgers without prose modification.

---

## 5. Customizing Skills for Your Organization

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
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
