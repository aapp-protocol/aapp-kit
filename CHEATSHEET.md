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
| `aapp draft <slug> issue <num>` | **✅ Yes** | Promote issue `#<num>`: Target Issue, Planned row and link in the draft commit |
| `aapp refine <id> "<msg>"` | **✅ Yes** | Commit an edit to an active plan's content through the plans commit engine |
| `aapp refine <id> slug <new-slug>` | **✅ Yes** | Rename a plan file; issue links and the matrix follow |
| `aapp refine pickup\|issues "<msg>"` | **✅ Yes** | Commit a validated hand edit of `pickup.md`, or `ISSUES.md` + road map |
| `aapp refine <id> blocked <num>` | **✅ Yes** | Block a plan on active issue `#<num>` (Status + `Blocked On:`); chain `&& aapp matrix` |
| `aapp tdd [id]` | **✅ Yes** | Declare a plan's failure-first tests (§3 identifiers, §4 test files) before freeze |
| `aapp plan [query]` | **✅ Yes** | Educational planning switchboard or query blueprints |
| `aapp plan-status [id]` | **✅ Yes** | Inspect plan lane matrix or specific blueprint details |
| `aapp matrix [check]` | **✅ Yes** | Re-derive state matrix from plan Status lines ('check' to audit) |
| `aapp freeze [id]` | **✅ Yes** | Lock blueprint blast radius & design into frozen backlog spec |
| `aapp start [id] [worktree <path> [branch <name>]]` | **✅ Yes** | Bind execution buffer & transition to ⚡ In Development (refused while a queued Plan Blocker names a Target File); with `aapp.planWorktrees on` (or `worktree`), in the plan's own branch and worktree, all or nothing |
| `aapp freeze-start [id] [worktree <path> [branch <name>]]` | **✅ Yes** | Atomically freeze blueprint and activate execution buffer (same pending-fix gate and plan worktree) |
| `aapp commit "<msg>"` | **✅ Yes** | Commit implementation code and record SHA into active plan |
| `aapp done [id]` | **✅ Yes** | Archive implemented blueprint to done/ and update archival ledger; repairs issue links to the plan; with `aapp.integrate` squash/ff/hook, also integrates a worktree plan into its parent branch and cleans up |
| `aapp done <id> integrate [squash\|ff\|hook] [target <b>] [no-cleanup] [force-cleanup] [override-hotfix-cap]` / `no-integrate` | **✅ Yes** | Integrate a worktree plan now (also an archived one, as a retry), or archive only (P-55) |
| `aapp issue hotfix "<text>" [file <path>]… [plan]` | **✅ Yes** | Log a blocking bug, queue it, block the plan (one commit; >`aapp.maxEmergencyHotfixes` blocks for good) |
| `aapp issue fix next-blocker \| <num> [file <path>…] \| <num> abort` | **✅ Yes** | Temporary mini plan for one fix, files from the issue's Location; waits up to `aapp.issueFixWait` for an open fix or uncommitted work (skill: `/aapp-fix [#<num>]`) |
| `aapp active [id]` | **✅ Yes** | Inspect, swap, or clear active plan execution buffer |
| `aapp test [filter]` | **✅ Yes** | Run test suites across repository or audit adopter environment |
| `aapp test verb [name]` | **✅ Yes** | Run contract-derived verb suites (`tests/verbs/<name>.sh`) |
| `aapp note [cmd]` | **✅ Yes** | Inspect, stage, push, or pull general and AI Git notes |
| `aapp issue [cmd]` | **✅ Yes** | Peek, allocate, close, or list issue IDs |

