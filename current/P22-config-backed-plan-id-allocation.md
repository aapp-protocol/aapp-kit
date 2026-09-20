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

This plan replaces all three scan tiers with a **monotonic counter held in git config** (`aapp.planId`), incremented once when a plan is initialized. The broken regex at line 267 is resolved by **deletion**, not repair.

Two properties motivate the change beyond simplicity:
- **IDs are never reused.** The ledger tier existed solely to stop a pruned plan file's ID from being handed out twice. A counter that only ever moves forward gives that guarantee unconditionally — including for plans in `.plans/aborted/`, whose IDs should stay permanently spent.
- **Allocation stops depending on parse correctness.** No markdown table, filename convention, or header format can break ID allocation again.

`git rev-parse --git-common-dir` resolves to `.git` here, so the counter is shared across every mounted worktree (`.plans`, `.agents`, `.githooks`) with no synchronisation work.

---

## 2. Technical Blueprint

### 2.1 The counter key

Introduce `aapp.planId` — **the next id to hand out**, not the last one used. camelCase matches every existing key (`aapp.aiAttribution`, `aapp.syncWorktrees`, `aapp.pullStrategy`).

**Next-free, not last-used (developer directive, 2026-09-20).** `aapp init` seeds a fresh project with **`1`**, so the first plan created is `P-1` and the key always reads as "the id you are about to get". An existing repository is seeded to `max(existing) + 1` — `25` here, with `P-24` currently the highest.

This is a deliberate reversal of the earlier last-used design. The practical difference is what `init` leaves behind: `aapp.planId=1` on a new project, rather than `0` or an unset key that has to be mentally decoded into "so the next one is 1". The value is directly readable as the answer to the only question anyone asks of it.

Consequence to keep in mind: an unset key now means `1`, not `0`. There is no longer a value that means "nothing allocated yet" distinct from "next is 1" — those are the same state, which is why the key is safe to read without a guard for absence.

**The stored value is a bare integer.** `aapp.planId=25`, not `P-25`. The `P-` prefix is a *namespace marker* applied at presentation to distinguish a plan id from an issue id (`#69`) or any other id the project may grow — it is not part of the value. Every comparison, increment, and config write operates on digits; `P-` is added only on output. This is also why an external provider may return either form (§2.6).

### 2.2 Two functions, one mutating

A single "get next" call is ambiguous: callers that merely want to display the next ID must not consume one. Split the responsibility.

```bash
# Read-only peek. Never mutates. Safe for status output.
get_next_plan_id() {
    local CUR
    CUR="$(git config --get aapp.planId 2>/dev/null || echo 1)"
    case "$CUR" in ''|*[!0-9]*) CUR=1 ;; esac
    printf 'P-%s\n' "$CUR"
}

# Claims the ID and persists the increment. Called exactly once per plan creation.
# NOTE: this is the local-counter core only. The authoritative definition is in
# §2.6, which wraps it with aapp-planid provider delegation. Implement §2.6's
# version -- this block shows the fallback path it falls through to.
allocate_plan_id() {
    local CUR
    CUR="$(git config --get aapp.planId 2>/dev/null || echo 1)"
    case "$CUR" in ''|*[!0-9]*) CUR=1 ;; esac
    git config aapp.planId "$((CUR + 1))" || return 1
    printf 'P-%s\n' "$CUR"
}
```

> **Single definition rule:** `allocate_plan_id` is specified in **one** place — §2.6. The block above exists to isolate the counter mechanics; do not implement both.

Under next-free semantics the peek becomes a plain read — no arithmetic at all — and allocation is "return the current value, store the successor". The increment is persisted **before** the id is printed, so a failed config write refuses to issue rather than handing out an id the counter does not know about.

The `case` guard replaces `$((10#$X))` entirely. `$((...))` on unvalidated input is exactly what made #69 fatal rather than merely wrong; validating before arithmetic removes that class of failure instead of guarding each site.

Leading-zero handling disappears with it — the counter is written by us and never zero-padded, so there is no octal hazard and no need for `10#`.

### 2.3 Seeding existing repositories

Git config is **not committed**. A fresh clone, or any repo predating this change, has no counter — and a counter starting at zero would re-issue live IDs. This is the one genuine risk in the design and it is handled at exactly one place: `aapp init`, following the established idempotent pattern at `lib/cmd_init.sh:452-476`.

**Portability constraint (developer directive, 2026-09-19).** The bootstrap must not depend on GNU-flavoured tool behaviour. This repo has already been bitten twice by that class of bug and both are still open:
- `#59` — `sort -z` is GNU/newer-BSD only and breaks the Plans pillar on older macOS (live at `lib/cmd_status.sh:230` and three sites in `lib/planning_health.sh`).
- `#60` — parsing `ls` output breaks on filenames containing newlines.

For the record, `sort -n` itself *is* POSIX.1-2017 and is already used at `lib/planning_health.sh:178-203`; it is `sort -z` that is the non-portable one. Rather than argue the margin, the bootstrap below avoids `sort`, `grep -o`, and `ls` **entirely** — it uses nothing but glob expansion, parameter expansion, and `test`. That is both maximally portable and immune to the `#60` newline class by construction.

```bash
# One-time bootstrap. Returns the NEXT free id (fresh project -> 1).
# No ls, no grep -o, no sort, no arithmetic on parsed text.
seed_plan_id() {
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

    printf '%s\n' "$((MAX + 1))"
}
```

Three details that are load-bearing rather than stylistic:

