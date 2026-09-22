# 🗺️ Plan: P-15 Adversarial Review Packet, Agent Egress Boundary & Review Plugin
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-16
* **Target Issue / Milestone:** Cross-agent review workflow (Layer 6 + reference plugin)
* **Plan ID:** P-15
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED -->

> ### ✏️ THIS IS A SKETCH — NOT READY FOR REFINEMENT OR EXECUTION
> It exists to capture decisions already settled so they are not re-derived or re-argued later. The
> **logic is deliberately unspecified** — no algorithms, no file-level design, no task breakdown.
> That work is deferred to a dedicated session, by explicit human decision, so it can be done with
> full attention rather than alongside other work.
>
> **Do not refine this plan, and do not begin implementation, until the human opens it.**
> An agent encountering this file should read §2 for settled ground and §5 for what is still open,
> then stop. Contributions of new *findings* to §5 are welcome; new *design* is not.
>
> **The Blast Radius in §4 is intentionally empty.** Per `#64` a plan in `.plans/current/` grants
> write access to every file it declares, regardless of status. A sketch must therefore declare
> nothing. §4 is filled in at refinement time, not before.

---

## 1. Context & Architectural Goal

**What.** Formalise the two-agent review workflow already in use: one agent drafts a blueprint, a
differently-trained agent audits it against shared on-disk ground truth, and findings return to the
plan. Deliver it as (a) a zero-dependency review-packet emitter, (b) a declared agent-egress boundary,
and (c) one reference plugin — not a maintained plugin ecosystem.

**Why.** The workflow is proven, not speculative. `P-9`, `P-13`, `P-14` and the flat-issues blueprint
each carry adversarial review in their §6 histories, and the findings were substantive: hard-blocked
Target Files, a configuration-erasure path, a silent data-loss path in git notes. It currently runs
entirely on manual copy-paste and human relay.

**Scope boundary.** The kit ships the contract plus one reference implementation. Plugins are
project-based and live in adopters' repositories. The kit does not maintain a plugin ecosystem.

---

## 2. Settled Ground (Do Not Re-Derive)

### 2.1 Rejected Approaches
| Rejected | Reason |
| :--- | :--- |
| `aapp peer-review --agent=<x>` invoking a vendor CLI | Makes an API key load-bearing in a zero-dependency kit; `set -e` at `aapp:8` means a peer's non-zero exit kills the dispatcher; and `.plans/*` is unconditionally always-allowed in the guard, so an unattended agent inherits write access to every blueprint |
| A 6th lifecycle skill alongside `status`/`digest`/`freeze`/`done`/`release` | Those five are lifecycle *verbs* that advance a plan through states. Critique is a quality *gate*. Whether it becomes a standalone skill or the missing Step 0 of `/aapp-freeze` is still open (§5) |
| A `.plans/reviews/` directory as the record of outcomes | Creates a fifth artifact class. Review *outcomes* already belong in each plan's §6; only the raw *log* is a new artifact |
| `AI-Reviewed-By:` as a commit trailer | Reviews happen against plans, not commits. The commit does not exist when the review runs |
| A `Reviewed By` column in `000-archive-ledger.md` | Provenance already lives in the plan lane; no new column is needed |

### 2.2 The Layering — One Artifact, Three Consumers
```text
L1   packet emitter    → stdout                    build first; works today with copy-paste
L2   lifecycle hook    → pipes L1 into any agent   after P-12 ships
L3   in-session skill  → reads the same packet     after the skills lane settles
```
L2 and L3 are thin wrappers over L1. This is one design, not three.

### 2.3 Layer 6 — The Agent Egress Boundary
`P-11`'s five leak layers (`pickup/.gitignore`, `.plans/.gitignore`, `.git/info/exclude`, pre-commit
reject, pre-push scan) all guard the **git** boundary. A review packet is egress that never touches
git: stdout → human → third-party model. It passes all five untouched.

The emitter must therefore be **allowlist-only** — explicitly enumerated files, `pickup/` denied in
code, never a `.plans/` glob. A naive context-bundling emitter would ship `pickup/hooks-transcript.md`
(51 KB) and `image.png` (461 KB) to an external model on first run. **This boundary, not the review
automation, is the plan's primary architectural contribution.**

### 2.4 What Separates a Reviewer From a Proofreader
Every substantive finding this workflow has produced came from **running probes against the live
repository** — executing the guard, grepping the engines, counting occurrences — not from reading the
plan text. The packet must therefore carry:
1. An adversarial preamble with the 🔴 blocker / 🟡 gap / 🟢 verified taxonomy.
2. The plan verbatim.
3. A **verification manifest** naming what findings must be checked against: the test suites, the
   guard's Section 2/3 precedence, current branch and HEAD.

