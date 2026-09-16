# 🗺️ Plan: P-14 AI Attribution Suite, Safe-by-Default Protocol & Historical Scrubber
* **Created:** 2026-09-15 | **Last Refined:** 2026-09-15
* **Target Issue / Milestone:** #66
* **Status:** 🟢 Ready for Execution
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED
     The pre-commit hook reads this line. A plan whose Status says BLOCKED grants no
     commit rights at all — its Blast Radius stops admitting files until you clear it. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Engine Rule**: No email addresses in AI attribution in any mode. `Co-authored-by:` is permanently rejected. Attribution is configured via `git config aapp.aiAttribution` (`none` | `commit` | `notes`).
> 4. **Pair 5 Invariant**: Target Files must never declare Section 2 protected files (`.githooks/*`, `.agents/skills/*`, `.claude/settings*`, `.cursor/rules/*`, `.git/config`).
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### ⏳ Partial Completion — This Plan Does Not Fully Close On Its Own
> Every phase below can be implemented and verified independently, **except automatic reviewer
> extraction** for the AI Contributors roster (§E.9). Until the adversarial-review plugin exists there
> is no mechanical source for agents that reviewed but never committed, so that part of the roster is
> seeded and maintained by hand. **Do not archive this plan as fully delivered without logging the
> carried-forward item as an open issue** — see §E.9 and Task 5.5.

---

## 1. Context & Architectural Goal

The legacy AI attribution model in AAPP inherited human git pair-programming conventions (`Co-authored-by: <Agent> <email>`). This model introduced severe architectural defects identified by red team review:
1. **GitHub Identity Hijacking**: When public git servers encounter `Co-authored-by: Antigravity <antigravity@google.com>`, GitHub scans its global user database, matches an unrelated user who verified that email (`shimonenator`), and irrevocably attributes commits and repository contributor badges to that individual. Mandating synthetic, no-reply, or `.invalid` emails is also rejected — an organisation running an in-house model may want a real identifier, but human email trailers force GitHub account matching. A dedicated, email-less custom trailer key is the required design.
2. **Configuration Erasure Vulnerability (B2)**: Storing the active attribution mode inside `.agents/AGENTS.md` is broken because `lib/cmd_init.sh:sync_agent_rules()` overwrites the entire protocol block on every `aapp init` or `upgrade`. Configuration must live in `git config aapp.aiAttribution`, following the established `aapp.allowPath` and `aapp.hookTimeout` pattern.
3. **Missing Enforcement Hook (B3)**: `pre-commit` never receives the commit message; git passes commit messages strictly to `commit-msg`. Validating attribution trailers and commit message shape requires a dedicated `templates/aapp-commit-msg` hook and dispatcher.
4. **Scrubber SHA Referencing & Worktree Orphanage (B4)**: Rewriting history with `filter-branch` alters commit SHAs referenced across `.plans/done/000-archive-ledger.md`, `.plans/done/000-issues-archive.md`, `.plans/ISSUES.md`, and `CHANGELOG.md` (14 distinct SHAs across 61 occurrences), and breaks extra worktrees. The rewrite must execute via a disciplined sequence: dismantle worktrees, rehearse on mirror, rewrite, map old→new 40-char SHAs, repair references, and enforce resolution via a new Planning Health check (Pair 6: Recorded SHA Integrity).
5. **Multi-Vendor Benchmarking — Two Deliberate Audiences (G3)**: Developers need historical auditability to compare how different AI agents perform over time, but not every project wants that record public. The two modes serve different intents and neither is a degraded form of the other. `ai-commit` (trailers) is the **durable public record** — visible on GitHub and in `git log`, travelling with every clone. `ai-notes` is the **private benchmarking record** — the same per-commit data, held in `refs/notes/commits`, which does not travel unless refspecs are configured. That non-travel is a genuine reason to choose notes, not merely a limitation of them: a team can benchmark agents internally without publishing anything about how the code was produced.

### Architectural Objectives:
- **Safe-by-Default**: `aapp init` defaults `aapp.aiAttribution` to `none`. Zero unexpected trailers, zero email leaks.
- **Dedicated CLI Switchboard**:
  - `aapp ai-status`: Reports current attribution mode and configuration.
  - `aapp ai-commit`: Activates semantic, email-less trailers (`AI-Agent: <Agent>`, `AI-Vendor: <Vendor>`, `AI-Model: <Model>`).
  - `aapp ai-notes`: Activates structured git-notes attribution with safe push refspecs (`+refs/heads/*:refs/heads/*` and `+refs/notes/*:refs/notes/*`) and `cat_sort_uniq` merge strategy.
  - `aapp ai-off`: Resets `aapp.aiAttribution` to `none`.
- **Commit-Msg Enforcement Engine**: Introduce `templates/aapp-commit-msg` to enforce attribution rules (ignoring `git revert` false positives per G2) and numeric subject length (`aapp.subjectMaxLen`, default 72 chars per G4).
- **Planning Health Pair 6**: Add `check_recorded_sha_integrity` to `lib/planning_health.sh` to ensure all recorded SHAs in archive ledgers and active backlogs resolve against `git cat-file -e <sha>^{commit}`.
- **Historical Scrubbing & Conversion**: Provide `scripts/scrub-attribution.sh` to convert all 110 legacy `Co-authored-by: Antigravity <antigravity@google.com>` trailers into `AI-Agent: Antigravity` + `AI-Vendor: Google`, preserving original timestamps to the exact second, repairing all ledger SHAs, and restoring worktrees cleanly.