- **`if ... then ... fi`, not `[ ... ] && MAX=$N`.** `aapp:7` and `lib/cmd_plan.sh:7` both set `-e`. A trailing `&&` list whose test fails yields a non-zero statement status; the explicit `if` can never do that.
- **`[ -e "$F" ] || continue`.** POSIX shells leave an unmatched glob as its literal pattern; without the guard the loop would process a file named `[Pp][0-9]*.md`. Verified in `dash`.
- **No `10#` and no leading-zero stripping.** POSIX `test -gt` parses operands as decimal integers, so a legacy `P-007` compares as `7`, not octal. Verified in `dash`. This is also why the comparison uses `test` rather than `$((...))` — arithmetic on parsed text is what made `#69` fatal.

Wired into `init` with the existing idempotent guard:

`MAX` starts at `0` and the function returns `MAX + 1`, so a project with no plans at all seeds to exactly **`1`** — no special-casing of the empty repo is needed, the arithmetic already says it.

#### Securing the counter across re-init and upgrade

`aapp init` is not a once-per-project command. `aapp upgrade` does not touch git config at all — it ends by instructing the user to *"Run `aapp init` inside any project to sync it to the latest protocol"* (`lib/cmd_upgrade.sh:44`). Init therefore runs repeatedly over a project's lifetime, and the counter has to survive every one of those runs.

The house pattern for every other key is a bare `-z` guard (`lib/cmd_init.sh:450-478`). That is **not sufficient here**, and the difference matters:

- A `-z` guard prevents *overwriting* a counter, which is the obvious hazard.
- But it also means init can never *correct* a counter that is stale **low** — and that state is reachable in normal use. After `aapp pull` (P-10) brings in a teammate's blueprints, `.plans/` holds ids higher than this clone's counter. The `-z` guard sees a non-empty value and leaves it alone; the next allocation then re-issues a live id.

So the counter is seeded **monotonically**: never lowered, raised whenever the scan finds something higher.

```bash
SEED="$(seed_plan_id "$REPO_ROOT/.plans")"
CUR="$(git config --get aapp.planId 2>/dev/null || true)"
case "$CUR" in ''|*[!0-9]*) CUR=0 ;; esac    # unset or corrupt -> treat as 0
if [ "$SEED" -gt "$CUR" ]; then
    git config aapp.planId "$SEED"
fi
```

This gives four protections in one comparison:

| State at `init` | Result |
| :--- | :--- |
| Unset (fresh clone, first init) | Seeded from scan — `1` on a new project |
| Already correct | Untouched — re-running `init` is a genuine no-op |
| Stale **low** (after `aapp pull`, or hand-created plan files) | **Raised** to the scan value |
| Ahead of the scan (ids issued by an `aapp-planid` provider, or plans archived and pruned) | **Left alone** — never lowered |
| Corrupt / non-numeric | Repaired from the scan |

The "ahead" row is the one that makes this safe to run unconditionally: a provider-issued or already-advanced counter is authoritative over a filesystem scan, so init must not drag it backwards. Monotonicity is the invariant — **`aapp.planId` only ever increases.**

It is also defence in depth. `.git/config` is not gate-protected: an agent with shell access can run `git config aapp.planId 1` without passing `blast-radius-guard` (the same reasoning that put the provider at a fixed `.agents/skills/aapp-planid/` path rather than behind a config key, §2.6). The counter cannot be made tamper-*proof*, but any tampering that lowers it is corrected at the next `init`, and `check_pair4_plan_id_integrity` remains the detector for anything that slips through.

**Verified by execution** in `bash` and `dash`, scan = `25`: unset -> `25`; `25` -> `25`; `3` -> `25`; `99` -> `99` (not lowered); `abc` -> `25`; `0` -> `25`. No input regresses the counter.

This runs **once per clone** and never again; it is a bootstrap, not an allocation path. **Verified by execution** in both `bash` and `dash`: this repository (highest is `P-24`) -> `25`; an empty `.plans` -> `1`; a `.plans` with empty `current`/`done`/`aborted` lanes -> `1`.

`.plans/aborted/` is included deliberately — an abandoned plan's ID must stay permanently spent.

### 2.4 What is deleted

The entire three-tier scan in `get_next_plan_id` is removed: the `current`/`done` filename walk, the per-file `get_plan_id` header scan, and the archive-ledger table scan containing the #69 defect. `get_plan_id()` itself **stays** — it is a separate, working helper used elsewhere to read a plan's declared ID.

### 2.5 Collision backstop is unchanged

`check_pair4_plan_id_integrity()` (`lib/planning_health.sh:296`) independently verifies that header IDs match filename prefixes and that no two plans share an ID. It does its own scanning and is deliberately **out of scope** — it remains the detector if the counter ever drifts (a hand-created plan file, a restored clone, a config reset).

Concurrency: git config read-modify-write is not atomic, so two agents allocating simultaneously in different worktrees could collide. This is not newly introduced — the scan had the same race — and Pair 4 catches it. `aapp pause` already exists to serialise multi-window work. Hardening beyond that is deferred (see Open Question 2).

### 2.6 Team coordination via a standard action plugin

**Directive (developer, 2026-09-19):** do not chase lifecycle events or add CLI verbs to make allocation hookable. Expose **one** well-known extension point, wired directly into the allocation function, and document that teams needing shared IDs must supply a plugin. Absent that plugin, the local git-config counter stands.

This supersedes the earlier hook-event approach in full. `on-digest` stays dead and that is now irrelevant to this plan — no event is dispatched, no command is added.

#### Provider discovery

> The name itself is pinned below under **The canonical name** — that section is authoritative; this one covers only how the entrypoint is located.