A plugin that forwards plan text produces a proofreader. One that hands over the manifest and the
ability to execute produces a reviewer.

### 2.5 Provenance Model
* **§6 of each plan is the decision. The review log is the evidence.** Both are kept: §6 records what
  changed, the log records what was argued and rejected.
* Two properties or it fails at distance: the log must be **findable from the plan** (plan ID in the
  filename) and must **survive archival** into `done/`.
* **The plugin populates records; it does not own them.** Hand-run reviews must remain valid, or the
  feature does not exist for anyone who never installs the plugin.
* The plugin's unique contribution is **fidelity**: exact agent and model, packet version, and
  findings counted by severity. *Which agent reviews well* is not answerable from a name — only from
  findings data.

### 2.6 Signing
Relevant to consensus (§2.7), not to credit. Once agreement authorises anything, the review record
becomes an authorisation token, and unsigned tokens are forgeable.
* **Honest limit, to be documented and never oversold:** a signature authenticates the human and
  machine that *recorded* a review, not the agent that produced it. No vendor PKI exists.
* Two layers: sign the commit (who recorded) and hash the review artifact (what was not edited after).
* Must stay opt-in — the test suites disable signing in three places.

### 2.7 Consensus Tiers — Design Recorded, Blocked on `#64`
* One new status **🔵 Peer-Reviewed**. Tier is a plan *attribute*; consensus is a *state*.
* **The tier boundary is not size or "architectural impact" — it is whether failure is self-sealing.**
  Tier A covers anything executing during init, commit, or guard evaluation, because a bad change
  bricks the machine that would fix it. A three-line guard edit is Tier A; a 400-line docs rewrite is
  Tier L.
* The classifier must be mechanical from declared Target Files, never self-certified, reusing the
  guard's own Section 2/3 path classes as the single source of truth.
* Consensus needs an artifact or it is not a state: agents, packet version, findings raised, resolved,
  and **waived with reasons**. The waived list is where the next incident becomes traceable.
* **Agreement is weak evidence.** Shared training data means shared blind spots; the auditor is
  anchored by reading the proposal; and rewarding agreement creates pressure to agree once it unlocks
  anything. Required mitigation: the auditor must state what it checked **and could not verify** — an
  audit returning zero findings and zero unverifiables is a failed audit.
* **Blocked:** tiers modulate a gate that does not exist. `#64` must land first.

### 2.8 Substrate Fixes Owned by `P-12`, Not This Plan
1. The 10-second hook watchdog assumes fire-and-forget notifications; an audit of a 37 KB plan runs
   1–5 minutes.
2. The six-event matrix has no `on-refine`. Critique belongs between digest and freeze; `on-freeze`
   surfaces blockers at the most expensive moment.
3. Exit-1 "rolling back uncommitted changes" is underspecified against a plan file mid-refinement.

---

## 🔨 3. Implementation Steps & Execution Checklist

*(Deliberately empty — see the sketch banner. No task breakdown exists until this plan is opened for
refinement.)*

### Prerequisites Before Refinement May Begin
- [ ] `#64` resolved — the status enum is enforced, so consensus tiers have a real gate to modulate.
- [ ] `#57` resolved — Out of Bounds is honoured across concurrent plans.
- [ ] `#56` resolved — glob matching no longer crosses `/`, so tier classification over Target Files is sound.
- [ ] `P-12` amended for the three mismatches in §2.8, or explicitly descoped from L2.
- [ ] Human opens this plan for a dedicated refinement session.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
*(Intentionally empty. A sketch declares no targets: per `#64`, any file listed here would immediately
become writable by an agent, and this plan is not ready for execution. Populate at refinement.)*

### 🛑 Out of Bounds (Do Not Touch)
*(Intentionally empty. Declaring out-of-bounds paths here could interfere with the execution of other
active blueprints. Populate at refinement.)*

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 — Placement.** Standalone `/aapp-critique` skill, or the missing Step 0 of `/aapp-freeze`? A critique pass is precisely what should gate the greenlight lock.
* [ ] **Question 2 — Review-log retention.** Keep logs whole, compress to a §6 summary at archive time, or gitignore the raw output and commit only the summary? `.plans/` is already 832 KB with 516 KB of it in `pickup/`; logs are the same shape — written once, read rarely, never smaller. Decide before the first log exists.
* [ ] **Question 3 — Packet verb naming.** `aapp review <plan>` reads as though it performs a review rather than emitting a packet for one.
* [ ] **Question 4 — Findings taxonomy stability.** Are 🔴/🟡/🟢 fixed by the contract, or adopter-configurable? Fixing them makes findings comparable across agents; configuring them fits the project-based plugin model.

