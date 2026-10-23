# 🗺️ Plan P-131: Lifecycle Governance And Review Gates
* **Created:** 2026-10-23 | **Last Refined:** 2026-10-23
* **Target Issue / Milestone:** Milestone: v0.10.0
* **Plan ID:** P-131
* **Changelog:** Added: pluggable external governance protocol, configurable HITL lifecycle enforcement, and dynamic CLI prompt steering
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->

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

### 📜 Background & Problem Statement
During real-world deployment testing in a fresh downstream target repository (`twiat`), an autonomous AI agent was instructed to triage and resolve repository issues one by one. The agent successfully resolved nine small issues in place using `aapp issue fix`. 

When encountering Issue #10, the fix exceeded the protocol line limits (at most 25 lines / 3 files). The CLI output gave diagnostic advice:
```text
Abort it and promote to a plan: 'aapp issue fix 10 abort', then 'aapp draft <slug> issue 10'.
```
Following this diagnostic, the agent aborted the fix, drafted the blueprint (`aapp draft`), immediately froze it (`aapp freeze`), activated it (`aapp start`), implemented Section 3, and archived it (`aapp done`)—**all in an unbroken, autonomous chain without yielding to the human developer, requesting review, or pausing between lifecycle states**.

### 🔍 Fact Record from Real-World Transcript (`real-plan-lifecycle-intent.md`)
1. **Agent Completion Bias**: LLMs are heavily conditioned to satisfy high-level task framing (e.g. *"sort them out one at a time"*) by chaining sub-skills end-to-end within their turn budget unless a strict mechanical boundary or explicit turn-yield invariant terminates their tool loop.
2. **Missing Stop / Yield Boundaries in Skills**: Existing skills (`aapp-plan`, `aapp-freeze`, `aapp-start`, `aapp-done`) lacked terminal yield rules. In fact, `aapp-start/SKILL.md` explicitly commanded: *"Do NOT pause to ask for redundant confirmation. Immediately proceed to execute Section 3..."*, accelerating unilateral execution.
3. **Context Density Disparity**: In the AAPP development repository, hundreds of files, tests, and historical commits reinforce protocol rules and gate conservatism. In a fresh adopter workspace, an agent possesses only the injected rules and skill files, causing base model completion reflexes to dominate.

### 🗣️ User Directives & Foundational Requirements
*(The following user directives from architectural discussions are preserved verbatim to govern all future implementations of this blueprint)*:

> **Directive 1 (The Real Lifecycle Intent):**
> *"To give you an introduction: I just initialized a new repository. The first thing was onboarding and codebase analysis. We identified a handful of issues, and I told the agent to log the issues, then sort them out one at a time. All were sorted using the `issue fix` command, but the last one was in need of a plan. The agent drafted the plan, applied freeze, start, and done without any breaks in between. I was just watching—I could have stopped it, but the intent was to observe the behavior. I received no briefing between review and freeze, nor after the implementation. The real intent is not to let an agent run on its own by default, but to keep the human in the loop. Now, because the kit also targets autonomous runs, we need adjustments."*

> **Directive 2 (Dynamic CLI Text & Out-of-Repo Lifecycle Tracking):**
> *"Certain string instructions in the CLI must be dynamically created based on the configuration option. Commands like freeze, start, and done do not need a special token. Because AAPP must be installed in order to run in any repository, it is best to track plan lifecycles outside of the repository. If human-in-the-loop (HITL) is the default configuration, approvals can be verified from there, ensuring that the 1%–5% of determined agents or misinterpreted prompts cannot trigger a 'fly-over' implementation. We must be realistic about what requires strict enforcement and what can be lax; in sensitive codebases, reviews must be mandatory."*

> **Directive 3 (Separation of Concerns & Standard Interface Contract):**
> *"'External State Engine' can actually be any program installed anywhere on the system; the essential factor is its communication standard with AAPP. A web interface may have its own state engine, while an agent orchestrator may have another. This keeps one thing simple: AAPP remains the planning and enforcement engine, while the logic of how approval is granted is outside its concern. A standard communication contract is needed to decide, enforce, and dynamically adjust CLI refusal messages based on configuration."*

