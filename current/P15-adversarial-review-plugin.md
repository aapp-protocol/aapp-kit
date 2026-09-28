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
* **F7 — Round termination: two independent conditions, and agreement is not one of them.** The
  round count is currently unspecified, and §2.7 already warns that agreement is weak evidence and
  that rewarding it creates pressure to agree. That rules agreement out as a terminator — if
  agreeing ends the loop, it becomes the cheapest exit. Two conditions that do not have that defect:
  * **Cost bound (always applies):** a configured maximum round count. Hitting it means
    *unresolved*, not *complete*.
  * **Early stop (may terminate sooner):** a round that produces no new findings. This extends
    §2.7's existing standard — an audit returning zero findings and zero unverifiables is a failed
    audit — from judging a single review to terminating a loop.

  Rationale from observed behaviour: in a two-round exchange on `P-33`, round 1 searched for the
  identifier `REPO_ROOT` and missed `cmd_test.sh:140`, where the variable is lowercase `repo_root`.
  The blue team's response surfaced it, which revealed the *search predicate* was wrong; round 2
  searched for the defect (`|| pwd`) instead and found seven further sites in `planning_health.sh`
  and `cmd_ai.sh`. The second round was productive because the first round's method was corrected —
  not because of adversarial pressure. This is a concrete instance of the shared-blind-spot risk
  §2.7 records: both agents anchored on the same identifier, and only an artifact exchange broke it.
  Round count therefore varies by problem — a dead-variable finding resolves in one round, a
  mis-predicated sweep needs two — which is what a fixed count cannot accommodate and an
  empty-round check can. Arithmetic to expect: the terminating round still costs a full round, since
  emptiness is only observable by running it.
* **F8 — Mechanical termination constrains the artifact format (bears on Question 2).** Deciding
  "no new findings" without trusting either agent's self-report means comparing findings across
  rounds mechanically — a new `(file, line, claim)` tuple, or the round counts as empty. That also
  closes the restatement loophole, where a reviewer keeps a loop alive by rephrasing prior findings.
  It requires findings to be **parseable**, not prose: these very findings (F1–F8) are readable but
  not diffable. Note the limit — a script can compare findings, but cannot detect that a reviewer
  *should* have looked somewhere it did not; that judgement stays with the reviewer. This is a mild
  argument for the separate per-plan artifact over inline notes, since a structured findings block
  is easier to keep machine-readable in its own file. Format itself is refinement-session work.
* **F9 — Review scope must allow several plans at once.** The packet and log are keyed to one plan
  ID (§2.5). A hand-run RFC across `P-34`/`P-35`/`P-37` (2026-09-27) found its most valuable results
  *between* plans: `P-35`'s declared test files losing write access under `P-37`'s parser, `P-35`'s
  new verb failing `P-34`'s contract check, and both plans editing `cmd_done`. No per-plan review
  could see these, and Pair 7 only compares Target Files once plans are ⚡ In Development. Packet and
  log naming need to accept a set of IDs (e.g. `34-35-37`).
* **F10 — Two reviewer modes: shared disk before packet.** In that RFC both agents worked on the same
  machine and appended to one file in `pickup/`. No packet was emitted, and the reviewer could run
  probes directly, which is §2.4's reviewer property. The L1 packet (§2.2) serves reviewers *without*
  repository access. The shared-disk mode is simpler and arguably comes first; the packet is the
  remote case.
* **F11 — `pickup/` collides with the egress boundary.** §2.3 denies `pickup/` in code. An RFC kept
  there cannot enter a packet. Either the review log lives outside `pickup/`, or the emitter
  allowlists that single named file. Decide with Question 2. The same RFC is evidence for Question 2:
  local raw log, decisions committed into each plan's §6 — F4's split, with no committed log needed
  for solo, single-machine use.
* **F12 — Observed: signed append-only blocks work; agents misattribute decisions.** Signed, dated,
  append-only blocks (agent/vendor/model) kept corrections beside the claims they answered. Twice in
  one session an agent recorded a user decision the user had not made. Separate `USER DECISION`
  blocks, taken from the user's own words, fixed this — a concrete instance of §2.7's "agreement is
  weak evidence". Replies already threaded by reference ("Re A3"); a per-item shape
  `(id, file:line, claim, status: open|agreed|refuted|user-decided)` would make F7's empty-round
  check mechanical (F8).
* **F13 — Each agent's chat is a context channel the others cannot see.** In the P-43/P-44 RFC
  (2026-09-28) the user worked with two agents in separate chat windows. What the user said in one
  chat — decisions, directions and the reasoning behind them — reached only that agent, which then
  acted on context the other lacked. The user's stated reason for writing decisions into the RFC: "I
  do not wish to repeat myself in both chat windows, also giving one agent more context than the
  other you act on that." A review artifact is therefore also the **context-parity channel**: every
  agent must copy what the user said in its chat into the shared artifact, in the user's words, so
  no agent audits from a private premise. This bears on §2.2 and F10: a packet or shared file
  carries on-disk ground truth, but user statements made in chat are ground truth too, and today
  they exist only in one agent's session.
