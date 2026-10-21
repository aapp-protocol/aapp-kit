# 🗺️ Plan P-900: Bash Commits Record Bare Hashes
* **Created:** 2026-10-21 | **Last Refined:** 2026-10-21
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-900
* **Changelog:** Changed: a plan's `Commits:` line records bare commit hashes, without the branch (P-900)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

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
A plan for the bash line of the kit (`develop` / `bashdev`); the Perl port reads and writes bare hashes on its own (P-115 `AAPP::State::plan_commits`).

Since P-39 (2026-09-28) the header records each commit as `` `sha` (branch) ``. P-39 meant `done` to check each commit against its recorded branch; that check was never built: `done` asks whether *any* branch or tag contains the commit, and every reader (`done`, the atomic-mode gate, `release`, `abort`, issue fixes, post-rewrite) takes the hash only. Since plan worktrees (P-57 on), the recorded branch is the plan's own `plan/P<n>-…` branch, deleted at `done`: the archive names branches that no longer exist.

The line becomes what it is used for, the hashes:
```markdown
* **Commits:** `8e51e53`, `3090f15`
* **Commits:** none
```
`* **Base:**` keeps its branch: integration reads it as the plan's parent (`plan_base_branch`, `resolve_plan_integrate_target`).

---

## 2. Technical Blueprint

### 2.1 Reader: `parse_plan_commits` (`lib/aapp-lib.sh`)
One hash per line; an item that is not a backticked hash is not a commit. Callers that did `awk '{print $1}'` keep working unchanged.
```bash
# parse_plan_commits <plan_file>
# Outputs the recorded commit hashes, one per line, in order.
# Strictly confined to the plan header (before any ## heading); `none` or prose yield nothing.
parse_plan_commits() {
    local pf="$1" raw_line val item
    [ -f "$pf" ] || return 0
    raw_line="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ { print; exit }' "$pf" 2>/dev/null || true)"
    [ -n "$raw_line" ] || return 0
    val="$(printf '%s\n' "$raw_line" | sed -E 's/^[[:space:]]*[\*|-]*[[:space:]]*\*\*Commits:\*\*[[:space:]]*//')"
    [ "$val" != "none" ] && [ -n "$val" ] || return 0
    local IFS=','
    for item in $val; do
        item="$(printf '%s' "$item" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ "$item" =~ ^\`([0-9a-fA-F]+)\`$ ]] && printf '%s\n' "${BASH_REMATCH[1]}"
    done
    return 0
}
```

### 2.2 Writers: every token is `` `sha` ``
| Where | Today | After |
| :--- | :--- | :--- |
| `lib/cmd_commit.sh` commit / adopt | ``new_token="\`$short_s\` ($target_br)"`` | ``new_token="\`$short_s\`"`` |
| `lib/cmd_commit.sh` amend | replaces `` `old` (br) `` with `` `new` ($curr_br) `` | ``updated_line="$(printf '%s' "$curr_line" \| sed -E "s\|\`$old_head_sha\`\|\`$new_sha\`\|g")"``; appends `` `new` `` when the old one was not recorded |
| `lib/cmd_plan.sh` auto-rebase (`_ig_*`) | `` `c_sha` ($IG_PLAN_BR) `` | `` `c_sha` `` |
| `lib/cmd_plan.sh` squash (`_sq_*`) | ``"\`$SQ_NEW\` ($SQ_TARGET)"`` | ``"\`$SQ_NEW\`"`` |
| `lib/cmd_plan.sh` done, squashed | `write_plan_commits "$done_file" "${recorded_commits[0]}"` (a parsed `sha branch` pair, unbackticked) | ``write_plan_commits "$done_file" "\`${recorded_commits[0]}\`"`` |
| `templates/aapp-post-rewrite` | ``TOKENS+=("\`$s\` ($branch)")`` | ``TOKENS+=("\`$s\`")`` |

`done`'s per-commit loop keeps its checks (the commit exists; some branch or tag contains it); it reads the hash from the parsed line directly. A commit made on a detached `HEAD` is recorded like any other; `done` refuses it until a branch or tag contains it, as today.

### 2.3 Open plans and the done folder
In the same change, the `Commits:` line of every plan in `.plans/current/` and `.plans/done/` is rewritten to bare hashes (one `aapp refine` per plan in `current/`; one plans commit for `done/`, which `aapp release` reads for the first commit of each plan). `.plans/release/` bundles stay as written: history, read by nothing.
```bash
sed -E '/^\* \*\*Commits:\*\*/ s/(`[0-9a-fA-F]+`)[[:space:]]*\([^)]*\)/\1/g'
```

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`: after this plan, `` `sha` (branch) `` is unknown to the reader; the open plans and `done/` are rewritten in the same change (§2.3).

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First
- [ ] Task 1.1: Update the tests that assert the old form to the bare form (red): `aapp_lib_test.sh::test_parse_plan_commits` (bare hashes; `` `sha` (branch) ``, prose and unbackticked hashes yield nothing), `verbs/done.sh::test_detached_commit_needs_a_branch` (a bare hash no branch contains is refused), and the fixtures of `pre-commit_test.sh`, `release_test.sh`, `verbs/issue.sh`, `verbs/issue.keyid.sh`, `verbs/commit.sh`, `worktree_hooks_test.sh` that write or check a `Commits:` line.