> **Directive 4 (Rejection of TTY Assumptions):**
> *"I cannot rely on a TTY, as I intend to write automated scripts and build a web view so the entire kit can run on a server and be administered remotely. Configuration must govern this, and the CLI must refuse actions if it lacks script or web session confirmation. Skill lines enforcing stops are also invaluable before reaching a hard CLI refusal."*

### 🎯 Architectural Goal
This plan delivers a unified, comprehensive architecture for **Lifecycle Governance & Review Gates**:
1. Keep the whole concept consolidated in this single plan within Group P-111 so historical decisions remain visible and unbroken.
2. Establish a decoupled, standard **Governance Communication Contract** allowing any external authority (web dashboard, remote API, daemon, orchestrator, script) to govern approval decisions without AAPP needing internal database or network bloat.
3. Introduce `aapp.governance` modes (`hitl` [default], `strict`, `lax`, `autonomous`) in the core Perl engine.
4. Dynamically generate CLI error messages, diagnostics, and steering guidance based on active governance mode.
5. Embed authoritative **Yield Invariants** in all lifecycle skill files (`aapp-plan`, `aapp-digest`, `aapp-freeze`, `aapp-start`, `aapp-done`).

---

## 2. Technical Blueprint

### 🏛️ System Architecture: Decoupled Dual-Plane Governance

```text
┌─────────────────────────────────────────────────────────────────┐
│                      AI Agent / Developer Shell                 │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Executes: aapp freeze / start / done
┌────────────────────────────────▼────────────────────────────────┐
│               AAPP Engine (Perl 5.26+ Core)                     │
│  - Reads git config aapp.governance                             │
│  - Validates Blast Radius, TDD assertions, open questions       │
│  - Invokes AAPP::Governance dispatcher                          │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Standard Protocol (JSON over stdio / exit code)
                                 │ Query: { action: "freeze", plan: "P-10", ... }
┌────────────────────────────────▼────────────────────────────────┐
│          External Authority (Pluggable System Program)          │
│  - Web Interface Backend / Daemon (HTTP / SQLite / Redis)       │
│  - Orchestrator (LangGraph, CrewAI, AutoGen, custom runners)   │
│  - CI / CD Automated Gate or Local Review CLI                   │
│  - Returns: Exit 0 (Approved) OR Exit non-zero + JSON Refusal   │
└─────────────────────────────────────────────────────────────────┘
```

### 1. Configuration Specification (`git config aapp.governance*`)

| Configuration Key | Values | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `aapp.governance` | `hitl`, `strict`, `lax`, `autonomous` | `hitl` | Active governance policy for plan lifecycle transitions. |
| `aapp.governanceHandler` | Executable path or command string | *(empty)* | Path to external authority binary/script invoked at lifecycle gates. |
| `aapp.governanceTimeout` | Integer seconds | `10` | Fail-closed execution timeout for external handler calls. |

#### Policy Definitions
- **`hitl` (Human-in-the-Loop, Default)**: Standard collaborative pairing. Enforces strict skill-level yield invariants; detects and blocks unilateral multi-gate chaining within a single execution turn. If a handler is configured, queries the handler; if unconfigured, requires human confirmation in interactive environments or explicit delegation.
- **`strict`**: Mandatory gatekeeping for sensitive codebases. Transition verbs (`freeze`, `start`, `done`, `abort`) fail closed unless an external authority program (`aapp.governanceHandler`) explicitly returns approval (Exit 0).
- **`lax`**: Low-risk prototyping. Dynamic warnings and yield advice are emitted to stdout, but hard refusals are relaxed.
- **`autonomous`**: Headless batch runners (CI/CD, `/goal`, overnight daemons). Gates auto-approve provided internal invariants (blast radius, green tests, zero open questions) pass.

### 2. Standard Governance Interface Contract

When an agent or script invokes a lifecycle transition (`freeze`, `start`, `done`, `abort`), AAPP executes the configured `aapp.governanceHandler`.

