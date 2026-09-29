# 🗺️ Plan P-32: Issue ID Allocation, Lifecycle Engine & Duplicate Detection

* **Created:** 2026-09-22 | **Last Refined:** 2026-09-29
* **Target Issue / Milestone:** #79 *(supersedes #79 upon completion)*
* **Plan ID:** P-32
* **Status:** 🔷 Frozen
* **Base:** `88aae65` (develop)
* **Commits:** `e295a83` (develop)

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement

Plan IDs are **stored, not derived**: `aapp.planId` holds a monotonic counter, `allocate_plan_id` claims from it, an optional `aapp-planid` provider plugin sources them centrally for teams, and Pair 4 independently detects duplicates. Issue IDs have **none of this**. They are typed by hand, with no counter, no provider contract, no lifecycle CLI verb, and no duplicate detection.

That gap produced a live collision on 2026-09-22: issue `#77` was logged at 00:10, fixed and relocated to `.plans/done/000-issues-archive.md` at 00:12, then **reused at 02:48 for an unrelated defect**.

Four structural causes create a slippery slope for everyone attempting to find the exact issue number:

1. **No Allocator or CLI Ingress**: Nothing claims an issue ID, persists an increment, or provides a command (`aapp issue next`) to query the next ID. Every allocation is a fresh manual file scan.
2. **The Priority-Ordering Trap in `ISSUES.md`**: `ISSUES.md` is ordered by **human triage priority, not numeric ID**. In active `ISSUES.md`, line 7 is `#92`, while line 21 (bottom of file) is `#76`. Anyone glancing at the bottom or running `tail -5 .plans/ISSUES.md` sees `#76` and erroneously concludes `#77` is available.
3. **The Relocation Invariant Gap**: `ISSUES.md` holds only active unresolved rows by design. Resolved issues (`#77` through `#91`) are moved to `.plans/done/000-issues-archive.md`. A scan of `ISSUES.md` alone is blind to the archive.
4. **Manual Table Surgery on Issue Close**: While `aapp done` archives plans, it currently does **not** relocate the target issue row in `ISSUES.md`. Furthermore, for direct quick fixes (no plan), developers must manually cut, format, and paste table rows between `ISSUES.md` and `000-issues-archive.md`. If forgotten, `aapp-pre-commit` rejects the commit.

A counter alone would not catch a hand-typed duplicate; detection alone would not stop a bad scan; and without a CLI verb, humans and AI agents must still resort to manual table edits. This plan delivers all four components in a unified architecture.

### Architectural Goal

1. **Shared allocation engine**: Extract counter mechanics from `allocate_plan_id` into a parameterized core (`_allocate_id`) in `lib/plan_resolver.sh` taking a config key, an ID prefix, and a provider plugin name, conforming to the P-33 fail-closed root resolution.
2. **Stored Issue ID counter**: `aapp.issueId` in git config, with `allocate_issue_id` / `get_next_issue_id`.
3. **Seed on first use**: When `aapp.issueId` is unset (always true in a fresh clone), seed it from **both** `ISSUES.md` and `000-issues-archive.md`, so relocation and priority ordering can never hide a used ID; no ledgers and no provider refuses.
4. **Focused CLI Ingress (`aapp issue`)**: Introduce an operational CLI verb:
   - `aapp issue [next]`: Read-only peek showing the next unassigned ID.
   - `aapp issue allocate`: Claims the ID and increments `aapp.issueId`.
   - `aapp issue close <id> [sha <sha>] [summary "<text>"]`: Mechanically relocates the issue row to `000-issues-archive.md`, prunes `issues_road_map.md`, commits, then notifies the team plugin (fire-and-forget).
   - `aapp issue list [<n> | all]`: Lists active issues in roadmap priority order; default cap 20 (the status briefing shows only the top 5).