---

## 2. Technical Blueprint

### A. Attribution Modes & Git Configuration Schema

Active attribution state is held strictly in Git configuration, **never** in `AGENTS.md`:
- `git config aapp.aiAttribution` -> enum: `none` (default), `commit`, `notes`
- `git config aapp.subjectMaxLen` -> integer: default `72` (max subject line length)

```
                            ┌────────────────────────────────────────┐
                            │    git config aapp.aiAttribution       │
                            └───────────────────┬────────────────────┘
                                                │
         ┌──────────────────────────────────────┼──────────────────────────────────────┐
         │ (default: unset or "none")           │ "commit"                             │ "notes"
         ▼                                      ▼                                      ▼
   [ aapp ai-off ]                     [ aapp ai-commit ]                     [ aapp ai-notes ]
┌──────────────────────────────┐    ┌──────────────────────────────┐    ┌──────────────────────────────┐
│ git config: none             │    │ git config: commit           │    │ git config: notes            │
│ Zero commit trailers         │    │ Semantic RFC 822 trailers:   │    │ Mode: Git Notes              │
│ Zero git notes               │    │ AI-Agent: <Name>             │    │ Push refspecs: heads + notes │
│ Human-only commit identity   │    │ AI-Vendor: <Vendor>          │    │ notes.mergeStrategy:         │
│                              │    │ AI-Model: <Model>            │    │ cat_sort_uniq                │
└──────────────────────────────┘    └──────────────────────────────┘    └──────────────────────────────┘
```

1. **`DISABLED` / `none` (Default)**:
   - Commits contain strictly human author & committer metadata. No trailers or notes added.
   - Verified by `aapp-commit-msg`: blocks legacy `Co-authored-by:` agent emails.

2. **`COMMIT` Mode (`aapp ai-commit`)**:
   - Commits append standardized email-less RFC 822 trailers:
     ```text
     feat(guard): implement external path allowlist

     AI-Agent: Antigravity
     AI-Vendor: Google
     AI-Model: gemini-3.8-flash-high
     ```
   - Eliminates email addresses completely, preventing GitHub user matching and account hijacking.
   - Separate keys (`AI-Agent`, `AI-Vendor`, `AI-Model`) allow direct querying without string splitting:
     ```bash
     git log --format="%h | %(trailers:key=AI-Vendor,valueonly=true) | %(trailers:key=AI-Agent,valueonly=true) | %s"
     ```