#### A. Ingress Payload (AAPP -> External Authority via STDIN)
```json
{
  "protocol_version": "1.0",
  "event": "lifecycle_gate",
  "action": "freeze",
  "plan_id": "P-131",
  "plan_title": "Lifecycle Governance And Review Gates",
  "repo_root": "/home/lorand/000/agent-planning-kit",
  "caller": "agent",
  "governance_mode": "hitl",
  "current_status": "🟣 Under Review",
  "target_status": "🔷 Frozen",
  "target_files": [
    "lib/AAPP/Governance.pm",
    "lib/AAPP/Output.pm"
  ],
  "unresolved_open_questions": 0
}
```

#### B. Egress Contract (External Authority -> AAPP)
- **Approved**: Process exits with return code `0`.
  Optional STDOUT JSON: `{"approved": true}`
- **Refused / Pending Review**: Process exits with return code `!= 0` (e.g. exit code `1`).
  STDOUT JSON payload:
  ```json
  {
    "approved": false,
    "reason": "awaiting_human_review",
    "review_url": "https://dashboard.local/reviews/P-131",
    "prompt_instruction": "Plan P-131 is currently awaiting human sign-off on the Web Console. Present the draft blueprint, target files, and unresolved questions to the user. STOP calling tools and yield your turn."
  }
  ```

### 3. Dynamic CLI Prompt Steering Engine (`AAPP::Output`)

CLI failure messages and post-action notes must not be static strings. They must actively inspect `aapp.governance` and guide LLM behavior:

#### A. Post-Draft Guidance (`aapp draft`)
- In `hitl` / `strict`:
  ```text
  🚀 Blueprint scaffolded: .plans/current/P131-lifecycle-governance.md
     Plan ID: P-131
     Status : 🟣 Under Review (Incubator)

  🛑 YIELD NOTICE (Human-In-The-Loop):
     Your turn is OVER. Present the blueprint summary, target files, and open questions
     to the user. You are strictly forbidden from calling 'aapp freeze' or 'aapp start'
     until the human explicitly instructs you to do so.
  ```
- In `autonomous`:
  ```text
  🚀 Blueprint scaffolded: .plans/current/P131-lifecycle-governance.md (Autonomous Mode)
     Proceeding to open question verification and freeze checks.
  ```

#### B. Fix Limit Exceeded Guidance (`aapp issue close`)
- In `hitl` / `strict`:
  ```text
  ❌ [Issue Limit Exceeded] Fix touches 32 lines (limit: 25).
     Aborted cleanly via 'aapp issue fix 10 abort'.
     Next: Run 'aapp draft <slug> issue 10' to scaffold a blueprint.
     🛑 STOP: Once drafted, present the plan to the user. Do not implement without review.
  ```

#### C. Lifecycle Gate Refusal (`aapp freeze` / `aapp done`)
- Emits the exact `prompt_instruction` supplied by the external handler, wrapped in an authoritative AAPP banner that triggers model restraint.

### 4. Authoritative Skill Yield Invariants (`SKILL.md`)

Update all lifecycle skills with bold negative constraints:
- `aapp-plan` & `aapp-digest`: Mandate turn yield immediately after blueprint creation.
- `aapp-freeze`: Require explicit delegation from the immediate user turn; forbid chaining to `aapp start`.
- `aapp-start`: Preserve continuous execution for Section 3 implementation, but enforce a hard yield boundary after `aapp commit`, explicitly forbidding unilateral invocation of `aapp done`.
- `aapp-done`: Require explicit user instruction to archive.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default for P-111 Perl port).
- **Fallback Inventory**: `None`. If `aapp.governanceHandler` is not configured, AAPP operates in internal `hitl` mode without requiring external binaries.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Governance Architecture & Module (`AAPP::Governance`)
- [ ] Task 1.1: Author `lib/AAPP/Governance.pm` core module supporting config parsing (`aapp.governance`, `aapp.governanceHandler`, `aapp.governanceTimeout`).
- [ ] Task 1.2: Implement deterministic IPC execution of external handlers with JSON payload serialization over STDIN and fail-closed timeout guards.
- [ ] Task 1.3: Author unit contract test suite `t/core/governance.t` validating all four modes (`hitl`, `strict`, `lax`, `autonomous`).

