# 🗺️ Plan P-32: Issue ID Allocation & Duplicate Detection
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-22
* **Target Issue / Milestone:** #79 *(supersedes #79 upon completion)*
* **Plan ID:** P-32
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement

Plan IDs are **stored, not derived**: `aapp.planId` holds a monotonic counter, `allocate_plan_id` claims from it, an optional `aapp-planid` provider plugin sources them centrally for teams, and Pair 4 independently detects duplicates. Issue IDs have **none of this**. They are typed by hand, with no counter, no provider contract, and no duplicate detection.

That gap produced a live collision. On 2026-09-22 issue `#77` was logged at 00:10, fixed and relocated to `.plans/done/000-issues-archive.md` at 00:12, then **reused at 02:48 for an unrelated defect**. The reuse happened because the next ID was chosen by scanning active `ISSUES.md` for the highest number — and the Relocation Invariant had already moved the resolved `#77` row out of that file. The archive was authoritative and was not consulted.

Three structural causes:

1. **No allocator.** Nothing claims an issue ID or persists an increment, so every allocation is a fresh manual scan whose correctness depends on remembering to read two files.
2. **Relocation hides used IDs.** `ISSUES.md` holds only active rows by design (the Relocation Invariant). Any allocator reading one file therefore sees a partial history, and the safest-looking scan is the wrong one.
3. **No detection backstop.** `check_pair4_plan_id_integrity` (`lib/planning_health.sh:296`) validates Plan ID uniqueness across blueprints. No equivalent exists for issue IDs, so a collision — whether from a bad scan or a hand-typed row — is never reported.

A counter alone would not have caught a hand-typed duplicate, and detection alone would not stop the bad scan. This plan delivers both.

### Architectural Goal

1. **Shared allocation engine**: Extract the counter mechanics from `allocate_plan_id` into a parameterized core taking a config key, an ID prefix, and a provider plugin name. Plans and issues become two callers of one implementation.
2. **Issue ID allocation**: `aapp.issueId` counter, `allocate_issue_id` / `get_next_issue_id`, and a separate `aapp-issueid` provider plugin for teams sourcing IDs centrally.
3. **Two-file seeding**: Seed `aapp.issueId` by scanning **both** `ISSUES.md` and `000-issues-archive.md`, so relocation can never hide a used ID from the seeder.
4. **Duplicate detection (Pair 8)**: Add `check_pair8_issue_id_integrity` reporting any issue ID appearing twice across the active ledger and the archive.

### Explicit Boundary: Two Independent Namespaces

`#<num>` and `P-<num>` are deliberately distinct namespaces — `.agents/AGENTS.md` states they must never be interchanged, and lifecycle verbs already reject `#9` where a Plan ID is expected. This plan preserves that: **two independent counters**, so `P-32` and `#32` may both exist. A single shared sequence was rejected because it would make issue numbers jump unpredictably (`#33`, `#37`, `#41`) and would collapse a separation the protocol relies on.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Parameterized Allocation Core (`lib/plan_resolver.sh`)

`allocate_plan_id` currently hardcodes three plan-specific values; everything else is generic counter mechanics including the **ratchet** (when a provider issues a high ID, push the local counter past it so a later offline allocation cannot regress into used numbers).

| Hardcoded today | Becomes a parameter |
| :--- | :--- |
| `aapp.planId` | config key |
| `P-` prefix | ID prefix |
| `.agents/skills/aapp-planid` | provider plugin name |

Introduce one internal core, with the existing public functions preserved as thin wrappers:

```bash
# _allocate_id <config-key> <prefix> <plugin-name> <label>
_allocate_id() {
    local KEY="$1" PREFIX="$2" PLUGIN="$3" LABEL="$4"
    local ROOT PDIR ENTRY RAW OUT CUR ISSUED
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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
        ISSUED="${OUT#$PREFIX}"
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

allocate_plan_id()  { _allocate_id aapp.planId  "P-" aapp-planid  "Plan ID"; }
allocate_issue_id() { _allocate_id aapp.issueId "#"  aapp-issueid "Issue ID"; }
```

