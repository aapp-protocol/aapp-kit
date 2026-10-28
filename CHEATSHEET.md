# AAPP Cheat Sheet

One page. For the full story see [README.md](README.md), [MANUAL.md](MANUAL.md), and [COOKBOOK.md](COOKBOOK.md).

AAPP keeps **planning, agent rules, and git hooks out of your source tree** — in separate
git worktrees — and stops an AI agent from editing files your plan never declared.

---

## ⚡ The Daily Working Loop (Run Anytime in Shell or Chat)

AAPP supports both conversational AI agent workflows and pure-human standalone terminal commands:

| Command | CLI? | Role & Purpose |
| :--- | :---: | :--- |
| `aapp status [short]` | **✅ Yes** | 4-pillar context recovery briefing (or 'short' for 1-line remote pulse; counts open adoption tasks); unblocks a plan once its blocker's fix commit is in the plan's parent branch |
| `aapp status json` \| `aapp issue list [<n> \| all] json` | **✅ Yes** | The briefing, or the issue list, as one JSON document for scripts (P-94); fields in `docs/reference/08-output-json.md` |
| `aapp draft [slug]` | **✅ Yes** | Scaffold blueprint from template, stamp ID & date, register in matrix |
| `aapp draft <slug> issue <num>` | **✅ Yes** | Promote issue `#<num>`: Target Issue, Planned row and link in the draft commit |
| `aapp draft <slug> group [<id>]` | **✅ Yes** | A group plan (`🧩 Group Plan`) with its amendments member, or a member of group `<id>`; `aapp refine <id> group <gid>\|none` joins or leaves before start |
| `aapp refine <amend-id> request "<summary>" [file <path> [for <id>] \| heading "<h>"]` | **✅ Yes** | A member asks its group's amendments member for a file (`for` the plan it belongs to) or a correction of the group's text; then `approve <n>` / `refuse <n> "<reason>"` (`aapp.amendmentApprovalRequired`; off: approved at once), `decision <n> "<reason>"` for the group's text |
| `aapp commit "<msg>" amendment <n>` | **✅ Yes** | In the requester's worktree: approved request R<n>'s one commit; for another plan it lands on the feature branch at once and that plan records it; the requester's `done` closes the request |
| `aapp refine <id> "<msg>"` | **✅ Yes** | Commit an edit to an active plan's content through the plans commit engine |
| `aapp refine <id> slug <new-slug>` | **✅ Yes** | Rename a plan file; issue links and the matrix follow |
| `aapp refine pickup\|issues "<msg>"` | **✅ Yes** | Commit a validated hand edit of `pickup.md`, or a change to existing rows of `ISSUES.md` (new rows: `aapp issue log`; the work queue: `aapp issue queue`) |
| `aapp refine <id> closes <num> [remove]` | **✅ Yes** | List a further issue the plan sorts (`Also Closes:`), or take it off; `aapp done` closes it with the plan's commit (P-86) |
| `aapp refine <id> blocked <num>` | **✅ Yes** | Block a plan on active issue `#<num>` (Status + `Blocked On:`); chain `&& aapp matrix` |
| `aapp refine <id> unblocked <num>` | **✅ Yes** | Remove closed issue `#<num>` from a plan's `Blocked On:` by hand: for a fix that reached the plan's parent branch as another commit (squash, cherry-pick, rebase) |
| `aapp refine issues "<msg>" branch <num> <name>` | **✅ Yes** | Name the branch issue `#<num>`'s fix must land on (the development branch clears it) |
| `aapp tdd [id]` | **✅ Yes** | Declare a plan's failure-first tests (§3 identifiers, §4 test files) before freeze |
| `aapp plan [query]` | **✅ Yes** | Educational planning switchboard or query blueprints |
| `aapp plan conflict-check <id> <id>… [json]` | **✅ Yes** | Can these plans run at the same time? A group checks its members; exit 1 on a collision |
| `aapp plan conflict-free [<id>\|<group>] [json]` | **✅ Yes** | Plans free to start now, compatible with `<id>`, or a group's members in waves for parallel agents |
| `aapp plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]` | **✅ Yes** | Abandon a plan: archived to `aborted/`, worktree and branch removed, its issue back to 🟡 `Incubated`; a group plan takes its open members and feature branch after a confirmation |
| `aapp plan-status [id]` | **✅ Yes** | Inspect plan lane matrix or specific blueprint details |
| `aapp review draft <id> \| <slug>` | **✅ Yes** | Design review: write a plan's (or a topic's) RFC in `.plans/pickup/`, from the template; local, not committed (`/aapp-review`) |
| `aapp review flag <id> "<finding>" [file <path>]` | **✅ Yes** | Implementation review: sign a finding into the ⚡ plan's §7, from any checkout |
| `aapp review fix <id> F<n> "<task>"` / `fix done <id> F<n>` / `fix decline <id> F<n> "<reason>"` | **✅ Yes** | The implementer answers a finding from the plan's own checkout: a task in §8, ticked, or declined with a reason |
| `aapp review check <id>` | **✅ Yes** | Lists open findings and unticked fixes; exit 1 while any is open |
| `aapp matrix [check]` | **✅ Yes** | Re-derive state matrix from plan Status lines ('check' to audit) |
| `aapp freeze [id]` | **✅ Yes** | Lock blueprint blast radius & design into frozen backlog spec |
| `aapp start [id] [worktree <path> [branch <name>]]` | **✅ Yes** | Bind execution buffer & transition to ⚡ In Development (refused while a queued Plan Blocker names a Target File); with `aapp.planWorktrees on` (or `worktree`), in the plan's own branch and worktree, all or nothing |
| `aapp start <group> [base <branch>]` | **✅ Yes** | Cut the group's feature branch from its parent; members then start from it; the group's `aapp done` gates and merges it into the parent |
| `aapp freeze-start [id] [worktree <path> [branch <name>]]` | **✅ Yes** | Atomically freeze blueprint and activate execution buffer (same pending-fix gate and plan worktree) |
| `aapp commit "<msg>"` | **✅ Yes** | Commit implementation code and record SHA into active plan |
| `aapp done [id]` | **✅ Yes** | Archive implemented blueprint to done/ and update archival ledger; repairs issue links to the plan; with `aapp.integrate` squash/ff/hook, also integrates a worktree plan into its parent branch and cleans up |
| `aapp done <id> integrate [squash\|ff\|hook] [target <b>] [no-cleanup] [force-cleanup] [override-hotfix-cap]` / `no-integrate` | **✅ Yes** | Integrate a worktree plan now (also an archived one, as a retry), or archive only (P-55) |
| `aapp release <version-or-bump> [unverified] [yes] [check] [push] [json] [no-archive] [no-changelog]` | **✅ Yes** | Milestone release bundling, tag ledgers, changelog rollup & hook-based versioning |
| `aapp issue hotfix "<text>" [file <path>]… [branch <name>] [plan]` | **✅ Yes** | Log a blocking bug, queue it, block the plan (one commit; >`aapp.maxEmergencyHotfixes` blocks for good); its fix lands on the plan's parent branch when every file is one of the plan's Target Files, otherwise where the team's `aapp-issue-branch` plugin says (or the development branch), or on `<name>` |
| `aapp issue fix next-blocker \| <num> [file <path> ["<why>"]]… [force] \| <num> abort` | **✅ Yes** | Temporary mini plan for one fix; files outside Location require a reason; held to at most 3 files (`aapp.fixMaxFiles`) and 25 lines (`aapp.fixMaxLines`); collision notice on active plan overlap (`aapp.fixCollision`); made in `.workspace/fix-<num>`; `close` lands it as one commit (P-82) |
| `aapp issue fix <num> group <id>` | **✅ Yes** | A group-caused bug: the issue is retargeted to the group's feature branch, the fix opens in `.workspace/fix-<num>` cut from it; `close` lands it there |
| `aapp active [id]` | **✅ Yes** | Inspect, swap, or clear active plan execution buffer |
| `aapp test [filter]` | **✅ Yes** | Run the kit's own test suites (never the current repository's) |
| `aapp test verb [name]` | **✅ Yes** | Run contract-derived verb suites (`tests/verbs/<name>.sh`) |
| `aapp test jobs <n>` | **✅ Yes** | Run up to `<n>` suites at once; default: CPU count rounded down to a multiple of 4; `jobs 1` is serial |
| `aapp note [cmd]` | **✅ Yes** | Inspect, stage, push, or pull general and AI Git notes |
| `aapp issue queue <num> [urgent \| low \| remove]` | **✅ Yes** | A person clears an issue for work in a level of `## 📋 Queued` (Normal by default; another level moves it), or takes it off; `aapp issue fix` opens only queued issues and plan blockers (P-89) |
| `aapp issue abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]` | **✅ Yes** | Withdraw an issue (wrong, invalid, unwanted): archived as `aborted`; its plan (through `plan abort`) or open mini plan goes with it; plans it blocked resume |
| `aapp issue log <sev> <type> "<symptom>" [file <path>]… [branch <name>] [note "<text>"]` | **✅ Yes** | Log an issue: the id (the tracker's, or the kit's counter) and the row in `ISSUES.md`, one commit (no road-map line; queue with `aapp issue queue`); `note` is kept outside Git |
| `aapp issue close <id>` \| `list [<n> \| all] [confirm]` \| `list note <num>` | **✅ Yes** | Close an issue; list the open ones (syncing with a provider that lists); show one with its description and notes |
| `aapp refine issues "<msg>" note <num> "<text>"` | **✅ Yes** | Add a note to an issue (never committed) |
| `aapp companion [add \| status \| push \| remove \| list]` | **✅ Yes** | Cross-repo bridge across 3 topologies (`checkout`, `worktree`, `clone`); delegates write guards per G1; bounded push & offline status |