The provider is resolved through the existing P-12 action-plugin mechanism at `.agents/skills/aapp-planid/`. Entrypoint discovery is already implemented and extension-agnostic (`resolve_plugin_entrypoint`, `lib/cmd_hook.sh:113`): `run` -> `aapp-planid` -> `scripts/run` -> `scripts/aapp-planid`, then any-extension variants. A team may therefore ship the provider as a shell script, a Python file, or a compiled binary with no change here.

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
    local ROOT PDIR ENTRY RAW OUT CUR ISSUED
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
        # Ratchet the local counter past the issued id so the fallback never regresses.
        CUR="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        case "$CUR" in ''|*[!0-9]*) CUR=1 ;; esac
        ISSUED="${OUT#P-}"
        if [ "$ISSUED" -ge "$CUR" ]; then git config aapp.planId "$((ISSUED + 1))"; fi
        printf '%s\n' "$OUT"
        return 0
    fi

    # 2. No plugin installed -> local git config counter.
    CUR="$(git config --get aapp.planId 2>/dev/null || echo 1)"
    case "$CUR" in ''|*[!0-9]*) CUR=1 ;; esac
    git config aapp.planId "$((CUR + 1))" || return 1
    printf 'P-%s\n' "$CUR"
}
```

Four contract points that are deliberate rather than incidental:

- **Only absence falls back.** A plugin that is installed but *fails* is fatal (`return 1`), never a silent downgrade to local allocation. Falling back on failure would reintroduce exactly the collision the provider exists to prevent — and would do it invisibly, at the worst moment.
- **Either form accepted, integer enforced.** A provider may return `P-42` or bare `42` — the `P-` is only a namespace marker (§2.1), so demanding it would be arbitrary. Beyond stripping that optional prefix we check one thing: is it an integer? If not, error out and refuse to allocate. We do not normalize, repair, or interpret third-party output.
- **The local counter ratchets past every id the provider issues.** If the provider is later uninstalled, the git-config fallback resumes at one *above* the highest id actually issued, never re-handing one out.
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

#### The canonical name — decided, not to be guessed

**`aapp-planid`.** One name, used verbatim everywhere it appears:

| Where | Path |
| :--- | :--- |
| Installed provider (adopter-supplied) | `.agents/skills/aapp-planid/` |
| Shipped reference example | `examples/plugins/aapp-planid/` |
| Entrypoint lookup argument | `resolve_plugin_entrypoint "$PDIR" "aapp-planid"` |
| Direct invocation (free via switchboard) | `aapp aapp-planid` |

**The example carries the same name as the real thing on purpose.** `aapp install` preserves `examples/` on disk (P-24), so an adopter reaches a reference implementation that is already named correctly and can be copied straight to `.agents/skills/` without a rename step. A differently-named sample (the earlier `planid-remote`) would have forced every adopter to know that the directory must be renamed on the way in — precisely the kind of thing teams should not have to guess.

Suffix handling for shipped samples (`run` vs `run.sample`) is **P-24's decision, not this plan's**. P-22 creates the example under the canonical *directory* name; P-24 owns whether the entrypoint file carries a `.sample` suffix and how drop-in installs it.

Why this name and not the alternatives:

- **`aapp-` prefix is mandatory, not stylistic.** `.agents/skills/aapp-*` is Guard Section 2 protected, which is what makes an installed provider tamper-evident against agents (§2.6). A name without the prefix loses that protection outright.
- **Rejected: `aapp-plan-id`.** More readable in isolation, but `aapp-plan` already exists as a governance skill and the two would sit adjacent in `.agents/skills/`, differing by one segment. `aapp-planid` is distinguishable at a glance; `aapp-plan-id` is not.
- **Rejected: `aapp-planid-provider`.** Accurate about role but verbose, and inconsistent with the house convention, which names the *domain* rather than the mechanism — `aapp-hooks`, not `aapp-hook-runner`.
- **Consistent with existing skills:** `aapp-active`, `aapp-digest`, `aapp-done`, `aapp-freeze`, `aapp-freeze-start`, `aapp-hooks`, `aapp-pause`, `aapp-plan`, `aapp-release`, `aapp-start`, `aapp-status`.

One genuine ambiguity the name cannot resolve on its own, so documentation must: every other `aapp-*` skill is **shipped by the kit**, while `aapp-planid` is **supplied by the adopter**. The docs have to say so explicitly, or a team will reasonably assume it arrives with `aapp init` and wonder why it is missing.

#### Shipped mock example

`examples/plugins/aapp-planid/run` — a **mock only**, matching the style of the existing `examples/plugins/hello-tool/run`. It simulates fetching an id from a remote authority and prints a single id line. It performs no network I/O and exists so an adopter can read the contract and copy a correctly-named directory straight into `.agents/skills/`.

#### The coordination boundary (settled, 2026-09-20)

This is the design decision, and it is deliberately a boundary rather than a mechanism:

| Repository shape | What is required | Why |
| :--- | :--- | :--- |
| **Solo developer** | Nothing. The local counter suffices. | One clone, one counter, no concurrent allocator. Safe by construction, zero configuration. |
| **Any repository with more than one contributor** | An `aapp-planid` provider backed by a central authority. | Coordination cannot be synthesised locally. It has to come from somewhere central, and that is what the provider seam exists for. |

The core deliberately does **not** simulate central coordination — not with a committed counter file, not with CI arbitration. Both were considered and rejected (Questions 9 and 10): a committed file detects a split rather than preventing one, and a workflow runs after push, so it too can only detect. Neither becomes an authority, and pretending otherwise would hand teams a false guarantee.

So the boundary is named instead. A solo developer gets a correct system with no setup. A team gets a correct system by installing one plugin. Nobody gets a system that silently *appears* coordinated while not being so.

#### Documentation obligation

The boundary is the thing that must be documented, in `MANUAL.md` and `README.md`, in plain terms:

- Out of the box, plan ids are allocated per clone. **For a solo developer this is correct and needs no action.**
- **As soon as a repository has more than one contributor, an `aapp-planid` provider is required.** Without one, two contributors can allocate the same id independently, and nothing in the core prevents it.
- `check_pair4_plan_id_integrity` stays the after-the-fact detector in both modes — the safety net, not the mechanism.
- **The provider's name is `aapp-planid`** and must be installed at `.agents/skills/aapp-planid/`. State the exact path — this is not discoverable and teams must not have to guess it. Note explicitly that, unlike every other `aapp-*` skill, this one is adopter-supplied and does **not** arrive with `aapp init`; a working reference lives at `examples/plugins/aapp-planid/`.
- The provider contract (§2.6): return `P-42` or bare `42`, exit non-zero to refuse. Absence falls back to the local counter; presence-and-failure is fatal.

The failure mode of under-documenting this is specific enough to state: a team adopts AAPP, watches ids allocate cleanly for weeks while only one person happens to be drafting plans, then collides the first time two people draft concurrently. The threshold has to be explicit rather than discovered.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: **one declared fallback** — `aapp-planid` plugin absent -> local `aapp.planId` git-config counter (§2.6).
  - *Nature:* this is a **designed extension point**, not a legacy shim or dual-syntax parser. Nothing is retained for backwards compatibility and there is no retirement date: the local counter is the permanent default, and the plugin is the permanent opt-in override. It is declared here because the Clean Break Invariant prohibits *un-named* fallbacks, and a two-path resolution must be named whatever its motivation.
  - *Scope limit:* the fallback triggers on **plugin absence only**. A plugin that is installed and fails is fatal — there is no degraded path.
  - The removed three-tier scan itself gets no fallback: it is deleted outright, with no "scan if config is unset" path. An unseeded repo starts at `P-1`, correct for a new project and flagged by Pair 4 in any other case.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Confirm `aapp.planId` is unset in this repo and that `git rev-parse --git-common-dir` resolves to a shared `.git` across all mounted worktrees.
- [ ] Task 1.2: Implement `seed_plan_id` per §2.3 and verify it returns **`25`** here (highest in use is `P-24`) and **`1`** for an empty `.plans`. Test under `dash` as well as `bash`, and against a fixture containing a filename with an embedded newline (the `#60` class) and a zero-padded `P-007`.

