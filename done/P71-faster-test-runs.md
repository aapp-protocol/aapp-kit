# 🧩 Group Plan P-71: Faster Test Runs
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Plan ID:** P-71
* **Changelog:** Changed: `aapp test` runs suites in parallel and splits the slowest verb suites; a full run takes about a minute instead of six
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** ✅ Done
* **Base:** `150cc2b` (develop)
* **Feature Branch:** feature/faster-test-runs
* **Worktree:** .workspace/P71 (feature/faster-test-runs)
* **Members:** P-67, P-68
* **Commits:** `a5e6851` (feature/faster-test-runs)
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-71` (or `aapp refine <id> group P-71`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
The full suite, which the `pre-done` test gate (P-60) runs on every `done`, takes about 6 minutes. This group makes it about a minute, without skipping a test: suites run in parallel (P-67), then the slowest verb suites are split into parts so the longest one no longer sets the floor (P-68). Scoped or partial runs are not part of it (pickup: Test Time & Kit Modularity).

Merge criterion: both members archived, the gate green on the feature branch, and a full `aapp test` on it measured (wall time reported in the group's `done`).

## 2. Shared Decisions
- The gate is unchanged: it always runs the whole suite.
- Exit codes, selection tokens and the summary rows of `aapp test` keep their contract; only how suites are scheduled and split changes.
- No new config key; the job count is worked out from the CPU count (P-67 Q1, Q2).

## 3. Members & Order
- P-67 (parallel runner), then P-68 (suite parts and splits): they share `lib/cmd_test.sh`, `lib/docs/verbs/test.md` and `tests/verbs/test.sh` (`aapp plan conflict-free P-71` shows two waves), and P-68 builds on P-67's scheduler.

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
No changes.

### .agents/CODEMAP.md
<!-- aapp-base: 2520063a704ba2506f9b8777a5c3960e1bd1f99a824a32db96ce86eb6545eacb -->
````markdown
### 🧪 Unified Test Runner Orchestrator (`lib/cmd_test.sh`)
* **Purpose:** Single entrypoint for automated test discovery, selective filtering, subshell isolation, execution timing, and assertion metric aggregation across all kit components.
* **Key Behaviors:**
  * Zero double-dash invariant: bare positional tokens (`list`, `strict`, `quiet`, `bail`, `jobs <n>`).
  * Parallel scheduling (P-67): up to N suites at once, N from `jobs <n>` or the CPU count rounded down to a multiple of 4; each suite's output captured in its own file and flushed in one write when it finishes; summary rows in selection order; one `trap` stops running suites and removes the files on exit or interrupt.
  * Suite parts (P-68): `tests/verbs/<verb>.<part>.sh` belongs to `<verb>`; `verb <verb>` runs it with all its parts, each scheduled as its own suite.
  * Fail-closed sandbox propagation (`AAPP_TEST_SANDBOX_STRICT=1`).
  * Adopter mode fallback: delegates to `aapp.testCommand` / auto-detected project runner (`npm`, `cargo`, etc.) or performs non-destructive AAPP protocol environment health audit.
* **Anti-Wrapper Warning:** Never bypass subshell sandboxing or alter suite exit codes.
````

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified; the members carry their own questions.)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Plan implementation completed and archived to done/.
* **2026-10-11:** Group started: `feature/faster-test-runs` from `develop`.
* **2026-10-11:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-11:** Group drafted.