5. **Unified Close in `aapp done`**: Update `cmd_done` in `lib/cmd_plan.sh` to delegate issue closure to `cmd_issue_close`, automating the Relocation Invariant when a plan completes.
6. **Team Provider Plugin (`aapp-issue`)**: Provider plugin mirroring `aapp-planid`, supporting `AAPP_ACTION=allocate` and `close` (notifying external trackers like GitHub Issues, Jira, or Linear).
7. **Duplicate detection (Pair 8)**: Add `check_pair8_issue_id_integrity` reporting any issue ID repeated *within* one ledger. Cross-ledger collisions are already caught by Pair 1 (`check_pair1_disjointness`).

### Explicit Boundary: Two Independent Namespaces

`#<num>` and `P-<num>` are deliberately distinct namespaces — `.agents/AGENTS.md` states they must never be interchanged, and lifecycle verbs reject `#9` where a Plan ID is expected. This plan preserves **two independent counters**, so `P-32` and `#32` may both exist.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Parameterized Allocation Core (`lib/plan_resolver.sh`)

`allocate_plan_id` currently hardcodes plan-specific values; everything else is generic counter mechanics including the **ratchet**.

Extract one internal core conforming to P-33 fail-closed repository root resolution:

```bash
# _allocate_id <config-key> <prefix> <plugin-name> <label>
_allocate_id() {
    local KEY="$1" PREFIX="$2" PLUGIN="$3" LABEL="$4"
    local ROOT PDIR ENTRY RAW OUT CUR ISSUED
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ [$LABEL] Not inside a Git repository." >&2
        return 1
    }
    PDIR="$ROOT/.agents/skills/$PLUGIN"

    # 1. Delegate to the provider plugin when one is installed.
    if [ -d "$PDIR" ] && ENTRY="$(resolve_plugin_entrypoint "$PDIR" "$PLUGIN" 2>/dev/null)"; then
        OUT="$(AAPP_ACTION=allocate AAPP_REPO_ROOT="$ROOT" "$ENTRY" 2>/dev/null)" || {
            echo "❌ [$LABEL] Provider plugin failed; refusing to allocate locally." >&2
            return 1
        }
        RAW="$OUT"
        OUT="$(_normalize_id "$RAW" "$PREFIX" "$LABEL")" || return 1
        CUR="$(git config --get "$KEY" 2>/dev/null || true)"
        case "$CUR" in ''|*[!0-9]*) CUR=0 ;; esac
        ISSUED="${OUT#"$PREFIX"}"
        if [ "$ISSUED" -ge "$CUR" ]; then git config "$KEY" "$((ISSUED + 1))"; fi
        printf '%s\n' "$OUT"
        return 0
    fi

    # 2. No plugin installed -> local git config counter.
    CUR="$(git config --get "$KEY" 2>/dev/null || true)"
    case "$CUR" in
        '')       CUR=1 ;;
        *[!0-9]*) echo "❌ [$LABEL] $KEY is not an integer: '$CUR'. Run 'aapp init' to reseed." >&2
                  return 1 ;;
    esac
    git config "$KEY" "$((CUR + 1))" || return 1
    printf '%s%s\n' "$PREFIX" "$CUR"
}

# _normalize_id <raw> <prefix> <label>
_normalize_id() {
    local RAW="$1" PREFIX="$2" LABEL="$3"
    local N="${RAW#"$PREFIX"}"
    case "$N" in
        ''|*[!0-9]*)
            echo "❌ [$LABEL] Provider must return an integer id (got: '$RAW')" >&2
            return 1
            ;;
    esac
    printf '%s%s\n' "$PREFIX" "$N"
}

allocate_plan_id()  { _allocate_id aapp.planId  "P-" aapp-planid  "Plan ID"; }
allocate_issue_id() { _allocate_id aapp.issueId "#"  aapp-issue   "Issue ID"; }

# Read-only peek; keeps the current fail-closed get_next_plan_id behaviour.
# _next_id <config-key> <prefix> <label>
_next_id() {
    local KEY="$1" PREFIX="$2" LABEL="$3" CUR
    CUR="$(git config --get "$KEY" 2>/dev/null || true)"
    case "$CUR" in
        '')       CUR=1 ;;
        *[!0-9]*) echo "❌ [$LABEL] $KEY is not an integer: '$CUR'. Run 'aapp init' to reseed." >&2
                  return 1 ;;
    esac
    printf '%s%s\n' "$PREFIX" "$CUR"
}

get_next_plan_id()  { _next_id aapp.planId  "P-" "Plan ID"; }
get_next_issue_id() { _next_id aapp.issueId "#"  "Issue ID"; }
```

