---
title: Group Amendments Reference
description: How a member of a plan group asks for a file or a correction outside its own plan, who approves it, and how the change is made and recorded.
---

# 🧩 Group Amendments Reference

A plan group (`aapp draft <slug> group`) splits one feature into member plans. Once a member starts, its plan is never amended: its Target Files are locked. Development still finds things the planning missed: a test outside the member that asserts the behaviour it changes, a file of a member already archived, a wrong sentence in the group's shared decisions.

The group's **amendments member** is where those needs go. It is a plan drafted together with the group, started by the group's `start`, and archived last. It holds no code of its own; it is the group's ordered record of what its planning missed.

---

## 1. Roles

| Role | Who | Does |
| :--- | :--- | :--- |
| **Requester** | A member in development, from its own worktree | Asks for a file or a correction (`request`) |
| **Approver** | A person or a managing agent, from any checkout | Approves or refuses (`approve`, `refuse`) |
| **Owner** | The plan the change belongs to: the requester itself (default), another member (in `current/` or archived), or the group plan | Records the landed file in its §4 |
| **Amendments member** | The group's `*-amendments.md` plan | Holds the request lines (`## Scope Requests`) and the corrections of the group's text (`## Decisions`) |

---

## 2. A file request, step by step

1. **Request** (requester's worktree):
   ```bash
   aapp refine <amend-id> request "<summary>" file <path> [for <plan-id>]
   ```
   Adds `R<n>` as `pending`. `for` names the owner when the file belongs to another plan of the group; without it the requester owns it. Until R<n> is approved, do not touch the file: continue with your own Target Files, or stop.
2. **Approve or refuse** (any checkout):
   ```bash
   aapp refine <amend-id> approve <n>
   aapp refine <amend-id> refuse <n> "<reason>"
   ```
   `approve` is refused when another plan in development lists the file, or another approved request not yet committed holds it. Approval adds the file to no plan; it lets the requester write that one file until its commit.
3. **Make the change in one commit** (requester's worktree, holding that file only):
   ```bash
   aapp commit "<msg>" amendment <n>
   ```
   The commit carries `Amendment: R<n>` and is not listed in the requester's `Commits`.
   - **The requester owns it:** the commit stays on the requester's branch; R<n> becomes `committed`, and the requester's `done` records it.
   - **Another plan owns it:** the change lands at once on the requester's parent branch (the feature branch). The owner gains the file in its Target Files and a line under `### Amendments` at the end of its §4, with the landed hash. The requester's branch is rebased; the other members in development are named with the rebase command they need.
4. **Close** (requester's `done`): every request of the member is closed in its archive commit.

A later change to the same file is a new request.

---

## 3. A correction of the group's text

The group plan's `## Architecture & Codemap` and shared decisions are every member's guide. To correct them:

1. The member asks: `aapp refine <amend-id> request "<summary>" heading "<heading>"`.
2. The approver approves it (`approve <n>`).
3. From the amendments member's own worktree, the corrected section is written into the group plan, then:
   ```bash
   aapp refine <amend-id> decision <n> "<reason>"
   ```
   One plans commit holds the group plan and a `D<k>` line under `## Decisions`; R<n> becomes `applied`. A change outside the named section is refused.

Members re-read the group plan at start and at every session start or resume.

---

## 4. Request states

| State | Meaning |
| :--- | :--- |
| `pending` | Waiting for the approver |
| `approved (<approver>)` / `approved (auto)` | The requester may write the file until its amendment commit |
| `refused: <reason>` | Not granted |
| `committed` | The requester's own file, committed on its branch |
| `landed <sha>` | Landed for another owner on the feature branch |
| `applied` | A heading correction written into the group plan |
| `closed · landed <sha>` | Closed by the requester's `done`, with its commit |
| `closed · unused` | Approved, never committed |
| `closed · withdrawn` | Still pending at `done`, or the requester was aborted (`aapp plan abort`) |

States move by verbs only; never edit the request lines by hand.

---

## 5. Seeing requests

- `aapp status`: under the group, `<k> request(s) wait for approval` and the members that must rebase; waiting approvals come first in Next Action. JSON: `requests`, `must_rebase` ([08. JSON Output Schemas](08-output-json.md)).
- `aapp plan-status <amend-id>`: every `R<n>` with its state, and the `Decisions`.

---

## 6. Settings and rules

- `aapp.amendmentApprovalRequired` (`true` by default): with `false`, a file request is `approved (auto)` when made, and a heading correction is recorded with `decision "<heading>" "<reason>"`.
- The amendments member is archived last: its `done` is refused while another member is in `current/`, or while a request is `pending`, `approved` or `committed`.
- The write guard and the pre-commit hook enforce the approval: before it, the file is outside the requester's plan; after the amendment commit, it is again.

**Settings on this page:** [Groups & Amendments](03-configuration-matrix.md#groups--amendments)

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Planning a Plan Group](../recipes/workflows/planning-a-plan-group.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
