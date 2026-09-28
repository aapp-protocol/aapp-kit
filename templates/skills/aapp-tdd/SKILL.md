---
name: aapp-tdd
description: Declare a plan's failure-first tests (§3 identifiers, §4 test files) before freeze.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP TDD (Opt-In Failure Test Declaration)

Declare and enumerate failure-first tests for an incubator blueprint before freeze.

## Execution Procedure

### Step 1: CLI Injection & Smart Scaffolding
1. Run the deterministic CLI verb:
   ```bash
   aapp tdd <target>
   ```
   - **New Feature/Slug:** If `<target>` is a new slug (e.g. `aapp tdd user-auth`), `aapp tdd` automatically scaffolds the new blueprint from the template and injects the failure test sections in a single atomic pass.
   - **Existing Plan:** If `<target>` matches an existing incubator plan (e.g. `P-42`, `42`, or slug), `aapp tdd` upgrades the blueprint by injecting the TDD failure sections.
   - **Unknown Plan ID:** If `<target>` is an unallocated Plan ID (e.g. `P-999`), `aapp tdd` fails closed.
2. **Failure Branch:** If the CLI exits non-zero (refusal or error), stop and report the refusal diagnostic to the user. Do NOT attempt to hand-edit the plan or bypass the CLI.

### Step 2: Enumerate Failure Cases & Propose Assertions
1. Inspect the target blueprint (`.plans/current/<plan>.md`), specifically `## 1. Context & Architectural Goal` and `## 2. Technical Blueprint`.
2. Infer the edge cases, boundary conditions, and refusal behaviors the design implies.
3. Propose failure test cases adhering to the project's own testing idiom:
   - Identify target test files (e.g. `tests/verbs/<verb>.sh`, `tests/test_<module>.py`, `src/test/...`).
   - Format test assertions: `- [ ] \`path/to/test::test_name\` -> asserts <failure condition>`.
4. Populate the injected sections:
   - In `### 🧪 Required Tests (Failure & Boundary Assertions)` under §3: list the unticked `- [ ]` test assertions.
   - In `### 🧪 Required Test Files` under §4: list the corresponding unique file paths (one backticked path per line).
   - Ensure bidirectional correspondence: every §3 test file prefix must appear in §4, and every §4 file must be referenced by at least one §3 test.

### Step 3: Record and Report
1. Commit the enumerated failure tests to the `plans` worktree:
   ```bash
   git -C .plans add "current/<plan>.md"
   git -C .plans commit -m "plan(refine): enumerate failure tests for <plan_id>"
   ```
2. Report the declared test assertions and files to the user, reminding them that Phase 1 of execution will write these tests and confirm them failing (Red 🔴) before implementation begins.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