### Phase 2: Core Implementation
- [ ] Task 2.1: Replace the three-tier scan in `get_next_plan_id` with the read-only config accessor (§2.2). Delete the ledger loop containing the #69 defect. Leave `get_plan_id()` intact.
- [ ] Task 2.2: Add `allocate_plan_id()` as the single mutating claim path.
- [ ] Task 2.3: Seed `aapp.planId` in `lib/cmd_init.sh` via `seed_plan_id` using the **monotonic ratchet** of §2.3 — deliberately *not* the bare `-z` guard used by the other keys at lines 450-478, since that cannot correct a stale-low counter after `aapp pull`. Confirm no `sort`, `grep -o`, or `ls` enters the path.
- [ ] Task 2.3b: Assert the ratchet is safe under repetition: run `aapp init` twice and confirm the second run is a no-op; set the counter low and confirm init raises it; set it high and confirm init leaves it alone.
- [ ] Task 2.4: Surface the key in the `aapp init` summary banner alongside the existing `aapp.remote` / `aapp.syncStrategy` lines.

### Phase 3: Instruction & Template Sync
- [ ] Task 3.1: Update `templates/skills/aapp-digest/SKILL.md` step 2 — it currently instructs agents to allocate "by scanning highest existing ID across `.plans/current/` and `.plans/done/`". Replace with `allocate_plan_id`.
- [ ] Task 3.2: Update `templates/skills/aapp-plan/SKILL.md` and `templates/AGENTS.md:206` to match.
- [ ] Task 3.3: **Do not hand-edit installed skills.** `.claude/skills/aapp-*` and `.agents/skills/aapp-*` are Guard Section 2 protected; refresh them by re-running `aapp init` so templates remain the single source.

