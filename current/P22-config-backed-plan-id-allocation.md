# 🗺️ Plan P-22: Config-Backed Monotonic Plan ID Allocation
* **Created:** 2026-09-19 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** #69
* **Plan ID:** P-22
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

`get_next_plan_id()` in `lib/plan_resolver.sh` allocates the next canonical unpadded Plan ID (`P-<num>`) by taking the maximum across three sources: blueprint **filenames** in `.plans/current` and `.plans/done`, the `* **Plan ID:**` **header** inside each blueprint, and finally the rows of the **archive ledger** (`.plans/done/000-archive-ledger.md`). The ledger tier exists because archived plan *files* may be pruned while the ledger retains their IDs permanently — it is the only durable floor preventing ID reuse.

**The ledger tier has never worked.** At `lib/plan_resolver.sh:267` the match arm is written as:

```bash
if [[ "$LINE" =~ \|[[:space:]]*`?P-([0-9]+)`?[[:space:]]*\| ]]; then
```

The backticks are unquoted. Bash performs command substitution on the right-hand side of `=~` before regex compilation, so the shell attempts to execute `` `?P-([0-9]+)` `` as a command. This is **not** a parse-time failure — `bash -n` reports the file as clean, which is why the defect survived review and 321 passing tests.

Verified runtime behaviour in this repository (2026-09-19, `develop` @ `bcd0995`):

1. Each ledger line emits two stderr lines: `command substitution: line 267: syntax error near unexpected token '[0-9]+'`.
2. The substitution yields the empty string, collapsing the regex to `\|[[:space:]]*?[[:space:]]*\|` — a pattern with **no capture group** that still matches ordinary ledger rows (confirmed: `BASH_REMATCH` has `count=1`, `BASH_REMATCH[1]` is unset).
3. Line 268 then evaluates `$((10#${BASH_REMATCH[1]}))` as `$((10#))`, which bash treats as a **fatal arithmetic error**: `10#: invalid integer constant (error token is "10#")`.
4. The shell aborts before reaching the terminal `echo "P-$((MAX_ID + 1))"`. Measured result on this repo: **stdout empty, exit code 1.**

The blast radius of that failure is wider than the function. `aapp:7` and `lib/cmd_plan.sh:7` both set `set -e`, so any caller inherits a hard abort rather than a degraded ID.

The defect is invisible to CI because the fixture in `tests/plan_resolver_test.sh` (which asserts `get_next_plan_id` returns `P-14`) never writes a `000-archive-ledger.md`; the ledger `while` loop is skipped entirely. Ledger fixtures exist only in `tests/write-guard_test.sh`, which never calls the resolver. This is a genuine cross-suite coverage hole, not merely a missing assertion.

**Architectural goal (revised 2026-09-19 — see §6).** The scan is not worth repairing. Deriving an identity counter by re-parsing filenames, markdown headers, and a markdown table on every allocation is a fragile reconstruction of a number the system could simply *remember*. #69 is a symptom of that design, not the disease.

This plan replaces all three scan tiers with a **monotonic counter held in git config** (`aapp.lastPlanId`), incremented once when a plan is initialized. The broken regex at line 267 is resolved by **deletion**, not repair.

Two properties motivate the change beyond simplicity:
- **IDs are never reused.** The ledger tier existed solely to stop a pruned plan file's ID from being handed out twice. A counter that only ever moves forward gives that guarantee unconditionally — including for plans in `.plans/aborted/`, whose IDs should stay permanently spent.
- **Allocation stops depending on parse correctness.** No markdown table, filename convention, or header format can break ID allocation again.

`git rev-parse --git-common-dir` resolves to `.git` here, so the counter is shared across every mounted worktree (`.plans`, `.agents`, `.githooks`) with no synchronisation work.

---

## 2. Technical Blueprint

### 2.1 The counter key

Introduce `aapp.lastPlanId` — the highest ID ever *allocated*, not the highest currently on disk. camelCase matches every existing key (`aapp.aiAttribution`, `aapp.syncWorktrees`, `aapp.pullStrategy`).

It stores the **last used** value rather than the next free one so that an unset key and a zero value mean the same thing, and so the stored number always corresponds to a plan that really was created.

**The stored value is a bare integer.** `aapp.lastPlanId=22`, not `P-22`. The `P-` prefix is a *namespace marker* applied at presentation to distinguish a plan id from an issue id (`#69`) or any other id the project may grow — it is not part of the value. Every comparison, increment, and config write operates on digits; `P-` is added only on output. This is also why an external provider may return either form (§2.6).

### 2.2 Two functions, one mutating

A single "get next" call is ambiguous: callers that merely want to display the next ID must not consume one. Split the responsibility.

