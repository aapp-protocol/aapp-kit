# 📥 Pickup & Brainstorming
*Dump your raw ideas, mobile notes, or late-night thoughts here. One entry per idea.*

> **This is a queue, not a batch.** Nothing here is acted on until you name it: `/digest <idea>` takes **one** entry and works it into a new blueprint or an amendment to an existing plan. Bare `/digest` lists what is waiting and asks which one you want. Only the entry actually digested is removed — the rest stay put.

## 🆕 New Ideas / Prompt Inputs
- [ ] Configuration Manager CLI (`aapp config`): Add manifest-backed `config.tsv` and `aapp config` command (`list`, `get`, `set`) with type validation to inspect and manage `git config aapp.*` repository settings.
- [ ] Work Dispatch Queue for Multi-Agent Execution (`aapp dispatch` / `aapp queue`): In multi-agent environments implementing multiple plans concurrently across isolated worktrees, a central work dispatch queue would coordinate which agent claims which plan. Currently, `state_matrix.md` defines the human priority sequence, but there is no automated worker claiming/leasing mechanism (`aapp next` / `aapp claim`) or queue tracker to allocate frozen, unblocked plans to idle agents without collisions or duplicate effort. Explore introducing a lightweight queue/workpool protocol. Also covers integration: merge finished plans into `develop` one at a time, keeping both sides of `CHANGELOG.md` conflicts, stopping only on real code conflicts (from the P-48 rework).
- [ ] Autonomous Blast-Radius Lease Negotiation & Quarantined Handoff: When an autonomous or unattended agent hits an out-of-bounds file collision caused by an intentional clean break (e.g. legacy test suites breaking on new fail-closed invariants), unattended execution cannot prompt a human. Explore a structured negotiation protocol: (1) requesting a signed out-of-band blast-radius lease expansion from an evaluator/orchestrator, or (2) executing a Quarantined Partial Handoff (committing in-bounds changes proven green under unit isolation, reverting the out-of-bounds collateral file, and emitting an automated regression handoff ticket). Long-range capability for autonomous agent fleets.
- [ ] Reserved ID Blocks: provider plugin pre-reserves plan/issue IDs so allocation works while it is unreachable. Design: P-32 Q5.
- [ ] Plan rename & link repair (`aapp rename <id> <slug>`): renames an active plan and rewrites its link in ISSUES.md "Target Plan / Fix" cells and the road map (only the link path; issue text stays). `aapp done` repairs the same links when it moves a plan to `done/`, which breaks them today.


