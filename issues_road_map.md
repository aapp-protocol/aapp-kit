# 🗺️ Issue Priority Board

> **Role:** This file does one thing — it puts the issues recorded in root `ISSUES.md` into the order you intend to fix them. It is an **active view**, not a historical record. `ISSUES.md` holds the detail; this holds the sequence.
>
> **Active-Only Queue Invariant:** This board only tracks active, unresolved issues. When an issue is resolved, it is pruned from this board (the pre-commit hook automatically purges any marked ✅ or Resolved). Historical records belong exclusively in `.plans/done/000-issues-archive.md`.
>
> **Not for future implementations.** Raw feature requests and new capabilities never appear here — they belong in `.plans/state_matrix.md`.
>
> **But an issue may have a plan.** If a fix is large enough to need a blueprint and a locked Blast Radius, promote it (`digest ISSUE-00X`) — and it **stays on this board**, marked 🔵 `Planned` with a link to its blueprint, until the fix ships. Promotion changes how it gets fixed, not which lane it lives in.
>
> **Rule for Agents:** This ordering is a human judgement call — appetite, dependency, and context, not a severity calculation. Read it as given and report it as given. Do **not** re-sort, re-rank, or "correct" these priorities unless explicitly asked.

---

## ⭐ User Priority (Pinned / Immediate Human Focus)
*Direct developer overrides based on current focus and appetite.*
*(No pinned user overrides)*


## 🔴 High Priority (Technical Urgency)
1. #49 -> `aapp upgrade` clones default branch, but `main` is 13 commits behind `develop` and carries pre-fix guard; upgrades downgrade Layer 1.

## 🟡 Medium Priority (Upcoming Iterations)
1. #76 -> Unbounded changelog bullet length and commit body verbosity cause context briefing blowup and git log bloat. 🔵 Planned under [P-28](current/P28-conciseness-enforcement-and-changelog-governance.md).

## 🟢 Low Priority (Test Infrastructure & Verification)
- [ ] #63 -> No CI runs test suites (102 test cases) and no release gate blocks publishing `main` trailing `develop`.

## 📥 Triage (Incoming / Unsequenced)
*Newly logged issues awaiting prioritization.*
- [ ] #58 -> `AAPP_VERSION` stayed 1.0.0 without release tags, so protocol block still stamps `v1.0.0` after upgrade.
- [ ] #59 -> `sort -z` is GNU/newer-BSD only and fails on older macOS `sort`, breaking the Plans pillar of briefing.
- [ ] #60 -> Plan filenames with newlines break unquoted `ls -1` iteration in enforcement engine.
- [ ] #67 -> AI credits generator relies on commit trailers and cannot mechanically extract agents that contributed review without committing (awaiting adversarial-review plugin).
- [ ] #73 -> 🔵 Planned under P-25 (Delimited Template Sync & Tiered Document Governance). Stale templates persist in worktrees; `copy_guarded` never refreshes guarded destinations.
- [ ] #79 -> 🔵 Planned under P-32 (Issue ID Allocation & Duplicate Detection Engine). Issue IDs lack monotonic allocator and duplicate checks.
- [ ] #84 -> Write-guard refuses `.plans/*` writes when cwd is inside the `.plans` worktree.
- [ ] #85 -> Status-line regex duplicated across 22 call sites with divergent legacy alias handling.
- [ ] #86 -> Pair 5 keeps a fifth Target Files parser outside the P-37 library.
- [ ] #87 -> Emergency Hotfix Extensions live in design-locked §4, so they are refused once a plan is Frozen.
- [ ] #92 -> `aapp test` runs other projects' tests (auto-detect, `aapp.testCommand`) outside the kit clone; should run kit suites only.
- [ ] #93 -> Bare `aapp draft` offers only already-planned issues and hides incubated ones (emoji filter mismatch).
- [ ] #94 -> Plugin names hardcoded in ~9 places; no shipped registry (`lib/plugins.tsv`).
- [ ] #95 -> "Small" fix is undefined in invariant 5; default <10 changed lines, adopter override in `PROJECT.MD`.