- [ ] Task 3.4a: Move `resolve_plugin_entrypoint` from `lib/cmd_hook.sh` into `lib/hook_dispatcher.sh` and have `cmd_hook.sh` consume it there. Do not duplicate it.
- [ ] Task 3.4b: Wire `aapp-planid` resolution into `allocate_plan_id` per §2.6, sourcing `hook_dispatcher.sh` the way `lib/cmd_sync.sh:193` does. Verify the inherited `set -e` is safe in every `plan_resolver.sh` caller.
- [ ] Task 3.5: Ship the mock provider at `examples/plugins/aapp-planid/run` — **the canonical name**, so it can be copied to `.agents/skills/` without a rename. Match `hello-tool/run` style; no network I/O. Entrypoint suffix (`run` vs `run.sample`) is P-24's call.
- [ ] Task 3.6: Document **the coordination boundary** (§2.6) in `MANUAL.md` and `README.md`: a solo developer needs nothing; **any repository with more than one contributor requires an `aapp-planid` provider**; without one, concurrent contributors can allocate the same id and nothing in the core prevents it. State the threshold explicitly rather than leaving it to be discovered.

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Rewrite the `get_next_plan_id` assertions in `tests/plan_resolver_test.sh` against the counter. Cover: unset key yields `P-1`; peek is a pure read, non-mutating across repeated calls; `allocate_plan_id` returns the current value then stores the successor (`aapp.planId` advances by exactly 1 per call) and is strictly monotonic; a failed config write refuses to issue; a corrupt/non-numeric value currently degrades to `1` rather than aborting — assert whichever behaviour Open Question 8 settles on.
- [ ] Task 4.2: Assert `get_next_plan_id` emits **nothing on stderr** — the assertion that would have caught #69.
- [ ] Task 4.3: Confirm Pair 4 still passes and remains capable of detecting a duplicate ID (§2.5).
- [ ] Task 4.3b: Cover the plugin path in `tests/plan_resolver_test.sh`: absent plugin -> config counter; mock provider -> its id is used and ratchets `aapp.planId`; failing provider -> non-zero, **no** local allocation.
- [ ] Task 4.3c: Test `normalize_plan_id` on `P-42` and `42` (both -> `P-42`) and on a non-integer (error + non-zero, no allocation).
- [ ] Task 4.4: Run all suites; confirm the total moves from 321 with no regressions.
- [ ] Task 4.5: Document `aapp.planId` in `MANUAL.md` / `README.md` config tables; update `ARCHITECTURE.md` and `.agents/CODEMAP.md` for the resolver's changed contract (a new exported function is an interface change).
- [ ] Task 4.6: Update `CHANGELOG.md` and run syntax checks before committing.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/plan_resolver.sh` -> Delete three-tier scan; reimplement `get_next_plan_id` as read-only config peek; add `allocate_plan_id`.
- [ ] `lib/cmd_init.sh` -> Seed `aapp.planId` idempotently with the one-time bootstrap; surface it in the init summary.
- [ ] `tests/plan_resolver_test.sh` -> Rewrite ID-allocation assertions against the counter; add stderr-cleanliness assertion.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Replace scan-based allocation instruction with `allocate_plan_id`.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Same instruction update.
- [ ] `templates/AGENTS.md` -> Update the allocation protocol description at line 206.
- [ ] `MANUAL.md` -> Document the `aapp.planId` key.
- [ ] `README.md` -> Add the key to the configuration reference.
- [ ] `ARCHITECTURE.md` -> Record the shift from derived to stored plan identity.
- [ ] `.agents/CODEMAP.md` -> Update the `lib/plan_resolver.sh` entry for the new function surface.
- [ ] `lib/hook_dispatcher.sh` -> Receive `resolve_plugin_entrypoint` so it is sourceable by both `cmd_hook.sh` and `plan_resolver.sh`.
- [ ] `lib/cmd_hook.sh` -> Consume the relocated `resolve_plugin_entrypoint` instead of defining it.
- [ ] `NEW FILE` -> `examples/plugins/aapp-planid/run` -> Mock provider plugin demonstrating the `aapp-planid` contract (no network I/O).
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_install.sh` -> Installation asset preservation decoupled into P-24.
- [ ] `tests/install_test.sh` -> Installer testing decoupled into P-24.
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

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Counter is local, not shared. → RESOLVED (developer, 2026-09-19): a standard action plugin, not lifecycle hooks.** See §2.6. `allocate_plan_id` resolves `.agents/skills/aapp-planid/` via the existing P-12 discovery; if no provider is installed it uses the local git-config counter. Teams needing shared IDs supply the plugin; this is documented as an opt-in obligation rather than built in. The earlier hook-event approach (`post-sync` re-seed + `on-freeze` gate) is **withdrawn** — no events, no new CLI verbs.
* [ ] **Question 2 — Concurrency hardening.** Should `allocate_plan_id` take a lock (e.g. `.git/aapp_planid.lock`) to serialise simultaneous allocation across worktrees, or is the existing `aapp pause` discipline plus Pair 4 detection sufficient?
* [ ] **Question 3 — Should `#69` close as fixed or as obsolete?** The defective line is deleted rather than corrected. It affects how the archive ledger records this work.
* [ ] **Question 4 — Template drift, root cause now identified.** `.plans/plan-template.md` is stale against canonical `templates/plan-template.md`: it still carries the retired status enum (`🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED`) and lacks the `* **Plan ID:**` field entirely, so any plan scaffolded from the worktree copy is born invalid under the strict enum from `a782e5e`. **The cause is `copy_guarded` (`lib/cmd_init.sh`), which returns early when the destination exists and therefore never overwrites.** `lib/cmd_init.sh:219` copies the template only on first init; every subsequent init silently skips it, so the worktree copy has never been refreshed since it was created. This affects every `copy_guarded` destination, not just the template. Fold into this plan, or log as its own issue? *Still unrelated to the counter redesign.*
* [ ] **Question 5 — Severity of `#69`.** Recorded as `Low` and sitting unsequenced in Triage, but verified behaviour is a hard failure (`get_next_plan_id` returns empty, exit `1`, under `set -e` callers). Correct the `Sev` field? *Board ordering is your judgement call — I have not re-sequenced it.*
* [x] **Question 6 — Drop-In Mode Asset Handling & Installation Asset Preservation. → DECOUPLED (developer, 2026-09-19): split into dedicated blueprint P-24.** All distribution, installation asset preservation (`$SHARE_DIR/examples/`), `.sample` convention, and drop-in mode questions moved to P-24 to keep P-22 strictly focused on core plan identity (`#69`).
* [ ] **Question 7 — Three plans now contend for the same two `lib/` files.** The split did not dissolve this; it added a third claimant. `lib/hook_dispatcher.sh` and `lib/cmd_hook.sh` are Target Files in **P-22, P-23 and P-24 simultaneously**, each for a different reason: P-22 *moves* `resolve_plugin_entrypoint` into `hook_dispatcher.sh` so `plan_resolver.sh` can source it; P-23 adds pre/post event alias mapping and validation; P-24 adds a `.sample` exclusion filter **to that same function**. All three also share `MANUAL.md`, `README.md` and `CHANGELOG.md` (routine). The Disjointness Activation Gate (`.agents/AGENTS.md:233`) permits only one in flight.
  - **Hard ordering dependency:** P-24's Task 2.1 is written as *"add the `.sample` filter to `resolve_plugin_entrypoint` in `lib/hook_dispatcher.sh` (or `lib/cmd_hook.sh`)"* — the parenthetical exists precisely because P-22 has not yet moved it. P-24 cannot be specified definitively until P-22's relocation lands.
  - **Concrete artefact conflict:** P-22 creates `examples/plugins/aapp-planid/run`; P-24 Task 4.3 requires that same plugin to use `run.sample`. One of the two must change. Naming it `run.sample` in P-22 from the outset is harmless — the mock lives under `examples/`, never under `.agents/skills/`, so it is never resolved as a real provider — but the `.sample` convention is P-24's to settle, so this plan has not pre-empted it.
  - Suggested sequence: **P-22 -> P-24 -> P-23**, or move the relocation into whichever plan runs first and have the others consume it. *Sequencing is your call.*
