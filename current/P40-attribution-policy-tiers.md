# 🗺️ Plan P-40: Attribution Policy Tiers
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** #81
* **Plan ID:** P-40
* **Status:** ⚡ In Development
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

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

## 1. Context & Architectural Goal

### Problem Statement
`aapp.aiAttribution` has three values — `none`, `commit`, `notes` — and `commit` mode refuses every
commit without an `AI-Agent:` trailer (`templates/aapp-commit-msg`). Its only advice for a human
commit is `aapp ai-off`, a repository-wide switch. Consequences:

1. **A human cannot commit in `commit` mode.** Every commit in this repository since attribution was
   enabled passed only because an agent wrote its trailers.
2. **Human-run lifecycle verbs fail silently (#81).** `aapp freeze`, `start`, `done`, `draft` from a
   terminal produce trailer-less commits; the hook refuses them through the `.plans/.githooks`
   symlink and `|| true` hides it. Every lifecycle commit this week was completed by hand.
3. **One setting means two things.** Storage (public trailers vs private git notes) and enforcement
   (who must carry attribution) are the same value, so "a human in a traced repository" has no mode.

Settled in the P-39 RFC (`.plans/pickup/p39-commit-helper-rfc.md`, decisions C25–C35, C28) and split
out of P-39: attribution is decided by explicit configuration and identity, never by detecting a
terminal (C29).

### Architectural Goal
1. Four modes in one setting: `none | lax | strict | notes`, `lax` the default.
2. `lax` trusts good behaviour: trailers are validated when present, a commit without them is a human
   commit. `strict` enforces a trace on every commit. `notes` stores private notes and is strict for
   anything that carries an identity.
3. One attribution layer — identity resolution and note writing — that the P-39 commit engine and the
   lifecycle verbs call; no verb composes trailers by hand.
4. No exemptions: every commit meets the mode's rule (C26).

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) — the kit is unannounced; no alias for `commit`.
- **Fallback Inventory**: `None (Clean Break)`. A repository still set to `aapp.aiAttribution=commit`
  is refused loudly at commit time with the command that migrates it (§2.2); the hook never guesses
  `lax` or `strict` for it. This repository migrates with `aapp ai-lax` when P-40 lands.

### 2.1 Modes

| `aapp.aiAttribution` | Storage | Enforcement | For |
| :--- | :--- | :--- | :--- |
| `none` | nothing | AI trailers refused (unchanged) | Pure human repositories |
| `lax` *(default)* | public trailers | Trailers present → validated (format, banned emails); absent → human commit | Mixed human/AI work |
| `strict` | public trailers | Every commit must carry valid trailers | Autonomous agents, or a human who delegates all bookkeeping |
| `notes` | private git notes | Trailers in the message refused (unchanged); every commit the CLI makes with an identity carries a note | Internal AI/script tracing |

- **`strict` with a human in the loop** (C35 addendum): a human who commits personally switches to
  `ai-lax` or `ai-off` for that stretch. No per-commit override.
- **Stated limit** (C27): in `lax`, an agent that omits its identity is indistinguishable from a
  human. `strict` exists for those who need the guarantee; the plan-template invariant teaches the
  identity tokens.
- **`notes`** (C31, C32): intended for AI and automated scripts. The hook cannot tell a raw agent
  commit from a human one when neither carries trailers, so the guarantee sits in the CLI: every
  commit the CLI makes with a resolved identity writes its note. A raw commit without a note passes
  as human.

### 2.2 Commit-Msg Hook (`templates/aapp-commit-msg`)
- Banned `Co-Authored-By` checks stay first and apply in every mode.
- `lax`: no trailer → accept. Trailers present → the three must be well-formed (`AI-Agent:`,
  `AI-Vendor:`, `AI-Model:`), emailless.
- `strict`: missing or malformed trailers → refuse, printing the identity tokens and `AAPP_AGENT_*`
  forms and, for a human, `aapp ai-lax`.
- `notes`, `none`: unchanged.
- Unknown value, including the retired `commit` → refuse: *`aapp.aiAttribution=commit` is retired; run
  `aapp ai-lax` or `aapp ai-strict`.*
- **No exemptions** (C26): no subject-prefix or worktree exemption. Lifecycle commits meet the mode's
  rule like any commit (C35): in `lax` they pass as they are; in `strict` the agent's environment
  supplies the trailers.

### 2.3 Setup Verbs (bare, no `--flags`)

| Verb | Sets |
| :--- | :--- |
| `aapp ai-off` | `none` (unchanged) |
| `aapp ai-lax` | `lax` — new |
| `aapp ai-strict` | `strict` — new |
| `aapp ai-notes` | `notes` (unchanged) |
| ~~`aapp ai-commit`~~ | removed; the dispatcher's unknown-verb message names `ai-lax` / `ai-strict` |