### Phase 2: Dynamic CLI Prompt Steering (`AAPP::Output` & Diagnostics)
- [ ] Task 2.1: Extend `lib/AAPP/Output.pm` with governance-aware message formatting (`yield_notice`, `gate_refusal_banner`).
- [ ] Task 2.2: Update `lib/AAPP/Cmd/Plan.pm` (and transitional `lib/cmd_plan.sh`) to inject dynamic yield instructions into `draft` and `issue abort/promote` diagnostics.
- [ ] Task 2.3: Integrate `AAPP::Governance::check_gate` into lifecycle verbs: `freeze`, `start`, `done`, and `abort`.

### Phase 3: Skill File Invariants & Rule Updates
- [ ] Task 3.1: Update `.agents/skills/aapp-plan/SKILL.md` and `aapp-digest/SKILL.md` with the post-draft Yield Invariant.
- [ ] Task 3.2: Update `.agents/skills/aapp-freeze/SKILL.md` with the Delegation Invariant.
- [ ] Task 3.3: Update `.agents/skills/aapp-start/SKILL.md` adding the completion yield rule after Section 3 commits.
- [ ] Task 3.4: Update `.agents/skills/aapp-done/SKILL.md` with explicit delegation requirements.
- [ ] Task 3.5: Synchronize behavioral rules in `.agents/AGENTS.md`.

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run full test suite (`aapp test`) confirming zero regressions across existing verbs and hooks.
- [ ] Task 4.2: Author documentation contract in `lib/docs/core/governance.md` and user guide in `MANUAL.md`.
- [ ] Task 4.3: Verify single-pass workspace state compatibility with `AAPP::State`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly confined to the files listed under `### 📂 Target Files`.
- [ ] `NEW FILE` -> `lib/AAPP/Governance.pm` -> Core governance protocol, handler executor, and mode switchboard.
- [ ] `NEW FILE` -> `t/core/governance.t` -> Unit tests for governance modes and external handler IPC.
- [ ] `NEW FILE` -> `lib/docs/core/governance.md` -> Core interface contract for external governance handlers.
- [ ] `lib/AAPP/Output.pm` -> Dynamic governance-aware yield notices and refusal banners.
- [ ] `lib/AAPP/Config.pm` -> Configuration defaults for `aapp.governance*`.
- [ ] `lib/AAPP/Cmd/Plan.pm` -> Gate checks in freeze, start, and done verbs.
- [ ] `lib/cmd_plan.sh` -> Transitional bash lifecycle gate checks during porting.
- [ ] `.agents/skills/aapp-plan/SKILL.md` -> Post-draft Yield Invariant.
- [ ] `.agents/skills/aapp-digest/SKILL.md` -> Post-digest Yield Invariant.
- [ ] `.agents/skills/aapp-freeze/SKILL.md` -> Freeze Delegation Invariant.
- [ ] `.agents/skills/aapp-start/SKILL.md` -> Post-implementation Yield Invariant.
- [ ] `.agents/skills/aapp-done/SKILL.md` -> Archival Delegation Invariant.
- [ ] `.agents/AGENTS.md` -> Protocol rule updates for governance and HITL gates.
- [ ] `MANUAL.md` -> Adopter documentation for external governance configuration and web UI integration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/JSON.pm` -> JSON parser/formatter core is complete and locked.
- [ ] `lib/AAPP/Text.pm` -> Emoji normalizer is locked.
- [ ] `.githooks/blast-radius-guard` -> Write-time interception mechanism remains untouched.
- [ ] `.plans/current/P111-perl-port-of-the-kit.md` -> Group architecture applied at group done.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified by user directives and architectural contract)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-23:** Plan drafted as dedicated Group P-111 member to consolidate external governance, HITL lifecycle enforcement, and dynamic CLI steering into a single historical record.
