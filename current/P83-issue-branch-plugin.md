# 🗺️ Plan P-83: Issue Branch Plugin
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-83
* **Changelog:** Added: a team plugin, `aapp-issue-branch`, names the branch an issue's fix lands on from its files (P-83)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-72
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
An issue's fix must land on the right branch. In a project with one branch per module (say `develop`, a `core` branch and module branches), where a bug is seen says nothing about where its fix belongs: a core defect met while working on a module belongs on `core`. The one fact about an issue that does say it is its files.

This plan reserves one plugin, `aapp-issue-branch`. The team writes it; it holds the team's knowledge of which branch owns which paths, in whatever form the team keeps it. When the kit needs to know where an issue's fix lands, it sends the issue with its files and the plugin answers the branch. The kit defines no declaration format and stores none; without the plugin every fix lands on the development branch.

A plugin is the right place for this because the answer is not only a map of paths. Many people may have access to the code without clearance to change every branch, and those rules are internal to a team: they are in no public repository and the kit cannot know them. The plugin can answer from them, or refuse.

A branch is never taken from where an issue was logged or raised. A person or an agent may still name one (`branch <name>`), and that is not put to the plugin.

---

## 2. Technical Blueprint
- **When it is asked:** when the kit is about to act on an issue's branch and the row names none: `issue fix <n>` (and `fix next-blocker`) before the fix opens, and `issue close <n>` of an issue with no open fix. Views (`status`, `issue list`) never ask; they show what the row holds.
- **When it is not asked:** the row's `Branch` cell names a branch (a person or an agent decided, with `aapp refine issues "<msg>" branch <n> <name>` or `issue hotfix … branch <name>`), or the fix is opened with `group <group>`.
- **The exchange** (P-77 protocol), event `issue.branch`: `data` carries the whole issue (`id`, `sev`, `type`, `date`, `symptom`, `status`) and `files`, the paths the fix covers: those in the row's Location and those given with `file <path>`. No credentials and no remote URL, as for every plugin.

  | Answer | The kit does |
  |---|---|
  | `ok` with `branch` | takes that branch: writes it to the row's `Branch` cell (nothing is written for the development branch) and goes on; `fix` opens on it, `close` requires the commit in it |
  | `declined` | takes the development branch; nothing is written |
  | `failed`, a timeout, `ok` without `branch`, a malformed answer, a branch that exists neither here nor on a remote | refuses: the fix does not open, the issue is not closed, nothing is written. The plugin's `message` is shown, with the way past it: `aapp refine issues "<msg>" branch <n> <name>` |

  A plugin that breaks never sends a fix to the development branch by default: that would be the wrong-place fix this plan prevents.