`normalize_plan_id` is likewise reduced to a wrapper over `_normalize_id <raw> <prefix> <label>`, and `get_next_issue_id` mirrors `get_next_plan_id` as a **read-only peek that claims nothing**.

The ratchet comment in the current implementation (`Capture into RAW first…`) documents a real trap — assigning the substitution straight back into `OUT` clobbers it before the `||` branch can report the value. That comment must survive the extraction.

### 2.2 Why Seeding Cannot Be Shared

`seed_plan_id` (`lib/cmd_init.sh:498`) scans `P<num>*.md` **filenames** across `current/`, `done/` and `aborted/`, then parses ledger rows for archived plans whose files were removed. Issues have no per-issue files — they are **table rows** in two Markdown tables. The extraction differs entirely even though the shape (find max, add one) is the same.

A new `seed_issue_id` therefore scans both tables:

```bash
# seed_issue_id <plans-dir> -> next free issue id (1 when no issues exist)
seed_issue_id() {
    local PLANS="$1"
    local ACTIVE="$PLANS/ISSUES.md"
    local ARCHIVE="$PLANS/done/000-issues-archive.md"
    local F LINE N MAX=0

    for F in "$ACTIVE" "$ARCHIVE"; do
        [ -f "$F" ] || continue
        while IFS= read -r LINE; do
            case $LINE in
                '| #'*) N=${LINE#*'| #'}; N=${N%%[!0-9]*} ;;
                *) continue ;;
            esac
            [ -n "$N" ] || continue
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done < "$F"
    done

    printf '%s\n' "$((MAX + 1))"
}
```

**Scanning both files is the core correctness requirement of this plan**, not an optimization: reading only `ISSUES.md` is precisely the mistake that produced the `#77` collision.

Seeding is wired in `lib/cmd_init.sh` beside the existing plan seed (`:563-566`), with identical semantics — seed only when the value is missing or non-numeric, so a live counter is never disturbed by a repeat `init` (including the `init` that follows `aapp upgrade`).

### 2.3 The `aapp-issueid` Provider Plugin Contract

A **separate** plugin rather than a kind parameter on `aapp-planid`. This keeps the existing plan-provider contract untouched — installed `aapp-planid` providers continue working with no migration — and gives each namespace one plugin with one job.

| Aspect | Contract |
| :--- | :--- |
| Location | `.agents/skills/aapp-issueid/` (entrypoint resolved by `resolve_plugin_entrypoint`, extension-agnostic) |
| Invocation | `AAPP_ACTION=allocate AAPP_REPO_ROOT=<root> <entrypoint>` |
| Output | A bare integer or `#<int>` on stdout |
| Failure | Non-zero exit **aborts allocation** — it never silently falls back to the local counter |
| Absence | Only plugin *absence* falls back to `aapp.issueId` |

The absence-vs-failure asymmetry is inherited from P-22 and is deliberate: a present-but-broken provider must not hand out local IDs that the central authority will later reissue.

A `examples/plugins/aapp-issueid/run.sample` mock ships inert per the P-24 `.sample` convention.

### 2.4 Central vs Local Divergence

When a provider is installed it is authoritative. The **ratchet** in §2.1 means a centrally issued ID always pushes the local counter past itself, so if the provider later becomes unreachable, local fallback allocation resumes above every ID the authority handed out — it can never regress into used numbers.

The reverse direction is **not** solved and is not solvable in this design: local allocations made while offline do not inform the central authority, so two contributors working offline can collide. P-22 accepted this trade for plans; this plan inherits it. Pair 8 (§2.5) is the backstop that reports such a collision rather than preventing it.

### 2.5 Pair 8: Issue ID Duplicate Detection (`lib/planning_health.sh`)

`check_pair4_plan_id_integrity` (`:296`) detects duplicate Plan IDs across blueprints. Pair 8 is its issue-lane counterpart, and it must scan **both** ledgers — a duplicate spanning active and archived rows is exactly the `#77` case and the one a single-file check misses.