```bash
# Read-only peek. Never mutates. Safe for status output.
get_next_plan_id() {
    local LAST
    LAST="$(git config --get aapp.lastPlanId 2>/dev/null || echo 0)"
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    echo "P-$((LAST + 1))"
}

# Claims the ID and persists the increment. Called exactly once per plan creation.
# NOTE: this is the local-counter core only. The authoritative definition is in
# §2.6, which wraps it with aapp-planid provider delegation. Implement §2.6's
# version -- this block shows the fallback path it falls through to.
allocate_plan_id() {
    local LAST NEXT
    LAST="$(git config --get aapp.lastPlanId 2>/dev/null || echo 0)"
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    NEXT=$((LAST + 1))
    git config aapp.lastPlanId "$NEXT" || return 1
    printf 'P-%s\n' "$NEXT"
}
```

> **Single definition rule:** `allocate_plan_id` is specified in **one** place — §2.6. The block above exists to isolate the counter mechanics; do not implement both.

The `case` guard replaces `$((10#$X))` entirely. `$((...))` on unvalidated input is exactly what made #69 fatal rather than merely wrong; validating before arithmetic removes that class of failure instead of guarding each site.

Leading-zero handling disappears with it — the counter is written by us and never zero-padded, so there is no octal hazard and no need for `10#`.

### 2.3 Seeding existing repositories

Git config is **not committed**. A fresh clone, or any repo predating this change, has no counter — and a counter starting at zero would re-issue live IDs. This is the one genuine risk in the design and it is handled at exactly one place: `aapp init`, following the established idempotent pattern at `lib/cmd_init.sh:452-476`.

**Portability constraint (developer directive, 2026-09-19).** The bootstrap must not depend on GNU-flavoured tool behaviour. This repo has already been bitten twice by that class of bug and both are still open:
- `#59` — `sort -z` is GNU/newer-BSD only and breaks the Plans pillar on older macOS (live at `lib/cmd_status.sh:230` and three sites in `lib/planning_health.sh`).
- `#60` — parsing `ls` output breaks on filenames containing newlines.

For the record, `sort -n` itself *is* POSIX.1-2017 and is already used at `lib/planning_health.sh:178-203`; it is `sort -z` that is the non-portable one. Rather than argue the margin, the bootstrap below avoids `sort`, `grep -o`, and `ls` **entirely** — it uses nothing but glob expansion, parameter expansion, and `test`. That is both maximally portable and immune to the `#60` newline class by construction.

```bash
# One-time bootstrap. No ls, no grep -o, no sort, no arithmetic on parsed text.
seed_last_plan_id() {
    local PLANS="$1" LEDGER="$1/done/000-archive-ledger.md"
    local DIR F BNAME LINE N MAX=0

    for DIR in current done aborted; do
        [ -d "$PLANS/$DIR" ] || continue
        for F in "$PLANS/$DIR"/[Pp][0-9]*.md; do
            [ -e "$F" ] || continue          # literal-glob guard when no match
            BNAME=${F##*/}
            N=${BNAME#[Pp]}                  # strip the P
            N=${N%%[!0-9]*}                  # keep the leading digit run
            [ -n "$N" ] || continue
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done
    done

    # Ledger rows cover archived plans whose files were pruned (P-0..P-8 here).
    if [ -f "$LEDGER" ]; then
        while IFS= read -r LINE; do
            case $LINE in
                *'`P-'*) N=${LINE#*\`P-}; N=${N%%[!0-9]*} ;;
                *) continue ;;
            esac
            [ -n "$N" ] || continue
            if [ "$N" -gt "$MAX" ]; then MAX=$N; fi
        done < "$LEDGER"
    fi

    printf '%s\n' "$MAX"
}
```

Three details that are load-bearing rather than stylistic:

- **`if ... then ... fi`, not `[ ... ] && MAX=$N`.** `aapp:7` and `lib/cmd_plan.sh:7` both set `-e`. A trailing `&&` list whose test fails yields a non-zero statement status; the explicit `if` can never do that.
- **`[ -e "$F" ] || continue`.** POSIX shells leave an unmatched glob as its literal pattern; without the guard the loop would process a file named `[Pp][0-9]*.md`. Verified in `dash`.
- **No `10#` and no leading-zero stripping.** POSIX `test -gt` parses operands as decimal integers, so a legacy `P-007` compares as `7`, not octal. Verified in `dash`. This is also why the comparison uses `test` rather than `$((...))` — arithmetic on parsed text is what made `#69` fatal.

Wired into `init` with the existing idempotent guard:

```bash
if [ -z "$(git config --get aapp.lastPlanId 2>/dev/null || true)" ]; then
    git config aapp.lastPlanId "$(seed_last_plan_id "$REPO_ROOT/.plans")"
fi
```

This runs **once per clone** and never again; it is a bootstrap, not an allocation path. Verified against this repository: returns `22`.

`.plans/aborted/` is included deliberately — an abandoned plan's ID must stay permanently spent.

### 2.4 What is deleted

The entire three-tier scan in `get_next_plan_id` is removed: the `current`/`done` filename walk, the per-file `get_plan_id` header scan, and the archive-ledger table scan containing the #69 defect. `get_plan_id()` itself **stays** — it is a separate, working helper used elsewhere to read a plan's declared ID.

### 2.5 Collision backstop is unchanged

