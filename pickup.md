# 📥 Pickup & Brainstorming
*Dump your raw ideas, mobile notes, or late-night thoughts here. One entry per idea.*

> **This is a queue, not a batch.** Nothing here is acted on until you name it: `/digest <idea>` takes **one** entry and works it into a new blueprint or an amendment to an existing plan. Bare `/digest` lists what is waiting and asks which one you want. Only the entry actually digested is removed — the rest stay put.

## 🆕 New Ideas / Prompt Inputs
- [ ] Configuration Manager CLI (`aapp config`): Add manifest-backed `config.tsv` and `aapp config` command (`list`, `get`, `set`) with type validation to inspect and manage `git config aapp.*` repository settings.
- [ ] Attribution enforcement reaches mechanical worktree commits: `.plans/.githooks -> ../.githooks` makes `aapp-commit-msg` run on commits in the `.plans` worktree, so in `commit` attribution mode it rejects the plain messages that lifecycle verbs generate themselves (`plan(freeze):`, `plan(start):`, `plan(done):` in `lib/cmd_plan.sh`). Those are mechanical state transitions with no AI authorship to attribute. Observed 2026-09-23: `aapp freeze P-33` and `aapp start P-33` both printed success while their internal commit was rejected, leaving the Status edit and `state_matrix.md` staged but uncommitted — the `|| true` on the commit hides the rejection, so the verb reports a restore point that does not exist. The verbs themselves are correct; the question is where the attribution boundary should stop. Consider scoping the check by worktree or by commit-subject prefix rather than adding trailers to mechanically generated messages.