* [ ] **Question 8 — Should a corrupt `aapp.planId` error at allocation time?** The two contexts now want different behaviour, which clarifies this question. At **init** a corrupt value is repaired from the filesystem scan (§2.3) — correct, because init has an authoritative source to repair *from*. At **allocation** `case "$CUR" in ''|*[!0-9]*) CUR=1 ;; esac` silently restarts the sequence at `P-1`, colliding with every existing plan — and allocation has no scan to fall back on. Recommend: keep the repair at init, and make allocation **error out** on a non-empty non-numeric value rather than re-issuing from `1` (an *unset* key still legitimately means `1`). That matches the principle applied to provider output in §2.6. Flagged rather than changed because it alters designed behaviour.

* [x] **Question 9 — Committed counter file. → RESOLVED (developer, 2026-09-20): not adopted.** A tracked counter detects a split rather than preventing one, so it never becomes the central source of truth that would justify it. `aapp.planId` remains the source of truth and amendment 11 stands unreversed. `.plans/plan-template.md` was in any case the wrong host — a template copied to create plans, which would only have kept the counter across `init` because of the `copy_guarded` defect in Question 4.
* [x] **Question 10 — Central id authority via CI. → RESOLVED (developer, 2026-09-20): no CI route.** Coordination for a multi-contributor repository comes from **a hook to a central place** — the `aapp-planid` provider — not from GitHub Actions in the core. Settled model: **a solo developer is safe with the local counter; any repository with more than one contributor requires a provider.** See §2.6 *The coordination boundary*, which this plan must document in `MANUAL.md` and `README.md`.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-19:** Plan initialized via `/aapp-digest #69` (promotion from `ISSUES.md`, issue lane -> plan lane). Root cause verified empirically rather than assumed: confirmed parse-clean / runtime-fatal behaviour, empty-capture arithmetic abort, `stdout=''` + `exit 1`, and the cross-suite fixture gap that hid it from 321 passing tests.
* **2026-09-19 (amendment):** **Design direction changed by the developer** — do not repair the regex; stop deriving plan IDs by parsing altogether and hold the counter in git config, updating it when a plan is initialized. Rewrote §1 goal and replaced §2 entirely: three-tier scan deleted, `aapp.planId` counter introduced, `get_next_plan_id` demoted to a read-only peek, `allocate_plan_id` added as the sole mutating claim, and `$((10#...))` removed in favour of pre-arithmetic validation. Blast Radius widened materially: the allocation contract is documented in three template/skill files and `AGENTS.md`, so those now require synchronised edits (installed skill copies stay out of bounds under Guard Section 2). `#69` is now resolved by deletion rather than correction. New Open Questions 1-3 cover the counter's local-only nature, concurrency, and how `#69` should be closed; prior questions on failure posture and `10#` guard scope are obsolete and were dropped. Plan renamed `P22-ledger-scan-regex-integrity.md` -> `P22-config-backed-plan-id-allocation.md`.
* **2026-09-19 (amendment 2):** **Portability directive from the developer** on the §2.3 bootstrap. Investigation corrected the specific premise — `sort -n` is POSIX.1-2017 and already in use at `lib/planning_health.sh:178-203`; `sort -z` is the non-portable one (`#59`). The genuine defects in the first draft were different: it used `grep -o` (a GNU extension) and parsed `ls` output, the latter reproducing the exact bug class of open issue `#60`. Rather than substitute one tool for another, §2.3 was rewritten to drop `sort`, `grep -o` and `ls` entirely in favour of glob expansion, parameter expansion and `test` — immune to the `#60` newline class by construction. Added three load-bearing notes: explicit `if/fi` over `&&` lists (both callers run `set -e`), the literal-glob `[ -e ]` guard, and reliance on POSIX `test` decimal parsing instead of `$((10#...))`. **Verified by execution** in both `bash` and `dash`, under `set -e`: real repo -> `22`; fixture with a newline-containing filename, a zero-padded `P-007`, a decoy `plan-no-id.md`, and a ledger-only `P-44` -> `44`; empty `.plans` -> `0` (yielding `P-1`).
* **2026-09-19 (amendment 3):** **Open Question 1 resolved by the developer** — coordinate the counter across a team with the P-12 hook engine. Added §2.6. Verified the enabling property: committed-registry handlers default to `gate` (`hook_dispatcher.sh:257`) while local `git config` overrides are forced to `notify` (`:276`), so a team gate cannot be locally bypassed. **Discovered that the developer's first choice, `on-digest`, is a dead event** — advertised at `cmd_hook.sh:190`, documented in the hooks SKILL and registry, shipping a sample handler, but carrying zero `dispatch_hook` call sites. Root cause is structural: there is no `lib/cmd_digest.sh` and no digest CLI verb, because digest is an agent-driven skill workflow — the same reason `get_next_plan_id` has no runtime callers. Retargeted implementation onto two events that do fire: `post-sync` (`cmd_sync.sh:202`) for preventive re-seeding and `on-freeze` (`cmd_plan.sh:225`/`:303`, already `|| exit 1`) for collision gating. Blast Radius extended with two handler scripts, `registry.tsv`, and `tests/hooks_test.sh`. Added Open Question 6 on whether promoting `aapp digest` to a real CLI verb — the only thing that would activate `on-digest` — belongs here or in its own blueprint.
* **2026-09-19 (amendment 4):** **Approach replaced on developer direction** — stop trying to match commands and lifecycle events; expose one standard extension point wired into the allocation function, falling back to git config when absent. §2.6 rewritten around the `aapp-planid` action plugin at `.agents/skills/aapp-planid/`, reusing P-12 extension-agnostic discovery. The `aapp-` prefix is deliberate: Guard Section 2 makes an installed provider tamper-evident. Withdrew the entire hook-event approach (`post-sync` re-seed, `on-freeze` gate, two handler scripts, `registry.tsv`, `tests/hooks_test.sh`) and dropped Open Question 6 on promoting `aapp digest` to a CLI verb — `on-digest` remains dead and is now irrelevant here. Contract pinned on four points: only plugin *absence* falls back (a present-but-failing provider is fatal, never a silent local allocation); provider output is validated as `P-<digits>` before trust; the local counter ratchets forward on plugin success so the fallback never regresses; and the read-only peek never invokes the provider. Ships `examples/plugins/aapp-planid/run` as a mock only. **Declared the fallback in the Fallback Inventory** as the Clean Break Invariant requires — named as a designed extension point rather than a legacy shim, with no retirement date. **Corrected a flaw found while verifying:** `resolve_plugin_entrypoint` lives in `lib/cmd_hook.sh`, which is not safely sourceable (top-level dispatcher at `:265-296` would execute on source). It must first move to `lib/hook_dispatcher.sh`, which is sourceable and already sourced by `lib/cmd_sync.sh:193`. Noted the inherited `set -e` and a third inline copy in the `aapp` switchboard, both handled or scoped out explicitly.
* **2026-09-19 (amendment 5):** **Provider output contract relaxed on developer direction** — the `P-` prefix is a namespace marker distinguishing plan ids from issue ids, not part of the value, so a provider may return either `P-42` or bare `42`. Replaced the strict `P-[0-9]*` check with `normalize_plan_id`, which accepts `P-42`/`p-42`/`P42`/`42`, trims whitespace, and collapses legacy zero-padding to the canonical unpadded form of P-13 (`P-007` -> `P-7`). Rejects empty, `P-`, non-numeric, decimal, negative and trailing-junk values; rejects `#`-prefixed ids with a distinct rc 2, since an issue id in the plan namespace indicates a provider bug rather than malformed text. Made the number/prefix split explicit in §2.1: `aapp.planId` stores a bare integer and `P-` is applied only on output. Verified across `bash` and `dash` on 16 inputs.
* **2026-09-19 (amendment 6):** **Security rationale confirmed & installation asset preservation added on developer direction** — (1) Affirmed the defined canonical name `.agents/skills/aapp-planid/` over a `git config` key to prevent rogue/lost agents with shell access from hijacking the provider without a gate (Guard Section 2 mechanically blocks agent tampering with `aapp-*`). (2) Added §2.7 and updated `lib/cmd_install.sh` and `tests/install_test.sh` to preserve `examples/` in `$SHARE_DIR/examples/` during `aapp install` as mock examples expand. (3) Recorded drop-in mode handling of `examples/` as deferred under Open Question 6 per developer directive.
* **2026-09-19 (amendment 7):** **Drop-in mode explicitly affirmed as undecided on developer direction** — Clarified across §2.7, §3 (Task 2.5), §4 (Out of Bounds), and Open Question 6 that what happens to `examples/` at drop-in is not yet decided. Drop-in mode (`lib/cmd_init.sh` Phase 7) is strictly out of scope and left untouched; only global `aapp install` (`lib/cmd_install.sh`) preserves `examples/` to `$SHARE_DIR/examples/`.
* **2026-09-19 (amendment 8):** **Parsing simplified on developer direction — no elaborate matching.** The amendment-5 normalizer was over-built: it folded case, trimmed whitespace, collapsed zero-padding, matched four input shapes and carried a special exit code for `#`-prefixed values. Replaced with one prefix strip and one integer check; a non-integer is an error with a message and no allocation. Either form (`P-42` or `42`) is still accepted, per the namespace-marker rationale in §2.1. Emitting a well-formed id is the third party's responsibility — our side does not normalize, repair, or interpret provider output.
* **2026-09-19 (amendment 9):** **Review pass requested by the developer.** Fixed a real defect in §2.6's `allocate_plan_id`: `OUT="$(normalize_plan_id "$OUT")"` clobbered `OUT` before the `||` branch executed, so the error message reported `''` instead of the offending value and duplicated the message `normalize_plan_id` already emits — now captured via `RAW` with the redundant echo dropped (demonstrated by execution). Renumbered this session's parsing-simplification entry from a duplicate 'amendment 6' to 'amendment 8' — a concurrent session had independently written amendments 6 and 7 into this file. Raised Open Question 7 (Blast Radius collides with P-23 on 5 Target Files, 2 of them substantive) and Open Question 8 (a corrupt `aapp.planId` silently degrades to `0` and re-issues `P-1`, contradicting the error-out principle applied to provider output). Verified the concurrently-added §2.7 against the source: `AAPP_SCRIPT_DIR` and the `lib/cmd_install.sh:85-87` copy block it cites are both accurate.
* **2026-09-19 (amendment 10):** **Plan split on developer direction** — Decoupled installation asset preservation (§2.7), Task 2.5, Task 4.3d, installer target files, and Open Question 6 into dedicated blueprint P-24 (Example Asset Preservation & Sample Hook/Plugin Convention). P-22's Blast Radius is now razor-focused on core plan identity (#69) and runtime allocation.
* **2026-09-20 (amendment 11):** **Counter semantics reversed on developer direction — `init` seeds `1`.** The key is renamed `aapp.lastPlanId` -> `aapp.planId` and now stores **the next id to hand out** rather than the last one used, so a fresh project reads `aapp.planId=1` after `aapp init` and the first plan created is `P-1`. `get_next_plan_id` becomes a plain read with no arithmetic; `allocate_plan_id` returns the current value and persists the successor, writing before printing so a failed config write refuses to issue. `seed_last_plan_id` -> `seed_plan_id`, now returning `MAX + 1`, which makes the empty-repo case fall out of the arithmetic (`0 + 1`) with no special casing. Provider ratchet updated for the new semantics: an issued id `N` advances the counter to `N + 1`, not to `N`. **Verified by execution** in `bash` and `dash`: this repo (highest `P-24`) -> `25`; empty `.plans` -> `1`; empty lanes -> `1`. Open Question 8 restated — a corrupt value now silently restarts at `P-1` rather than `P-1` via zero, the same hazard under new wording.
  *Note:* the key rename was applied globally, so earlier change-log entries now read `aapp.planId` where they originally said `aapp.lastPlanId`. The rename itself is recorded here; no entry's meaning changed.