### 2.2 Seed on First Use (`lib/plan_resolver.sh`)

Git config is not cloned, and a clone never runs `aapp init`, so a counter written at init exists only in the clone that ran it. The counter is therefore seeded **when an ID is first needed**, in whichever clone asks:

- `seed_issue_id <plans-dir>` scans both `ISSUES.md` and `done/000-issues-archive.md` (priority order and relocation can never hide a used ID) and returns the numeric max + 1. Template example rows (dated `YYYY-MM-DD`) are skipped, so a new project gets `#1`. Returns 2 when neither ledger file exists.
- `allocate_issue_id` / `get_next_issue_id` pass a seeder to `_allocate_id` / `_next_id`; it runs only when `aapp.issueId` is **unset** (a provider, when installed, still decides first):

| State | Result |
| :--- | :--- |
| counter set | use it |
| counter unset, ledgers present | seed from them (`next` peeks without writing) |
| counter unset, no ledger files, no provider | refuse: IDs belong to a remote authority whose `aapp-issue` provider is not installed |

- `aapp init` does not seed `aapp.issueId`; its banner says the counter is seeded on first allocate.
- A non-integer counter still refuses; the hint is `git config --unset aapp.issueId` (reseed from the ledgers), not `aapp init`.
- Plan IDs keep init-time seeding here; the same clone gap for `aapp.planId` is out of scope.

### 2.3 The `aapp-issue` Provider Plugin Contract

A dedicated plugin at `.agents/skills/aapp-issue/` (entrypoint resolved via `resolve_plugin_entrypoint`):

| Action | Invocation & Environment | Output & Exit | Local Fallback |
| :--- | :--- | :--- | :--- |
| `allocate` | `AAPP_ACTION=allocate AAPP_REPO_ROOT=<root> <entrypoint>` | Prints `#<num>` or bare `<num>`, exits 0 | Claims from `aapp.issueId` counter |
| `close` | `AAPP_ACTION=close AAPP_ISSUE_ID=<id> AAPP_COMMIT_SHA=<sha> AAPP_SUMMARY="<msg>" <entrypoint>` | Hands the closure to the tracker, exits 0 | Local archive is always completed first |

- **No `peek` action**: `aapp issue next` reads the local counter only, like `get_next_plan_id`; the counter is ratcheted on every provider allocation.
- **`allocate`**: Plugin absence falls back to the local counter; plugin failure aborts allocation (fail closed), identical to `aapp-planid`.
- **`close` is fire-and-forget**: Invoked once, after the local archive commit. Retry, queueing and later delivery are the plugin implementer's responsibility. A non-zero exit prints a warning and never blocks `close` or `aapp done` (registered in the Fallback Inventory).
- Sample is a one-line delegation shim like `aapp-planid/run.sample`: `exec "${AAPP_ISSUE_CMD:-$HOME/.local/bin/aapp-issue-provider}" "$@"`.
- Registered in `cmd_plugins_status()` in `lib/cmd_hook.sh` and in the `.agents/CODEMAP.md` §5 plugin registry table.

### 2.4 The Issue Lifecycle CLI Verb (`aapp issue`) & `aapp done` Integration

Add `lib/cmd_issue.sh` and register `issue` in `lib/verbs.tsv`:

```text
aapp issue [next | allocate | close <id> [sha <sha>] [summary "<text>"] | list [<n> | all]]
```

1. **`aapp issue [next]`**:
   - Queries `get_next_issue_id` (local counter only).
   - Prints the next free issue ID (e.g. `Next available issue ID: #93`).
2. **`aapp issue allocate`**:
   - Executes `allocate_issue_id`.
   - Returns the claimed issue ID on stdout (e.g. `#93`) and updates `aapp.issueId`.