3. **`NOTES` Mode (`aapp ai-notes`)**:
   - Keeps commit messages clean and human-only.
   - **Private by intent.** Notes stay local unless the operator configures refspecs, so this mode suits teams that want per-commit agent benchmarking without publishing it. Choosing notes is a deliberate privacy decision and the kit must not undermine it — see §E.8.
   - **Staged Note Buffer Architecture (`aapp_pending_note.<msg-sha256>`)**:
     - **Message-SHA Keying**: To prevent concurrent overwrites (B4) and misattribution from abandoned commits (B2), the buffer is keyed strictly by the SHA-256 hash of the commit message:
       ```text
       $(git rev-parse --git-path aapp_pending_note).<message-sha256>
       ```
       *(Token trailers were rejected to avoid polluting commit messages; tree hashes were rejected because subsequent `git add` operations invalidate them).*
     - **Byte-Faithful Hashing Invariant (B1)**:
       - `git log -1 --format=%B` is **not** byte-faithful: it injects an extra trailing newline, corrupting the hash.
       - Command substitution `$(...)` strips trailing newlines, producing a third distinct hash.
       - **Canonical Reader**: Both `commit-msg` and `post-commit` calculate the commit message hash using the exact byte stream from the commit object:
         ```bash
         MSG_HASH=$(git cat-file commit HEAD 2>/dev/null | sed '1,/^$/d' | sha256sum | awk '{print $1}')
         ```
     - **Staged Telemetry Payload**:
       Prior to committing, the agent or developer stages structured YAML into `$NOTE_DIR/aapp_pending_note.<msg-sha256>` (via `aapp ai-note --stage`):
       ```yaml
       agent: Antigravity
       vendor: Google
       model: gemini-3.8-flash-high
       task: guard-path-authorization
       custom:
         test-pass-rate: 100%
         duration-sec: 42
       ```
       *(Note: `custom` fields here represent private local benchmarking telemetry, separate from the public `AAPP-AI-CREDITS` README footer — see §E.6 and §E.8).*
     - **Atomic Attachment & Failure Safety (B3)**:
       When `git commit` succeeds, `templates/aapp-post-commit` locates the matching note buffer by `MSG_HASH`.
       **Unlink on Success Only (`&&`)**:
       ```bash
       git notes add -f -F "$MATCHED_NOTE_FILE" HEAD 2>/dev/null && rm -f "$MATCHED_NOTE_FILE" || {
           echo "❌ [aapp notes] Failed to attach note to HEAD. Preserving buffer: $MATCHED_NOTE_FILE" >&2
       }
       ```
       If `git notes add` fails (e.g. ref lock or disk error), the note is preserved on disk and reported to `stderr`.
     - **Reaping & TTL Sweep (B5)**:
       On every commit, `aapp-post-commit` reaps orphaned notes older than `aapp.noteTTL` (default 1440 mins / 24h) using portable `-exec rm -f {} +`:
       ```bash
       find "$NOTE_DIR" -maxdepth 1 -name 'aapp_pending_note.*' -mmin "+${TTL_MINS:-1440}" -exec rm -f {} + 2>/dev/null
       ```
     - **Mismatch Warning (B5)**:
       If `post-commit` finds pending note files in `$NOTE_DIR` but none matches `MSG_HASH`, it emits an immediate diagnostic warning to `stderr` while the operator is still at the terminal.
     - **Identical Message Collisions (G3)**:
       If two commits share identical byte-for-byte messages, the first attaches and unlinks the buffer; the second finds no buffer and safely receives no note (fails safe).
     - **Amend Durability (G2)**:
       On `git commit --amend`, `notes.rewriteRef` copies the previous note to the new SHA. If a new note was staged for the amended message, `post-commit` attaches it with `-f`, cleanly superseding the copied note. If no note was staged, the copied note persists untouched.
   - Configures push refspecs idempotently with `--replace-all` and includes heads so branch pushes remain intact (G1):
     ```bash
     git config --replace-all remote.origin.push "+refs/heads/*:refs/heads/*"
     git config --add remote.origin.push "+refs/notes/*:refs/notes/*"
     git config --replace-all remote.origin.fetch "+refs/heads/*:refs/heads/*"
     git config --add remote.origin.fetch "+refs/notes/*:refs/notes/*"
     git config notes.mergeStrategy cat_sort_uniq
     git config notes.rewriteMode concatenate
     git config --replace-all notes.rewriteRef "refs/notes/commits"
     ```
   - **`notes.rewriteRef` is mandatory, not optional.** Git's documentation states it *"does not have
     a default value; you must configure this variable to enable note rewriting."* Without it,
     `notes.rewriteMode` is inert — it describes how to combine notes when copying, and copying is
     disabled entirely. An operator who selects notes mode for durable private benchmarking would
     otherwise lose it **silently** on the first `git commit --amend` or `git rebase`.
   - **Known durability limits, to be documented rather than papered over:**
     - `cherry-pick` is not in git's default rewrite set (`amend` and `rebase` are), so notes do not
       follow a cherry-picked commit.
     - `filter-branch` carries no notes at all without explicit handling — see §D.1.
     - These limits are the strongest practical argument for `ai-commit` as the default: trailers live
       inside the commit object and survive every operation that drops notes.

### B. Hook Enforcement & Post-Commit Infrastructure

AAPP establishes three coordinated hook layers for the commit lifecycle:

1. **Commit-Msg Enforcement Hook (`templates/aapp-commit-msg`)**:
   - Invoked by thin runner `templates/commit-msg` (`core.hooksPath=.githooks`).
   - Evaluates two check pairs:
     - **Check 1: Subject Length & Shape (G4)**: Reads `git config aapp.subjectMaxLen` (default 72). Refuses commits exceeding length with actionable advice. Enforces Commit Conciseness Invariant.
     - **Check 2: Attribution Policy & Revert Safety (G2)**: Reads `git config aapp.aiAttribution`. Ignores revert commits (`^This reverts commit [0-9a-f]+` or quoted lines `^>`). In `commit` mode, requires valid `AI-Agent:` trailer and blocks synthetic vendor emails (`Co-authored-by:`). In `none` mode, verifies no AI attribution trailers are present.
   - **Message-Hash Sync (G1)**: If a human edits the commit message in `$EDITOR` during `git commit`, `commit-msg` receives the final buffer `$1`. It computes `sha256sum "$1"` and renames any pre-staged `aapp_pending_note.<initial-hash>` to `aapp_pending_note.<final-hash>`, ensuring post-commit matches seamlessly.

2. **Post-Commit Staged Note Attacher (`templates/aapp-post-commit`)**:
   - Invoked by thin runner `templates/post-commit`.
   - Resolves canonical directory: `NOTE_DIR="$(git rev-parse --git-path .)"`.
   - Recomputes exact commit body hash via `git cat-file commit HEAD | sed '1,/^$/d' | sha256sum | awk '{print $1}'` (B1).
   - If `aapp_pending_note.<hash>` exists, attaches to `HEAD` via `git notes add -f -F` and unlinks on success (`&&`) (B3).
   - If pending notes exist but none match `HEAD`, warns to `stderr` (B5).
   - Reaps expired notes older than `aapp.noteTTL` (default 1440m) via `find ... -mmin +TTL -exec rm -f {} +` (B5).
   - Silent no-op when no pending notes exist.
   - Both hooks enforce the `chmod +x` permission invariant upon installation.

### C. Planning Health Pair 6: Recorded SHA Integrity (`lib/planning_health.sh`)

