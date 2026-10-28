# 🗺️ Plan P-137: Perl Port Documentation And Manuals Overhaul
* **Created:** 2026-10-24 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-137
* **Changelog:** Changed: overhaul README.md, MANUAL.md and CHEATSHEET.md to document pure Perl 5.26+ runtime, noun-first CLI hierarchy, layered configuration, lifecycle governance, and group amendments
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-137` is the twenty-first member of group `P-111` (*Perl Port Of The Kit*). It executes immediately after `P-122` (which removes all legacy bash modules and establishes pure-Perl `./aapp`) and prior to archiving the group amendments member (`P-112`).

Throughout the Perl port, significant architectural advancements, subsystems, and behavioral corrections were introduced beyond simple language translation:
1. **Zero Non-Core Dependencies & Pure Perl 5.26+ Runtime**: Zero bash, zero `python3` helpers, zero CPAN modules, built-in deterministic JSON (`AAPP::JSON`), and decorative-only emojis (`AAPP::Text`).
2. **Layered Configuration (`P-132`)**: Hierarchical `main.conf` cascading (`System > User > Repo`) with administrative key allowlisting.
3. **Lifecycle Governance & Review Gates (`P-131`)**: Configurable `aapp.governance` modes (`hitl`, `strict`, `lax`, `autonomous`), standard IPC interface contract for external authorities (`aapp.governanceHandler`), and turn-yielding invariants.
4. **Group Amendments Ledger & Pre-Commit Verification (`P-130`)**: Group-addressed amendments (`aapp plan amend <group-id>`), deviations, claims reader, and delegated token verification bypassing the Design Lock without `--no-verify`.
5. **Noun-First CLI Hierarchy (`P-117`, `P-118`, `P-119`, `P-138`)**: All commands organized cleanly by noun (`aapp plan`, `aapp issue`, `aapp pickup`, `aapp review`) under `lib/AAPP/Runner/`, eliminating legacy `refine` and standalone verbs.
6. **Whole-Group Plan Invariant (`P-133`)**: Mandate that all planning pointers name §1 Goal, §2 Shared Decisions, and target architecture first.
7. **Unified Telemetry Sink**: Structured JSONL event logging via `AAPP::Logger::log_event` into `aapp.logFile` (`.git/aapp.log`).

Existing user manuals and guides (`README.md`, `MANUAL.md`, `CHEATSHEET.md`) still reference legacy bash concepts, outdated installation assumptions, and lack documentation for these new subsystems. Plan `P-137` executes a comprehensive documentation overhaul, serving as the definitive, holistic fact-check across the entire ported kit.

---

## 2. Technical Blueprint

### 2.1 Front-Door Overhaul (`README.md`)
Rewrite `README.md` to reflect the modern Perl-powered kit:
- **Core Value Proposition**: Deterministic planning, worktree isolation, dual-layer blast radius enforcement, and zero-dependency Perl 5.26+ engine.
- **Prerequisites & Requirements**: Git 2.20+ and Perl 5.26+ (core modules only). Explicitly note zero external packages (no npm, no pip, no python3, no CPAN).
- **Quick Start & Lifecycle Walkthrough**: Highlighting the standard workflow (`init` -> `draft` -> `freeze` -> `start` -> `commit` -> `done`).
- **Feature Callouts**: Highlight layered configuration (`main.conf`), lifecycle governance review gates, and worktree isolation.

### 2.2 Comprehensive Reference Manual Overhaul (`MANUAL.md`)
Overhaul `MANUAL.md` into an exhaustive technical reference:
- **Runtime Architecture**: Single-pass workspace state model (`AAPP::State`), ordered JSON builder (`AAPP::JSON`), decorative-only emoji parser (`AAPP::Text`).
- **Layered Configuration Guide**: Structure of `/etc/aapp/main.conf`, `~/.config/aapp/main.conf`, and repo-level `.git/config` with precedence and security allowlists.
- **Lifecycle Governance & HITL Gates Guide**: Documenting governance modes (`hitl`, `strict`, `lax`, `autonomous`), the `aapp.governanceHandler` JSON IPC protocol, and web dashboard / SSH integration.
- **Group Plans & Amendments Ledger**: Comprehensive guide to group coordination (`P-101`), group-addressed amendments (`aapp refine amends <group>`), deviations, claims resolution, and token-based pre-commit authorization.
- **Telemetry & Logging**: The `.git/aapp.log` JSONL event stream, schema formats, and test harness slicing.

### 2.3 Cheatsheet Synchronization (`CHEATSHEET.md`)
Update `CHEATSHEET.md` with modern command syntax:
- Document all noun-first commands (`aapp plan ...`, `aapp issue ...`, `aapp pickup ...`, `aapp review ...`).
- Document `aapp plan amend <group-id> request|approve|decision`.
- Document `aapp plan status <group-id> amends [json]`.
- Document governance configuration flags (`git config aapp.governance*`).
- Clarify pure-Perl test execution via `aapp test` and `prove -l t/`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default).
- **Fallback Inventory**: `None`. All documentation strictly presents the current Perl runtime and kit behavior with zero legacy bash references.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: README.md Overhaul
- [ ] Task 1.1: Rewrite `README.md` with updated runtime prerequisites, architectural pillars, and quick start guide.
- [ ] Task 1.2: Verify all markdown links, code blocks, and command examples in `README.md`.

### Phase 2: MANUAL.md Comprehensive Reference
- [ ] Task 2.1: Author the Layered Configuration section in `MANUAL.md`.
- [ ] Task 2.2: Author the Lifecycle Governance & Review Gates section in `MANUAL.md`.
- [ ] Task 2.3: Author the Group Plans & Amendments Ledger section in `MANUAL.md`.
- [ ] Task 2.4: Update Hook Architecture, Blast Radius Enforcement, and Telemetry sections in `MANUAL.md`.

### Phase 3: Cheatsheet & Adopter Docs Sync
- [ ] Task 3.1: Synchronize `CHEATSHEET.md` with new verb forms and configuration parameters.
- [ ] Task 3.2: Verify consistency between `MANUAL.md`, `lib/verbs.tsv`, and `lib/docs/verbs/*.md`.

### Phase 4: Final Fact-Check & Verification
- [ ] Task 4.1: Audit the entire documentation set against the running Perl kit to guarantee 100% contract fidelity.
- [ ] Task 4.2: Verify zero broken relative links and zero machine paths across all modified documentation files.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly confined to the files listed under `### 📂 Target Files`.
- [ ] `README.md` -> Front-door project overview, prerequisites, and quick-start guide.
- [ ] `MANUAL.md` -> Comprehensive reference manual covering runtime, config, governance, and ledgers.
- [ ] `CHEATSHEET.md` -> Quick-reference card updated with amendments and governance commands.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/` -> Code modifications are out of bounds; documentation reflects already-shipped Perl code.
- [ ] `t/` -> Test files remain untouched.
- [ ] `ARCHITECTURE.md` & `.agents/CODEMAP.md` -> Managed by group plan `P-111` applied on group done.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — documentation scope is fully defined by ported Perl subsystems and user directives)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Aligned documentation scope with noun-first CLI command hierarchy (`aapp plan`, `aapp issue`, `aapp pickup`, `aapp review`).
* **2026-10-24:** Drafted as a dedicated documentation and manuals overhaul plan (`P-137`) in Group `P-111`, serving as the comprehensive fact-check of all ported Perl subsystems and kit corrections.