`aapp init` seeds `lax` when the key is unset (today: `none`) and never overwrites an existing value.
`aapp ai-status` reports the mode and what it enforces.

### 2.4 Attribution Layer (`lib/attribution.sh`, sourced; functions only)
The decorator that P-39's commit engine and the lifecycle verbs call — attribution is written in one
place.

**`resolve_ai_identity`** — the agent's name, vendor and model, most explicit source first (P-39 Q4):
1. parameters passed by the calling verb (`agent <A> vendor <V> model <M>`);
2. environment: `AAPP_AGENT_NAME`, `AAPP_AGENT_VENDOR`, `AAPP_AGENT_MODEL`;
3. per-worktree git config (`git config --worktree aapp.aiAgent` …), used with caution;
4. a vendor `Co-Authored-By: Name <email>` in the message → converted to emailless trailers, email
   dropped, with a **warning** naming the conversion;
5. nothing → no identity (a human action in `none`/`lax`/`notes`; a refusal in `strict`).

Plain repository config is never read (shared by every worktree). Names normalise through the
existing `apply_agent_aliases` / `normalize_agent_identity` in `lib/cmd_ai.sh`, which move here.

**`attribution_decorate <message-file> [identity]`** — per mode: `lax`/`strict` append the trailers
when an identity resolved; `strict` without one exits 1; `notes`/`none` leave the message alone.

**`attribution_note <sha> [identity] [text]`** — `notes` mode only (C34):

| Identity | Text | Result |
| :--- | :--- | :--- |
| yes | yes | note: identity lines, then the text |
| yes | no | note with the identity only — passes silently |
| no | yes | **exit 1**, stderr names the missing identity and the exact fix |
| no | no | no note (human commit) |

What the text contains is the adopter's business (their agents' instructions); the kit does not
police it. Long commit bodies are **not** moved into notes (C33 rejected; length belongs to P-28).

### 2.5 Division of Work with P-39
- **P-40 (this plan):** modes, hook, setup verbs, `init` default, the attribution layer and its tests.
- **P-39 (after P-40):** the commit engine calls `resolve_ai_identity`, `attribution_decorate` and
  `attribution_note`; exposes `agent … vendor … model …` and `note "<text>"` tokens; migrates the
  lifecycle verbs to `plans_commit` with standard subjects (C35).