3. **`aapp issue close <id> [sha <sha>] [summary "<text>"]`**:
   - Accepts bare `79` (an unquoted `#79` is a shell comment); normalizes via `normalize_issue_id`. Optional values use bare keyword tokens (`sha`, `summary`), per the CLI bare-token rule.
   - Extracts matching row from `.plans/ISSUES.md`:
     `| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |`
   - Formats into archive row:
     `| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |`
   - Inserts row at top of `.plans/done/000-issues-archive.md`.
   - Deletes row from `.plans/ISSUES.md`.
   - Prunes matching `- [ ] #<id>` entry from `.plans/issues_road_map.md`.
   - Commits the three files via `plans_commit`.
   - Row already archived → skips the local move and only re-notifies the plugin. ID in neither ledger → error.
   - If `aapp-issue` plugin is present, invokes with `AAPP_ACTION=close` (fire-and-forget, §2.3).
4. **`aapp issue list [<n> | all]`**:
   - Displays active issues in roadmap priority order, reusing the status briefing's roadmap ordering so both views agree.
   - Capped at 20 by default; bare `<n>` sets the cap, `all` removes it (bare tokens, no `-n`). A truncated list ends with `… N more (aapp issue list all)`.

#### `aapp done` Delegation:
In `cmd_done` (`lib/cmd_plan.sh:991`):
When `target_issue` is extracted (e.g. `#79`), if it matches `#*`:
`cmd_done` invokes `cmd_issue_close "$target_issue" "$commit_sha" "[$bname]($bname) - $summary"`, automatically fulfilling the Relocation Invariant upon plan completion.
- Issue check runs before any archive mutation: an ID in neither ledger aborts `done`.
- The local close does not commit separately here: `ISSUES.md`, `done/000-issues-archive.md` and `issues_road_map.md` join `done_targets`, so plan archive and issue close land in one `plans_commit`.

### 2.5 Pair 8: Issue ID Duplicate Detection (`lib/planning_health.sh`)