`check_pair4_plan_id_integrity()` (`lib/planning_health.sh:296`) independently verifies that header IDs match filename prefixes and that no two plans share an ID. It does its own scanning and is deliberately **out of scope** — it remains the detector if the counter ever drifts (a hand-created plan file, a restored clone, a config reset).

Concurrency: git config read-modify-write is not atomic, so two agents allocating simultaneously in different worktrees could collide. This is not newly introduced — the scan had the same race — and Pair 4 catches it. `aapp pause` already exists to serialise multi-window work. Hardening beyond that is deferred (see Open Question 2).

### 2.6 Team coordination via a standard action plugin

**Directive (developer, 2026-09-19):** do not chase lifecycle events or add CLI verbs to make allocation hookable. Expose **one** well-known extension point, wired directly into the allocation function, and document that teams needing shared IDs must supply a plugin. Absent that plugin, the local git-config counter stands.

This supersedes the earlier hook-event approach in full. `on-digest` stays dead and that is now irrelevant to this plan — no event is dispatched, no command is added.

#### The standard name

`aapp-planid`, resolved through the existing P-12 action-plugin mechanism at `.agents/skills/aapp-planid/`. Entrypoint discovery is already implemented and extension-agnostic (`resolve_plugin_entrypoint`, `lib/cmd_hook.sh:113`): `run` -> `aapp-planid` -> `scripts/run` -> `scripts/aapp-planid`, then any-extension variants. A team may therefore ship the provider as a shell script, a Python file, or a compiled binary with no change here.

**Relocation required before reuse.** `resolve_plugin_entrypoint` currently lives in `lib/cmd_hook.sh`, which is **not safely sourceable**: it carries a top-level dispatcher (`SUBCMD="${1:-hooks}"` followed by an executing `case`, `:265-296`). Sourcing it to borrow the function would run `cmd_hooks_status` as a side effect, or `exit 1` on an unrecognised first argument.

Move the function into `lib/hook_dispatcher.sh`, which *is* safely sourceable — its only top-level statements are `set -e` and a `REPO_ROOT` guard, and `lib/cmd_sync.sh:193` already sources it as established precedent. `lib/cmd_hook.sh` then consumes it from there. This keeps one implementation rather than adding a duplicate helper.

Two notes for the implementer:
- Sourcing `hook_dispatcher.sh` **enables `set -e` in the caller** (`:15`). Harmless for `aapp` and `lib/cmd_plan.sh`, which already set it, but `lib/plan_resolver.sh` must be checked against that.
- A **third** inline copy of this resolution exists in the `aapp` switchboard (`:157-175`). Consolidating all three is worth doing but is **out of scope here** — this plan moves one function and leaves the switchboard untouched.

The `aapp-` prefix is deliberate: `.agents/skills/aapp-*` is Guard Section 2 protected, so an installed provider is **tamper-evident — agents cannot rewrite the ID authority**. That is the same protection already relied on for the hooks registry.

**Defined Name vs. Git Config Rationale:** A dedicated Git config key (e.g. `git config aapp.planIdPlugin <name>`) was considered and rejected because it creates an un-gated security blind spot: while `.git/config` is protected from direct tool edits, an autonomous agent running shell commands (`run_command` / `Bash`) could execute `git config aapp.planIdPlugin ...` without passing any gate, hijacking the ID authority to an arbitrary or broken script. In contrast, `.agents/skills/aapp-planid/` begins with `aapp-` and is permanently protected under Guard Section 2 (`blast-radius-guard`), mechanically blocking AI agents from modifying or overriding the team provider script.

It also gains `aapp plugins` discovery and `aapp aapp-planid` direct invocation for free, with no switchboard change.

#### Resolution order inside `allocate_plan_id`

```bash
allocate_plan_id() {
    local ROOT PDIR ENTRY RAW OUT LAST NEXT
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    PDIR="$ROOT/.agents/skills/aapp-planid"

    # 1. Delegate to the provider plugin when one is installed.
    if [ -d "$PDIR" ] && ENTRY="$(resolve_plugin_entrypoint "$PDIR" "aapp-planid")"; then
        OUT="$(AAPP_ACTION=allocate AAPP_REPO_ROOT="$ROOT" "$ENTRY" 2>/dev/null)" || {
            echo "❌ [Plan ID] Provider plugin failed; refusing to allocate locally." >&2
            return 1
        }
        # NB: capture into RAW first. Assigning the substitution straight back into
        # OUT clobbers it before the || branch runs, losing the offending value.
        RAW="$OUT"
        OUT="$(normalize_plan_id "$RAW")" || return 1   # normalize_plan_id already reported why
        # Ratchet the local counter forward so the fallback never regresses.
        LAST="$(git config --get aapp.lastPlanId 2>/dev/null || echo 0)"
        case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
        NEXT="${OUT#P-}"
        if [ "$NEXT" -gt "$LAST" ]; then git config aapp.lastPlanId "$NEXT"; fi
        printf '%s\n' "$OUT"
        return 0
    fi

    # 2. No plugin installed -> local git config counter.
    LAST="$(git config --get aapp.lastPlanId 2>/dev/null || echo 0)"
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    NEXT=$((LAST + 1))
    git config aapp.lastPlanId "$NEXT" || return 1
    printf 'P-%s\n' "$NEXT"
}
```

