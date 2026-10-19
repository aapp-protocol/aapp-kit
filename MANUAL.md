# 📖 Asymmetric Agent Planning Protocol (AAPP) — Technical Manual

> **The executive technical manual and navigational portal for zero-drift autonomous agent workflows.**
>
> 🍳 **Practical Recipes**: For task-oriented how-to guides, see the [AAPP Cookbook](COOKBOOK.md).  
> ⚡ **Quick Reference**: For daily terminal commands and quick lookups, see [CHEATSHEET.md](CHEATSHEET.md).  
> 🏠 **Repository Overview**: For project pitch and installation quickstart, see [README.md](README.md).

---

## 🏛️ 1. Core Architectural Axioms

The AAPP runtime enforces four fundamental axioms mechanically through Git plumbing and verification hooks:

1. **Zero Context Pollution (Orphan Worktrees)**:
   Agent behavioral rules (`.agents/`), planning scratchpads (`.plans/`), and enforcement engines (`.githooks/`) reside on isolated Git orphan branches mounted as concurrent worktrees. Planning artifacts, debate scratchpads, and agent instructions never touch application source history.
   *Specification*: [Worktree Architecture](docs/concepts/01-worktree-architecture.md) · [Git Plumbing Mechanics](docs/reference/12-git-plumbing.md).

2. **The Blast Radius Lock (Deterministic Containment)**:
   Autonomous agents are strictly confined to the explicit `### 📂 Target Files` declared in the active blueprint. Layer 1 (`blast-radius-guard`) intercepts write tool operations before touching disk, and Layer 2 (`aapp-pre-commit`) validates staged changes at commit time.
   *Specification*: [Blast Radius Engine](docs/concepts/02-blast-radius-engine.md) · [Security & Threat Model](docs/concepts/04-security-and-threat-model.md).

3. **The Two-Lane Separation Law (Issues vs. Plans)**:
   Defects in existing shipping code are tracked in the flat issue ledger (`.plans/ISSUES.md`). New features, capabilities, and multi-file refactors are tracked as blueprints in `.plans/current/`. The lanes never merge. Resolved issues are physically relocated to archive ledgers.
   *Specification*: [Two-Lane Governance](docs/concepts/03-two-lane-governance.md) · [Issue Protocol](docs/reference/07-issue-protocol.md).

4. **The Clean Break Invariant (Zero Backward Fallbacks)**:
   In refactors, migrations, and schema upgrades, clean breaks are the mandatory default. Autonomous agents never unilaterally introduce backwards-compatibility shims, legacy aliases, or dual-syntax parser regexes unless explicitly registered in the blueprint's Section 2.
   *Specification*: [Document Governance](docs/reference/11-document-governance.md) · [Integration & Rebase](docs/reference/10-integration-and-rebase.md).

---

## 🧭 2. Master Specification Map (The Diátaxis Directory)

AAPP organizes technical documentation following the Diátaxis architecture:

### 💡 Conceptual Specifications (`docs/concepts/`)
High-level architectural deep-dives explaining mechanics, design rationale, and trust models:
* [01. Worktree Architecture & Storage Primitives](docs/concepts/01-worktree-architecture.md): Orphan branches, detached commits, and worktree isolation.
* [02. Dual-Layer Blast Radius Enforcement](docs/concepts/02-blast-radius-engine.md): Write-time interception and commit-time verification gates.
* [03. Two-Lane Governance (Issues vs. Plans)](docs/concepts/03-two-lane-governance.md): Issue ledgers, relocation invariants, and plan promotion.
* [04. Security Boundaries & Threat Model](docs/concepts/04-security-and-threat-model.md): Pair-programming containment and shell containment boundaries.

