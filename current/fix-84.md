# 🩹 Issue Fix #84: Relativise against `PRIMARY_ROOT`; MANUAL FAQ to use `git -C .plans`.
* **Plan ID:** #84
* **Target Issue / Milestone:** #84
* **Changelog:** Fixed: the write guard allows `.plans/` and `.agents/` writes from inside those worktrees, and by absolute path from a linked worktree
* **Status:** ⚡ In Development
* **Commits:** `13adeb2` (develop)

Temporary mini plan (P-52): deleted by `aapp issue close 84`; the issue row is the record.

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh`
- [ ] `tests/write-guard_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
