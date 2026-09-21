# AAPP Cheat Sheet

One page. For the full story see [README.md](README.md) and [MANUAL.md](MANUAL.md).

AAPP keeps **planning, agent rules, and git hooks out of your source tree** — in separate
git worktrees — and stops an AI agent from editing files your plan never declared.

---

## ⚡ The Daily Working Loop (Run Anytime in Shell or Chat)

AAPP supports both conversational AI agent workflows and pure-human standalone terminal commands:

| Command | CLI? | Role & Purpose |
| :--- | :---: | :--- |
| `aapp status [short]` | **✅ Yes** | 4-pillar context recovery briefing (or 'short' for 1-line remote pulse) |
| `aapp draft [slug]` | **✅ Yes** | Scaffold blueprint from template, stamp ID & date, register in matrix |
| `aapp plan [query]` | **✅ Yes** | Educational planning switchboard or query blueprints |
| `aapp plan-status [id]` | **✅ Yes** | Inspect plan lane matrix or specific blueprint details |
| `aapp freeze [id]` | **✅ Yes** | Lock blueprint blast radius & design into frozen backlog spec |
| `aapp start [id]` | **✅ Yes** | Bind execution buffer & transition to ⚡ In Development |
| `aapp freeze-start [id]` | **✅ Yes** | Atomically freeze blueprint and activate execution buffer |
| `aapp done [id]` | **✅ Yes** | Archive implemented blueprint to done/ and update archival ledger |
| `aapp active [id]` | **✅ Yes** | Inspect, swap, or clear active plan execution buffer |

AI agent counterparts: `/aapp-status`, `/aapp-digest [idea]`, `/aapp-freeze [plan]`, `/aapp-start [plan]`, `/aapp-done [plan]`, `/aapp-pause [reason]`, `/aapp-release`, `/aapp-plan` (and `/plan`).

Plans are `P-[num]`, issues are `#[num]`. `aapp freeze P-9`, `aapp freeze 9`, and `aapp freeze guard-path` all resolve to the same blueprint.

---

## 🔄 Team Sync & Emergency Controls

| Command | Role & Purpose |
| :--- | :--- |
| `aapp push` | Push active worktrees (`.plans`, `.agents`, `.githooks`) to remote |
| `aapp pull` | Pull remote updates for active worktrees with non-negotiable `--ff-only` |
| `aapp sync` | Bi-directional sync: pull updates followed by push |
| `aapp pause` | Emergency brake: quarantine in-flight changes into stashes across worktrees |
| `aapp resume` | Disengage brake, verify commit drift, and restore stashes by SHA |

---

## 🛠️ Setup & Maintenance

| Command | Role & Purpose |
| :--- | :--- |
| `aapp init` | Initialize or update AAPP worktrees in current repository |
| `aapp install` | Install AAPP globally into `~/.local/bin` and configure PATH |
| `aapp upgrade` | Upgrade global AAPP binaries & templates from upstream |
| `aapp develop` | Link local development clone globally via symlinks |
| `aapp uninstall` | Remove global AAPP binaries and shared directories |
| `aapp version` | Show installed AAPP version (`-v`, `--version`) |
| `aapp help` | Show grouped command catalog (`-h`, `--help`) |

`aapp init` is idempotent — re-run it after any template change to propagate engines into `.githooks/` and `.agents/`. It never overwrites your own content.

---

## 🪝 Extensibility Catalog: Lifecycle Hooks & Action Plugins

Centralizes hook triggers and plugin contracts structured around execution timing:

| Timing Tier | Prefix | Role & Semantics | Canonical Events |
| :--- | :---: | :--- | :--- |
| **Pre-Mutation Gates** | `pre-*` | **Gating**: Runs *before* disk mutation or Git commit. Exit code `0` = pass; non-zero = **hard abort** with zero state change. | `pre-freeze`, `pre-start`, `pre-done`, `pre-sync` |
| **Action Delegates** | `on-*` | **Delegating**: Executes or replaces the core operation (e.g. custom transport). | `on-sync`, `on-pickup`, `on-digest` |
| **Post-Mutation Observers** | `post-*` | **Observing**: Runs *after* state is securely recorded. Broadcasts telemetry or triggers downstream sync. | `post-freeze`, `post-start`, `post-done`, `post-sync`, `post-pause`, `post-resume` |

### Extension Management Commands

| Command | Role & Purpose |
| :--- | :--- |
| `aapp hooks` | Audit registered lifecycle hooks and verify SHA256 integrity (or `aapp hooks --events`) |
| `aapp hook-test` | Dry-run test a lifecycle event trigger with mock payload |
| `aapp hook-run` | Execute a registered hook handler with specified payload |
| `aapp hook-hash` | Compute SHA256 registration hash for hook script |
| `aapp plugins` | Discover installed action plugins in `.agents/skills/` |

Action plugin entrypoints reside at `.agents/skills/{name}/run` (extension-agnostic executable: binary, `.sh`, `.py`). Standard provider: `aapp-planid`.

---

## 🤖 Attribution & Metadata (AI Switchboard)

Attribution mode is governed by repository configuration (`git config aapp.aiAttribution`):

