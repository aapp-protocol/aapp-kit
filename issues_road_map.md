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
2. #52 -> Deny payload omits `hookEventName` and `permissionDecisionReason`; agent blocked with no reason to self-correct.
3. #64 -> Status enum is not enforced in write-guard/pre-commit (`🚫|BLOCKED` check only; `🔴` and `🟡` fall through to unblocked).

## 🟡 Medium Priority (Upcoming Iterations)
- [ ] #50 -> Drop-in mode on `agent-planning-kit` or `aapp-develop-kit` resolves root to kit itself rather than cwd.
- [ ] #51 -> Self-consumption `rm -rf` gated on basename allowlist rather than directory contents/signatures.

## 🟢 Low Priority (Test Infrastructure & Verification)
- [ ] #62 -> Deny-schema assertion checks only `decision == 'deny'`, not that denial reason reaches caller.
- [ ] #63 -> No CI runs test suites (102 test cases) and no release gate blocks publishing `main` trailing `develop`.

## 📥 Triage (Incoming / Unsequenced)
*Newly logged issues awaiting prioritization.*
- [ ] #55 -> CHANGELOG enforcement accepts `.plans/CHANGELOG.md` on a 900s mtime window; wall-clock dependence is non-deterministic.
- [ ] #56 -> Glob matching lets `*` cross `/`; blast radius is wider than blueprint authors intend.
- [ ] #57 -> File marked Out of Bounds by one plan is allowed when second active plan lists it as target.
- [ ] #58 -> `AAPP_VERSION` stayed 1.0.0 without release tags, so protocol block still stamps `v1.0.0` after upgrade.
- [ ] #59 -> `sort -z` is GNU/newer-BSD only and fails on older macOS `sort`, breaking the Plans pillar of briefing.
- [ ] #60 -> Plan filenames with newlines break unquoted `ls -1` iteration in enforcement engine.