`check_pair8_issue_id_integrity` scans both `ISSUES.md` and `done/000-issues-archive.md`:
- Extracts all issue IDs matching `^\|[[:space:]]*#[0-9]+`.
- Verifies no issue ID is repeated within the same ledger (cross-ledger collisions stay with Pair 1).
- If duplicates are found, reports the exact ID and the ledger.
- Registered in `check_planning_health` immediately following Pair 7 (`:668`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `aapp-issue` `close` failure → warning only; the local archive is authoritative and delivery is the plugin's responsibility.
- Existing plans and functions calling `allocate_plan_id` or `get_next_plan_id` remain 100% binary- and signature-compatible.
- Existing repositories and fresh clones seed `aapp.issueId` from their ledgers on the first `aapp issue allocate`; `aapp init` no longer writes it.
- Zero duplicate issue IDs currently exist on `develop`; Pair 8 passes cleanly immediately.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Shared Allocation Core
- [x] Task 1.1: Extract `_allocate_id` and `_normalize_id` in `lib/plan_resolver.sh` using P-33 fail-closed root resolution.
- [x] Task 1.2: Refactor `allocate_plan_id`, `normalize_plan_id`, and `get_next_plan_id` to delegate to the shared core.
- [x] Task 1.3: Implement `allocate_issue_id` and `get_next_issue_id`.
- [x] Task 1.4: Verify `tests/plan_resolver_test.sh` passes with zero regressions to plan ID allocation.

### Phase 2: Seed on First Use & Init Banner
- [x] Task 2.1: Implement `seed_issue_id` in `lib/plan_resolver.sh` scanning `ISSUES.md` and `done/000-issues-archive.md`, skipping template rows.
- [x] Task 2.2: Seed an unset `aapp.issueId` on first `allocate` / `next`; refuse when there are no ledgers and no provider.
- [x] Task 2.3: `aapp init` banner reports the counter, or that it is seeded on first allocate.

### Phase 3: Issue Lifecycle CLI Verb (`aapp issue`) & `aapp done`
- [x] Task 3.1: Implement `lib/cmd_issue.sh` supporting `next`, `allocate`, `close <#id> [sha] [summary]`, and `list`.
- [x] Task 3.2: Register `issue` in `lib/verbs.tsv` and dispatch from `aapp`.
- [x] Task 3.3: Wire `cmd_done` in `lib/cmd_plan.sh` to automatically call `cmd_issue_close` when `target_issue` matches `#<id>`.
- [x] Task 3.4: Author contract specification in `lib/docs/verbs/issue.md`.

### Phase 4: Provider Plugin Contract & Extension Catalog
- [x] Task 4.1: Author delegation shim `examples/plugins/aapp-issue/run.sample` (`AAPP_ISSUE_CMD`).
- [x] Task 4.2: Register `aapp-issue` in `cmd_plugins_status()` in `lib/cmd_hook.sh` and the CODEMAP §5 registry.

### Phase 5: Pair 8 Duplicate Detection
- [x] Task 5.1: Implement `check_pair8_issue_id_integrity` in `lib/planning_health.sh`.
- [x] Task 5.2: Register Pair 8 in `check_planning_health` following Pair 7.

### Phase 6: Verification, Tests & Documentation
- [x] Task 6.1: Author contract test suite `tests/verbs/issue.sh` covering `next`, `allocate`, and `close`.
- [x] Task 6.2: Add unit tests in `tests/plan_resolver_test.sh` covering issue allocation, provider ratchet, and Pair 8.
- [x] Task 6.3: Run full test runner (`./aapp test strict quiet`) ensuring all test suites pass.
- [x] Task 6.4: Update `MANUAL.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, `.agents/CODEMAP.md`, and `.agents/AGENTS.md`.
- [x] Task 6.5: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Extract parameterized allocation core; add allocate_issue_id, get_next_issue_id and first-use seed_issue_id.
- [ ] `lib/cmd_init.sh` -> Surface the issue counter in the banner (no seeding).
- [ ] `lib/cmd_plan.sh` -> Delegate issue closure in cmd_done to cmd_issue_close.
- [ ] `NEW FILE` -> `lib/cmd_issue.sh` -> Operational CLI switchboard for aapp issue.
- [ ] `lib/verbs.tsv` -> Register issue verb in daily tier.
- [ ] `NEW FILE` -> `lib/docs/verbs/issue.md` -> Verb behavior contract documentation.
- [ ] `lib/cmd_hook.sh` -> Register aapp-issue in plugin extension status.
- [ ] `lib/planning_health.sh` -> Implement and register check_pair8_issue_id_integrity.
- [ ] `NEW FILE` -> `examples/plugins/aapp-issue/run.sample` -> Reference mock provider plugin.
- [ ] `tests/plan_resolver_test.sh` -> Test issue allocation, two-file seeding, ratchet, and Pair 8.
- [ ] `NEW FILE` -> `tests/verbs/issue.sh` -> Contract test suite for aapp issue.
- [ ] `MANUAL.md` -> Document aapp issue, aapp.issueId, provider contract, and Pair 8.
- [ ] `CHEATSHEET.md` -> Add aapp issue and aapp.issueId to reference cards.
- [ ] `ARCHITECTURE.md` -> Document dual stored identity and issue lifecycle engine.
- [ ] `.agents/CODEMAP.md` -> Register issue commands and Pair 8.
- [ ] `.agents/AGENTS.md` -> Update issue triage protocol to use allocate_issue_id and aapp issue.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🚨 Emergency Hotfix Extensions
- [ ] `aapp` -> Dispatch the `issue` verb (Task 3.2 requires it; omitted from Target Files).
- [ ] `tests/verbs/done.sh` -> Fixture targets `#42`, absent from every ledger; `done` now refuses a dangling Target Issue.
- [ ] `lib/docs/verbs/done.md` -> Contract gains the Target Issue close effect and refusal.
- [ ] `templates/AGENTS.md` -> Adopter copy of the `.agents/AGENTS.md` issue-ID and close wording.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/ISSUES.md` -> Row content is issue-lifecycle data; do not hand-edit historical rows (writes by `aapp issue close` / `aapp done` are exempt).
- [ ] `.plans/done/000-issues-archive.md` -> Archive rows are never rewritten (inserts by `aapp issue close` / `aapp done` are exempt).
- [ ] `.githooks/*` -> Pair 5 self-protected; propagate via aapp init.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.

---

## ❓ 5. Open Questions & Settled Decisions

* [x] **Question 1 — One shared counter or two independent ones? → RESOLVED (developer, 2026-09-22): two independent counters.** `#<num>` and `P-<num>` are distinct namespaces. `P-32` and `#32` may both exist.
* [x] **Question 2 — Provider plugin naming & contract? → RESOLVED (developer, 2026-09-28; amended 2026-09-29): `aapp-issue` plugin mirroring `aapp-planid`.** Supports `allocate` (fail closed) and `close` (fire-and-forget; retry is the plugin's job). No `peek`.
* [x] **Question 3 — Does this plan include duplicate detection? → RESOLVED (developer, 2026-09-22; amended 2026-09-29): Yes, Pair 8, within-ledger only.** Pair 1 already reports cross-ledger collisions.
* [x] **Question 5 — Non-blocking allocation when the provider is unreachable? → RESOLVED (developer, 2026-09-29): Out of scope; follow-up plan using plugin-reserved ID blocks (HiLo).** No temporary IDs, no renumbering, no push gate. `aapp.issueIdBlockSize` / `aapp.planIdBlockSize` (seeded `0` by `aapp init`, never overwritten; `0` = always blocking). The plugin owns the numbers: `AAPP_ACTION=reserve-id-block AAPP_BLOCK_SIZE=<n>` prints space-separated IDs, stored verbatim in `aapp.issueIdReserved` / `aapp.planIdReserved`; the kit never computes them. Provider reachable → normal allocate; when 3 or fewer reserved IDs remain, request a new block and append it. Provider down → take the first reserved ID. Down and list empty → refuse. P-32 builds the shared `_allocate_id` the follow-up extends.
* [x] **Question 4 — CLI ingress & issue lifecycle scope? → RESOLVED (developer, 2026-09-28): Add `aapp issue` CLI verb with automated close delegation in `aapp done`.** Automates mechanical relocation and eliminates manual markdown surgery for both direct bugfixes and plan completions.

---

## 📦 6. Change Log & Refinement History
* **2026-09-29:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-29:** §2.2 seeding moved from `aapp init` to first use: config is not cloned and clones never run init. Template rows skipped; no ledgers and no provider refuses. Proven by `test_clone_first_allocate_continues_ledgers` and `test_no_ledgers_without_provider_refuses`.
* **2026-09-29:** Plan activated into ⚡ In Development via start.
* **2026-09-29:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-29:** Plan activated into ⚡ In Development via start.
* **2026-09-29:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-29:** Review amendments: Pair 8 narrowed to within-ledger (Pair 1 covers cross-ledger); `get_next_*` kept fail-closed; `close` takes bare id + keyword tokens, commits via `plans_commit`, joins `done_targets` in `aapp done`; plugin drops `peek`, `close` fire-and-forget, shim sample, CODEMAP §5; `list` reuses status ordering, default cap 20 (`list <n>` / `list all`); Out of Bounds exempts verb writes; Q5 non-blocking allocation deferred to follow-up plan (plugin-reserved ID blocks).
* **2026-09-28:** Comprehensive refinement based on active codebase state:
  1. Conformed allocation core to P-33 fail-closed root resolution.
  2. Updated stale line citations across `lib/cmd_init.sh` and `lib/planning_health.sh`.
  3. Added `aapp issue` operational CLI verb (`next`, `allocate`, `close`, `list`) to permanently resolve manual table surgery and ID collisions.
  4. Wired `aapp done` to delegate to `cmd_issue_close`, automating the Relocation Invariant upon plan completion.
  5. Expanded provider plugin contract (`aapp-issue`) to support `close` action for team/remote tracker sync.
* **2026-09-22:** Blueprint initialized after issue `#77` reuse incident.