AI agent counterparts: `/aapp-status`, `/aapp-digest [idea]`, `/aapp-freeze [plan]`, `/aapp-start [plan]`, `/aapp-done [plan]`, `/aapp-pause [reason]`, `/aapp-release`, `/aapp-plan` (and `/plan`), `/aapp-tdd [plan]`.

Plans are `P-[num]`, issues are `#[num]`. `aapp freeze P-9`, `aapp freeze 9`, and `aapp freeze guard-path` all resolve to the same blueprint.

---

## 🔄 Team Sync & Emergency Controls

| Command | Role & Purpose |
| :--- | :--- |
| `aapp push` | Push active worktrees (`.plans`, `.agents`, `.githooks`) to remote |
| `aapp pull` | Pull remote updates for active worktrees with non-negotiable `--ff-only` |
| `aapp sync` | Bi-directional sync: pull updates followed by push |
| `aapp offline [mount \| unmount [force] \| on \| off \| status \| sync]` | The `.offline` worktree: issues and draft plans staged while a provider is unreachable (or skipped with `on`), under temporary ids; `sync` publishes them and gives them their real ids. Never pushed |
| `aapp pause` | Emergency brake: quarantine in-flight changes into stashes across worktrees |
| `aapp resume` | Disengage brake, verify commit drift, and restore stashes by SHA |
| `aapp companion add <name> <path> [worktree] \| <url>` | Register checkout, dedicated non-AAPP worktree, or clone under `.workspace/companion/` |
| `aapp companion status [name] [json]` | Offline telemetry: active branch, dirty count, ahead/behind vs upstream, last fetch |
| `aapp companion push <name>` | Bounded push: delegates to companion's upstream tracking branch (refuses dirty) |
| `aapp companion remove <name> [force]` | Unlinks checkout, or cleans worktree/clone (guards unpushed commits unless force) |
| `aapp companion list` | List all registered companion repositories, modes, and paths |