```bash
# check_pair8_issue_id_integrity <issues-file> <archive-file>
# Reports any issue id appearing more than once across both ledgers.
```

- Extracts IDs from rows matching `^\|[[:space:]]*#[0-9]+`, consistent with how `check_taxonomy_and_schema` already parses the flat table.
- Reports each duplicate naming **both** locations (`active` / `archive`) so the offender is actionable.
- Returns the violation count, matching the Pair 1–7 convention, and is registered in `check_planning_health` (`:640`) so it runs everywhere the engine runs (`aapp test`, `aapp pause`, `aapp resume`).
- **Detection only** — it never renumbers. Renumbering a published issue ID breaks inbound references and is a human decision.

Had Pair 8 existed, the `#77` reuse would have been reported at the next health run instead of surviving in the ledger.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- `allocate_plan_id`, `normalize_plan_id` and `get_next_plan_id` keep their exact signatures and behavior; only their bodies delegate to the shared core. No caller changes.
- The `aapp-planid` provider contract is untouched, so existing team providers need no migration.
- Existing repositories seed `aapp.issueId` on the next `aapp init` from both ledgers, so the counter starts above every ID already in use.
- The pre-existing duplicate `#77` (active `#78` after renumbering, archive `#77` retained) is already resolved and is **not** renumbered by this plan; Pair 8 must report a clean ledger once implemented.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Shared Allocation Core
- [ ] Task 1.1: Extract `_allocate_id` and `_normalize_id` in `lib/plan_resolver.sh` per §2.1, preserving the ratchet logic and the `RAW` capture comment verbatim.
- [ ] Task 1.2: Reduce `allocate_plan_id`, `normalize_plan_id` and `get_next_plan_id` to wrappers with unchanged signatures and behavior.
- [ ] Task 1.3: Add `allocate_issue_id` and `get_next_issue_id` (read-only peek, claims nothing).
- [ ] Task 1.4: Verify `tests/plan_resolver_test.sh` passes unchanged — plan-side behavior must be provably identical after extraction.

### Phase 2: Two-File Seeding
- [ ] Task 2.1: Implement `seed_issue_id` in `lib/cmd_init.sh` per §2.2, scanning both `ISSUES.md` and `done/000-issues-archive.md`.
- [ ] Task 2.2: Wire `aapp.issueId` seeding beside the existing plan seed (`:563-566`), seeding only when missing or non-numeric.
- [ ] Task 2.3: Surface the next issue ID in the `aapp init` completion banner alongside the next plan ID (`:849-851`).

### Phase 3: Provider Plugin Contract
- [ ] Task 3.1: Author `examples/plugins/aapp-issueid/run.sample` as an inert mock per the P-24 `.sample` convention.
- [ ] Task 3.2: Register `aapp-issueid` in the standard extension points catalog in `cmd_plugins_status()` (`lib/cmd_hook.sh`) so `aapp plugins` reports it as Active / Sample Available / Not Installed with the local-counter fallback state.

### Phase 4: Pair 8 Duplicate Detection
- [ ] Task 4.1: Implement `check_pair8_issue_id_integrity` in `lib/planning_health.sh` per §2.5, scanning both ledgers and naming both locations of each duplicate.
- [ ] Task 4.2: Register Pair 8 in `check_planning_health` (`:640`) following the Pair 1–7 error-accumulation convention.