### Findings Contributed Since Sketching
*(Findings only, per the banner. No design, no task breakdown, no Target Files.)*

* **F1 — A plan-declared failure-test section would be a manifest input (bears on §2.4).** A separate
  line of work proposes `aapp harden <id>`: an opt-in, injected `### 🧪 Required Tests` section in
  which a plan enumerates its failure cases as named test identifiers (`path::name -> asserts …`),
  language-agnostic by construction. Where it exists, it gives a reviewer something *executable* to
  check rather than prose to read, which is the proofreader/reviewer distinction §2.4 already draws.
  Candidate addition to the verification manifest alongside the test suites and guard precedence.
* **F2 — Ownership of that section resolves to the author (consistent with §2.5).** A reviewer must
  **propose** missing failure cases as findings; it must not append to the plan's declared tests
  directly. Three reasons, all already in this plan: §2.5 says the plugin populates records but does
  not own them; §2.3 makes the packet a one-way egress boundary, which a write path back into an
  enforced section would invert; and §2.1 rejected unattended agent write access to `.plans/*` for
  the same reason. A proposed-but-declined case belongs in the waived list of §2.7, where it is
  traceable if the incident later happens. Operational note: pre-commit would verify declared test
  files exist, so a reviewer appending un-written tests would block the *author's* next commit.
* **F3 — That section creates a third candidate position, bearing on Question 1.** Question 1 offers
  standalone `/aapp-critique` or Step 0 of `/aapp-freeze`. If failure-case enumeration becomes a
  distinct step, the sequence `draft → harden → critique → freeze` places critique *after* the plan
  has declared its failure modes. Auditing an enumeration is a different task from deriving one, so
  this is an input to Question 1, not an answer to it.
* **F4 — The retention argument for Question 2 is distribution, not size.** Question 2 is framed as a
  size problem. The stronger consideration is that **this kit is asynchronous: a plan may be drafted
  on one machine and implemented on another, by a different agent in a different session.** Review
  deliberation is planning-machine evidence; the implementation machine needs the *decision*, not the
  argument that produced it. A separate per-plan review artifact keeps the plan the same size for the
  implementer no matter how many review rounds occurred, and lets the round count stay undecided
  rather than becoming a structural property of the plan file. Inline notes make N rounds visible to
  every downstream reader; a sibling artifact does not. This also means the artifact must be
  **committed**, not local — `pickup/` cannot host it, since `.plans/.gitignore` excludes `pickup/*`
  entirely and it would never reach the implementing machine.
* **F5 — "Survives archival" is not free in the current code.** §2.5 requires the log to survive
  archival into `done/`. `cmd_done` (`lib/cmd_plan.sh`) moves exactly one file and stages exactly that
  basename, under `|| true`. A companion review artifact would be silently left behind in `current/`
  on archive. Whatever shape Question 2 settles on, `cmd_done` must learn about companion files.
* **F6 — Correction to a figure cited in Question 2.** Question 2 cites `pickup/` at 516 KB of an
  832 KB `.plans/`. As of 2026-09-23 `pickup/` measures 12 KB; it has been pruned since sketching.
  The size half of the retention argument is materially weaker than recorded.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Sketched from two `pickup.md` entries (adversarial peer review + Layer 6; consensus tiers), both now digested and pruned. Captures settled ground only — rejected approaches with reasons, the L1/L2/L3 layering, the Layer 6 egress boundary, the verification-manifest insight, the provenance model, signing limits, the consensus-tier design and its `#64` blocker, and the three `P-12` substrate mismatches. Logic, task breakdown and Blast Radius are deliberately deferred to a dedicated refinement session by human decision.
* **2026-09-23:** Added six findings to §5 (F1–F6) from a session on plan-declared failure tests. No
  design, no task breakdown, no Target Files — the sketch banner holds. F1–F3 bear on §2.4 and
  Question 1; F4 reframes Question 2 around asynchronous multi-machine execution rather than size;
  F5 records that `cmd_done` moves only the plan file, so §2.5's archival-survival requirement needs
  code; F6 corrects the `pickup/` figure cited in Question 2 (12 KB, not 516 KB).