### Phase 2: Reader and Writers
- [ ] Task 2.1: `parse_plan_commits` per §2.1.
- [ ] Task 2.2: The writers per §2.2 (`cmd_commit.sh`, `cmd_plan.sh`, `aapp-post-rewrite`).

### Phase 3: Data and Documentation
- [ ] Task 3.1: Rewrite the `Commits:` lines of `.plans/current/` and `.plans/done/` per §2.3.
- [ ] Task 3.2: Docs name the bare form: `lib/docs/verbs/commit.md`, `lib/docs/verbs/done.md`, `lib/docs/verbs/plan.md`, `lib/docs/core/aapp_lib.md`, `docs/reference/01-lifecycle-state-machine.md`, `docs/reference/02-cli-commands-and-verbs.md`, `docs/reference/10-integration-and-rebase.md`, `templates/AGENTS.md`, `ARCHITECTURE.md`.
- [ ] Task 3.3: `./aapp test strict quiet` green.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/aapp-lib.sh` -> `parse_plan_commits` reads bare hashes.
- [ ] `lib/cmd_commit.sh` -> Commit, adopt and amend write bare hashes.
- [ ] `lib/cmd_plan.sh` -> Auto-rebase, squash and done write bare hashes.
- [ ] `templates/aapp-post-rewrite` -> Rewritten hashes recorded bare.
- [ ] `tests/aapp_lib_test.sh` -> Parser test on the bare form.
- [ ] `tests/pre-commit_test.sh` -> Fixture `Commits:` lines.
- [ ] `tests/release_test.sh` -> Fixture `Commits:` lines.
- [ ] `tests/verbs/done.sh` -> Fixture lines; a bare hash no branch contains is refused.
- [ ] `tests/verbs/issue.sh` -> Fixture `Commits:` lines.
- [ ] `tests/verbs/issue.keyid.sh` -> Fixture `Commits:` lines.
- [ ] `tests/verbs/commit.sh` -> Recorded form after commit and detached commit.
- [ ] `tests/worktree_hooks_test.sh` -> Post-rewrite record.
- [ ] `lib/docs/verbs/commit.md` -> Records the bare hash.
- [ ] `lib/docs/verbs/done.md` -> Test descriptions on the bare form.
- [ ] `lib/docs/verbs/plan.md` -> Commits line format.
- [ ] `lib/docs/core/aapp_lib.md` -> `parse_plan_commits` lists hashes.
- [ ] `docs/reference/01-lifecycle-state-machine.md` -> Commits line format.
- [ ] `docs/reference/02-cli-commands-and-verbs.md` -> Commits line format.
- [ ] `docs/reference/10-integration-and-rebase.md` -> Rewritten hashes recorded bare.
- [ ] `templates/AGENTS.md` -> The commit helper records the hash.
- [ ] `ARCHITECTURE.md` -> Commit helper entry.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/` -> The Perl port handles its own reader and writers (P-111 group).
- [ ] `.plans/release/` -> Archived bundles stay as written.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-21:** Drafted for the bash line: `Commits:` records bare hashes; the P-39 branch record was never read.
