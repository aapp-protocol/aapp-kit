# 🧩 Group Plan P-103: Group Lifecycle And Amendments
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-17
* **Plan ID:** P-103
* **Changelog:** Added: groups take what development finds through an amendments member with approval, plans in development are amended only from their own checkout, and a group's `done` gates before its docs commit (P-103)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Feature Branch:** none
* **Members:** P-101, P-102, P-99
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-103` (or `aapp refine <id> group P-103`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
The lifecycle of a group, from its start to its `done`:
1. **While members are in development**, a plan in development is amended only from its own checkout, and a refusal redirects the agent (P-99). What development finds goes to the group's amendments member: members request, an approver grants, the amendments member implements and lands on the feature branch, members rebase (P-101). Members are never amended after start.
2. **At the group's end**, nothing that claims delivery is committed before every check has passed, and cleanup is the last step (P-102, #165).

Review: `.plans/pickup/p103-group-lifecycle-rfc.md` (settled 2026-10-17; user decisions in its §4).

---

## 2. Shared Decisions
- **Feature branch:** `feature/group-lifecycle-and-amendments`, cut from `develop`.
- **Ownership by place.** The owner of a plan in development is its checkout, never something an agent holds (no ID, token or process). The risk addressed is an accident out of good will; a clear refusal at the right place prevents it (layer 0).
- **Members are never widened.** Every mid-development addition goes through the amendments member, approved when `aapp.amendmentApprovalRequired` is `true` (default). Approval is enforced by the existing blast radius: an unapproved file is not in the amendments member's Target Files.
- **Amendments land on the feature branch, members rebase**, as they take a parent's commits; fast-forward only, by P-55's path. A landed test may wait for a member's work (TDD one level up); the order it creates is shown, not prevented.
- **Trace:** every change to an amendments plan is a plans commit; `pre-refine` / `on-refine` / `post-refine` carry every refine elsewhere; landed commits carry `Plan-ID: <amend-id>`. A group is never squashed, so landed amendments reach the parent as they are.
- **One guide:** the group plan's `## Architecture & Codemap` is the only guide members code from. Once the group is frozen it changes only through the amendments member: the corrected section is written into the group plan with a `Decisions` line in the amendments member, in one commit (P-99's lock accepts nothing else). Members read it when they start and at every session start or resume. The archived group plan shows what was implemented.
- **Gate before delivery claims:** a group's `done` runs the gate before its docs commit, restores the docs when a hook refuses it, and cleans up last.

---