### 📚 Reference Manuals (`docs/reference/`)
Authoritative, exhaustive specifications, schemas, tables, and lookup dictionaries:
* [01. Lifecycle State Machine](docs/reference/01-lifecycle-state-machine.md): Plan statuses, state transitions, and execution gates.
* [02. CLI Commands & Verbs Reference](docs/reference/02-cli-commands-and-verbs.md): All 35 CLI verbs across 4 tested tiers with parameter variations.
* [03. Configuration Matrix](docs/reference/03-configuration-matrix.md): Exhaustive table of 22+ `git config aapp.*` settings and defaults.
* [04. Plugin & Hook Engine](docs/reference/04-plugin-and-hook-engine.md): 5-column `registry.tsv` contract, dual delivery, and 17 lifecycle triggers.
* [05. AI Attribution Suite & Notes](docs/reference/05-ai-attribution-and-notes.md): Emailless semantic trailers, Git notes asymmetry, and switchboard modes.
* [06. Action Plugin Protocol](docs/reference/06-plugin-protocol.md): JSON envelope exchange contract for external action plugins.
* [07. Issue Tracker Protocol](docs/reference/07-issue-protocol.md): External tracker integration, event payloads, and sync loops.
* [08. JSON Output Schemas](docs/reference/08-output-json.md): Structured telemetry schemas for programmatic CLI consumers.
* [09. Event Telemetry & Logging](docs/reference/09-event-telemetry.md): Append-only out-of-tree event audit logging contracts.
* [10. Worktree Integration & Rebase](docs/reference/10-integration-and-rebase.md): Rebase rules, squash integration, and worktree cleanup.
* [11. Three-Tier Document Governance](docs/reference/11-document-governance.md): Engine templates, hybrid files, and pure domain data tiers.
* [12. Git Plumbing & Worktree Mechanics](docs/reference/12-git-plumbing.md): Detached orphan commits, remote synchronization, and worktree repair.
* [13. Planning Health Integrity Engine](docs/reference/13-planning-health-engine.md): 8 invariant check pairs and `aapp doctor` diagnostics.
* [14. Agent Skills & Slash Commands](docs/reference/14-agent-skills-and-slash-commands.md): 13 universal skills, slash command bindings, and custom skills.
* [15. Configuration Hierarchy & Precedence](docs/reference/15-configuration-hierarchy.md): Git config resolution order and CI environment variables.
* [16. Configuration Options & Catalog](docs/reference/16-configuration-options.md): Complete Git config key catalog and resolution scopes.
* [17. Planning Health Diagnostics](docs/reference/17-planning-health-diagnostics.md): Automated static analysis, `aapp doctor` tooling, and repair commands.
* [18. Agent Skills Catalog](docs/reference/18-agent-skills-catalog.md): Universal skills catalog, ASCII dispatch, and execution bounds.
* [19. Interactive Skills & Slash Commands](docs/reference/19-skills-and-slash-commands.md): Chat UI slash commands, IDE triggers, and custom skill authoring.

### 🍳 Practical Recipes & Operations
* [AAPP Cookbook](COOKBOOK.md): Hands-on recipes organized by topic under `docs/recipes/`.
* [Troubleshooting Guide](docs/guides/01-troubleshooting.md): Diagnosing and recovering from common errors, blocks, and desynchronizations.

---

## ⚡ 3. Quick Operational Cheat Matrix

| Objective | CLI Command | Slash Command | Enforced Precondition |
| :--- | :--- | :--- | :--- |
| **Morning Briefing** | `aapp status` | `/aapp` or `/aapp-status` | Clean git status |
| **Draft Plan** | `aapp draft <slug> [issue <n>]` | `/aapp-plan` | Free incubator drafting |
| **Declare TDD Tests** | `aapp tdd <id>` | `/aapp-tdd` | Plan in `📝 Refining` |
| **Freeze Design** | `aapp freeze <id>` | `/aapp-freeze` | Questions resolved |
| **Activate Execution** | `aapp start <id>` | `/aapp-start` | Plan in `🔷 Frozen` |
| **Plan-Bound Commit** | `aapp commit "<msg>"` | — | Inside Target Files |
| **Close & Archive** | `aapp done <id>` | `/aapp-done` | Verification complete |
| **Fix Queued Bug** | `aapp issue fix <num>` | `/aapp-fix` | Cleared on roadmap |
| **Emergency Brake** | `aapp pause [reason]` | `/aapp-pause` | Quarantines stashes |

---

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](COOKBOOK.md)
- ⚡ [Daily Cheatsheet](CHEATSHEET.md)
- 🏠 [Repository Overview](README.md)