| Command | Mode / Role | Purpose & Behavior |
| :--- | :--- | :--- |
| `aapp ai-commit` | Public attribution | Switch to public, emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) |
| `aapp ai-notes` | Local-first attribution | Switch to local-first git notes (`refs/notes/commits`) — pristine commit messages |
| `aapp ai-off` | Pure human | Disable AI attribution (default safe state) |
| `aapp ai-credits` | Contributors block | Generate or update alphabetical `AI Contributors` block in `README.md` |
| `aapp ai-status` | Status inspection | Display current AI attribution mode and pending notes |
| `aapp ai-note` | Buffer staging | Pre-stage customizable note buffer for next commit (`--stage`) |

---

## ⚙️ Repository Configuration Reference (`git config aapp.*`)

AAPP controls repository behavior via standard Git configuration:

| Setting Key | Type / Enum | Default | Subsystem | Purpose & Behavior |
| :--- | :--- | :--- | :--- | :--- |
| `aapp.planId` | integer | `1` | Core / Lifecycle | Monotonic Plan ID allocation counter (claimed via `allocate_plan_id`). |
| `aapp.aiAttribution` | `none` / `commit` / `notes` | `none` | AI Attribution | Attribution mode (emailless semantic trailers vs. git notes vs. human). |
| `aapp.aiCredits` | `true` / `false` | `false` | AI Attribution | Automatically maintains alphabetical `AI Contributors` in `README.md`. |
| `aapp.subjectMaxLen` | integer | `72` | Git Hooks | Numeric conciseness limit for commit subject lines (enforced in `aapp-commit-msg`). |
| `aapp.protectStable` | `true` / `false` | `true` | Branch Guard | Refuses direct commits on `main` when dual-branch topology (`develop`) is active. |
| `aapp.devBranch` | string | `develop` | Branch Guard | Target development branch for branch protection parity. |
| `aapp.allowPath` | string (multi) | *(empty)* | Write Guard | External filesystem paths authorized for AI file writes (`blast-radius-guard`). |
| `aapp.remote` | string | `origin` | Remote Sync | Git remote targeted by `aapp push`, `aapp pull`, and `aapp sync`. |
| `aapp.syncStrategy` | `builtin` / `hook` | `builtin` | Remote Sync | Transport engine for worktree sync (`builtin` git plumbing vs custom hook). |
| `aapp.syncWorktrees` | string (list) | `plans agents githooks` | Remote Sync | Space-delimited worktrees synchronized across remotes. |
| `aapp.pullStrategy` | `ff-only` | `ff-only` | Remote Sync | Non-negotiable fast-forward safety invariant for worktree updates. |
| `aapp.allowLocalHooks` | `true` / `false` | `true` | Hook Engine | Enables/disables local clone hook overrides (`git config aapp.hook.[event]`). |
| `aapp.hookTimeout` | integer (seconds) | `10` | Hook Engine | Execution timeout ceiling for local notify hook handlers. |

---

## 📂 Where things live

Four worktrees, none of them on your code branch:

```
.plans/     plans branch      blueprints, issues, pickup     ← your planning brain
.agents/    agents branch     AGENTS.md, skills              ← agent behaviour rules
.githooks/  githooks branch   the enforcement engines        ← never edit by hand
.claude/    (gitignored)      bridge to Claude Code          ← generated by aapp init
```

Four pillars — what `aapp status` reads:

| Pillar | File | Holds |
| :--- | :--- | :--- |
| Shipped | `CHANGELOG.md` | what already landed |
| Issues | `.plans/ISSUES.md` | open defects (resolved ones move to the archive) |
| Plans | `.plans/state_matrix.md` | every active blueprint and its status |
| Pickup | `.plans/pickup.md` | raw ideas, unprocessed |

---

## 🚦 Plan status — these five words only

```
🟣 Under Review  →  📝 Refining  →  🔷 Frozen  →  ⚡ In Development      🟥 BLOCKED
```

`🟥 BLOCKED` withdraws all commit rights for that plan.

---

## 🛑 "My write was refused"

Two layers enforce the Blast Radius:
- **Write-time** — refuses the edit before it happens (agent file-writing tools)
- **Commit-time** — refuses the commit (`git commit`)

**The one rule that matters: do not route around a refusal.** Not with a heredoc, not with
`sed`, not by disabling the hook. A refusal means the file is outside the plan you were given.

Do this instead:
1. The file *should* be in scope → add it to `### 📂 Target Files` in the plan, then retry.
2. The file *shouldn't* be in scope → you've found a real boundary. Stop and ask.
3. It's an unrelated bug you hit mid-plan → log it in `.plans/ISSUES.md` and carry on.

---

## 💡 Three things newcomers trip on

- **Freezing is what grants write access.** A blueprint sitting in the Incubator is a
  document, not a permit.
- **Never edit `.githooks/` or `.agents/skills/aapp-*` directly.** They're regenerated.
  Edit `templates/` and run `aapp init`.
- **`/aapp-digest` takes one idea, not the whole pickup file.** It's a queue you draw from
  deliberately, not a batch to process.