- Scans `.plans/done/000-archive-ledger.md`, `.plans/done/000-issues-archive.md`, `.plans/ISSUES.md`, and `CHANGELOG.md` for 7–40 character commit hashes.
- For each hash, executes:
  ```bash
  git cat-file -e "${sha}^{commit}" 2>/dev/null
  ```
- Flags any dangling or unresolvable SHAs. Blocks commit / freeze until all references resolve.

### D. Historical Scrubber Runbook (`scripts/scrub-attribution.sh`)

Because rewriting history invalidates existing worktrees and modifies SHAs across the repository, the scrubber follows an airtight, disciplined workflow:

1. **Pre-flight & Backup**:
   - Rehearse execution on a mirror clone (`/tmp/aapp-kit-rehearsal`).
   - Confirm zero uncommitted changes across all worktrees.
   - Record current commit SHAs across `main`, `develop`, `plans`, `agents`, and `githooks`.
   - **Notes pre-flight.** `filter-branch` does not carry `refs/notes/*`. Check with
     `git notes list` (and any non-default refs under `git for-each-ref refs/notes/`). If any exist,
     back them up and re-map them against the old→new SHA map from step 4, or abort. *In this
     repository the check is currently a no-op — no notes exist — but the scrubber ships to adopters
     who may have them, so the step is required, not advisory.*
2. **Worktree Teardown**:
   - Remove extra worktrees (`git worktree remove .plans`, `.agents`, `.githooks`).
3. **Conversion Rewrite**:
   - Run `git filter-branch --msg-filter` over `--all` replacing:
     ```text
     Co-authored-by: Antigravity <antigravity@google.com>
     ```
     with:
     ```text
     AI-Agent: Antigravity
     AI-Vendor: Google
     ```
   - Retain exact `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`.
4. **Ledger Reference Repair**:
   - Read `.git/filter-branch/map/` (old full SHA → new full SHA mapping).
   - In a single post-filter commit across all branches containing ledgers:
     - Replace each old full/short SHA with the new corresponding SHA.
     - Re-abbreviate to standard 7 characters where appropriate.
5. **Verification & Worktree Reconstruction**:
   - Run `planning_health.sh` with Pair 6 to verify 100% SHA resolution.
   - Recreate worktrees (`git worktree add .plans plans`, etc.).
   - Force-push branches with lease: `git push --force-with-lease --all origin`.

### E. AI Contributors Footer (`aapp ai-credits`)

A generated, append-only block in `README.md` disclosing which AI agents worked on the codebase.
**This is a transparency statement, not promotion and not a contribution ranking.** The informative
disclosure is the *scope* of AI involvement — planning, code, and review — not who did which part.

#### E.1 Locked Block Format
Placed after the final section of `README.md`:

```markdown
<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- Antigravity (Google)
- Claude (Anthropic)

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->
```

#### E.2 Generation Contract
* **Union, never subtraction.** `new roster = existing block ∪ agents found in history`. The existing
  block is an **input**, not merely output. Once an agent appears it is never removed by the tool.
* **Deterministic ordering.** Sort agent names with `LC_ALL=C sort`; vendor in parentheses.
  Locale sorting is unstable and would churn the file between machines and CI — verified:
  `Ågent` sorts first under `en_US`, last under `LC_ALL=C`.
* **Byte-identical when unchanged.** No commit counts, no dates, no durations, no timestamps,
  no role annotations. Any of these would dirty `README.md` on every regeneration.
* **Explicit command only — never wired to a hook.** A post-commit hook rewriting `README.md`
  would produce churn on every commit and silently mutate a user-facing document mid-commit.
  Recommended cadence: on demand, plus a release-checklist review item.

#### E.3 Failure Modes — Refuse, Never Degrade
| Condition | Required behaviour |
| :--- | :--- |
| Shallow clone / truncated history (`--depth 1`, CI `fetch-depth: 1`) | Union preserves existing names; never truncates the roster |
| Block markers present but unparseable | **Refuse with error.** Never regenerate from history alone |
| No `README.md` | Skip with notice. Never create one |
| No AI trailers and no existing block | Emit nothing. No empty heading |

#### E.4 Corrections Are Renames, Not Deletions
The roster is append-only by design: *a transparency statement that can be quietly trimmed is not one.*
Identity corrections (an agent recorded once as `Claude Code` and once as `Claude`) are handled by an
alias map, never a delete path:
```bash
git config --add aapp.aiAlias "Claude Code=Claude"
```
The tool exposes no removal operation. Removing an agent requires a deliberate hand edit — which is a
visible, signed diff in history, and that visibility is the accountability mechanism.

#### E.5 Toggle
* `git config aapp.aiCredits` -> boolean, default `false`.
* Deliberately **separate** from `aapp.aiAttribution`. The reason is *not* that publishing is a further
  disclosure — the trailers are already public in history; the footer only makes them findable without
  running `git log`. The reason is narrower: not every repository has a `README.md` worth appending to.
* `aapp ai-off` stops updating the block. It does **not** delete it.