---

## 🛠️ Setup & Maintenance

| Command | Role & Purpose |
| :--- | :--- |
| `aapp init` | Initialize or update AAPP worktrees; seeds and syncs `.plans/adoption.md` checklist |
| `aapp install` | Install AAPP globally into `~/.local/bin` and configure PATH |
| `aapp upgrade` | Upgrade global AAPP binaries & templates from upstream |
| `aapp develop` | Link local development clone globally via symlinks |
| `aapp uninstall` | Remove global AAPP binaries and shared directories |
| `aapp version` | Show installed AAPP version (`-v`, `--version`) |
| `aapp help` | Show grouped command catalog (`-h`, `--help`) |
| `aapp help <verb>` | Print that verb's synopsis and arguments, from its installed contract; `aapp <verb> help` is the same |
| `aapp help <verb> full` | Print the verb's whole contract (arguments, refusals, effects, tests) |

`aapp init` is idempotent — re-run it after any template change to propagate engines into `.githooks/` and `.agents/`. It never overwrites your own content and updates `.plans/adoption.md` verification ticks.

---

## 🪝 Extensibility Catalog: Lifecycle Hooks & Action Plugins

Centralizes hook triggers and plugin contracts structured around execution timing:

| Timing Tier | Prefix | Role & Semantics | Canonical Events |
| :--- | :---: | :--- | :--- |
| **Pre-Mutation Gates** | `pre-*` | **Gating**: Runs *before* disk mutation or Git commit. Exit code `0` = pass; non-zero = **hard abort** with zero state change. | `pre-freeze`, `pre-start`, `pre-done`, `pre-refine`, `pre-sync` |
| **Action Delegates** | `on-*` | **Delegating**: Executes or replaces the core operation (e.g. custom transport). | `on-start`, `on-refine`, `on-sync`, `on-pickup`, `on-digest` |
| **Post-Mutation Observers** | `post-*` | **Observing**: Runs *after* state is securely recorded. Broadcasts telemetry or triggers downstream sync. | `post-freeze`, `post-start`, `post-done`, `post-abort`, `post-refine`, `post-sync`, `post-pause`, `post-resume` |

