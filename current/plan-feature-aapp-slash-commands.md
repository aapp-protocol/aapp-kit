# 🗺️ Plan: Shippable AAPP Slash Commands (`.claude/commands/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** `ISSUE-061`
* **Status:** 🔴 Under Review

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### 🔒 Execution Note: `.githooks/` is write-protected
> `blast-radius-guard` hard-blocks every write to `.githooks/*` (self-protection). The engine copy is therefore **never edited directly**. Edit `templates/blast-radius-guard.sh` and run `aapp init` to propagate it into `.githooks/blast-radius-guard`. The same applies to `.agents/AGENTS.md`, which is regenerated from `templates/AGENTS.md` by the delimited-block sync.

---

## 1. Context & Architectural Goal

`README.md:241-245` presents `/status`, `/digest`, `/freeze`, `/done` and `/release` as slash commands, but they exist **only as prose** inside `templates/AGENTS.md`. In Claude Code they resolve to unknown commands. Today the protocol works only when the agent has already read a ~20 KB `AGENTS.md` into context — which is exactly what does *not* happen on a cold session, in a subagent, or in any project the user has just adopted AAPP into.

**Goal:** ship the five lifecycle verbs as real, self-contained command files that `aapp init` installs into **every** AAPP project, so the protocol is executable from a cold start with no prior context load.

Three constraints drive the design:

1. **Portability.** The commands ship as `templates/`, are synced by `aapp init`, and must work in a project that has never seen AAPP before. They cannot assume `aapp` is on `PATH`, that `python3` exists, or that `AGENTS.md` is in context.
2. **Self-containment over indirection.** Each file carries its own procedure inline. `@`-referencing `.agents/AGENTS.md` would pull ~20 KB into context on every invocation and would break in projects using the root-`AGENTS.md` layout.
3. **Single source of truth.** Inlining duplicates procedure text that also lives in `templates/AGENTS.md`. That duplication is the main risk this plan carries, and Phase 3 pins it with a drift test rather than a build step.

---

## 2. Technical Blueprint

### 2.1 Namespace: `.claude/commands/aapp/` → `/aapp:status`

Custom commands **override built-ins of the same name**. A flat `.claude/commands/status.md` would therefore shadow Claude Code's own `/status` in *every project that adopts AAPP* — a surprising, protocol-wide regression for anyone who relies on it.

Namespacing under a subdirectory yields `/aapp:status`, `/aapp:digest`, `/aapp:freeze`, `/aapp:done`, `/aapp:release`. This buys three things:

* **No collisions** — not with built-ins, not with a project's own `/deploy`-style commands.
* **Clean ownership** — the whole `aapp/` directory is AAPP-owned, so `aapp init` may overwrite it byte-for-byte on every run, exactly as it already does for `.githooks/aapp-pre-commit`. User files elsewhere in `.claude/commands/` are never touched.
* **Discoverability** — typing `/aapp:` autocompletes the full lifecycle.

The bare words (`status`, `digest <idea>`, …) remain valid natural-language triggers, because `templates/AGENTS.md` already defines them as prose triggers. Nothing regresses for existing users; they gain a tab-completable path.

### 2.2 Sync semantics — engine files, not user templates

| Class | Existing example | Sync verb | Applies here |
| :--- | :--- | :--- | :--- |
| User-owned scaffold | `pickup.md`, `ISSUES.md` | `copy_guarded` (create if absent) | ✗ |
| AAPP-owned engine | `aapp-pre-commit`, `blast-radius-guard` | `cp` byte-for-byte every init | ✓ |

The command files encode protocol behaviour that must stay in lockstep with the installed `AGENTS.md` version, so they follow the **engine** rule. A new `sync_slash_commands()` helper in `lib/cmd_init.sh` runs `mkdir -p .claude/commands/aapp` and copies all five files unconditionally. This makes `aapp init` the upgrade path for commands, matching how the hooks already upgrade.

### 2.3 Anatomy of a command file

```markdown
---
description: <one line — Claude uses this to decide when to auto-invoke>
argument-hint: [plan-name]
allowed-tools: Bash(aapp status), Read, Glob
---
```