## 3. Members & Order
One after the other: all three list `lib/cmd_plan.sh`.
1. **P-102** (`P102-group-done-lifecycle-order.md`, #165): the order of a group's `done`.
2. **P-99** (`P99-amending-plans-in-development.md`): owner-only refine and its refusal, the group section lock and the amendments lock rule, the `refine` events.
3. **P-101** (`P101-group-amendments-member.md`): the amendments member, built on P-99.

This group has no amendments member of its own: P-101 introduces it.

---

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
<!-- aapp-base: new -->
````markdown
## Group Lifecycle: Ownership, Amendments, Done (P-103)

**A plan in development belongs to its checkout (P-99).** A `refine` that edits a plan in development runs only from its recorded worktree, or, for a plan without one, from the checkout whose active-plan buffer holds it. Elsewhere it is refused, and the refusal says what to do instead: tell the developer, log an issue, or add a pickup line. Ownership rests on the place, never on something an agent holds: sessions lose memory on a reboot or a session cap. Verbs that write defined fields (commit SHAs, blocked state, closes, a group's members, amendments requests) run from any checkout. Every `refine` fires `pre-refine` (gate), `on-refine` (in-transaction) and `post-refine` (observer), with the kind of refine in the payload. The design lock also covers a frozen group's `## Architecture & Codemap`.

**Members are never amended after start (P-101).** Each group has an amendments member (`* **Kind:** amendments`), drafted with the group and archived last. A member's session requests a file or decision (`refine <amend-id> request`); with `aapp.amendmentApprovalRequired` (default `true`) an approver, a person or a managing agent, approves it, which adds the file to the amendments member's Target Files, the one §4 change the lock accepts for that kind. The amendments member implements, then lands its commits on the feature branch by fast-forward (`commit … land`, P-55's path, no test gate); members rebase onto the feature branch as they take a parent's commits. A landed test may wait for a member's work; status shows the order it creates. Request lines move `pending` → `approved` | `refused` → `landed`, by verbs only; `plan-status` and `status` show them. That member is the group's ordered record of what its planning missed. The group plan's `## Architecture & Codemap` stays the one guide: a correction is written into it, recorded in the amendments member's `Decisions` in the same commit, and members re-read it at start and at every session start or resume.

**A group's `done` gates before it claims delivery (P-102).** Checks and the gate run on the feature branch first; only then are the `ARCHITECTURE.md` sections and the umbrella changelog entry committed, restored by `reset --hard` when a hook refuses that commit. The group is archived, the parent fast-forwarded, the `.agents/CODEMAP.md` sections committed, and cleanup runs last.
````

### .agents/CODEMAP.md
<!-- aapp-base: fb240cf3411db7fb3a58d2536804b665634c24d51af1a69a5843ad2abfd1d0a1 -->
````markdown
### 🎯 Plan Lifecycle Switchboard (`lib/cmd_plan.sh`)
* **Purpose:** Single source of truth for in-flight plan execution state and worktree context buffers.
* **Key Commands:**
  * `aapp refine <plan> "<msg>"` -> Commits an edit to an active plan's content (only the plan file, through `plans_commit`); the agents' path for plan edits, so nothing runs raw git on `.plans` (P-47). Tokens: `blocked <num>` (`plan_block_on`, P-49); `slug <new-slug>` renames the file and repairs links (`_refine_slug`, P-50). Reserved targets `pickup` / `issues` commit validated ledger edits (`_refine_ledger` + `check_ledger_issues` / `check_pickup_entries` in `planning_health.sh`, P-50). A plan in development, and every plan of a group in development, is refined only from its owning checkout (its recorded worktree, else the checkout whose buffer holds it; for a group, a checkout bound to one of its plans); elsewhere the refusal names the owner and says what to do instead (P-99). Verb-written fields stay open from any checkout. Every refine fires `pre-refine` (gate), `on-refine` (in-transaction) and `post-refine` (observer) with its `kind` (P-99).
  * Amendments member (P-101) -> a member with `* **Kind:** amendments` (`templates/amendments-template.md`), drafted with its group, archived last. `refine <amend-id> request "<summary>" [file <path> | heading "<heading>"]` (from a checkout of the group; the requester from its buffer), `approve <n>` / `refuse <n> "<reason>"` (`aapp.amendmentApprovalRequired`, default `true`; approving adds the file to its Target Files after the disjointness check), `file <path> "<reason>"` (approval not required), `decision <n> "<reason>"` (the corrected group section and its `Decisions` line in one plans commit). Request lines move `pending` → `approved` | `refused` → `landed` | `applied`, by verbs only. Its `done` refuses while another member is open or a request is pending or approved but not landed or applied; with no commit it is archived with `none` in the ledger.
  * `aapp draft <slug> issue <num>` -> promotion: Target Issue, `issue_mark_planned`, one commit (P-50).
  * `aapp tdd <plan>` -> Injects failure test declaration sections (`### 🧪 Required Tests` in §3, `### 🧪 Required Test Files` in §4) into an incubator blueprint before freeze.
  * `aapp freeze-start <plan>` -> Atomic validator, disjointness check, status update (`⚡`), and buffer binding.
  * `aapp freeze <plan>` -> Locks blueprint into 🔷 Frozen backlog specification, verifying TDD correspondence if present.
  * `aapp start <plan>` -> Activates frozen specification (`🔷`) into development (`⚡`). A group member's start prints where to read the group's `## Architecture & Codemap` (P-101).
  * Plan worktrees (P-54) -> `_wt_parse_tokens` (`worktree`/`branch`), `_wt_prepare` (render, refuse, base), `_wt_create` (worktree, kit links, `info/exclude`, bind), `_wt_locate` (read back after `on-start`), `_wt_rollback` (snapshot restore), `_wt_session` (`aapp.planSession`, detached); `_wt_start` runs them as one transaction for `start` and `freeze-start` on a plan's first start. `done` refuses a dirty plan worktree, clears the holding worktree's buffer and prints the removal advice.
  * `aapp done <plan>` -> Archives implemented plan to `done/`, enforcing mechanical TDD completion gate (`tdd (N/N)` recorded in archive ledger).
  * Plan branch integration (P-55) -> `_ig_parse_tokens`, `_ig_decide` (worktree plans only; `aapp.integrate`), `_ig_preflight` (every check before the archive; issue lock), `_ig_run` (squash / ff / `on-integrate` after the archive; retry-safe; for a group, the CODEMAP sections between the integration and the cleanup), `_ig_message` (lineage + attribution trailers), `_ig_cleanup` (ignored-file refusal, quarantine, always last), `_ig_resolve_done` / `_ig_standalone` (`done <id> integrate` on an archived plan). `_ig_preflight` and the fast-forward also serve `commit … land` (P-101).
  * Further issues a plan closes (P-86) -> `plan_also_closes(plan_file)` (the ids of `* **Also Closes:**`), `_refine_closes(plan, num, [remove])` (`refine <plan> closes <num> [remove]`: active issue, not the plan's own Target Issue; the row is not touched); `cmd_done` archives each listed issue with the recorded commit after the Target Issue, skipping an archived one and leaving open one whose branch neither is the plan's parent nor holds the commit; `_issue_dependent_ids` in `cmd_issue.sh` counts them.
  * The squash on the plan branch (P-84) -> `plan_made_for_issue(plan_file)` (the plan's `Target Issue` and the issue's `Planned` row linking the plan agree; used by `start` / `freeze-start` to give such a plan its own worktree, and by `done`), `_sq_decide` (every plan under `squash`; a plan made for an issue under any setup; never a group), `_sq_run` (one commit on the plan branch with `_ig_message` and the last commit's `AI-*` trailers; sets `SQ_OLD`, `SQ_NEW`), `_sq_restore` (the former tip, when the archive fails), `_sq_label`, `_sq_correct_records` (a plan archived earlier and squashed by `done <id> integrate squash`: `Commits:`, archive ledger line, `ledger_set_archive_commit`, one `plan(record)` commit). `cmd_done` records `SQ_NEW`; `_ig_run` fast-forwards in every mode.
  * Group plans (P-64, P-102) -> a plan whose title is `# 🧩 Group Plan P-<n>:` (`aapp_is_group_plan`, `templates/group-template.md`): `draft … group [<id>]` (a new group also drafts its amendments member), `_refine_group` (join/leave until started), `_group_start` (feature branch from the parent, no worktree), `_member_group_check` / `_wt_prepare` (members start from the feature branch), `_group_done_prepare` (checks only: open members, section dry runs, `.workspace/P<n>`, parent merge, clean worktree), then `pre-done` on the feature branch (a group's check is "every member archived"; the payload carries the feature branch tip), then the ARCHITECTURE sections and umbrella changelog via `aapp commit`, restored by `reset --hard` when a hook refuses it; then the normal `done` path with `IG_MODE=ff`. `_group_stamp_sections` (base lines at `refine`). `_wt_link_kit` is shared with plan worktrees.
  * Plan conflict audit (P-65, read-only) -> `plan_compare_targets(a, b)` (exact non-shared target intersection, as the activation gate), `cmd_plan_conflict_check` (pairwise, groups expand, exit 1 on collision), `cmd_plan_conflict_free` (pending vs ⚡; `_pc_against` for one plan; `_pc_waves` for a group: members in listed order into the first disjoint wave, wave 1 also clear of ⚡ plans), `json` token; dispatched from `cmd_plan_switchboard`.
  * Plan abort (P-69) -> `cmd_plan_abort` (routed by `cmd_plan_switchboard`): `_ab_parse_tokens`, `_ab_check_worktree` / `_ab_check_issue` (every refusal before any change), `_ab_archive_one` (move to `aborted/`, header, `000-aborted-ledger.md`, issue row, group member), `_ab_restore` (snapshot on a failed commit), then `_ab_teardown` / `_ab_drop_branch` (worktree, branch) and `_ab_hook` (`post-abort`). A group plan archives its open members in the same commit. `_wt_quarantine` is shared with `_ig_cleanup`.
  * `aapp active [id]` -> Displays or sets active plan pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  * `aapp active swap` / `aapp active clear` -> Toggles between current and previous buffer or clears context.
  * `aapp plan-status [id]` -> Deterministic read-only inspector for plan matrix or specific blueprint; an amendments member's requests with their states (P-101).
  * `aapp plan [query]` -> Educational planning switchboard guiding users and agents.
  * Disjointness Activation Gate -> Shared docs only print a `[Shared Doc]` notice (P-48); otherwise enforces non-overlapping target file sets between concurrent `⚡ In Development` plans, and refuses a start on a file named by a queued 🧱 Plan Blocker (`issue_queued_blockers` + `issue_location_paths`, P-58). The same check runs when a file is added to an amendments member (P-101).
* **Anti-Wrapper Warning:** Never manually write to `.git/aapp_active_plan` without going through `cmd_plan.sh`.
````

<!-- aapp-base: 91877c393bdddb39344347ed2a158c29001628655dcb37babe84c95f68b2164d -->
````markdown
### 📝 Plan-Bound Commit Helper (`lib/cmd_commit.sh`)
* **Commit mode (P-51):** `aapp_commit_mode` / `aapp_changelog_mode` / `aapp_plan_stamp_modes` (`lib/aapp-lib.sh`): `atomic` refuses a second standard commit (helper) and a raw code commit (pre-commit hook); every commit and `draft` stamp `Commit Mode:` / `Changelog Mode:` in the plan header, logging a switch in §6.
* **Purpose:** Single source of truth for committing staged implementation code, attaching attribution via P-40, and recording commit SHAs in the active plan.
* **Key Commands:**
  * `aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]` -> Commits staged files in worktree, decorates attribution, and records SHA and branch in active plan. In an amendments member each commit carries `Plan-ID: <amend-id>` (P-101).
  * `aapp commit ["<msg>"] land` -> In an amendments member's worktree only: lands its commits on the group's feature branch by `_ig_preflight` and fast-forward (`lib/cmd_plan.sh`), never `git branch -f`; no test gate; moves the requests whose files the landed commits touch to `landed`; prints the members that must rebase (P-101).
  * `aapp commit amend ["<msg>"]` -> Amends last commit, preserving message if omitted without duplicate trailers, and updates recorded SHA in active plan.
  * `aapp commit adopt <sha>...` -> Adopts existing commits made outside the helper and records them into active plan with a warning.
* **Anti-Wrapper Warning:** Never bypass `aapp commit` during an active plan; it ensures trailer compliance, lock resilience, and plan ledger integrity.
````

<!-- aapp-base: e54c68add52764a3513b7cd2a08b71652454671d16095f22c51a13fc67a9083a -->
````markdown
### 📊 Context Recovery Briefing (`lib/cmd_status.sh`)
* **Purpose:** The four-pillar context recovery briefing: Shipped (`CHANGELOG.md` and its Git history), Issues (the work queue), Plans (`.plans/current/`), and Pickup (`pickup.md`), with the pause banner, adoption tasks, staged offline work and the next action. Collects every section into records first; the terminal renderer and the JSON renderer (`aapp status json`) print them (P-91).
* **Key Functions:** `status_records_<section>` (`overview`, `templates`, `pause`, `shipped`, `issues`, `plans`, `pickup`, `adoption`, `offline`, `next`) and `status_notices` -> the records (Shipped from the changelog's Git history, `git log -n 15`, the file's first entries without history); `status_items_max` / `status_text_max` -> `aapp.statusItemsMax` (5) and `aapp.statusTextMax` (220), refused naming the key below 1; `status_render_terminal` / `status_render_json` -> the two renderers.
* **Groups (P-101):** under its group, an amendments member shows the requests waiting for approval and the members that must rebase onto the feature branch (JSON `requests`, `must_rebase`); Next Action names waiting requests first. In a checkout bound to a group member, the briefing tells the agent to re-read the group's `## Architecture & Codemap`.
* **Anti-Wrapper Warning:** Must remain strictly non-destructive and idempotent. A renderer computes nothing: a value both renderers need is a record field.
````

<!-- aapp-base: b2d3486c1f1b939ad33a4b186f1b545e24acfd7f8969eede2d79060d5c292862 -->
````markdown
### 🪝 Lifecycle Hooks & Action Plugins Engine (`lib/hook_dispatcher.sh`, `lib/cmd_hook.sh`)
* **Purpose:** Zero-dependency lifecycle hook dispatch, SHA-256 cryptographic integrity verification, process watchdog timeout gating, and dynamic action plugin discovery.
* **Key Functions:**
  * `dispatch_hook(event, data_json, repo_root)` -> Dual Delivery dispatcher streaming JSON on `stdin` alongside exported `AAPP_*` environment variables with process watchdog timeout enforcement (exit 124 on timeout).
  * `execute_with_watchdog(cmd, timeout)` -> Process watchdog isolating execution with configurable timeout (`aapp.hookTimeout`, default 10s) and terminating runaway handlers; every plugin call runs under it too, with its own limit `aapp.pluginTimeout` (default 10s, P-77).
  * `build_event_envelope(event, data_json)` / `run_action_plugin(entry, root, action, event, data_json)` / `json_field(json, key)` / `json_escape(text)` -> The shared envelope (with `repository.remote` and reserved `extra`), the plugin call, and flat-answer parsing: see §5 **Plugin Payload Standard**.
  * Answer handling (P-77): reads `status`, `message`, `handled` and `version`; delivers each line of the list file; runs the `do` list after the plugin exits and the step has released its lock (whitelist `lib/plugin_do.tsv`, in order, each command under its own lock, each result reported, the asking plugin not called again); marks the plugin's environment so a writing verb run during a step refuses.
  * `resolve_plugin_entrypoint(pdir, name)` -> Extension-agnostic plugin resolution (`run`, `$name`, `scripts/run`, `scripts/$name`, pattern match) with `.sample` exclusion filtering.
  * `cmd_plugins_status()` -> `aapp plugins`: **Kit Plugins** (every row of `lib/plugins.tsv`, installed or not, incl. `RESERVED (planned, …)`), a `==========================` delimiter, then **Your Plugins** (any other executable plugin in `.agents/skills/`, with a warning for unregistered `aapp-*` names). Fails closed when the registry is missing (P-46).
  * `cmd_hooks_status()` / `cmd_hook_hash()` -> Validates executable bits and live SHA-256 integrity against `.agents/skills/aapp-hooks/registry.tsv`. Refuses execution on hash mismatches in `mode=gate`.
* **Events:** `pre-freeze`, `post-freeze`, `pre-start`, `on-start`, `post-start`, `pre-done`, `post-done`, `post-abort`, `on-integrate`, `pre-refine`, `on-refine`, `post-refine` (P-99: every `refine`, payload `plan_id`, `kind`, `args`, `files`, `commit`), `pre-sync`, `on-sync`, `post-sync`, `post-pause`, `post-resume`.
* **Test gate (P-60):** `examples/hooks/test-gate.sh.sample`, a `pre-done` gate running the handler's `TEST_CMD` in the payload's `worktree` (else the repository root); dogfooded as `.agents/hooks/test-gate.sh`.
* **Anti-Wrapper Warning:** Never bypass `registry.tsv` hash verification or run unhashed handlers in `mode=gate`.
````

<!-- aapp-base: 042e52dd56b0b0db8dd782ef79a75273231228b603b879ee1e76c931a39a0f6a -->
````markdown
### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`)
* **Purpose:** Authoritative git pre-commit gate verifying staged changes before recording commit objects.
* **Enforcement Gates:**
  1. Section 0b: Project Circuit Breaker (refuses code commits while project is paused; allows `.plans/*` and `.agents/*`).
  2. Blast Radius compliance across non-bypass staged files.
  3. Frozen Plan Immutability: Rejects edits to `## 2. Technical Blueprint` and `## 4. Blast Radius` on `🔷 Frozen` and `⚡ In Development` plans, and to a group plan's `## Architecture & Codemap`, except a change carried with a new `Decisions` line in the group's amendments member naming each changed heading; a `Kind: amendments` plan may add `### 📂 Target Files` lines only (P-99).
  4. Changelog verification: Enforces `CHANGELOG.md` entry for any code changes.
  5. Issue roadmap hygiene: Auto-prunes resolved issues (`✅`/`Resolved`) in <5ms.
  6. Relocation Invariant: Detects and blocks active `ISSUES.md` if resolved rows are committed.
  7. Worktree isolation & Fail-Closed Quarantine: Refuses execution if `.plans/` is missing or unmounted.
````

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Group drafted with members P-101 and P-102.
* **2026-10-17:** P-99 joined. Refined from the settled review (`.plans/pickup/p103-group-lifecycle-rfc.md`): goal, shared decisions, order P-102 → P-99 → P-101, the ARCHITECTURE.md section; Question 1 (order) answered by the review. One guide (developer): corrections go into the group plan through the amendments member. The `.agents/CODEMAP.md` sections written (plan switchboard, commit helper, briefing, hooks engine, pre-commit gate). Question 2 answered by the developer: the new ARCHITECTURE.md section is added; rule 23 of `## 🚦 4.` (the old `done` order) is shortened to a pointer by an issue logged when the group lands.
