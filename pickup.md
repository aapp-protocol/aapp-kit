# 📥 Pickup & Brainstorming
*Dump your raw ideas, mobile notes, or late-night thoughts here. One entry per idea.*

> **This is a queue, not a batch.** Nothing here is acted on until you name it: `/digest <idea>` takes **one** entry and works it into a new blueprint or an amendment to an existing plan. Bare `/digest` lists what is waiting and asks which one you want. Only the entry actually digested is removed — the rest stay put.

## 🆕 New Ideas / Prompt Inputs
- [ ] Configuration Manager CLI (`aapp config`): Add manifest-backed `config.tsv` and `aapp config` command (`list`, `get`, `set`) with type validation to inspect and manage `git config aapp.*` repository settings.
- [ ] Work Dispatch Queue for Multi-Agent Execution (`aapp dispatch` / `aapp queue`): In multi-agent environments implementing multiple plans concurrently across isolated worktrees, a central work dispatch queue would coordinate which agent claims which plan. Currently, `state_matrix.md` defines the human priority sequence, but there is no automated worker claiming/leasing mechanism (`aapp next` / `aapp claim`) or queue tracker to allocate frozen, unblocked plans to idle agents without collisions or duplicate effort. Explore introducing a lightweight queue/workpool protocol.