Four contract points that are deliberate rather than incidental:

- **Only absence falls back.** A plugin that is installed but *fails* is fatal (`return 1`), never a silent downgrade to local allocation. Falling back on failure would reintroduce exactly the collision the provider exists to prevent — and would do it invisibly, at the worst moment.
- **Either form accepted, integer enforced.** A provider may return `P-42` or bare `42` — the `P-` is only a namespace marker (§2.1), so demanding it would be arbitrary. Beyond stripping that optional prefix we check one thing: is it an integer? If not, error out and refuse to allocate. We do not normalize, repair, or interpret third-party output.
- **The local counter ratchets forward on every plugin success.** If the provider is later uninstalled, the git-config fallback resumes from the highest ID actually issued rather than from a stale local value.
- **`get_next_plan_id` (the read-only peek) never calls the plugin.** Peeking must stay free of side effects and must not depend on a provider being reachable; it reports the local counter only, and documents that the real ID may come from the provider.

#### Id validation

Accept either form — `P-42` or bare `42` — then check it is an integer. Nothing more. A provider that returns anything else has a bug, and it is the provider's job to emit a well-formed id, not ours to guess at one.

```bash
# Accepts "P-42" or "42". Anything that is not a plain integer is an error.
normalize_plan_id() {
    local N="${1#P-}"
    case "$N" in
        ''|*[!0-9]*)
            echo "❌ [Plan ID] Provider must return an integer id (got: '$1')" >&2
            return 1
            ;;
    esac
    printf 'P-%s\n' "$N"
}
```

That is the entire parsing surface: one prefix strip, one integer check, one error message. No whitespace normalization, no case folding, no zero-padding logic, no pattern matching on shapes of input. Canonical formatting is the provider's responsibility — if it emits `P-007`, it gets `P-007`; the comparison below is unaffected because POSIX `test -gt` reads it as decimal.

#### Shipped mock example

`examples/plugins/planid-remote/run` — a **mock only**, matching the style of the existing `examples/plugins/hello-tool/run`. It simulates fetching an ID from a remote authority and prints a single `P-<n>` line. It performs no network I/O, is not installed by `aapp init`, and exists purely so an adopter can see the contract and copy it.

### 2.7 Installation Asset Preservation (`examples/`)

AAPP's mock examples are actively expanding (`examples/hooks/`, `examples/plugins/`, and future mock providers like `planid-remote/run`). Adopters and AI agents require these reference examples on the machine to inspect canonical patterns and copy working templates.

Currently, `lib/cmd_install.sh:84-87` copies `lib/`, `templates/`, and `tests/` to `$SHARE_DIR` (`~/.local/share/aapp-kit/`), but omits `examples/`. When the installer self-consumes the temporary clone directory, all examples are permanently lost from the machine.

1. **Global Installation (`aapp install`)**:
   `lib/cmd_install.sh` is updated to copy `examples/` to `$SHARE_DIR/examples/` alongside templates and libraries:
   ```bash
   [ -d "$AAPP_SCRIPT_DIR/examples" ] && cp -r "$AAPP_SCRIPT_DIR/examples" "$SHARE_DIR/"
   ```
2. **Drop-In Mode (`./aapp-kit/aapp init`) — Explicitly Undecided & Untouched**:
   In drop-in mode, an adopting repository consumes the kit directory upon successful initialization (`lib/cmd_init.sh:715-731`). **It is yet not decided what will happen to `examples/` at drop-in.**
   - Therefore, drop-in mode is **strictly untouched** in this plan.
   - Phase 7 of `lib/cmd_init.sh` remains completely unchanged.
   - The question of whether drop-in should preserve examples to `$SHARE_DIR/examples/`, copy them into the adopter project, leave drop-in minimal, or provide an opt-in mechanism is deferred and held open under **Open Question 6** for future consideration.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: **one declared fallback** — `aapp-planid` plugin absent -> local `aapp.lastPlanId` git-config counter (§2.6).
  - *Nature:* this is a **designed extension point**, not a legacy shim or dual-syntax parser. Nothing is retained for backwards compatibility and there is no retirement date: the local counter is the permanent default, and the plugin is the permanent opt-in override. It is declared here because the Clean Break Invariant prohibits *un-named* fallbacks, and a two-path resolution must be named whatever its motivation.
  - *Scope limit:* the fallback triggers on **plugin absence only**. A plugin that is installed and fails is fatal — there is no degraded path.
  - The removed three-tier scan itself gets no fallback: it is deleted outright, with no "scan if config is unset" path. An unseeded repo starts at `P-1`, correct for a new project and flagged by Pair 4 in any other case.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Confirm `aapp.lastPlanId` is unset in this repo and that `git rev-parse --git-common-dir` resolves to a shared `.git` across all mounted worktrees.
- [ ] Task 1.2: Implement `seed_last_plan_id` per §2.3 and verify it returns `22` here. Test it under `dash` as well as `bash`, and against a fixture containing a filename with an embedded newline (the `#60` class) and a zero-padded `P-007`.