- **Until P-39 lands:** lifecycle verbs still commit the whole `.plans` index under `|| true`. In
  `lax` their commits pass (fixing #81 for human-run verbs); in `strict` they are refused, now visible
  only when the verb's failure is surfaced by P-39. This plan does not touch `lib/cmd_plan.sh`.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Failure-first: the declared tests are written and confirmed Red 🔴 before the code they cover.*

### 🧪 Required Tests (Failure & Boundary Assertions)
- [x] `tests/ai_attribution_test.sh::test_lax_accepts_human_commit` -> `lax`, no trailers: commit succeeds
- [x] `tests/ai_attribution_test.sh::test_lax_validates_present_trailers` -> `lax`, malformed or emailed trailers: refused
- [x] `tests/ai_attribution_test.sh::test_strict_requires_trailers` -> `strict`, no trailers: refused with the identity forms and `aapp ai-lax` hint
- [x] `tests/ai_attribution_test.sh::test_strict_accepts_valid_trailers` -> `strict`, the three emailless trailers: accepted
- [x] `tests/ai_attribution_test.sh::test_retired_commit_mode_refuses` -> `aapp.aiAttribution=commit`: refused, naming `ai-lax` / `ai-strict`
- [x] `tests/ai_attribution_test.sh::test_banned_coauthor_rejected_in_every_mode` -> a vendor `Co-Authored-By` with email is refused by the hook in `none`, `lax`, `strict`, `notes`
- [x] `tests/ai_attribution_test.sh::test_setup_verbs_switch_modes` -> `ai-off`/`ai-lax`/`ai-strict`/`ai-notes` set the value; `ai-commit` is an unknown verb naming the replacements
- [x] `tests/ai_attribution_test.sh::test_identity_precedence` -> parameters beat environment beat worktree config; repository config is ignored
- [x] `tests/ai_attribution_test.sh::test_coauthor_converted_with_warning` -> `resolve_ai_identity` turns a `Co-Authored-By: … <email>` into emailless trailers and warns
- [x] `tests/ai_attribution_test.sh::test_strict_decorate_without_identity_exits_1` -> `attribution_decorate` in `strict` with no identity: exit 1
- [x] `tests/ai_attribution_test.sh::test_note_text_without_identity_exits_1` -> `notes`, text but no identity: exit 1, stderr names the fix
- [x] `tests/ai_attribution_test.sh::test_note_identity_only_passes` -> `notes`, identity and no text: note written, no warning
- [x] `tests/install_test.sh::test_init_defaults_to_lax` -> fresh `aapp init` seeds `lax`; an existing value is kept
- [x] `tests/worktree_hooks_test.sh::test_lax_accepts_human_plans_commit` -> a trailer-less commit inside `.plans` passes in `lax` (#81)

### Phase 1: Red Tests
- [x] Task 1.1: Write the Required Tests; confirm Red 🔴.

### Phase 2: Modes & Hook
- [x] Task 2.1: `templates/aapp-commit-msg`: `lax`, `strict`, retired-`commit` refusal, banned co-authors in every mode (§2.2).
- [x] Task 2.2: `lib/cmd_ai.sh`: `ai-lax`, `ai-strict`; remove `ai-commit`; `ai-status` wording (§2.3).
- [x] Task 2.3: `lib/cmd_init.sh`: seed `lax` when unset.
- [x] Task 2.4: `aapp`, `lib/verbs.tsv`, `lib/cmd_help.sh`: verb rows and dispatch.

### Phase 3: Attribution Layer
- [x] Task 3.1: `lib/attribution.sh`: `resolve_ai_identity`, `attribution_decorate`, `attribution_note` (§2.4); move the alias/normalise helpers from `cmd_ai.sh`.
- [x] Task 3.2: Required Tests Green 🟢 (`aapp test ai_attribution`, `install`, `worktree_hooks`).

### Phase 4: Propagation, Docs, Regression
- [x] Task 4.1: `aapp init` on this repository; `aapp ai-lax` here.
- [x] Task 4.2: `templates/plan-template.md` invariant 3 and `templates/AGENTS.md` wording for the four modes.
- [x] Task 4.3: `README.md`, `MANUAL.md` (§9), `CHEATSHEET.md`, `ARCHITECTURE.md`, `.agents/CODEMAP.md`, `CHANGELOG.md`.
- [x] Task 4.4: `aapp test strict quiet` before the commit.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `templates/aapp-commit-msg` -> Four modes, retired-commit refusal, no exemptions
- [ ] `lib/cmd_ai.sh` -> ai-lax, ai-strict, ai-commit removed, ai-status wording
- [ ] `NEW FILE` -> `lib/attribution.sh` -> Identity resolution, decorator, note writer
- [ ] `lib/cmd_init.sh` -> Seed lax when unset
- [ ] `aapp` -> Dispatch for the ai verbs
- [ ] `lib/verbs.tsv` -> ai verb rows
- [ ] `lib/cmd_help.sh` -> Help wording for the ai tier
- [ ] `templates/plan-template.md` -> Invariant 3 wording for the four modes
- [ ] `templates/AGENTS.md` -> Attribution wording for the four modes
- [ ] `README.md` -> Attribution section
- [ ] `MANUAL.md` -> Section 9 attribution modes
- [ ] `CHEATSHEET.md` -> ai verb rows
- [ ] `ARCHITECTURE.md` -> Attribution policy rule
- [ ] `.agents/CODEMAP.md` -> Name lib/attribution.sh
- [ ] `CHANGELOG.md` -> Record under Changed and Fixed

### 🧪 Required Test Files
> Test files that prove this plan's failure cases. Frozen with the blast radius; per-test identifiers are tracked in §3.
- `tests/ai_attribution_test.sh`
- `tests/install_test.sh`
- `tests/worktree_hooks_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Lifecycle verbs migrate to the commit engine in P-39, not here.
- [ ] `.githooks/*` -> Installed engines; `aapp init` propagates template changes.
- [ ] `templates/skills/*` -> No skill wording depends on the mode names.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in the P-39 RFC decisions C25–C35 and C28.)*

### Dependencies & Sequencing
- **Before `P-39`** (user decision C28): P-39 builds its commit engine on these modes and calls `lib/attribution.sh`.
- **Resolves #81** for human-run lifecycle commits in `lax`; P-39 completes it by migrating the verbs to `plans_commit` and surfacing their failures.
- **Pair 7:** shares `lib/verbs.tsv`, `aapp`, `MANUAL.md`, `CHEATSHEET.md` with P-39 — sequential by decision.
- **Source of truth for decisions:** `.plans/pickup/p39-commit-helper-rfc.md` §4.

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Completed all 4 implementation phases. 24/24 suites passing (530 tests).
* **2026-09-28:** Plan activated into ⚡ In Development via start.
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-09-28:** Drafted from the P-39 RFC after the user split attribution out of P-39 and ordered it first (C28). Carries: four modes with `notes` always strict for identified commits (C25, C30–C32); `lax` default and its stated limit (C27); `strict` with a human in the loop (C35 addendum); no exemptions (C26); standard lifecycle commits meeting the mode's rule (C35); notes travelling with the commit, bare attribution passing, text without identity exit 1 with stderr (C34); identity sources (P-39 Q4); TTY detection rejected (C29); long bodies not in notes (C33).