* **F14 — Agents are invited to argue against the user's proposals.** Same RFC, user's words: "each
  of you can come up with counter arguments against my proposals as it is the only way to get the
  best of it." §2.7 warns that agreement between agents is weak evidence; the same holds for
  agreement with the user. A review contract that records user decisions (F12) should also require
  counter-arguments against user directions where there is reason for them, each with its reason and
  an alternative, and leave the final call to the user. In practice this surfaced two objections to
  the user's own direction (the P-43/P-44 RFC, C36–C37) and one against the reviewer's own proposal
  (C35).
* **F15 — Where to draw the line: a phased sequence with a stop at every hand-off (starting point,
  not settled).** Observed in the P-43/P-44 RFC: after the user settled it, one reviewer re-checked the
  finalized plans and the #91 fix and raised six new findings (C69–C74); the other side accepted all
  six in one block (A27–A32) without stating what it checked. The late work was valuable (C69 would
  have erased AI audit notes on amend) but it reopened a settled review, widened its scope to new
  code, and was never independently verified — so an empty-round stop (F7) could not occur, and one
  side's extra work went unseen by the other. The user's framing: "if not settled can't be frozen, if
  settled the other one won't come back for a check unless instructed", and their proposed sequence:
  agree on the RFC, write the plans, the reviewer reads the plans and analyses the affected code,
  comes back with refinements, these are double-checked by the blue team and picked up in the plan,
  the plan is frozen and implemented; the red team rests or is given an implementation review. The
  user's own caveat: "Not one is perfect but we need a good starting point."

  | # | Step | Who | Stops because |
  |---|---|---|---|
  | 1 | Agree the RFC | both + user | the user settles it |
  | 2 | Write the plans | blue (author) | the plans are committed |
  | 3 | Read the plans, analyse the affected code, return refinements | red | **one pass** over a pinned scope: Target Files and their direct callers |
  | 4 | Check the refinements, fold them into the plan | blue | each accepted or refuted **with evidence**; disputes go to the user, not into another round |
  | 5 | Freeze, then implement | user, then blue | the freeze gate is the hard stop for design |
  | 6 | Rest, or review the implementation | red | see rows 6a–6c |

  Additional rows, with the reasoning behind each:

  | # | Rule | Why |
  |---|---|---|
  | 3a | Red states what it checked **and could not verify** | §2.7: a zero-findings, zero-unverifiables audit is a failed audit. It also tells blue exactly which ground was covered, so step 4 need not guess. |
  | 3b | The scope is pinned to the plans' and code's commit SHAs at the start of step 3 | A moving target produces new findings by construction. In the RFC the plans changed three times mid-review (`0bd32e2`, `0c4e3d9`, `5685ef5`); each change started a new review in effect. |
  | 3c | Findings outside the pinned scope go to the issues lane, not into the review | A codebase always holds one more true finding; admitting them keeps any round from being empty (F7). They are not lost — they are routed. |
  | 4a | Blue answers each refinement separately, citing what it checked | Blanket agreement (A27–A32) accepts findings nobody verified; agreement is weak evidence (§2.7). Per-item evidence makes red's work *seen* by blue. |
  | 4b | A dispute goes to the user once; it does not start another red/blue round | Ping-pong is the loop without a stop. The user is the tie-break, as in the RFC's §4. |
  | 4c | Between 4 and 5, red may **propose** missing failure tests; blue owns them | F2: reviewer proposes, author owns (P-35's `aapp tdd`). "How could this break" belongs in declared tests, not in more review rounds. |
  | 5a | After freeze, a design flaw means unfreezing — a deliberate user step | The existing design lock (plan back to `📝 Refining`). Nothing reopens design automatically. |
  | 6a | Trigger for an implementation review is the tier (§2.7), not a fixed "always" or "never" | Tier A (init, hooks, guard — failure is self-sealing) gets one; Tier L (docs, ordinary verbs) does not; red rests. Mechanical from Target Files, never self-certified. |
  | 6b | Implementation-review scope is the commits recorded in the plan header (P-39), checked against the frozen plan and its declared failure tests (P-35) | The scope pins itself: no search for "what changed", no drift into unrelated code. |
  | 6c | Implementation findings: bug → issues lane or fix before `done`; design flaw → unfreeze (5a) | The implementation review ends with the plan. A new cycle starts only with the next plan. |
  | 7 | Post-settlement conformance check (each §4 decision present in the plan or not) is allowed on either side | A bounded checklist, the same for both sides, so it is symmetric by construction. It adds no new findings; a serious late finding is routed by the user (one more round, or the issues lane). |

  Known weakness: rows 3–4 rely on honest severity and scope judgements by each agent; an agent can
  still inflate a finding to justify another round. Row 4a (per-item verification by the other side)
  limits this but does not remove it.
* **F16 — Tier boundaries belong to the adopter's project, declared in `.agents/PROJECT.MD` (user
  direction; corrects F15 row 6a).** The kit serves many repositories, so the review tier cannot be
  keyed to this repository's own paths. Both agents made that mistake: Antigravity's first
  suggestions were relative to this kit's files, and F15 row 6a names "init, hooks, guard". The user
  directed Antigravity (by prompt, in its chat) to place critical boundaries in `PROJECT.MD`, because
  the kit is "for many" projects. Antigravity's elaboration: each adopter declares its irreversible or
  non-self-healing areas (e.g. `src/auth/**`, `src/billing/**`, `db/migrations/**`) in a "Critical
  Boundaries" section; a plan whose Target Files intersect that list is Tier A, otherwise Tier L —
  mechanical, visible to humans and agents, and domain-agnostic. Counter-arguments and limits (Claude):
  * **Self-certification reopens.** `.agents/*` is always writable (`templates/blast-radius-guard.sh`
    §3, lines 306-309; only kit skills and settings are self-protected). An authoring agent could
    delete a boundary in the same session and turn its own plan into Tier L, against §2.7's "never
    self-certified". Options: classify against `PROJECT.MD` as of the plan's `Base` commit, not the
    working copy; and/or treat any change to the boundary section itself as Tier A.
  * **Two sources, not one.** The kit's own machinery in an adopter repo (`.githooks/*`,
    `.agents/skills/aapp-*`, `.claude/settings*`) is universal; §2.7 already classifies it through the
    guard's Section 2/3 path classes. Tier A = those classes ∪ the adopter's declared boundaries.
    Replacing one with the other would drop the universal part. For this kit's own repository, its
    `PROJECT.MD` would list `lib/cmd_init.sh`, `templates/aapp-*`, `templates/blast-radius-guard.sh` —
    which is where F15 row 6a's examples belong.
  * **No new parser.** Parser sprawl is already logged (#85, #86). The boundary list should use the
    Target Files form (one backticked path per line) and P-37's shared parser.
  * **Name.** The file is `PROJECT.MD` (upper case); `PROJECT.md` is a different file on
    case-sensitive filesystems.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Sketched from two `pickup.md` entries (adversarial peer review + Layer 6; consensus tiers), both now digested and pruned. Captures settled ground only — rejected approaches with reasons, the L1/L2/L3 layering, the Layer 6 egress boundary, the verification-manifest insight, the provenance model, signing limits, the consensus-tier design and its `#64` blocker, and the three `P-12` substrate mismatches. Logic, task breakdown and Blast Radius are deliberately deferred to a dedicated refinement session by human decision.
* **2026-09-23:** Added six findings to §5 (F1–F6) from a session on plan-declared failure tests. No
  design, no task breakdown, no Target Files — the sketch banner holds. F1–F3 bear on §2.4 and
  Question 1; F4 reframes Question 2 around asynchronous multi-machine execution rather than size;
  F5 records that `cmd_done` moves only the plan file, so §2.5's archival-survival requirement needs
  code; F6 corrects the `pickup/` figure cited in Question 2 (12 KB, not 516 KB).
* **2026-09-23:** Added F7–F8 to §5 from an observed two-round exchange on `P-33`. F7 proposes round
  termination by cost bound plus empty-round early stop, with agreement explicitly excluded per §2.7,
  and records the predicate-correction mechanism that made round 2 productive. F8 notes that
  mechanical termination requires parseable findings, bearing on Question 2's artifact shape. Still
  findings only — no design, no task breakdown, no Target Files.
* **2026-09-27:** Added F9–F12 from a hand-run cross-plan RFC on `P-34`/`P-35`/`P-37`: reviews across
  several plans, shared-disk mode before the packet, the `pickup/` egress collision, and signed blocks
  with separate user-decision records. Findings only.
* **2026-09-28:** Added F13–F14 from the P-43/P-44 RFC: each agent's chat is a separate context channel,
  so the review artifact must carry the user's own chat statements; and agents are invited to argue
  against the user's proposals. Findings only.
* **2026-09-28:** Added F15 from the same RFC: a phased red/blue sequence with a stop at every
  hand-off (RFC → plans → one-pass red review → evidenced blue check → freeze → tiered implementation
  review), with the reasoning per rule. Recorded as the user's starting point, not settled design.
* **2026-09-28:** Added F16: review-tier boundaries declared by the adopter in `.agents/PROJECT.MD`
  (user direction, elaborated by Antigravity), with limits — self-certification via the always-writable
  `.agents/`, universal kit paths kept, shared parser, file name. Corrects F15 row 6a. Findings only.
