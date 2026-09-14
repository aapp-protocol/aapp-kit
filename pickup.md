# 📥 Pickup & Brainstorming
*Dump your raw ideas, mobile notes, or late-night thoughts here. One entry per idea.*

> **This is a queue, not a batch.** Nothing here is acted on until you name it: `/digest <idea>` takes **one** entry and works it into a new blueprint or an amendment to an existing plan. Bare `/digest` lists what is waiting and asks which one you want. Only the entry actually digested is removed — the rest stay put.

## 🆕 New Ideas / Prompt Inputs
- [ ] **Adversarial Peer Review & Layer 6 (Agent Egress Boundary)**: Own blueprint. Formalize the two-agent pattern — one agent drafts (Architect), a differently-trained agent audits (Auditor) against shared on-disk ground truth in `.plans/`. Proven manually over three rounds on `plan-feature-aapp-slash-commands.md` (its §6 entries dated 2026-09-14 *are* the output).

  **Core primitive — build this first:** `aapp review <plan>` emits a curated packet to **stdout** (no `pbcopy`/`xclip` — POSIX pipe only). Contents: adversarial preamble with 🔴 blocker / 🟡 portability / 🟢 verified taxonomy; the plan file verbatim; and a *verification manifest* naming what findings must be checked against (the three suites in `tests/`, `blast-radius-guard.sh` Section 2/3 precedence, current branch + HEAD). The manifest is the value over `cat` — it is what produced real findings rather than prose review. Works today with copy-paste; becomes the shared input for every later layer.

  **🔴 Layer 6 — the actual architectural contribution (Agent Egress Boundary):** `plan-feature-aapp-airgapped-pickup.md` has 5 leak layers (`pickup/.gitignore`, `.plans/.gitignore`, `.git/info/exclude`, pre-commit reject, pre-push scan) — **all five guard the git boundary**. A review packet is egress that never touches git: stdout → human → third-party model (or hook pipe → external model API). It bypasses every git guard. A naive context-bundling emitter would ship `.plans/pickup/hooks-transcript.md` (51 KB chat dump) and `image.png` (461 KB) to an external agent on first run.
  - **Strict Allowlist-only:** Emitter packages *only* the named plan (`.plans/current/<plan>.md`), its declared `### 📂 Target Files` (resolved to repo-relative canonical paths via `realpath`), declared test suites, and git HEAD hash.
  - **Hard Egress Denylist:** Code-level refusal to bundle anything matching `.plans/pickup/*`, credential patterns (`.env*`, `.git/config`, `*token*`, `*secret*`, `.ssh/*`), or uncommitted scratch files.
  - **Symlink Inode Guard:** Every candidate path is resolved via `realpath` before packaging to prevent symlink traversal out of the repo or into `.plans/pickup/`.
  - **Packet Size Ceiling:** Hard cap (e.g. 150 KB); aborts with exit code 2 if exceeded, preventing unbounded prompt dumping and context poisoning.
  - **The Asymmetric Prompt Anchor:** The auditor receives *only* the plan text and on-disk files — never the architect's scratchpad, conversation transcript, or internal thoughts. Exposing internal rationalizations introduces LLM confirmation bias and destroys auditing independence.

  **The Core vs. Plugin Hybrid Split:**
  - **Core AAPP owns (100% offline, zero-dependency, pure POSIX bash):** The deterministic packet emitter (`aapp review <plan>`), the Layer 6 Egress Allowlist validator, the Status Enum gate (`🟢` check), the `🔵 Peer-Reviewed` state machine transition, the mechanical Tier classifier (Self-Sealing check against Target Files), and the universal `/aapp-critique` skill. Core remains completely offline and vendor-neutral; it never handles API keys, vendor CLI flags, or network calls.
  - **Plugins / Lifecycle Hooks own (External Runner Orchestration):** Model invocation lives in `.plans/hooks/on-refine` (or an adopter plugin). Adopters can hook in `claude -p`, `gh copilot`, `ollama run`, or a corporate review endpoint. Hook handles vendor flags, timeouts, and streaming output back to the terminal. Core never shells out to a vendor CLI.

  **Hook contract amendments needed in `plan-feature-aapp-lifecycle-hooks.md`:**
  - (1) Replace the 10s notify watchdog in §E with a configurable execution timeout (auditing a 37 KB plan takes 1–4 min);
  - (2) Add `on-refine` to the hook event matrix (critique belongs between digest and freeze; `on-freeze` catches blockers at the most expensive moment);
  - (3) Clarify exit-1 rollback semantics so a failed audit does not wipe the draft plan under refinement.

  **Layering roadmap:** L1 `aapp review <plan>` (POSIX stdout, copy-paste) → L2 `.plans/hooks/on-refine` pipes L1 into adopter-configured agent CLI → L3 `/aapp-critique` skill reads the same packet in-session. One canonical packet emitter, three consumption modes.

  **Rejected:** `aapp peer-review --agent=claude` shelling out to a vendor CLI. Makes an API key load-bearing for a core verb; `set -e` at `aapp:8` means a peer-agent non-zero exit kills the dispatcher; and an unattended agent writing `.plans/reviews/` inherits unconditional write access to every blueprint via `blast-radius-guard.sh:110`. Findings belong in the plan's own §6 / §5, not a fifth pillar.

