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
1. #77 -> `aapp done` moves plan to `done/` without updating header status, leaving archived plans marked `⚡ In Development`.


## 🔴 High Priority (Technical Urgency)
1. #49 -> `aapp upgrade` clones default branch, but `main` is 13 commits behind `develop` and carries pre-fix guard; upgrades downgrade Layer 1.
2. #74 -> Tests hardcode throwaway credentials (`T <t@t>`) without sandbox guards; relative `core.hooksPath` blinds linked worktrees (`.plans`, `.agents`). 🔵 Planned under [P-26](current/P26-test-harness-isolation-and-worktree-hooks.md).

## 🟡 Medium Priority (Upcoming Iterations)
1. #75 -> Flat 36-verb catalog causes discovery fatigue for beginners; cheatsheet drifted to 44% coverage (16/36 verbs) missing core lifecycle. 🔵 Planned under [P-27](current/P27-tiered-cli-discovery-and-cheatsheet-sync.md).
2. #76 -> Unbounded changelog bullet length and commit body verbosity cause context briefing blowup and git log bloat. 🔵 Planned under [P-28](current/P28-conciseness-enforcement-and-changelog-governance.md).

## 🟢 Low Priority (Test Infrastructure & Verification)
- [ ] #63 -> No CI runs test suites (102 test cases) and no release gate blocks publishing `main` trailing `develop`.

## 📥 Triage (Incoming / Unsequenced)
*Newly logged issues awaiting prioritization.*
- [ ] #58 -> `AAPP_VERSION` stayed 1.0.0 without release tags, so protocol block still stamps `v1.0.0` after upgrade.
- [ ] #59 -> `sort -z` is GNU/newer-BSD only and fails on older macOS `sort`, breaking the Plans pillar of briefing.
- [ ] #60 -> Plan filenames with newlines break unquoted `ls -1` iteration in enforcement engine.
- [ ] #67 -> AI credits generator relies on commit trailers and cannot mechanically extract agents that contributed review without committing (awaiting adversarial-review plugin).
- [ ] #73 -> 🔵 Planned under P-25 (Delimited Template Sync & Tiered Document Governance). Stale templates persist in worktrees; `copy_guarded` never refreshes guarded destinations.