### Phase 5: Verification & Documentation
- [ ] Task 5.1: Add tests in `tests/plan_resolver_test.sh` covering: issue allocation increments `aapp.issueId`; `get_next_issue_id` claims nothing; two-file seeding picks the max across active and archive; a provider ratchets the local counter past a high issued ID; a failing provider aborts rather than falling back; and Pair 8 detects an active/archive duplicate while passing a clean ledger.
- [ ] Task 5.2: Run all suites via `aapp test`; verify zero regressions, especially plan-side allocation.
- [ ] Task 5.3: Document `aapp.issueId`, `allocate_issue_id`, the `aapp-issueid` provider contract, and Pair 8 in `MANUAL.md`; add `aapp.issueId` to the configuration matrices in `MANUAL.md` and `CHEATSHEET.md`.
- [ ] Task 5.4: Update `ARCHITECTURE.md` (extend the *Plan Identity: Stored, Not Derived* section to cover issue identity) and `.agents/CODEMAP.md` (shared allocation core, `seed_issue_id`, Pair 8).
- [ ] Task 5.5: Update `.agents/AGENTS.md` so the issue-lane protocol instructs agents to claim IDs via `allocate_issue_id` instead of scanning `ISSUES.md` by hand.
- [ ] Task 5.6: Update `CHANGELOG.md` and run syntax checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/plan_resolver.sh` -> Extract shared allocation core; add `allocate_issue_id` and `get_next_issue_id`.
- [ ] `lib/cmd_init.sh` -> Add `seed_issue_id` (two-file scan), wire `aapp.issueId` seeding, surface next issue ID in the banner.
- [ ] `lib/planning_health.sh` -> Add and register `check_pair8_issue_id_integrity`.
- [ ] `lib/cmd_hook.sh` -> Register `aapp-issueid` in the standard extension points catalog.
- [ ] `NEW FILE` -> `examples/plugins/aapp-issueid/run.sample` -> Inert mock issue ID provider.
- [ ] `tests/plan_resolver_test.sh` -> Cover issue allocation, two-file seeding, provider ratchet and abort, and Pair 8.
- [ ] `MANUAL.md` -> Document `aapp.issueId`, the provider contract, and Pair 8.
- [ ] `CHEATSHEET.md` -> Add `aapp.issueId` to the configuration matrix.
- [ ] `ARCHITECTURE.md` -> Extend stored-identity section to cover issue IDs.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/ISSUES.md` -> Row content is issue-lifecycle data, not implementation scope; the existing `#77`/`#78` history is settled and must not be renumbered.
- [ ] `.plans/done/000-issues-archive.md` -> Archive is append-only and terminal.
- [ ] `lib/cmd_matrix.sh` -> Matrix derivation is owned by P-30 and unaffected.
- [ ] `lib/cmd_plan.sh` -> Plan lifecycle verbs call the allocator but need no changes.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.githooks/*` -> Pair 5 self-protected; propagate via `aapp init`.

---

## ❓ 5. Open Questions & Settled Decisions

* [x] **Question 1 — One shared counter or two independent ones? → RESOLVED (developer, 2026-09-22): two independent counters.** `#<num>` and `P-<num>` are distinct namespaces that `.agents/AGENTS.md` forbids interchanging, and lifecycle verbs already reject a `#` where a Plan ID belongs. A single sequence would make issue numbers jump unpredictably and collapse that separation. `P-32` and `#32` may therefore both exist.
* [x] **Question 2 — Provider plugin: extend `aapp-planid` with a kind parameter, or ship a separate plugin? → RESOLVED (developer, 2026-09-22): a separate `aapp-issueid` plugin.** Leaves the existing `aapp-planid` contract untouched so installed team providers need no migration, and keeps one plugin per namespace with no kind dispatch.
* [x] **Question 3 — Does this plan include duplicate detection, or does `#79` keep that half? → RESOLVED (developer, 2026-09-22): this plan takes both halves and supersedes `#79`.** A counter prevents future bad scans but cannot catch a hand-typed duplicate; detection reports collisions but cannot stop them. Only both together close the hole that produced the `#77` reuse.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-22:** Blueprint scaffolded on developer direction after git history showed issue `#77` had been logged, resolved and relocated before being reused hours later for an unrelated defect. Establishes a parameterized allocation core shared by both namespaces, an `aapp.issueId` counter seeded from **both** the active ledger and the archive (the single-file scan being the actual cause of the collision), a separate `aapp-issueid` provider plugin leaving the plan contract untouched, and Pair 8 duplicate detection as the backstop for offline divergence. Records the two-independent-counters decision, the separate-plugin decision, and the supersession of `#79`.