- [ ] **Consensus tiers for peer review (extends the Adversarial Peer Review blueprint)**: Insert agent-consensus states into the plan lifecycle, with routing by recoverability tier. Depends on ISSUE-064 above.

  **State machine — one new status, not two lanes.** Tier is a plan *attribute*, consensus is a *state*: `🔴 Under Review → 🟡 Refining ⇄ (aapp review → peer audit → findings into §6) → 🔵 Peer-Reviewed`.
  - From `🔵 Peer-Reviewed`, `Tier: L` auto-promotes to `🟢 Ready for Execution` and executes with an async notification to the human.
  - From `🔵 Peer-Reviewed`, `Tier: A` holds at `🔵` until a human explicitly runs `/aapp-freeze`.
  - `🟢` retains its exact current semantics across all tools (`plan-template.md:5`, `AGENTS.md`, and test suites take purely additive changes).

  **Tier classifier must be mechanical, never self-certified.** "No architectural impact" cannot be delegated to the agents being gated. Compute the tier as a pure function of the declared `### 📂 Target Files`.
  - **The Self-Sealing Failure Boundary:**
    - **Tier A (Self-Sealing Failure / Manual Gate):** Touches files executing during init, commit, or write-guard evaluation (`blast-radius-guard.sh`, `aapp-pre-commit`, `aapp`, `cmd_init.sh`, `.githooks/*`, plus any new file under `lib/` or `templates/`). A bug here bricks the engine that enforces correctness, and `.githooks/` is write-protected and regenerable only via `aapp init` — a broken `cmd_init.sh` seals its own exit. A 3-line guard fix is always Tier A.
    - **Tier L (Self-Healing Failure / Auto-Promote):** Touches docs, `tests/*`, `.plans/*`, read-only reporters (`cmd_status.sh`), standalone utilities. Failure is immediately visible and revertible in one git commit. A 400-line docs rewrite is Tier L.
  - **Single Source of Truth:** Reuse `blast-radius-guard.sh:94-118` Section 2/Section 3 path classes as the canonical classifier logic. `aapp review` refuses to emit a Tier-L consensus header if Target Files intersect any Tier-A path pattern.

  **Mandatory Artifact: §7 Peer Consensus Record:**
  Add `## 🤝 7. Peer Consensus Record` to `plan-template.md`:
  ```markdown
  ## 🤝 7. Peer Consensus Record
  - **Review Date:** YYYY-MM-DD
  - **Architect:** Agent ID & Model (e.g. `Antigravity (Gemini 2.0 Pro)`)
  - **Auditor:** Agent ID & Model (e.g. `Claude Code (Sonnet 3.5 / Opus)`)
  - **Review Packet Hash:** `sha256:<hash>` (emitted by `aapp review <plan>`)
  - **Classified Tier:** `Tier A (Manual Gate Required)` | `Tier L (Auto-Promote Eligible)`
  
  ### 🔍 Invariants Verified
  - [x] Invariant 1 (e.g. POSIX sh compatibility; zero external dependencies)
  - [x] Invariant 2 (e.g. Write-guard Section 2 self-protection preserved across symlinks)
  - [x] Invariant 3 (e.g. All regression test suites pass cleanly)
  
  ### ⚠️ Unverifiable Assumptions & Inherent Blind Spots (Sycophancy Defense)
  *Auditor must document what it checked and could NOT verify on-disk. Audits with 0 findings and 0 unverifiables fail validation.*
  - e.g. Windows NTFS junction symlink behavior without admin rights
  - e.g. Runtime memory consumption under extreme concurrency
  
  ### 📝 Findings & Waivers Table
  | # | Severity (🔴/🟡/🟢) | Component | Finding Summary | Resolution / Waiver Rationale |
  |---|---|---|---|---|
  | 1 | 🔴 Blocker | `sync_claude_settings()` | Adopter settings overwritten | Resolved in §6 (added non-destructive merge) |
  | 2 | 🟡 Warning | `ARG_MAX` on macOS | CLI argument overflow | Waived (covered by sys.stdin streaming in ISSUE-041) |
  ```

  **Sycophancy Mitigation & Disagreement Value:**
  - LLMs share training corpora and anchor onto proposed blueprints. An auditor protocol rewarding rapid "agreement" creates sycophancy where agents rubber-stamp drafts to unlock execution.
  - Verification requires adversarial tension: the auditor must explicitly document its *unverifiables*, and any waived findings must carry an explicit risk rationale. Findings resolved must cross-link to §6 refinement history.

  **Note:** these are lifecycle *states*, orthogonal to a plan's own implementation Phases 1/2/3. Do not conflate the axes.
