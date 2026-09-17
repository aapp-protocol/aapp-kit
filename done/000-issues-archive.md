# 🏛️ Master Issue Archive Ledger

Append-only historical ledger of verified and resolved issues.

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `hookSpecificOutput.permissionDecision` JSON output and exit code 2 in `blast-radius-guard.sh`. |
| #2 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Stripped `$REPO_ROOT/` from absolute target file paths in `blast-radius-guard.sh`. |
| #3 | `Critical` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Used safe plumbing orphan branch creation in `cmd_init.sh` preventing uncommitted file destruction. |
| #4 | `High` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Changed directory to `$REPO_ROOT` in guard and pre-commit to prevent cwd-relative fail-open. |
| #5 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `D` (deletions) to `--diff-filter` to enforce Out-of-Bounds on deleted files. |
| #6 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Used NUL-delimited `find` iteration in `cmd_status.sh` for plan files containing spaces. |
| #7 | `High` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned `.claude/settings.json` hook configuration with valid PreToolUse schema in `MANUAL.md`. |
| #8 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Moved `SKIP_BLAST_RADIUS=1` bypass check to the top before CHANGELOG enforcement. |
| #9 | `Medium` | `SEC` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Added pure-POSIX JSON fallback in `deny_action()` when `python3` is missing. |
| #10 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Added warning notice in `cmd_init.sh` when `.claude/settings.json` merge is skipped without python3. |
| #11 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Briefing in `cmd_status.sh` reads both `ISSUES.md` and `issues_road_map.md`. |
| #12 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Filtered bracketed placeholder lines in `pickup.md` during status briefing. |
| #13 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Exported `AAPP_VERSION` outside subshell and suppressed consumer notice on upgrades. |
| #14 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Exempted `aapp-develop-kit` and `agent-planning-kit` in self-consumption check. |
| #15 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Handled standalone clone target detection in drop-in mode in `cmd_init.sh`. |
| #16 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Stamped protocol marker version dynamically from `AAPP_VERSION` at sync time. |
| #17 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Safeguarded against data loss on missing `<!-- AAPP-PROTOCOL:END -->` tag in `cmd_init.sh`. |
| #18 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Removed unused dead variables `IS_RESTORE` and `AAPP_IS_DROP_IN`. |
| #19 | `Medium` | `DOCS` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Softened direct shell redirection claims in `README.md`. |
| #20 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Regenerated Table of Contents and fixed broken section anchors in `README.md`. |
| #21 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Clarified master runner `.githooks/pre-commit` vs managed engine `.githooks/aapp-pre-commit`. |
| #22 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Synchronized test suite case counts across documentation. |
| #23 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned slash command lifecycle table in `README.md` with `AGENTS.md` protocol. |
| #24 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Synchronized Table of Contents and Section 7 sub-TOC anchors in `MANUAL.md`. |
| #25 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Corrected syntax validation claims in `MANUAL.md` to reflect Python, PHP, and JSON checkers. |
| #26 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Clarified No-Plan Grace Period description for active blueprints in `MANUAL.md`. |
| #27 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned orphan branch plumbing documentation and exit code 2 error handling in `MANUAL.md`. |
| #28 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Fixed relative plan link path from `../.plans/current/` to `current/` in `templates/issues.md`. |
| #29 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Corrected structural mapping tree for `.plans/` files in `templates/architecture.md`. |
| #30 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Updated comment marker reference from `AAPP-INIT` to `aapp init` in `templates/AGENTS.md`. |
| #31 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Executed `call_guard_json` with absolute paths on every assertion in `tests/write-guard_test.sh`. |
| #32 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Verified `hookSpecificOutput.permissionDecision` in response schema in `tests/write-guard_test.sh`. |
| #33 | `Medium` | `TEST` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Cleaned up helper definitions and test assertions in `tests/write-guard_test.sh`. |
| #34 | `Medium` | `TEST` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Added regression test coverage for deletions, fallback init, and develop mode in `tests/`. |
| #35 | `Critical` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Fixed awk plan parser to strip backticked/unbackticked markers before target extraction. |
| #36 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `sh\|bash\|zsh` and extensionless binaries to `CORE_CODE_REGEX` in `templates/aapp-pre-commit`. |
| #37 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Supported bold markdown `\| **ISSUE-001** \|` and filtered `Resolved` status in `cmd_status.sh`. |
| #38 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added hook manager warning notice when custom non-shell hook exists in `cmd_init.sh`. |
| #39 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Modernized and renamed example blueprint to `example-plan-unified-install-and-upgrade.md`. |
| #40 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added regression test coverage for backticked `NEW FILE` and `MODIFY` markers in `tests/pre-commit_test.sh`. |
| #41 | `High` | `SEC` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Streamed JSON stdin to Python eliminating ARG_MAX crash on large writes in `blast-radius-guard.sh`. |
| #42 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Filtered resolved and done items in `issues_road_map.md` parser in `cmd_status.sh`. |
| #43 | `High` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Safely unlinked symlinks before installing to prevent deleting repo files in `cmd_install.sh`. |
| #44 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Stamped protocol version dynamically in awk avoiding non-portable sed -i in `cmd_init.sh`. |
| #45 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Cleaned up broken/dangling symlinks using -e \|\| -L checks in `cmd_uninstall.sh`. |
| #46 | `Medium` | `SEC` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Used POSIX head -n 1 and quoted REPO_ROOT in pattern expansion in `blast-radius-guard.sh`. |
| #47 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Supported dash plan status bullets and trimmed pickup idea whitespace in `cmd_status.sh`. |
| #53 | `High` | `SEC` | 2026-09-10 | 2026-09-15 | `7d00a00` | [`P9-guard-path-authorization.md`](P9-guard-path-authorization.md): Added `MultiEdit` to PreToolUse matcher across settings templates, init merger, and `.claude/settings.json`. |
| #54 | `High` | `SEC` | 2026-09-10 | 2026-09-15 | `7d00a00` | [`P9-guard-path-authorization.md`](P9-guard-path-authorization.md): Added `.git/config` and `*/.git/config` to Section 2 self-protection in `blast-radius-guard.sh`. |
| #61 | `High` | `CORE` | 2026-09-14 | 2026-09-14 | `12b2ba7` (`v1.1.0`) | Universal AAPP Skills in `templates/skills/`, bridged to `.claude/skills/`, decoupled settings. |
| #66 | `High` | `CORE` | 2026-09-15 | 2026-09-16 | `3ffa3cf` | [`P14-ai-attribution-suite.md`](P14-ai-attribution-suite.md): Safe-by-default attribution switchboard (`ai-commit`/`ai-notes`/`ai-off`), hook infrastructure, Option C staged notes, and history scrubber (partially delivered per §E.9). |
| #64 | `High` | `SEC` | 2026-09-14 | 2026-09-16 | `fc68376` | Filtered out incubator drafts (`🔴`, `🟡`) from active plans in write-guard and pre-commit, ensuring drafts do not lock commits. |
| #52 | `High` | `SEC` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Added `hookEventName: 'PreToolUse'` and `permissionDecisionReason` to `blast-radius-guard.sh` deny payload and mirrored reason to stderr. |
| #55 | `Medium` | `HOOK` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Removed non-deterministic 900s wall-clock mtime check for `.plans/CHANGELOG.md` in `aapp-pre-commit`, replacing with git-verified status. |
| #62 | `Medium` | `TEST` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Added assertions in `write-guard_test.sh` validating `hookEventName`, `permissionDecisionReason`, and mirrored stderr. |
| #56 | `Medium` | `SEC` | 2026-09-10 | 2026-09-17 | `c98c982` | [`P18-glob-path-traversal-precision.md`](P18-glob-path-traversal-precision.md): Implemented pure-Bash `glob_to_regex` compiler, safe bracket grammar (`[...]`), and 3-tier fast path matching in `blast-radius-guard.sh` and `aapp-pre-commit`. |
| #68 | `High` | `SEC` | 2026-09-16 | 2026-09-17 | `98bf317` | [`P16-frozen-plan-immutability.md`](P16-frozen-plan-immutability.md): Implemented Section 2b design-lock immutability engine in `templates/aapp-pre-commit`, refusing in-flight edits to §2 and §4 of frozen blueprints while keeping checkboxes and changelog writable. |
| #57 | `Medium` | `SEC` | 2026-09-10 | 2026-09-17 | `df1828b` | [`P17-blast-radius-precision-and-isolation.md`](P17-blast-radius-precision-and-isolation.md): Structurally dissolved by Single-Active-Plan Architecture and per-worktree pointer buffer isolation (`.git/aapp_active_plan`). |
| #50 | `High` | `CLI` | 2026-09-10 | 2026-09-17 | `46539f8` | Resolved target repository to project root when drop-in kit is executed outside kit directory. |
| #51 | `High` | `CLI` | 2026-09-10 | 2026-09-17 | `ac7d9a1` | Gated self-consumption on content signature and pristine git status, and added `--keep` flag to install and init. |