### Phase 2: Core Implementation
- [ ] Task 2.1: Replace the three-tier scan in `get_next_plan_id` with the read-only config accessor (§2.2). Delete the ledger loop containing the #69 defect. Leave `get_plan_id()` intact.
- [ ] Task 2.2: Add `allocate_plan_id()` as the single mutating claim path.
- [ ] Task 2.3: Seed `aapp.lastPlanId` in `lib/cmd_init.sh` via `seed_last_plan_id`, using the idempotent guard pattern already at lines 452-476. Confirm no `sort`, `grep -o`, or `ls` enters the path.
- [ ] Task 2.4: Surface the key in the `aapp init` summary banner alongside the existing `aapp.remote` / `aapp.syncStrategy` lines.
- [ ] Task 2.5: Update `lib/cmd_install.sh` to copy `examples/` to `$SHARE_DIR/examples/` during `aapp install` (§2.7). (Global install only; drop-in mode in `cmd_init.sh` is untouched as its disposition is not yet decided).

### Phase 3: Instruction & Template Sync
- [ ] Task 3.1: Update `templates/skills/aapp-digest/SKILL.md` step 2 — it currently instructs agents to allocate "by scanning highest existing ID across `.plans/current/` and `.plans/done/`". Replace with `allocate_plan_id`.
- [ ] Task 3.2: Update `templates/skills/aapp-plan/SKILL.md` and `templates/AGENTS.md:206` to match.
- [ ] Task 3.3: **Do not hand-edit installed skills.** `.claude/skills/aapp-*` and `.agents/skills/aapp-*` are Guard Section 2 protected; refresh them by re-running `aapp init` so templates remain the single source.