* **`$ARGUMENTS` / `$1`** carry the verb's operand (`/aapp:digest ISSUE-049` → `$1`).
* **`disable-model-invocation: true`** on `freeze`, `done` and `release` — these are state transitions with real consequences (`freeze` grants commit rights; `done` moves files and commits). They must be human-triggered only. `status` and `digest` stay model-invocable.
* **`!`aapp status`` injection** is used *only* in `status.md`, guarded so a missing binary degrades gracefully rather than erroring:

  ```
  !`command -v aapp >/dev/null 2>&1 && aapp status || echo "(aapp CLI not on PATH — read the four pillar files directly)"`
  ```

  This is the key win: the deterministic CLI briefing is injected as real data, and the agent's job narrows to interpreting it and proposing next actions.

  **Failure semantics are harsher than they look, and Phase 1 must respect them.** A non-zero exit from an injected command **aborts the entire invocation** — Claude never sees the command file at all, so an unguarded `` !`aapp status` `` turns a missing binary into a dead command rather than a degraded one. Two rules follow:

  1. The expression must always exit 0. The `&& … || echo …` form above satisfies this; every injected command added later needs the same treatment or a trailing `|| true`.
  2. **Injected commands never prompt for permission — if the permission check returns anything but `allow`, the invocation aborts.** A compound expression (`command -v … && aapp status || echo …`) is unlikely to match a narrow `allowed-tools: Bash(aapp status)` pattern, so Phase 1 must verify the real matching behaviour and widen the pattern, or move the guard logic into a tiny shipped helper script that can be allow-listed as a single stable command.
* Each file ends with a pointer line — *"Full protocol contract: `.agents/AGENTS.md` (or root `AGENTS.md`)"* — so the agent can escalate to the canonical text when a case is genuinely ambiguous, without paying for it on every call.

### 2.4 Drift control

`templates/AGENTS.md` remains canonical prose; the command files are the executable summary. A new assertion block in `tests/install_test.sh` verifies, for each of the five verbs, that the command file exists, parses as YAML frontmatter + body, declares a `description`, and mentions the same canonical artefact paths as its `AGENTS.md` section (`.plans/state_matrix.md` for `freeze`, `000-archive-ledger.md` for `done`, and so on). This catches the realistic drift — a step being added to `AGENTS.md` and not to the command — without a generator.

### 2.5 Self-protection

An agent that can rewrite `.claude/commands/aapp/freeze.md` can rewrite its own gate. `templates/blast-radius-guard.sh` currently hard-blocks `.claude/settings.json` and `.githooks/*`; the same `case` gains `.claude/commands/aapp/*` so the AAPP namespace is tamper-proof while a project's own commands stay freely editable.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Author the command templates
- [ ] Task 1.1: Create `templates/commands/` and author `status.md` — frontmatter (`description`, `allowed-tools: Bash(aapp status), Read, Glob`), guarded `!`aapp status`` injection, and the 5-step four-pillar briefing contract. Must state "never omit a pillar".
- [ ] Task 1.2: Author `digest.md` — `argument-hint: [idea or ISSUE-ID]`, `$ARGUMENTS`, and the 6-step routing procedure (resolve → route to lane → NEW/AMEND → scaffold → clean pickup → report). Must preserve "produces a draft, never a green light".
- [ ] Task 1.3: Author `freeze.md` — `disable-model-invocation: true`, `argument-hint: [plan-name]`, the 3-step lock procedure, and an explicit note that freezing grants commit rights under the pre-commit hook.
- [ ] Task 1.4: Author `done.md` — `disable-model-invocation: true`, the 4-step archive procedure (move → ledger line → strip from `state_matrix.md` → commit the `plans` worktree).
- [ ] Task 1.5: Author `release.md` — `disable-model-invocation: true`, `argument-hint: [version]`, the 5-step preflight runbook against `.plans/release/release_checklist.md`.

### Phase 2: Wire the sync into `aapp init`
- [ ] Task 2.1: Add `sync_slash_commands()` to `lib/cmd_init.sh` — `mkdir -p .claude/commands/aapp`, unconditional `cp` of all five, guarded by `[ -d "$AAPP_TEMPLATES/commands" ]`.
- [ ] Task 2.2: Call it from the existing `.claude/` phase (PHASE 5), and extend the completion banner with `➡️  Slash commands:  .claude/commands/aapp/`.
- [ ] Task 2.3: Add `.claude/commands/aapp/*` to the self-protection `case` in `templates/blast-radius-guard.sh`, then run `aapp init` to propagate into `.githooks/blast-radius-guard`.
- [ ] Task 2.4: Document the five commands and the `/aapp:` namespace in `templates/AGENTS.md`; run `aapp init` to re-sync the protocol block into `.agents/AGENTS.md`.