* **2026-09-20 (amendment 12):** **Counter secured across re-init and upgrade, per developer direction.** Established that `aapp init` is re-run throughout a project's life — `aapp upgrade` changes no config and ends by directing the user to run `init` (`lib/cmd_upgrade.sh:44`) — so the seed must be safe under repetition. Replaced the bare `-z` guard (the house pattern at `lib/cmd_init.sh:450-478`) with a **monotonic ratchet**: never lower, raise when the scan finds higher. The `-z` guard was insufficient because it can never correct a counter that is stale **low**, a state reachable in normal use — after `aapp pull` imports a teammate's blueprints, the local counter sits below the ids now on disk and the next allocation re-issues a live id. The ratchet covers unset, already-correct (true no-op), stale-low (raised), ahead-of-scan (left alone, since a provider-issued counter outranks a filesystem scan), and corrupt (repaired) in one comparison, with **`aapp.planId` only ever increases** as the invariant. Noted as defence in depth: `.git/config` is not gate-protected, so an agent with shell access can lower the key, but the next `init` corrects it and Pair 4 remains the detector. **Verified by execution** in `bash` and `dash` across six starting states; none regresses the counter. Sharpened Open Question 8 — init repairing a corrupt value is right because it has a source to repair from; allocation has none, so it should error rather than restart at `P-1`.
* **2026-09-20 (amendment 13):** **Assessed whether a central id authority is warranted; recommended against it.** Recorded Question 10. Confirmed the developer's observation that committed state detects rather than prevents a split, then established that GitHub Actions cannot serve as the authority either: workflows run after push, so an Action would detect rather than allocate, duplicating `check_pair4_plan_id_integrity` which already exists. Noted that the maintainer merging PRs is already the serialization point, that a colliding draft blueprint costs one `git mv` plus a header line to renumber, and that binding allocation to GitHub would cost the kit its zero-dependency host-agnostic architecture — with `aapp-planid` already providing the seam for teams that genuinely need central issuance. **Found the gap actually worth closing:** Pair 4 is invoked only from `lib/cmd_status.sh` and `lib/cmd_pause.sh` and is **not** wired into `templates/aapp-pre-commit`, so duplicate-id detection is advisory rather than gated. Wiring the existing check into pre-commit is a few lines against already-written code and enforces at commit and post-merge. Left out of this plan's Blast Radius pending a decision, since `templates/aapp-pre-commit` is currently Out of Bounds here.
* **2026-09-20 (amendment 14):** **Coordination model settled by the developer; Questions 9 and 10 closed.** The rule is a boundary, not a mechanism: **a solo developer is safe with the local counter and needs nothing; any repository with more than one contributor requires a hook to a central place — the `aapp-planid` provider.** The committed-counter file (Q9) is **not adopted** — it detects a split rather than preventing one, so `aapp.planId` remains the source of truth and amendment 11 stands unreversed. The CI-arbitration route (Q10) is **not taken** — a workflow runs after push and can only detect, and binding allocation to GitHub would cost the kit its host-agnostic, zero-dependency architecture. The core will not simulate central coordination by either means, on the grounds that a false guarantee is worse than a named limitation. Added §2.6 *The coordination boundary* and restored an explicit documentation obligation (the prior one was dropped during the P-24 split), sharpening Task 3.6 so the threshold is documented in `MANUAL.md` and `README.md` — a team should learn where the line sits before colliding, not after.
* **2026-09-20 (amendment 15):** **Canonical provider name pinned and the shipped example realigned to it.** The name is **`aapp-planid`**, used verbatim for the installed provider (`.agents/skills/aapp-planid/`), the entrypoint lookup argument, and — newly — the shipped example, which was misnamed `examples/plugins/planid-remote/`. Renaming it matters because `aapp install` keeps `examples/` on disk (P-24), so the reference implementation must be copyable into `.agents/skills/` **without a rename step**; a differently-named sample forces adopters to know a mapping that is nowhere written down. Recorded the rationale rather than just the choice: the `aapp-` prefix is mandatory because Guard Section 2 protection keys on it; `aapp-plan-id` was rejected because the existing `aapp-plan` governance skill would sit adjacent and differ by one segment; `aapp-planid-provider` was rejected as inconsistent with the house convention of naming the domain (`aapp-hooks`, not `aapp-hook-runner`). Added the documentation obligation that the exact install path be stated and that `aapp-planid` is **adopter-supplied**, unlike every other `aapp-*` skill which ships with `aapp init`. Suffix handling (`run` vs `run.sample`) is explicitly left to P-24; Question 7's artefact conflict narrows to that one file rename inside P-24's own scope.
  *Follow-up within amendment 15:* corrected two defects introduced by that same edit — Task 3.5's rewrite was silently defeated because the global `planid-remote` -> `aapp-planid` rename ran first and left its anchor unmatchable, and the pre-existing `#### The standard name` section was left defining the name alongside the new canonical section. The former is now worded as intended; the latter is demoted to `#### Provider discovery` and defers to the canonical section, so the name is specified in exactly one place.

