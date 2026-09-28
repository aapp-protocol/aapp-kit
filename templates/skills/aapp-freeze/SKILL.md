---
name: aapp-freeze
description: Lock and greenlight a blueprint for code execution. Verifies open questions, marks blast radius locked, and moves plan to Greenlight Zone.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP Freeze (Greenlight & Blast Radius Lock)

Lock and greenlight an incubator blueprint for code execution via the authoritative CLI engine. Freezing transitions a plan from design into the approved backlog.

## Execution Procedure

### Step 1: Execute Authoritative CLI Verb
Invoke the deterministic freeze verb:
```bash
aapp freeze [target]
```
*(If `<target>` is omitted, `aapp freeze` prompts or selects candidate incubator plans).*

### Step 2: Deterministic Failure Branch (Fail Closed)
If `aapp freeze` exits non-zero, **STOP immediately**.
**Do NOT attempt manual header editing, state matrix table surgery, or raw git commits on the plans worktree.**

Parse and explain the exact CLI diagnostic:
- **Unresolved Open Questions**: If `## ❓ 5. Open Questions` contains unresolved (`- [ ]`) questions, review and resolve them with the user before freezing.
- **TDD Discrepancy**: If §3 failure assertions and §4 test files do not match bidirectionally, synchronize them before freezing.
- **Non-Incubator Status**: A plan must be in `🟣 Under Review` or `📝 Refining` to be frozen.
- **Invalid Blast Radius**: Ensure `### 📂 Target Files` conforms to the protocol syntax.

### Step 3: Success Confirmation
On exit 0, `aapp freeze` has locked the blast radius and technical blueprint, updated the plan header status to `🔷 Frozen`, and transitioned the plan into the Greenlight Zone in `state_matrix.md`.

Confirm the freeze with the user and offer:
- Begin implementation immediately via `aapp start [target]`.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