- [ ] Task 3.4a: Move `resolve_plugin_entrypoint` from `lib/cmd_hook.sh` into `lib/hook_dispatcher.sh` and have `cmd_hook.sh` consume it there. Do not duplicate it.
- [ ] Task 3.4b: Wire `aapp-planid` resolution into `allocate_plan_id` per §2.6, sourcing `hook_dispatcher.sh` the way `lib/cmd_sync.sh:193` does. Verify the inherited `set -e` is safe in every `plan_resolver.sh` caller.
- [ ] Task 3.5: Ship the mock provider at `examples/plugins/planid-remote/run`, matching `hello-tool/run` style. No network I/O; not installed by `init`.
- [ ] Task 3.6: Document the opt-in contract in `MANUAL.md` / `README.md`: teams needing shared IDs must supply an `aapp-planid` plugin; absent one, IDs are per-clone and Pair 4 is the detector.

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Rewrite the `get_next_plan_id` assertions in `tests/plan_resolver_test.sh` against the counter. Cover: unset key yields `P-1`; peek is non-mutating across repeated calls; `allocate_plan_id` persists and is strictly monotonic; a corrupt/non-numeric value degrades to `0` rather than aborting.
- [ ] Task 4.2: Assert `get_next_plan_id` emits **nothing on stderr** — the assertion that would have caught #69.
- [ ] Task 4.3: Confirm Pair 4 still passes and remains capable of detecting a duplicate ID (§2.5).
- [ ] Task 4.3b: Cover the plugin path in `tests/plan_resolver_test.sh`: absent plugin -> config counter; mock provider -> its id is used and ratchets `aapp.lastPlanId`; failing provider -> non-zero, **no** local allocation.
- [ ] Task 4.3c: Test `normalize_plan_id` on `P-42` and `42` (both -> `P-42`) and on a non-integer (error + non-zero, no allocation).
- [ ] Task 4.3d: Update `tests/install_test.sh` to assert `examples/` is copied to `$SHARE_DIR/examples/` during `aapp install`.
- [ ] Task 4.4: Run all suites; confirm the total moves from 321 with no regressions.
- [ ] Task 4.5: Document `aapp.lastPlanId` in `MANUAL.md` / `README.md` config tables; update `ARCHITECTURE.md` and `.agents/CODEMAP.md` for the resolver's changed contract (a new exported function is an interface change).
- [ ] Task 4.6: Update `CHANGELOG.md` and run syntax checks before committing.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/plan_resolver.sh` -> Delete three-tier scan; reimplement `get_next_plan_id` as read-only config peek; add `allocate_plan_id`.
- [ ] `lib/cmd_init.sh` -> Seed `aapp.lastPlanId` idempotently with the one-time bootstrap; surface it in the init summary.
- [ ] `lib/cmd_install.sh` -> Copy `examples/` to `$SHARE_DIR/examples/` during `aapp install` (global install only).
- [ ] `tests/install_test.sh` -> Assert `examples/` copied to `$SHARE_DIR` on install.
- [ ] `tests/plan_resolver_test.sh` -> Rewrite ID-allocation assertions against the counter; add stderr-cleanliness assertion.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Replace scan-based allocation instruction with `allocate_plan_id`.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Same instruction update.
- [ ] `templates/AGENTS.md` -> Update the allocation protocol description at line 206.
- [ ] `MANUAL.md` -> Document the `aapp.lastPlanId` key.
- [ ] `README.md` -> Add the key to the configuration reference.
- [ ] `ARCHITECTURE.md` -> Record the shift from derived to stored plan identity.
- [ ] `.agents/CODEMAP.md` -> Update the `lib/plan_resolver.sh` entry for the new function surface.
- [ ] `lib/hook_dispatcher.sh` -> Receive `resolve_plugin_entrypoint` so it is sourceable by both `cmd_hook.sh` and `plan_resolver.sh`.
- [ ] `lib/cmd_hook.sh` -> Consume the relocated `resolve_plugin_entrypoint` instead of defining it.
- [ ] `NEW FILE` -> `examples/plugins/planid-remote/run` -> Mock provider plugin demonstrating the `aapp-planid` contract (no network I/O).
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/planning_health.sh` -> Pair 4 is the independent collision backstop; it must keep scanning and must not be coupled to the counter.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected. Regenerate via `aapp init`, never edit.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected. Same rule.
- [ ] `.plans/done/000-archive-ledger.md` -> Append-only historical record. The bootstrap reads it once; nothing writes to it.
- [ ] `templates/blast-radius-guard.sh` -> Unrelated enforcement engine; its own `ls -1` defect is tracked separately as `#60`.
- [ ] `templates/aapp-pre-commit` -> Enforcement engine is out of scope.
- [ ] `lib/cmd_sync.sh` -> Sync transport untouched. This plan uses no lifecycle events.
- [ ] `lib/cmd_plan.sh` -> Hook dispatch untouched. This plan uses no lifecycle events.
- [ ] `templates/skills/aapp-hooks/` -> Hook registry and handlers are out of scope entirely.
- [ ] `aapp` -> The switchboard's inline copy of plugin resolution (`:157-175`) is left as-is; consolidating all three copies is a separate refactor.
- [ ] `lib/hook_dispatcher.sh` dispatch logic -> Only the relocated helper is added; event dispatch, registry parsing, and watchdog behaviour are untouched.
- [ ] `.agents/skills/aapp-planid/` -> Adopter-supplied and Guard Section 2 protected. This plan defines the contract and ships a mock under `examples/`; it never installs a provider.
- [ ] `lib/cmd_init.sh` (Phase 7 drop-in consumption) -> Drop-in folder consumption is untouched; what will happen to `examples/` at drop-in is not yet decided and is strictly out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Counter is local, not shared. → RESOLVED (developer, 2026-09-19): a standard action plugin, not lifecycle hooks.** See §2.6. `allocate_plan_id` resolves `.agents/skills/aapp-planid/` via the existing P-12 discovery; if no provider is installed it uses the local git-config counter. Teams needing shared IDs supply the plugin; this is documented as an opt-in obligation rather than built in. The earlier hook-event approach (`post-sync` re-seed + `on-freeze` gate) is **withdrawn** — no events, no new CLI verbs.
* [ ] **Question 2 — Concurrency hardening.** Should `allocate_plan_id` take a lock (e.g. `.git/aapp_planid.lock`) to serialise simultaneous allocation across worktrees, or is the existing `aapp pause` discipline plus Pair 4 detection sufficient?
* [ ] **Question 3 — Should `#69` close as fixed or as obsolete?** The defective line is deleted rather than corrected. It affects how the archive ledger records this work.
* [ ] **Question 4 — Template drift discovered during digest.** `.plans/plan-template.md` is stale against canonical `templates/plan-template.md`: it still carries the retired status enum (`🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED`) and lacks the `* **Plan ID:**` field entirely. Any plan scaffolded from the worktree copy would be born with an invalid status under the strict enum from `a782e5e`. Fold into this plan, or log as its own issue? *Unrelated to the counter redesign — still open.*
* [ ] **Question 5 — Severity of `#69`.** Recorded as `Low` and sitting unsequenced in Triage, but verified behaviour is a hard failure (`get_next_plan_id` returns empty, exit `1`, under `set -e` callers). Correct the `Sev` field? *Board ordering is your judgement call — I have not re-sequenced it.*
* [ ] **Question 6 — Drop-In Mode Asset Handling (Undecided).** It is yet not decided what will happen to `examples/` at drop-in (`./aapp-kit/aapp init`) when the kit folder self-consumes. Possible approaches for future decision: (a) Copy `examples/` to `$HOME/.local/share/aapp-kit/examples/` so the host machine retains them without polluting the adopter repository; (b) Copy into adopter repo (e.g. `examples/` or `.plans/examples/`); (c) Keep drop-in minimal with kit folder self-consumed and no examples copied; (d) Interactive prompt or user opt-in flag. *Held strictly open with zero drop-in code modifications in this plan per developer directive.*