AI agent counterparts: `/aapp-status`, `/aapp-digest [idea]`, `/aapp-freeze [plan]`, `/aapp-start [plan]`, `/aapp-done [plan]`, `/aapp-pause [reason]`, `/aapp-release`, `/aapp-plan` (and `/plan`), `/aapp-tdd [plan]`.

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
| `aapp help <verb>` | Print that verb's installed contract (arguments, refusals, effects) |

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
| `aapp hooks` | Audit registered lifecycle hooks and verify SHA256 integrity (or `aapp hooks events`) |
| `aapp hook-test` | Dry-run test a lifecycle event trigger with mock payload |
| `aapp hook-run` | Execute a registered hook handler with specified payload |
| `aapp hook-hash` | Compute SHA256 registration hash for hook script |
| `aapp plugins` | List kit-reserved plugins (`lib/plugins.tsv`, installed or not), then your own from `.agents/skills/` |

Action plugin entrypoints reside at `.agents/skills/{name}/run` (extension-agnostic executable: binary, `.sh`, `.py`). Kit-reserved names live in the shipped registry `lib/plugins.tsv` (never edit it; avoid the `aapp-` prefix for your own). Standard providers: `aapp-planid`, `aapp-issue-tracker` (JSON envelope on stdin, one JSON object on stdout).

---

## 🤖 Attribution & Metadata (AI Switchboard)

Attribution mode is governed by repository configuration (`git config aapp.aiAttribution`):

| Command | Mode / Role | Purpose & Behavior |
| :--- | :--- | :--- |
| `aapp ai lax` | Lax attribution | Switch to lax attribution (validates trailers if present; human commits pass freely) |
| `aapp ai strict` | Strict attribution | Switch to strict attribution (enforces valid trailers on every commit) |
| `aapp ai notes` | Local-first attribution | Switch to local-first git notes mode (`refs/notes/commits`) — pristine commit messages |
| `aapp ai none` | Pure human | Disable AI attribution (pure human authoring) |
| `aapp ai credits` | Contributors block | Generate or update alphabetical `AI Contributors` block in `README.md` |
| `aapp ai status` | Status inspection | Display current AI attribution mode and pending notes |

---

## ⚙️ Repository Configuration Reference (`git config aapp.*`)

AAPP controls repository behavior via standard Git configuration:

| Setting Key | Type / Enum | Default | Subsystem | Purpose & Behavior |
| :--- | :--- | :--- | :--- | :--- |
| `aapp.planId` | integer | `1` | Core / Lifecycle | Monotonic Plan ID allocation counter (claimed via `allocate_plan_id`). |
| `aapp.changelogMode` | `plan` / `commit` | `plan` | Git Hooks | `plan`: one entry per plan from its `**Changelog:**` line, written by `aapp commit`. `commit`: every code commit changes `CHANGELOG.md`. |
| `aapp.commitMode` | `atomic` / `microcommits` | `atomic` | `aapp commit`, Git Hooks | `atomic`: one commit per plan (`aapp commit amend` for more). `microcommits`: any number. |
| `aapp.issueFixWait` | minutes | `5` | `aapp issue fix` | How long `fix` and the issue lock wait for an open fix or uncommitted work; `0` fails at once (P-52, P-58). |
| `aapp.maxEmergencyHotfixes` | integer | `2` | `aapp issue hotfix` | Hotfixes a plan may take; the next one blocks it permanently. P-55 reads it at integration (P-52). |
| `aapp.planWorktrees` | `on` / `off` | `off` | `aapp start`, `freeze-start` | A plan's first start creates its own branch and worktree (P-54). |
| `aapp.planBranch` | template | `plan/{id}-{slug}` | `aapp start` | Plan branch name; `{id}` (`P51`), `{num}`, `{slug}`, `{repo}` (P-54). |
| `aapp.planWorktreePath` | template | `../{repo}-{id}` | `aapp start` | Plan worktree path, relative to the primary checkout (P-54). |
| `aapp.planSession` | command template | *(unset, personal)* | `aapp start` | Opens a session in the new plan worktree, detached; `{path}`, `{id}`, `{branch}`, `{slug}`, `{plan_file}` shell-quoted (P-54). |
| `aapp.integrate` | `manual` / `squash` / `ff` / `hook` | `manual` | `aapp done` | How `done` integrates a worktree plan into its parent branch; `manual` prints advice only (P-55). |
| `aapp.integrateTarget` | `parent` / `dev` / `<branch>` | `parent` | `aapp done` | Target: the plan's `Base:` branch, the development branch, or a named branch (P-55). |
| `aapp.integrateCleanup` | `true` / `false` | `true` | `aapp done` | Remove the plan worktree and branch after integrating (P-55). |
| `aapp.quarantineIgnored` | `true` / `false` | `false` | `aapp done` | Copy sensitive ignored files (`.env*`, keys) into `.git/aapp_quarantine/<id>/` before removal; otherwise they refuse the cleanup (P-55). |
| `aapp.issueId` | integer | *(unset)* | Core / Lifecycle | Monotonic issue ID counter (claimed via `aapp issue allocate`; seeded from both issue ledgers on first use). |
| `aapp.planState.<slug>` | string (multi) | *(kit defaults)* | Core / Lifecycle | Custom plan status as `<emoji>\|<name>\|<heading>\|<rank>`; overrides a shipped status when the slug matches. |
| `aapp.aiAttribution` | `none` / `lax` / `strict` / `notes` | `none` | AI Attribution | Attribution mode: none (default; human-only), lax (mixed human/AI), strict (mandatory trailers), notes (private git notes). |
| `aapp.aiCredits` | `true` / `false` | `false` | AI Attribution | Automatically maintains alphabetical `AI Contributors` in `README.md`. |
| `aapp.subjectMaxLen` | integer | `72` | Git Hooks | Numeric conciseness limit for commit subject lines (enforced in `aapp-commit-msg`). |
| `aapp.protectStable` | `true` / `false` | `true` | Branch Guard | Refuses direct commits on `main` when dual-branch topology (`develop`) is active. |
| `aapp.devBranch` | string (list) | `develop dev development` | Branch Guard, `aapp start` | Candidate development branches, first present (local or remote) wins; plan worktrees branch from it, else the default branch (P-54). |
| `aapp.allowPath` | string (multi) | *(empty)* | Write Guard | External filesystem paths authorized for AI file writes (`blast-radius-guard`). |
| `aapp.remote` | string | `origin` | Remote Sync | Git remote targeted by `aapp push`, `aapp pull`, and `aapp sync`. |
| `aapp.syncStrategy` | `builtin` / `hook` | `builtin` | Remote Sync | Transport engine for worktree sync (`builtin` git plumbing vs custom hook). |
| `aapp.syncWorktrees` | string (list) | `plans agents githooks` | Remote Sync | Space-delimited worktrees synchronized across remotes. |
| `aapp.pullStrategy` | `ff-only` | `ff-only` | Remote Sync | Non-negotiable fast-forward safety invariant for worktree updates. |
| `aapp.allowLocalHooks` | `true` / `false` | `true` | Hook Engine | Enables/disables local clone hook overrides (`git config aapp.hook.[event]`). |
| `aapp.hookTimeout` | integer (seconds) | `10` | Hook Engine | Execution timeout ceiling for local notify hook handlers. |
| `aapp.notesRemote` | string | *(unset)* | Git Notes | Git remote for notes push/pull (unset = local-first). |
| `aapp.aiNotesGuard` | `warn` / `enforce` | `warn` | Git Notes | Audit guard mode: surfaces warnings (default) or enforces lossless settings on refs/notes/ai. |

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

## 💡 Things newcomers trip on

- **Freezing is what grants write access.** A blueprint sitting in the Incubator is a
  document, not a permit.
- **Never edit `.githooks/` or `.agents/skills/aapp-*` directly.** They're regenerated.
  Edit `templates/` and run `aapp init`.
- **`/aapp-digest` takes one idea, not the whole pickup file.** It's a queue you draw from
  deliberately, not a batch to process.
- **Cloned repos without `aapp` are in Inspection-Only mode.** If `git commit` warns of
  INSPECTION-ONLY mode, install AAPP globally (`aapp install`) to unlock commits.