### Extension Management Commands

| Command | Role & Purpose |
| :--- | :--- |
| `aapp hooks` | Audit registered lifecycle hooks and verify SHA256 integrity (or `aapp hooks events`) |
| `aapp hook-test` | Dry-run test a lifecycle event trigger with mock payload |
| `aapp hook-run` | Execute a registered hook handler with specified payload |
| `aapp hook-hash` | Compute SHA256 registration hash for hook script |
| Test gate | `examples/hooks/test-gate.sh.sample` on `pre-done`: `done` refuses unless `TEST_CMD` passes |
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

## ⚙️ Settings (`git config aapp.*`)

Every setting, with its default and every value it accepts, is in the [Configuration Reference](docs/reference/03-configuration-matrix.md); how system and user `main.conf` files layer over it, in the [Configuration Hierarchy](docs/reference/15-configuration-hierarchy.md). By group:

| Group | Keys |
| :--- | :--- |
| [Attribution & Notes](docs/reference/03-configuration-matrix.md#attribution--notes) | `aiAttribution`, `aiNotes`, `aiNotesGuard`, `aiAlias`, `aiAgent`/`aiVendor`/`aiModel` (per worktree), `aiCredits`, `notesRemote`, `noteTTL` |
| [Commits & Changelog](docs/reference/03-configuration-matrix.md#commits--changelog) | `commitMode`, `changelogMode`, `subjectMaxLen`, `commitLineMaxLen`, `bodyMaxLen`, `maxBodyLines`, `changelogMaxLen`, `docs` |
| [Plans & Worktrees](docs/reference/03-configuration-matrix.md#plans--worktrees) | `planWorktrees`, `planBranch`, `planWorktreePath`, `planSession`, `planId`, `planState.<slug>`, `pickupTitleMax` |
| [Groups & Amendments](docs/reference/03-configuration-matrix.md#groups--amendments) | `amendmentApprovalRequired` |
| [Issues & Fixes](docs/reference/03-configuration-matrix.md#issues--fixes) | `issueId`, `issueFixWait`, `fixMaxFiles`, `fixMaxLines`, `fixCollision`, `maxEmergencyHotfixes`, `issueArchiveMax`, `issueSyncWindow`, `issueCacheMax` |
| [Integration](docs/reference/03-configuration-matrix.md#integration) | `integrate`, `integrateTarget`, `integrateCleanup`, `integrateWait`, `autoRebase`, `quarantineIgnored` |
| [Branches, Remote & Sync](docs/reference/03-configuration-matrix.md#branches-remote--sync) | `devBranch`, `protectedBranches`, `protectStable`, `remote`, `syncWorktrees`, `syncStrategy`, `pullStrategy` |
| [Write Guard](docs/reference/03-configuration-matrix.md#write-guard) | `allowPath` |
| [Hooks & Plugins](docs/reference/03-configuration-matrix.md#hooks--plugins) | `hook.<event>`, `allowLocalHooks`, `hookTimeout`, `pluginTimeout` |
| [Offline](docs/reference/03-configuration-matrix.md#offline) | `offlineEnabled`, `offlineOnly`, `offlineIdOffset` |
| [Status & Output](docs/reference/03-configuration-matrix.md#status--output) | `statusOutputWidth`, `statusItemsMax`, `statusTextMax`, `jsonLocalPath` |
| [Release & Templates](docs/reference/03-configuration-matrix.md#release--templates) | `tagPrefix`, `initialVersion`, `releaseBranch`, `testCommand`, `templateSync` |
| [Companion](docs/reference/03-configuration-matrix.md#companion) | `companion.<name>.path`, `companion.<name>.mode` (written by `aapp companion`) |
| [Logging](docs/reference/03-configuration-matrix.md#logging) | `perlLogFile` |

All keys take the `aapp.` prefix: `git config aapp.planWorktrees on`.

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