- **Files owned by two branches** are the plugin's call. It answers one branch, or `failed` with a `message` naming the owners; the fix then waits until someone names the branch or splits the issue.
- **The plugin may refuse for its own reasons,** such as the person or agent having no clearance for the owning branch: it answers `failed` with a `message`, and the fix does not open. Who is asking is the plugin's to find out (the envelope carries no identity and no credentials). This is guidance given early, not access control: what a branch accepts is enforced where the branch is hosted.
- **The answer is recorded once.** After `ok` with a branch the cell holds it, so closing and unblocking (P-78) read the row and the plugin is not asked again for that issue.
- **Hotfixes follow the same rule.** `issue hotfix` stops writing the blocked plan's parent branch into the row (P-78 did): a hotfix names a branch only with `branch <name>`; otherwise the plugin decides from its files when the fix opens. See Question 1 for a hotfix raised from a group's member.
- **Shipped:** the reserved name in `lib/plugins.tsv`; the event and the `files` and `branch` fields in the issue reference; a sample (`examples/plugins/aapp-issue-branch/run.sample`) that reads a list of `path prefix` → `branch` lines kept beside it, answers `declined` when no line matches and `failed`, naming the owners, when the files match two branches. The list's format belongs to the sample, not to the kit.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: no plugin installed, or `declined`: the development branch. Not a legacy shim: it is the meaning of "no branch named" (P-78).

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.branchplugin.sh::test_answered_branch_opens_fix_there` -> asserts `ok` with `branch` opens the fix in `.workspace/fix-<n>` cut from that branch and writes the branch to the row's cell
- [ ] `tests/verbs/issue.branchplugin.sh::test_declined_is_dev_branch` -> asserts `declined`, and `ok` naming the development branch, open the fix on the development branch and leave the cell empty
- [ ] `tests/verbs/issue.branchplugin.sh::test_no_plugin_is_dev_branch` -> asserts with no plugin installed the fix opens on the development branch
- [ ] `tests/verbs/issue.branchplugin.sh::test_failure_refuses_fix` -> asserts `failed`, a timeout, `ok` without `branch` and a branch that does not exist each refuse the fix: no mini plan, no worktree, no commit, the cell unchanged, and the refusal names `aapp refine issues "<msg>" branch <n> <name>`
- [ ] `tests/verbs/issue.branchplugin.sh::test_plugin_message_is_shown` -> asserts the `message` of a `failed` answer (the owners of the files) is printed with the refusal
- [ ] `tests/verbs/issue.branchplugin.sh::test_named_branch_is_not_asked` -> asserts a row whose cell names a branch, and a fix opened with `group <group>`, do not call the plugin
- [ ] `tests/verbs/issue.branchplugin.sh::test_payload_carries_issue_and_files` -> asserts `data` holds the issue's fields and `files` (Location paths and `file <path>` additions), and neither credentials nor the remote URL
- [ ] `tests/verbs/issue.branchplugin.sh::test_answer_recorded_once` -> asserts after an answered branch a second `issue fix` of the same issue does not call the plugin
- [ ] `tests/verbs/issue.branchplugin.sh::test_next_blocker_asks` -> asserts `fix next-blocker` puts the claimed blocker to the plugin and opens on the answered branch
- [ ] `tests/verbs/issue.branchplugin.sh::test_direct_close_asks` -> asserts `issue close <n> sha <sha>` of an issue with no open fix asks the plugin, refuses a commit that is not in the answered branch, and refuses when the plugin fails
- [ ] `tests/verbs/issue.branchplugin.sh::test_views_do_not_ask` -> asserts `aapp status` and `aapp issue list` do not call the plugin
- [ ] `tests/verbs/issue.branchplugin.sh::test_sample_maps_paths` -> asserts the shipped sample answers the branch of a matching path, `declined` for a path no line matches, and `failed` naming both owners for files of two branches

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- `tests/verbs/issue.branch.sh::test_hotfix_takes_plan_parent_branch`: rewritten as `test_hotfix_names_no_branch` (a hotfix leaves the cell empty; `branch <name>` writes it), or kept for the group case if Question 1 is answered that way.
- `tests/verbs/issue.branch.sh::test_branch_token_adds_column`: unchanged; the explicit token stays.
- `tests/plugin_protocol_test.sh::test_reference_matches_code`: unchanged; it reads the events and fields from the code, so the reference must list `issue.branch`, `files` and `branch` for it to pass.

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.branchplugin.sh` with a scripted plugin fixture (guarded against calling `aapp` inside its step); change the hotfix test; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: One function in `lib/cmd_issue.sh` that settles an issue's branch (named in the row, else asked of the plugin, else the development branch), used by `fix` and `close`; the refusal on failure.
- [ ] Task 2.2: `issue hotfix` names a branch only with `branch <name>`.
- [ ] Task 2.3: Registry row, sample with its list, reference.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md`, the issue contract, the agent rules and the fix skill.
- [ ] Task 3.3: Architecture and Codemap sections live in group P-72.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> Settling an issue's branch through the plugin at `fix` and `close`; `hotfix` without a default branch.
- [ ] `lib/plugins.tsv` -> Reserved name `aapp-issue-branch`.
- [ ] `NEW FILE` -> `examples/plugins/aapp-issue-branch/run.sample` -> Sample: path prefixes mapped to branches.
- [ ] `NEW FILE` -> `examples/plugins/aapp-issue-branch/branches.sample` -> The sample's list.
- [ ] `docs/reference/07-issue-protocol.md` -> Event `issue.branch`, fields `files` and `branch`, the answers and what the kit does with each.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `MANUAL.md` -> Issues on several branches: the plugin, and that nothing is taken from where an issue is logged.
- [ ] `templates/AGENTS.md` -> Agent rules: a hotfix names no branch by itself; a refused fix names the next command.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> The refusal when the branch cannot be settled.
- [ ] `tests/verbs/issue.branch.sh` -> The hotfix test (§3).

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.branchplugin.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/hook_dispatcher.sh` -> The protocol is P-77's; this plan only uses it.
- [ ] `lib/aapp-lib.sh` -> The ledger functions already read and write the `Branch` cell (P-78).

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — A hotfix raised from a group's member.** The member can only resume when the fix is in the group's feature branch, and that branch takes the development branch's commits only at the group's `done`. With no default, such a hotfix lands on the development branch (or on a module branch the plugin names) and the member stays blocked until someone merges that branch into the feature branch or the fix is opened with `group <group>`. Options: (a) no default at all, the same rule everywhere; (b) a hotfix raised from a group's member keeps the feature branch as its default, because a feature branch is temporary and owned by the group, and `branch <name>` names another.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72, before P-74.