#### E.6 Credit vs. Telemetry — Rejected Alternatives (Do Not Re-Litigate)
| Rejected | Reason |
| :--- | :--- |
| Role annotations in the footer (`— authored` / `— reviewed`) | Creates visible classes in a list whose entire purpose is that there are none. Roles are captured in the plan lane instead |
| A `Reviewed By` column in `000-archive-ledger.md` | Review provenance already lives in the plan lane — each plan's §6 records its review history in prose (see `P13`, `P14`, `flat-issues`). The future adversarial-review plugin formalises that trail; it needs no new column |
| A `git log` verification pointer inside the footer | Per-commit granularity answers a question external readers are not asking, and invites a verification nobody performs |
| Dates, durations, or commit counts | Churn on every regeneration, plus an implied ranking that alphabetical ordering exists to avoid |

**The split:** the footer is *the credit* — equal, public, names only. The plan lane is *the telemetry* —
review history, findings, model versions. Different audiences, different rules.

#### E.7 The First Generation Is Permanent
Append-only means the initial roster is sticky. After the scrub, history will contain only
`AI-Agent: Antigravity`; agents that contributed review but never committed leave no trailer at all.
The initial roster must therefore be **seeded deliberately with human confirmation at execution time**,
not left to whatever the first `ai-credits` run happens to find.

#### E.8 Mode Boundary — The Footer Is `commit`-Mode Only

`aapp ai-credits` generates **only** when `aapp.aiAttribution = commit`. This is a design boundary,
not an error case:

| Mode | Footer | Why |
| :--- | :--- | :--- |
| `none` | not generated | Nothing is recorded, so there is nothing to disclose |
| `commit` | **generated** | Attribution is already public in the commit history; the footer only makes it findable without running `git log` |
| `notes` | **not generated** | Notes are private by intent. Deriving a public README statement from deliberately private metadata would invert the operator's choice |

**The rationale, to be documented verbatim in `MANUAL.md`:** choosing `ai-notes` is a decision to keep
the record of AI involvement internal — a legitimate one, and often the point of the mode. A tool that
then published a roster distilled from that record would defeat it. The footer therefore follows the
public record (trailers) and never the private one (notes). Notes mode remains fully useful for its own
purpose: identical per-commit benchmarking data, held locally, queryable by the team that produced it.

Two consequences:
* In `notes` mode `ai-credits` exits with an explanatory notice, not an error. It is a no-op by design.
* Because generation is union-only (§E.2), a `notes`-mode project that *does* want a footer may maintain
  the block by hand — the tool will never generate it, and equally will never erase it. Operators are
  informed, not locked out.

#### E.9 Deferred Completion — Automatic Reviewer Extraction

**This plan cannot be fully delivered until the adversarial-review plugin ships.**

*What is deferred.* `ai-credits` derives the roster from commit trailers. An agent that reviewed a
blueprint but never committed leaves no trailer, so it cannot be discovered mechanically. Today the
only record of review is prose in each plan's §6 (see `P13`, `P14`, `flat-issues`) — human-written,
inconsistently phrased, and not safely machine-parseable.

*What changes when the plugin lands.* The plugin knows, at review time, exactly which agent and model
produced the review. It writes that into the plan lane in a structured form, giving `ai-credits` a
second mechanical source alongside commit trailers. Reviewer entries then appear without hand-seeding
and the roster becomes fully self-maintaining.

*Interim behaviour.* Review-only agents are added by hand at seeding time (§E.7, and Open Question 2).
This is a supported state, not a workaround — the block is hand-editable by design.

*Why deferring is safe.* Generation is union-only and append-only (§E.2). The plugin, when it arrives,
only ever **adds**; it never has to reconcile, deduplicate against, or migrate a hand-seeded roster.
The alias map (§E.4) covers the one real hazard — the plugin recording a name in a different form from
the one seeded by hand. There is no schema debt in shipping the rest of this plan first.

*Completion criterion.* This plan is fully delivered when `ai-credits` populates reviewer entries from
a structured source with no manual step. Until then it is **partially delivered**, and the remainder
must live in the open-issues pillar rather than inside an archived blueprint — plans in `.plans/done/`
are not read again, and a deferred commitment recorded only there is a commitment that will be lost.

---

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Planning Health Pair 6 & Test Baseline
- [ ] Task 1.1: Author `check_recorded_sha_integrity()` (Pair 6) in `lib/planning_health.sh`.
- [ ] Task 1.2: Add unit tests for Pair 6 in `tests/plan_resolver_test.sh` verifying that both valid and dangling SHAs are correctly evaluated.