* [ ] **Question 7 — Blast Radius collides with P-23.** P-23 (*Lifecycle Hook Sequencing & Pre-Mutation Gates*, scaffolded concurrently) shares **5 Target Files** with this plan: `lib/hook_dispatcher.sh`, `lib/cmd_hook.sh`, `MANUAL.md`, `README.md`, `CHANGELOG.md`. Per the Disjointness Activation Gate (`.agents/AGENTS.md:233`) both cannot be in flight at once. The docs three are routine; the two `lib/` files are substantive — this plan *moves* `resolve_plugin_entrypoint` between them while P-23 *restructures dispatch sequencing* in the same files. Options: (a) sequence P-23 first, since it reshapes the dispatcher this plan borrows from; (b) move the `resolve_plugin_entrypoint` relocation into P-23, where those files are already open, and have P-22 consume it; (c) accept a merge conflict and serialise by hand. *(b) looks cleanest, but plan sequencing is your call.*
* [ ] **Question 8 — Should a corrupt `aapp.lastPlanId` degrade to `0`, or error?** §2.2/§2.6 currently do `case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac`, so a garbage config value silently yields `P-1` — colliding with every existing plan. That contradicts the principle applied to provider output in §2.6 ("not a clear int -> error out"). An unset key legitimately means zero; a *non-empty, non-numeric* key means something is wrong and arguably should refuse rather than restart the sequence. Recommend splitting the two cases; flagged rather than changed because it alters designed behaviour.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-19:** Plan initialized via `/aapp-digest #69` (promotion from `ISSUES.md`, issue lane -> plan lane). Root cause verified empirically rather than assumed: confirmed parse-clean / runtime-fatal behaviour, empty-capture arithmetic abort, `stdout=''` + `exit 1`, and the cross-suite fixture gap that hid it from 321 passing tests.
* **2026-09-19 (amendment):** **Design direction changed by the developer** — do not repair the regex; stop deriving plan IDs by parsing altogether and hold the counter in git config, updating it when a plan is initialized. Rewrote §1 goal and replaced §2 entirely: three-tier scan deleted, `aapp.lastPlanId` counter introduced, `get_next_plan_id` demoted to a read-only peek, `allocate_plan_id` added as the sole mutating claim, and `$((10#...))` removed in favour of pre-arithmetic validation. Blast Radius widened materially: the allocation contract is documented in three template/skill files and `AGENTS.md`, so those now require synchronised edits (installed skill copies stay out of bounds under Guard Section 2). `#69` is now resolved by deletion rather than correction. New Open Questions 1-3 cover the counter's local-only nature, concurrency, and how `#69` should be closed; prior questions on failure posture and `10#` guard scope are obsolete and were dropped. Plan renamed `P22-ledger-scan-regex-integrity.md` -> `P22-config-backed-plan-id-allocation.md`.
* **2026-09-19 (amendment 2):** **Portability directive from the developer** on the §2.3 bootstrap. Investigation corrected the specific premise — `sort -n` is POSIX.1-2017 and already in use at `lib/planning_health.sh:178-203`; `sort -z` is the non-portable one (`#59`). The genuine defects in the first draft were different: it used `grep -o` (a GNU extension) and parsed `ls` output, the latter reproducing the exact bug class of open issue `#60`. Rather than substitute one tool for another, §2.3 was rewritten to drop `sort`, `grep -o` and `ls` entirely in favour of glob expansion, parameter expansion and `test` — immune to the `#60` newline class by construction. Added three load-bearing notes: explicit `if/fi` over `&&` lists (both callers run `set -e`), the literal-glob `[ -e ]` guard, and reliance on POSIX `test` decimal parsing instead of `$((10#...))`. **Verified by execution** in both `bash` and `dash`, under `set -e`: real repo -> `22`; fixture with a newline-containing filename, a zero-padded `P-007`, a decoy `plan-no-id.md`, and a ledger-only `P-44` -> `44`; empty `.plans` -> `0` (yielding `P-1`).
* **2026-09-19 (amendment 3):** **Open Question 1 resolved by the developer** — coordinate the counter across a team with the P-12 hook engine. Added §2.6. Verified the enabling property: committed-registry handlers default to `gate` (`hook_dispatcher.sh:257`) while local `git config` overrides are forced to `notify` (`:276`), so a team gate cannot be locally bypassed. **Discovered that the developer's first choice, `on-digest`, is a dead event** — advertised at `cmd_hook.sh:190`, documented in the hooks SKILL and registry, shipping a sample handler, but carrying zero `dispatch_hook` call sites. Root cause is structural: there is no `lib/cmd_digest.sh` and no digest CLI verb, because digest is an agent-driven skill workflow — the same reason `get_next_plan_id` has no runtime callers. Retargeted implementation onto two events that do fire: `post-sync` (`cmd_sync.sh:202`) for preventive re-seeding and `on-freeze` (`cmd_plan.sh:225`/`:303`, already `|| exit 1`) for collision gating. Blast Radius extended with two handler scripts, `registry.tsv`, and `tests/hooks_test.sh`. Added Open Question 6 on whether promoting `aapp digest` to a real CLI verb — the only thing that would activate `on-digest` — belongs here or in its own blueprint.
* **2026-09-19 (amendment 4):** **Approach replaced on developer direction** — stop trying to match commands and lifecycle events; expose one standard extension point wired into the allocation function, falling back to git config when absent. §2.6 rewritten around the `aapp-planid` action plugin at `.agents/skills/aapp-planid/`, reusing P-12 extension-agnostic discovery. The `aapp-` prefix is deliberate: Guard Section 2 makes an installed provider tamper-evident. Withdrew the entire hook-event approach (`post-sync` re-seed, `on-freeze` gate, two handler scripts, `registry.tsv`, `tests/hooks_test.sh`) and dropped Open Question 6 on promoting `aapp digest` to a CLI verb — `on-digest` remains dead and is now irrelevant here. Contract pinned on four points: only plugin *absence* falls back (a present-but-failing provider is fatal, never a silent local allocation); provider output is validated as `P-<digits>` before trust; the local counter ratchets forward on plugin success so the fallback never regresses; and the read-only peek never invokes the provider. Ships `examples/plugins/planid-remote/run` as a mock only. **Declared the fallback in the Fallback Inventory** as the Clean Break Invariant requires — named as a designed extension point rather than a legacy shim, with no retirement date. **Corrected a flaw found while verifying:** `resolve_plugin_entrypoint` lives in `lib/cmd_hook.sh`, which is not safely sourceable (top-level dispatcher at `:265-296` would execute on source). It must first move to `lib/hook_dispatcher.sh`, which is sourceable and already sourced by `lib/cmd_sync.sh:193`. Noted the inherited `set -e` and a third inline copy in the `aapp` switchboard, both handled or scoped out explicitly.
* **2026-09-19 (amendment 5):** **Provider output contract relaxed on developer direction** — the `P-` prefix is a namespace marker distinguishing plan ids from issue ids, not part of the value, so a provider may return either `P-42` or bare `42`. Replaced the strict `P-[0-9]*` check with `normalize_plan_id`, which accepts `P-42`/`p-42`/`P42`/`42`, trims whitespace, and collapses legacy zero-padding to the canonical unpadded form of P-13 (`P-007` -> `P-7`). Rejects empty, `P-`, non-numeric, decimal, negative and trailing-junk values; rejects `#`-prefixed ids with a distinct rc 2, since an issue id in the plan namespace indicates a provider bug rather than malformed text. Made the number/prefix split explicit in §2.1: `aapp.lastPlanId` stores a bare integer and `P-` is applied only on output. Verified across `bash` and `dash` on 16 inputs.
* **2026-09-19 (amendment 6):** **Security rationale confirmed & installation asset preservation added on developer direction** — (1) Affirmed the defined canonical name `.agents/skills/aapp-planid/` over a `git config` key to prevent rogue/lost agents with shell access from hijacking the provider without a gate (Guard Section 2 mechanically blocks agent tampering with `aapp-*`). (2) Added §2.7 and updated `lib/cmd_install.sh` and `tests/install_test.sh` to preserve `examples/` in `$SHARE_DIR/examples/` during `aapp install` as mock examples expand. (3) Recorded drop-in mode handling of `examples/` as deferred under Open Question 6 per developer directive.
* **2026-09-19 (amendment 7):** **Drop-in mode explicitly affirmed as undecided on developer direction** — Clarified across §2.7, §3 (Task 2.5), §4 (Out of Bounds), and Open Question 6 that what happens to `examples/` at drop-in is not yet decided. Drop-in mode (`lib/cmd_init.sh` Phase 7) is strictly out of scope and left untouched; only global `aapp install` (`lib/cmd_install.sh`) preserves `examples/` to `$SHARE_DIR/examples/`.
* **2026-09-19 (amendment 8):** **Parsing simplified on developer direction — no elaborate matching.** The amendment-5 normalizer was over-built: it folded case, trimmed whitespace, collapsed zero-padding, matched four input shapes and carried a special exit code for `#`-prefixed values. Replaced with one prefix strip and one integer check; a non-integer is an error with a message and no allocation. Either form (`P-42` or `42`) is still accepted, per the namespace-marker rationale in §2.1. Emitting a well-formed id is the third party's responsibility — our side does not normalize, repair, or interpret provider output.
* **2026-09-19 (amendment 9):** **Review pass requested by the developer.** Fixed a real defect in §2.6's `allocate_plan_id`: `OUT="$(normalize_plan_id "$OUT")"` clobbered `OUT` before the `||` branch executed, so the error message reported `''` instead of the offending value and duplicated the message `normalize_plan_id` already emits — now captured via `RAW` with the redundant echo dropped (demonstrated by execution). Renumbered this session's parsing-simplification entry from a duplicate 'amendment 6' to 'amendment 8' — a concurrent session had independently written amendments 6 and 7 into this file. Raised Open Question 7 (Blast Radius collides with P-23 on 5 Target Files, 2 of them substantive) and Open Question 8 (a corrupt `aapp.lastPlanId` silently degrades to `0` and re-issues `P-1`, contradicting the error-out principle applied to provider output). Verified the concurrently-added §2.7 against the source: `AAPP_SCRIPT_DIR` and the `lib/cmd_install.sh:85-87` copy block it cites are both accurate.