### Phase 3: Verification & Edge Cases
- [ ] Task 3.1: Extend `tests/install_test.sh` — fresh `aapp init` creates all five files; a second `init` overwrites a locally modified AAPP command (engine semantics); an unrelated `.claude/commands/mine.md` survives untouched; a pre-existing `.claude/settings.json` still merges correctly.
- [ ] Task 3.2: Extend `tests/write-guard_test.sh` — `.claude/commands/aapp/freeze.md` is DENIED, `.claude/commands/mine.md` is ALLOWED.
- [ ] Task 3.3: Add the Section 2.4 drift assertions for all five verbs.
- [ ] Task 3.4: Verify degraded paths by hand — `aapp` absent from `PATH` (the invocation must still render, not abort), an `allowed-tools` pattern that actually matches the guarded compound command, and a project with no `.claude/` directory at all.
- [ ] Task 3.5: Run all three suites; update the case counts in `README.md:279-281` and the `.plans/ISSUES.md` verification line.
- [ ] Task 3.6: Update `README.md` §7 table to `/aapp:<verb>`, add a MANUAL.md section, add `.claude/commands/` to both architecture trees, and write the `CHANGELOG.md` entry.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `NEW FILE` -> `templates/commands/status.md` -> Four-pillar context recovery briefing.
- [ ] `NEW FILE` -> `templates/commands/digest.md` -> Idea/issue routing and blueprint scaffolding.
- [ ] `NEW FILE` -> `templates/commands/freeze.md` -> Blast Radius lock and greenlight.
- [ ] `NEW FILE` -> `templates/commands/done.md` -> Archive lifecycle and ledger append.
- [ ] `NEW FILE` -> `templates/commands/release.md` -> Release preflight runbook.
- [ ] `lib/cmd_init.sh` -> Add `sync_slash_commands()`, call site in PHASE 5, completion banner line.
- [ ] `templates/blast-radius-guard.sh` -> Add the AAPP command namespace to self-protection.
- [ ] `templates/AGENTS.md` -> Document the `/aapp:` namespace alongside the existing prose triggers.
- [ ] `tests/install_test.sh` -> Sync, overwrite, preservation and drift assertions.
- [ ] `tests/write-guard_test.sh` -> Self-protection assertions for the command namespace.
- [ ] `README.md` -> §7 lifecycle table, test counts.
- [ ] `MANUAL.md` -> Slash command reference section.
- [ ] `templates/architecture.md` -> Add `.claude/commands/` to the structural tree.
- [ ] `ARCHITECTURE.md` -> Mirror the tree change.
- [ ] `CHANGELOG.md` -> Unreleased entry citing ISSUE-061.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/` -> Write-protected engine copies; regenerate via `aapp init`, never edit.
- [ ] `.agents/AGENTS.md` -> Generated from `templates/AGENTS.md` by delimited-block sync.
- [ ] `lib/cmd_upgrade.sh` -> Distribution fixes belong to ISSUE-049, not this plan.
- [ ] `lib/cmd_install.sh` -> Self-consumption fixes belong to ISSUE-051, not this plan.
- [ ] `templates/aapp-pre-commit` -> Commit-time enforcement is unchanged by this work.
- [ ] `aapp` -> No dispatcher verb is added; these are agent commands, not CLI subcommands.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 — Namespace.** This plan specifies `/aapp:status` because a flat `/status` would shadow Claude Code's built-in `/status` in every adopting project. **Verified 2026-09-10:** shadowing is total and irreversible — custom commands are prompt templates, not callables, so there is no delegation, fall-through or `super()`-style mechanism, and no syntax reaches a shadowed built-in. The two verbs are also semantically unrelated (Claude's `/status` reports session and context usage; AAPP's reports the four project pillars), so the collision trades away a useful built-in for no gain. Namespacing is additionally the ecosystem idiom — plugin commands resolve as `/plugin-name:command-name`. The cost is that `README.md` and `AGENTS.md` currently document the bare form. Confirm the namespaced form, or accept the shadowing to keep the documented UX literal.
* [ ] **Question 2 — Commands vs. Skills.** Claude Code has merged custom commands into skills, and its docs now recommend `.claude/skills/<name>/SKILL.md` for new work; that form also produces `/<name>` and additionally supports supporting files and `context: fork`. This plan implements `.claude/commands/*.md` as requested. Confirm that, or re-target Phase 1 at `.claude/skills/`.
* [ ] **Question 3 — `aapp status` coupling.** `status.md` injects the CLI's output via `` !`aapp status` ``, which makes the briefing deterministic but ties the command to an installed binary (drop-in projects may not have one). **Verified 2026-09-10:** the failure mode is abort-the-whole-invocation, not graceful degradation, and the permission check must return `allow` or the invocation aborts too (see §2.3). Confirm the guarded-fallback approach, or drop the injection entirely and have the agent read the four pillar files directly — the safer option if `allowed-tools` cannot cleanly match the guarded expression.

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Verified `!` injection semantics: execution is pre-render and non-discretionary, a non-zero exit aborts the whole invocation, and a non-`allow` permission check does the same. Hardened §2.3, Task 3.4 and Open Question 3 accordingly.
* **2026-09-10:** Verified against the slash-command spec that no command-to-command delegation exists and that shadowing a built-in is total; recorded in Open Question 1.
* **2026-09-10:** Plan initialized from `ISSUE-061` (2026-09-10 audit sweep). Namespace, engine-sync semantics, self-protection scope and drift-test strategy specified; three open questions raised for human decision.