### Phase 2: Template Specifications & Hook Infrastructure
- [ ] Task 2.1: Update `templates/AGENTS.md` to specify:
  - Configuration source: `git config aapp.aiAttribution` (`none` | `commit` | `notes`).
  - Semantic trailer standard (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`).
  - Numeric Commit Conciseness Invariant (subject <= 72 chars, imperative mood).
  - Explicit asymmetry: trailers are primary; notes are opt-in and local-first.
  - Staged note buffer protocol (`aapp_pending_note.<msg-sha256>`) for customizable notes.
- [ ] Task 2.2: Create `templates/aapp-commit-msg` implementing subject length validation, attribution policy checks with revert exemption, and message-hash synchronization renaming pre-staged notes (`chmod +x`).
- [ ] Task 2.3: Create thin runner `templates/commit-msg` dispatching to `.githooks/aapp-commit-msg "$1"` (`chmod +x`).
- [ ] Task 2.4: Create `templates/aapp-post-commit` implementing byte-faithful hash extraction (`git cat-file commit HEAD | sed '1,/^$/d' | sha256sum`), atomic `&&` unlinking with stderr preservation on failure, mismatch diagnostic warnings, and portable TTL reaping (`find ... -mmin +TTL -exec rm -f {} +`) (`chmod +x`).
- [ ] Task 2.5: Create thin runner `templates/post-commit` dispatching to `.githooks/aapp-post-commit` (`chmod +x`).
- [ ] Task 2.6: Update `lib/cmd_init.sh` to install `commit-msg`, `aapp-commit-msg`, `post-commit`, and `aapp-post-commit` to `.githooks/` with executable permissions, and set `aapp.aiAttribution=none` by default.

### Phase 3: CLI Switchboard Implementation
- [ ] Task 3.1: Author `lib/cmd_ai.sh` supporting `ai-status`, `ai-commit`, `ai-notes`, and `ai-off`. Update `ai-status` to report pending notes count and age.
- [ ] Task 3.2: Implement safe, idempotent git-notes configuration in `ai-notes`: refspecs (`+refs/heads/*:refs/heads/*` + `+refs/notes/*:refs/notes/*` with `--replace-all`), `notes.mergeStrategy=cat_sort_uniq`, `notes.rewriteMode=concatenate`, and **`notes.rewriteRef=refs/notes/commits`** — the last is mandatory or notes are dropped on amend/rebase.
- [ ] Task 3.3: Register `ai-status`, `ai-commit`, `ai-notes`, and `ai-off` in `./aapp` command dispatcher and help output (`lib/cmd_help.sh`).
- [ ] Task 3.4: Update `lib/cmd_install.sh` to install `lib/cmd_ai.sh` and hook templates.
- [ ] Task 3.5: Implement `aapp ai-credits` in `lib/cmd_ai.sh` per §E — union generation, `LC_ALL=C` ordering, alias map resolution, and the §E.3 refusal matrix.
- [ ] Task 3.6: Register `ai-credits` in the `./aapp` dispatcher and `lib/cmd_help.sh`; add `aapp.aiCredits` (default `false`) to safe-by-default init.
- [ ] Task 3.7: Implement `aapp ai-note` in `lib/cmd_ai.sh` supporting `--stage` to write/customize metadata into `aapp_pending_note.<msg-sha256>`.

### Phase 4: Automated Test Suite
- [ ] Task 4.1: Create `tests/ai_attribution_test.sh` testing:
  - Default `none` state from `aapp init`.
  - State switching via `aapp ai-commit`, `aapp ai-notes`, and `aapp ai-off`.
  - Commit message validation in `aapp-commit-msg` (subject length overflow, missing trailer in commit mode, revert bypass).
  - Post-commit staged note attachment via byte-faithful message-SHA, developer customization, and silent no-op on unstaged commits.
  - Failure safety (failed attachment preserves buffer; unlinks only on `&&` success).
  - TTL cleanup sweep (`find ... -mmin +TTL -exec rm -f {} +`) and mismatch diagnostics.
  - Refspec idempotency during repeated `aapp ai-notes` invocations.
  - `notes.rewriteRef` is set by `ai-notes`, and a note survives `git commit --amend` and `git rebase`.
- [ ] Task 4.2: Extend `tests/ai_attribution_test.sh` for `ai-credits`: union preserves names absent from a shallow history; regeneration is byte-identical when unchanged; `LC_ALL=C` ordering is stable; notes mode is a no-op that neither generates nor erases an existing block (§E.8); unparseable block refuses; missing `README.md` skips; alias map merges duplicate identities; `ai-off` leaves the block intact.
- [ ] Task 4.3: Verify all test suites pass (146+ tests + new attribution & health tests).

### Phase 5: Historical Scrubber Script & Documentation
- [ ] Task 5.1: Author `scripts/scrub-attribution.sh` with `--dry-run`, timestamp preservation, SHA map parsing, and ledger rewriting.
- [ ] Task 5.2: Update `MANUAL.md` and `README.md` documenting the AI attribution suite, benchmarking workflows, and the commit-msg / post-commit hooks. **Must include the §E.8 mode-boundary rationale in full**: why the footer follows the public trailer record and never the private notes record, and that notes mode is a deliberate privacy choice serving internal benchmarking rather than a degraded form of commit mode.
- [ ] Task 5.3: Seed the initial `AI Contributors` block in `README.md` (§E.7) — impartially crediting `Antigravity (Google)` and `Claude (Anthropic)` as resolved in Q2.
- [ ] Task 5.4: Add an `AI Contributors` review line to `.plans/release/release_checklist.md` §2 and `templates/release_checklist.md` alongside the cheat-sheet review item.
- [ ] Task 5.5: Update `CHEATSHEET.md` with quick reference for `aapp ai-*` commands.
- [ ] Task 5.6: Update `CHANGELOG.md` under `[Unreleased]` recording the attribution switchboard, commit/post-commit hooks, and Pair 6 SHA validator.
- [ ] Task 5.7: Before archiving, log a carried-forward issue in `.plans/ISSUES.md` for automatic reviewer extraction (§E.9), scoped to the adversarial-review plugin, and reference it in this plan's archive-ledger row. Archive as **partially delivered**, never as fully closed.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
*(Marked: **LOCKED** — greenlit for execution)*

> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> Note: In accordance with Pair 5 self-protection, files installed into `.githooks/` are updated exclusively via `lib/cmd_init.sh` from source templates in `templates/`.

- [ ] `aapp` -> Register `ai-commit`, `ai-notes`, `ai-off`, `ai-status`, `ai-credits`, and `ai-note` in root CLI dispatcher.
- [ ] `lib/cmd_help.sh` -> Document AI attribution command family in help text.
- [ ] `NEW FILE` -> `lib/cmd_ai.sh` -> Core attribution switchboard, note staging manager, and credits generator.
- [ ] `templates/AGENTS.md` -> Document git config attribution model, semantic trailers, and subject conciseness invariant.
- [ ] `NEW FILE` -> `templates/commit-msg` -> Thin hook dispatcher for commit-msg event.
- [ ] `NEW FILE` -> `templates/aapp-commit-msg` -> Attribution and subject-length enforcement engine.
- [ ] `NEW FILE` -> `templates/post-commit` -> Thin hook dispatcher for post-commit event.
- [ ] `NEW FILE` -> `templates/aapp-post-commit` -> Staged note attacher for notes mode.
- [ ] `lib/cmd_init.sh` -> Install commit-msg and post-commit hooks and initialize safe-by-default git config.
- [ ] `lib/cmd_install.sh` -> Ensure `lib/cmd_ai.sh` and hook templates are packaged during installation.
- [ ] `lib/planning_health.sh` -> Add Pair 6 (Recorded SHA Integrity) validator.
- [ ] `NEW FILE` -> `tests/ai_attribution_test.sh` -> Automated test suite for AI attribution switchboard, hooks & credits.
- [ ] `tests/plan_resolver_test.sh` -> Add test coverage for Pair 6 SHA integrity verification.
- [ ] `NEW FILE` -> `scripts/scrub-attribution.sh` -> Historical conversion scrubber and ledger SHA repair utility.
- [ ] `README.md` -> Document AI attribution commands and host the seeded `AAPP-AI-CREDITS` block.
- [ ] `CHANGELOG.md` -> Document changes under `[Unreleased]`.
- [ ] `CHEATSHEET.md` -> Add `aapp ai-*` commands quick reference.
- [ ] `.plans/release/release_checklist.md` -> Add AI Contributors footer review item.
- [ ] `templates/release_checklist.md` -> Keep release checklist template aligned with .plans/release/release_checklist.md.
- [ ] `MANUAL.md` -> Document multi-vendor benchmarking, git notes caveats, post-commit staging, and commit shape rules.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Tool interception write-guard is frozen.
- [ ] `templates/aapp-pre-commit` -> Staged file pre-commit engine is frozen.
- [ ] `lib/plan_resolver.sh` -> Shorthand resolver is stable.
- [ ] `lib/cmd_uninstall.sh` -> Uninstaller is stable.

---

## ❓ 5. Open Questions & Settled Decisions

### Settled Decisions (Do Not Re-Open):
- **Email-less Trailers**: No email addresses in AI attribution in any mode. `Co-authored-by:` is permanently rejected.
- **Dedicated Keys**: Separate keys are adopted: `AI-Agent: <Agent>`, `AI-Vendor: <Vendor>`, `AI-Model: <Model>`.
- **History Scrubbing**: Proceeds by converting legacy `Co-authored-by: Antigravity <antigravity@google.com>` trailers into `AI-Agent: Antigravity` + `AI-Vendor: Google`.
- **Configuration Source**: Mode is stored in `git config aapp.aiAttribution` to prevent erasure by `sync_agent_rules()`.
- **AI Contributors Footer**: A generated, append-only `README.md` block. Transparency statement, not promotion. Names only, alphabetical, no roles/dates/counts. Wording locked in §E.1. Append-only is a property of the purpose, not merely of the tooling.
- **Footer Is `commit`-Mode Only**: `ai-credits` generates solely under `aapp.aiAttribution = commit`. Notes are private by intent; publishing a roster derived from them would invert the operator's choice. In notes mode the command is an explanatory no-op, and a hand-maintained block is never erased. Rationale documented in `MANUAL.md` per §E.8.
- **Notes Mode Is Not Degraded**: `ai-notes` is the private benchmarking record, not a lesser `ai-commit`. Documentation must not frame its non-travel as purely a limitation.
- **Partial Completion Is Expected**: Automatic reviewer extraction depends on the adversarial-review plugin and is explicitly out of scope here (§E.9). Deferring is safe because generation is union-only and append-only — the plugin will only ever add. The remainder is carried forward as an open issue at archive time, not left inside the archived blueprint.
- **Credit vs Telemetry**: The footer carries equal, name-only credit. Review provenance stays in the plan lane (`§6` of each blueprint, later formalised by the adversarial-review plugin). No ledger column is added.
- **Initial Roster Seeding (Resolved Q2)**: Impartially seed both `Antigravity (Google)` and `Claude (Anthropic)` in the initial `README.md` block, reflecting both planning/review and code contributions per §E.1.
- **Scrubber Execution Timing (Resolved Q1)**: Implement and unit-test the suite within the P-14 cycle; live execution of `scripts/scrub-attribution.sh` on this repository takes place after human backup of the project.
- **Message-SHA Keying**: Staged notes are keyed strictly by the SHA-256 of the commit message (`aapp_pending_note.<message-sha256>`), preventing concurrent staging races (B4) and abandoned-note misattribution (B2).
- **Byte-Faithful Hashing Invariant**: Message body hashes must be computed via `git cat-file commit HEAD | sed '1,/^$/d' | sha256sum | awk '{print $1}'` (B1), avoiding formatting newline injection (`%B`) or truncation (`$(...)`).
- **Failure Safety & TTL Cleanup**: Staged buffer unlinks only on success (`&&`), preserving on failure with stderr logging (B3). `post-commit` sweeps expired notes via `find ... -mmin +TTL -exec rm -f {} +` (B5).

### Open Questions (Gate):
*(None — design is fully specified and greenlight ready)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Plan frozen and greenlit for execution (/aapp-freeze P-14). Blast radius locked.
* **2026-09-16:** Hardened staged notes following second red-team review: adopted Message-SHA keying (`aapp_pending_note.<sha256>`), closed the B1 `format=%B` newline divergence using `git cat-file | sed`, specified `&&` atomic unlinking to preserve buffers on attachment failure (B3), added B5 TTL cleanup (`find ... -exec rm -f {} +`) and mismatch warnings to `post-commit`, and documented amend/collision invariants.
* **2026-09-16:** Integrated post-commit staged note attacher (`templates/post-commit`, `templates/aapp-post-commit`) enabling atomic, customizable notes. Resolved open questions Q1 (post-implementation backup before live scrub) and Q2 (impartial seeding of both Antigravity and Claude). Added `CHANGELOG.md`, `CHEATSHEET.md`, and `templates/release_checklist.md` to Target Files; corrected test suite path to `tests/plan_resolver_test.sh`.
* **2026-09-15:** Closed a silent data-loss path in notes mode: `notes.rewriteRef` was unset, and git documents it as having no default — without it `notes.rewriteMode` is inert and notes are dropped on every `amend` and `rebase`. Now set explicitly in `ai-notes` with test coverage. Documented the residual limits (`cherry-pick` outside git's default rewrite set; `filter-branch` carries no notes) and added a mandatory notes pre-flight to the scrubber runbook — a no-op in this repository today, but required for adopters.
* **2026-09-15:** Recorded partial-completion boundary (§E.9 plus a header banner): automatic reviewer extraction depends on the adversarial-review plugin, since agents that review without committing leave no trailer to discover. Interim roster seeding stays manual and supported; deferral carries no schema debt because generation is union-only and append-only, so the plugin will only ever add. Task 5.5 requires the remainder be logged as an open issue and referenced in the archive-ledger row, so the plan is archived as partially delivered rather than closed.
* **2026-09-15:** Added §E.8 Mode Boundary — the AI Contributors footer generates only under `ai-commit`. Notes are private by intent, so deriving a public roster from them would invert the operator's choice; in notes mode `ai-credits` is an explanatory no-op and never erases a hand-maintained block. Correspondingly reframed §1.5 and §2.A.3: `ai-notes` is the private benchmarking record, not a degraded `ai-commit`, and its non-travel is a reason to choose it rather than only a limitation. Task 5.2 now requires the rationale be documented in full.
* **2026-09-15:** Added §E AI Contributors Footer (`aapp ai-credits`) following design review: locked transparency wording; union-not-replace append-only generation; `LC_ALL=C` deterministic ordering; byte-identical regeneration (no counts, dates, or roles); explicit-command-only (hook wiring rejected); four-case refusal matrix covering shallow clones, unparseable blocks, absent README, and empty rosters; alias map for identity correction with no delete path; `aapp.aiCredits` toggle separate from attribution mode; credit-vs-telemetry split recording four rejected alternatives; and deliberate first-generation seeding since the roster is permanent.
* **2026-09-15:** Plan refined following adversarial red-team review:
  - Corrected root dispatcher path to `aapp` (B1).
  - Shifted configuration storage from `AGENTS.md` to `git config aapp.aiAttribution` to prevent `cmd_init` overwrite (B2).
  - Specified `templates/commit-msg` and `templates/aapp-commit-msg` for message-time enforcement (B3).
  - Designed disciplined scrubber sequence with SHA mapping, ledger repair, and Planning Health Pair 6 (B4).
  - Fixed push refspec override by combining heads + notes and set `notes.mergeStrategy=cat_sort_uniq` (G1).
  - Added revert exemption to attribution checker (G2).
  - Documented durable trailers vs local notes asymmetry (G3).
  - Added subject length check (`aapp.subjectMaxLen`) and numeric Commit Conciseness Invariant (G4).
  - Settled on separate trailer keys and history conversion.
* **2026-09-15:** Plan initialized from Issue #66 as a draft in the Incubator.
