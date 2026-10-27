---
title: Platform Verification Status
description: Which operating systems and environments the kit is tested on, the risks known on the others, how to check it on your machine and how to report the result.
---

# 🧪 Platform Verification Status (Help Wanted)

The kit is Bash, Git and Perl (5.26 or later), and it is developed and tested on Linux only. This page says what has been verified and what has not. **Untested does not mean broken, and it does not mean supported.** The risks below are *potential* problems read from the code, not confirmed defects. They are fixed when someone on that platform reports what actually happens, which usually also shows the cleanest fix.

---

## 1. Verification Matrix

| Environment | Status | What to watch for |
| :--- | :--- | :--- |
| **Linux** (GNU coreutils, Bash 5, Perl 5.26+) | ✅ Verified: the full kit test suites (`./aapp test`, `t/test-run`) | — |
| **macOS** (BSD userland, `/bin/bash` 3.2, system Perl) | ⚠️ Untested | BSD `sed -i` expects a backup-suffix argument (`sed -i ''`), and lifecycle verbs (`draft`, `freeze`, `start`, `done`, `offline`) use GNU-style `sed -i`. `sort -z` may be missing on older releases; `aapp status` and the planning health checks use it. `aapp install` must keep `templates/aapp-lib.sh` a symlink under BSD `cp -r`. Whether the scripts run under the system Bash 3.2 is unverified. |
| **Windows** (Git Bash / MSYS2) | ⚠️ Untested | With `core.symlinks=false`, `templates/aapp-lib.sh` checks out as a one-line text file; `aapp init` copies the library from `lib/` for this reason, so hooks should still work. Plan worktrees (`aapp.planWorktrees`) link `.githooks`, `.agents`, `.plans` and `.claude` as symlinks and fail closed when a link cannot be made: without symlink support they will not start. The kit passes Git Bash paths (`/c/Users/…`) to Perl: Git for Windows' own Perl reads them; a native Perl first on `PATH` (Strawberry, ActiveState) does not, and the write guard then refuses every write ("Perl core missing"). Line-ending handling is unverified. |
| **WSL** | ⚠️ Untested | Expected to behave like Linux (GNU userland). Repositories on `/mnt/c` may lose symlink support. |
| **FreeBSD / OpenBSD / NetBSD** | ⚠️ Untested | The same BSD `sed` and `cp` differences as macOS; Perl must be installed. |
| **Alpine / BusyBox** | ⚠️ Untested | BusyBox `sed`, `find -print0` and `sort -z` support; Perl must be installed (`apk add perl`). |
| **Agents other than Claude Code and Antigravity** | ⚠️ Untested | Skills and the write guard are wired for Claude Code; other agents read `.agents/AGENTS.md` ([14. Agent Skills](14-agent-skills-and-slash-commands.md#3-how-skills-reach-each-agent)). Whether their file tools pass through the write guard depends on the agent. |

### Build tools that may not see `.workspace/`
Plan worktrees live in `.workspace/`, a top-level dot-folder. These tools are not covered by the adoption checks and may skip or include it unexpectedly:
- **Turborepo** finds workspace packages through the package manager's manifest rather than by walking folders.
- **pnpm** workspace globs are root-relative and skip top-level dot-folders by default.
- **TypeScript**: common `tsconfig.json` `include` patterns skip top-level dot-folders.

---

## 2. How to Verify on Your Machine

1. **Run the kit's own test suites** before installing:
   ```bash
   git clone https://github.com/aapp-protocol/aapp-kit.git aapp-kit
   cd aapp-kit && ./aapp test && t/test-run
   ```
2. **Install, then try the lifecycle** in a scratch repository:
   ```bash
   ./aapp install
   mkdir /tmp/aapp-demo && cd /tmp/aapp-demo
   git init && git commit --allow-empty -m init
   aapp init
   aapp draft platform-check && aapp status
   ```
3. **Check the shared hook library** was installed correctly:
   ```bash
   ls -l "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/templates/aapp-lib.sh"   # expect: symlink -> ../lib/aapp-lib.sh
   test -f .githooks/aapp-lib.sh && ! test -L .githooks/aapp-lib.sh && echo "hook library OK"
   ```

---

## 3. How to Report

Open a GitHub issue on the kit repository, whether it worked or failed. A "works on my machine" report is just as useful: it moves a row from ⚠️ to ✅. Please include:

```bash
aapp version
uname -a
bash --version | head -1
perl -v | sed -n 2p
if sed --version >/dev/null 2>&1; then sed --version | head -1; else echo "BSD sed"; fi
```

Add the failing command and its full output. If you can see a cleaner way to fix it, suggest it; for platform differences that is often the most valuable part of a report.

**Settings on this page:** [Plans & Worktrees](03-configuration-matrix.md#plans--worktrees)

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🤝 [Contributing](../../CONTRIBUTING.md)
- 🏠 [Repository Overview](../../README.md)
