# 🏛️ Master Issue Archive Ledger

Append-only historical ledger of verified and resolved issues.

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary | Branch |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #92 | `Medium` | `CLI` | 2026-09-28 | 2026-10-18 | `3f5912d` | aapp test runs only the suites of the kit it runs from, never the current repository's tests, aapp.testCommand or a detected project runner; the health audit fallback is gone |  |
| #87 | `Medium` | `CORE` | 2026-09-27 | 2026-10-18 | `1e0a104` | plan parsing no longer grants writes under the retired Emergency Hotfix Extensions heading |  |
| #124 | `Low` | `CORE` | 2026-10-11 | 2026-10-18 | `6202e50` | done clears the active plan buffers only after its archive commit lands, so a failed commit leaves them bound |  |
| #108 | `Low` | `DOCS` | 2026-10-08 | 2026-10-18 | `3ca2f64` | ARCHITECTURE.md lists only the scripts that exist and gives the hook watchdog default as 10s (aapp.hookTimeout) |  |
| #110 | `Low` | `DOCS` | 2026-10-08 | 2026-10-18 | `0d054bf` | the MANUAL names the post-done event where it still said on-done |  |
| #162 | `Low` | `CLI` | 2026-10-16 | 2026-10-18 | `0726230` | start and freeze-start refused for a plan bound in another worktree name the command that resumes it there |  |
| #161 | `Low` | `TEST` | 2026-10-16 | 2026-10-17 | `cb7879b` | the ledger-access test passes its name pattern through the environment, so awk prints no escape warnings and matches a literal dot |  |
| #167 | `Low` | `HOOK` | 2026-10-17 | 2026-10-17 | `05bc893` | the pre-done test gate sample prints one line before the tests run, naming the command and the plan it waits for |  |
| #166 | `Low` | `DOCS` | 2026-10-17 | 2026-10-17 | `414e5f9` | [P-105](P105-architecture-rules-as-headings.md) - Architecture Rules As Headings |  |
| #165 | `Medium` | `CORE` | 2026-10-16 | 2026-10-17 | `f50a0f0` | [P-102](P102-group-done-lifecycle-order.md) - Group Done Lifecycle Order |  |
| #160 | `Low` | `CLI` | 2026-10-16 | 2026-10-16 | `4a7da2f` | [P-97](P97-draft-from-pickup-title.md) - Draft From Pickup Title |  |
| #164 | `Low` | `DOCS` | 2026-10-16 | 2026-10-16 | `7733a2f` | clarify issue log writes ISSUES.md only without a road-map line |  |
| #163 | `Low` | `CLI` | 2026-10-16 | 2026-10-16 | `076b601` | route -h and --help after verbs to help dispatcher |  |
| #155 | `Low` | `CLI` | 2026-10-16 | 2026-10-16 | `ca75504` | [P-93](P93-issue-list-layout.md) - Issue List Layout |  |
| #147 | `Low` | `CLI` | 2026-10-13 | 2026-10-16 | `2c165e6` | [P-88](P88-status-recent-and-bounded.md) - Status Recent And Bounded |  |
| #158 | `Low` | `DOCS` | 2026-10-16 | 2026-10-16 | `751b9da` | [P-95](P95-plugin-runtime-and-dx-fixes.md) - Plugin Runtime And Dx Fixes |  |
| #157 | `Low` | `CLI` | 2026-10-16 | 2026-10-16 | `751b9da` | [P-95](P95-plugin-runtime-and-dx-fixes.md) - Plugin Runtime And Dx Fixes |  |
| #156 | `Low` | `CLI` | 2026-10-16 | 2026-10-16 | `751b9da` | [P-95](P95-plugin-runtime-and-dx-fixes.md) - Plugin Runtime And Dx Fixes |  |
| #154 | `Medium` | `CLI` | 2026-10-16 | 2026-10-16 | `ca752a1` | an empty work queue shows no issue in the status briefing |  |
| #122 | `Low` | `CLI` | 2026-10-11 | 2026-10-15 | `6cf5dba` | [P-86](P86-plan-closes-further-issues.md) - Plan Closes Further Issues |  |
| #153 | `Low` | `DOCS` | 2026-10-15 | 2026-10-15 | `aborted` | Aborted: Done in P-85 |  |
| #152 | `Low` | `DOCS` | 2026-10-15 | 2026-10-15 | `aborted` | Aborted: Done in P-85 |  |
| #151 | `Low` | `DOCS` | 2026-10-14 | 2026-10-14 | `a245881` | the manual names the git notes the squash at `aapp done` does not carry |  |
| #149 | `Medium` | `CORE` | 2026-10-14 | 2026-10-14 | `ab469ca` | the squash at `aapp done` carries the last commit's AI note and every replaced commit's note |  |
| #150 | `Low` | `DOCS` | 2026-10-14 | 2026-10-14 | `7515287` | `ARCHITECTURE.md` describes the squash on the plan branch (P-84) |  |
| #148 | `High` | `CORE` | 2026-10-13 | 2026-10-13 | `3251ca5` | `ledger_set_archive_commit` corrects the commit an archived issue row names; unblocks P-84 |  |
| #145 | `Low` | `DOCS` | 2026-10-13 | 2026-10-13 | `13f174f` | `/aapp` and `/aapp-status` show the output of `aapp status` unchanged, with remarks after it |  |
| #144 | `Low` | `DOCS` | 2026-10-13 | 2026-10-13 | `5e1266a` | `/aapp` and `/aapp-status` report what `aapp status` printed, item by item, without dropping fields |  |
| #120 | `Low` | `CLI` | 2026-10-11 | 2026-10-13 | `f9e1388` | [P-87](P87-rules-on-demand.md) - Rules On Demand |  |
| #133 | `Low` | `CLI` | 2026-10-13 | 2026-10-13 | `6424d2f` | a fix's first commit, refused by a hook, can be retried with its `changelog` token |  |
| #142 | `Medium` | `CORE` | 2026-10-13 | 2026-10-13 | `8024e43` | an issue closed on the tracker is closed here at once; a plan waiting on it resumes when the fix commit is in its branch |
| #141 | `High` | `CORE` | 2026-10-13 | 2026-10-13 | `a69884d` | the agent CLI reference has a line for aapp offline; unblocks P-75 |
| #140 | `High` | `CORE` | 2026-10-12 | 2026-10-12 | `1ec09ee` | the issue and provider suites set aapp.offlineEnabled false: a failing provider is a failure there; unblocks P-75 | `feature/issue-tracker` |
| #139 | `Medium` | `CLI` | 2026-10-12 | 2026-10-12 | `f0308a5` | aapp issue list asks no provider inside a plugin step; the retired issue next and allocate are no longer named |  |
| #138 | `High` | `CORE` | 2026-10-12 | 2026-10-12 | `528ff7d` | the resolver tests no longer expect the issue provider to number issues through the counter; unblocks P-74 |  |
| #137 | `High` | `CORE` | 2026-10-12 | 2026-10-12 | `126d2e7` | the issue branch tests no longer log rows by hand; unblocks P-74 |  |
| #126 | `High` | `CORE` | 2026-10-12 | 2026-10-12 | `aborted` | Aborted: Shared project settings are a team plugin's job; the kit keeps per-clone config |  |
| #136 | `Medium` | `CORE` | 2026-10-12 | 2026-10-12 | `fa7c775` | a logged issue names a branch only when one is given; otherwise the development branch |  |
| #135 | `Low` | `DOCS` | 2026-10-12 | 2026-10-12 | `c24eb8e` | the agent rules and the fix, start and done skills describe fixes on the issue's branch |  |
| #134 | `High` | `CORE` | 2026-10-12 | 2026-10-12 | `a79f70f` | the issues table check accepts a ledger with further columns; unblocks P-78 |  |
| #132 | `High` | `CORE` | 2026-10-13 | 2026-10-12 | `5df988d` | adding files to an open group fix keeps its worktree and group, so `issue close` still lands it on the feature branch |  |
| #131 | `Low` | `DOCS` | 2026-10-13 | 2026-10-12 | `cb002d2` | the contracts, the agent rules, the manual and the usage line of `refine … blocked` and `draft … issue` say they take any issue id, a tracker's key included |  |
| #93 | `Medium` | `CLI` | 2026-09-28 | 2026-10-12 | `d1b9e68` | a bare `aapp draft` offers the issues awaiting a plan (Incubated), not the planned ones |  |
| #123 | `Medium` | `CORE` | 2026-10-11 | 2026-10-12 | `20e4182` | [P-76](P76-issue-abort.md) - Issue Abort |  |
| #118 | `Medium` | `CORE` | 2026-10-11 | 2026-10-12 | `a1412c0` | [P-69](P69-abort-plan.md) - Lifecycle Plan Abort & Worktree Decommissioning |  |
| #111 | `Low` | `CORE` | 2026-10-09 | 2026-10-11 | `d55aa29` | Fixed by P-66: the entry is given at commit, under the length gate |  |
| #117 | `High` | `CORE` | 2026-10-10 | 2026-10-11 | `d55aa29` | [P-66](P66-issue-fix-changelog-from-the-fix.md) - Issue Fix Changelog From The Fix |  |
| #121 | `High` | `CORE` | 2026-10-11 | 2026-10-11 | `c74d986` | `aapp done` restores the plan, ledgers and matrix when its archive commit fails |  |
| #119 | `High` | `CORE` | 2026-10-11 | 2026-10-11 | `8df5011` | `aapp done` finds a TDD plan's required test files in the plan's worktree |  |
| #116 | `Low` | `DOCS` | 2026-10-10 | 2026-10-10 | `6c55004` | Template lacked on-integrate; this repo's seeded copy kept pre-P-23 names (fixed in .agents d661711). |  |
| #115 | `High` | `TEST` | 2026-10-10 | 2026-10-10 | `be30b40` | Fixed via aapp issue fix: lib/cmd_test.sh, tests/verbs/test.sh |  |
| #114 | `High` | `TEST` | 2026-10-09 | 2026-10-10 | `0cc7b47` | [P-62](P62-guard-buffer-and-workspace-fixtures.md) - Guard Buffer And Workspace Fixtures |  |
| #113 | `Medium` | `CLI` | 2026-10-09 | 2026-10-09 | `16e57fe` | Fixed via aapp issue fix: lib/cmd_install.sh, tests/install_test.sh |  |
| #112 | `Medium` | `HOOK` | 2026-10-09 | 2026-10-09 | `0c0b004` | [P-61](P61-workspace-plan-worktrees.md) - Workspace Plan Worktrees & Cross-Worktree Guard Resolution |  |
| #109 | `Medium` | `HOOK` | 2026-10-08 | 2026-10-09 | `948abe7` | Fixed via aapp issue fix: lib/cmd_sync.sh, lib/hook_dispatcher.sh, tests/sync_test.sh |  |
| #101 | `Low` | `DOCS` | 2026-10-07 | 2026-10-08 | `15fda4f` | Fixed via aapp issue fix: templates/skills/aapp-digest/SKILL.md |  |
| #107 | `Low` | `CORE` | 2026-10-08 | 2026-10-08 | `ca7c679` | Fixed via aapp issue fix: lib/cmd_plan.sh, tests/verbs/freeze.sh, tests/verbs/freeze-start.sh, lib/docs/verbs/freeze.md, lib/docs/verbs/freeze-start.md, tests/install_test.sh, tests/verbs/tdd.sh |  |
| #105 | `Medium` | `CORE` | 2026-10-08 | 2026-10-08 | `6df62c1` | Fixed via aapp issue fix: lib/cmd_issue.sh |  |
| #106 | `Low` | `HOOK` | 2026-10-08 | 2026-10-08 | `ad64b00` | Fixed via aapp issue fix: templates/aapp-pre-commit |  |
| #103 | `Medium` | `CORE` | 2026-10-08 | 2026-10-08 | `ade93c3` | Fixed via aapp issue fix: lib/aapp-lib.sh, tests/verbs/start.sh, lib/docs/verbs/start.md, lib/docs/verbs/freeze-start.md, lib/cmd_plan.sh |  |
| #104 | `High` | `CORE` | 2026-10-08 | 2026-10-08 | `dd0865a` | Out of kit scope: layer-0 deployment hardening; practice to document (pickup: Layer-0 Enforcement Practice) |  |
| #102 | `Medium` | `DOCS` | 2026-10-07 | 2026-10-08 | `2c71bb9` | Fixed via aapp issue fix: templates/plan-template.md, templates/AGENTS.md, .agents/AGENTS.md |  |
| #84 | `Medium` | `HOOK` | 2026-09-27 | 2026-10-07 | `13adeb2` | Fixed via aapp issue fix: templates/blast-radius-guard.sh, tests/write-guard_test.sh |  |
| #98 | `High` | `HOOK` | 2026-10-04 | 2026-10-07 | `a248b10` | [P-52](P52-issue-fix-mini-plans.md) - Issue Fix Mini Plans (`aapp issue fix`) |  |
| #97 | `Medium` | `HOOK` | 2026-10-04 | 2026-10-07 | `ee1ba57` | Fixed via aapp issue fix: templates/aapp-pre-commit, tests/pre-commit_test.sh |  |
| #100 | `Medium` | `CLI` | 2026-10-07 | 2026-10-07 | `da419a2` | Anchor template delimiter regexes, prevent unclosed marker warning from aborting aapp init, and classify archive ledger as Tier 3 data. |  |
| #73 | `Medium` | `CLI` | 2026-09-20 | 2026-10-07 | `b54887b` | [P-25](P25-template-sync-and-document-governance.md) - Delimited Template Sync & Tiered Document Governance |  |
| #96 | `Medium` | `CORE` | 2026-10-03 | 2026-10-03 | `12cdb93` | [P-48](P48-shared-docs-concurrency.md) - Shared Docs Concurrency: Collision Exemption, Plan-Declared Changelog, Union Merge |  |
| #94 | `Low` | `CORE` | 2026-09-29 | 2026-10-03 | `24c24e5` | [P-46](P46-plugin-registry.md) - Plugin Registry |  |
| #79 | `Medium` | `CORE` | 2026-09-22 | 2026-10-02 | `c0edb4b` | [P-32](P32-issue-id-allocation-and-duplicate-detection.md) - Issue ID Allocation, Lifecycle Engine & Duplicate Detection |  |
| #91 | `Critical` | `CORE` | 2026-09-28 | 2026-09-28 | `5685ef5` | Direct fix (no plan): removed destructive `remote.origin.push/fetch` refspecs from `cmd_ai_notes` in `lib/cmd_ai.sh` to prevent force-pushing branches and destroying tracking refs. |  |
| #90 | `Medium` | `CORE` | 2026-09-28 | 2026-09-28 | `52f5fc9` | Direct fix (no plan): restored default `aapp.aiAttribution` to `none` across `cmd_init.sh`, `attribution.sh`, `cmd_commit.sh`, test fixtures, and documentation so AI attribution is opt-in developer choice. |  |
| #81 | `High` | `HOOK` | 2026-09-23 | 2026-09-28 | `32b7935` | Superseded by [P-40](P40-attribution-policy-tiers.md) (attribution policy tiers) and [P-39](../current/P39-plan-bound-commit-helper.md) (lifecycle commit engine). |  |
| #89 | `Medium` | `CLI` | 2026-09-27 | 2026-09-27 | `52c2c01` | Direct fix (no plan): `freeze`/`freeze-start` gate on incubator status, `done` on in-development, via the status registry; contracts and verb suites updated. |  |
| #88 | `Medium` | `CLI` | 2026-09-27 | 2026-09-27 | `8c0c103` | [P-34](P34-verb-behaviour-contracts.md) - `aapp done` re-derives the state matrix instead of deleting rows by substring; `test_matrix_row_removed_exactly`. |  |
| #78 | `Medium` | `CLI` | 2026-09-22 | 2026-09-27 | `bca7d9a` | [P-34](P34-verb-behaviour-contracts.md) - Ledger rows take the Target Issue from the plan header and the plan title as Impact Summary (D2); `test_ledger_row_populated`. |  |
| #82 | `Medium` | `CORE` | 2026-09-23 | 2026-09-27 | `416e115` | [P-37](P37-shared-hook-library.md) - Target Files parser single-sourced in `lib/aapp-lib.sh`; blockquotes, foreign subsections and fenced examples no longer grant writes. Pair 5 parser left for #86. |  |
| #83 | `High` | `CLI` | 2026-09-27 | 2026-09-27 | `ae1ff90` | [P-36](P36-deprecate-drop-in-and-enforce-runtime-reachability.md) - Deprecated broken drop-in installation, single-sourced runtime detection, enforced physical canonical fast-fail check in `cmd_init.sh`, added Section 0 reachability and Inspection-Only gate to pre-commit, and added sandbox test runtime confinement. |  |
| #80 | `Medium` | `CLI` | 2026-09-22 | 2026-09-23 | `432da13` | [P-33](P33-centralized-git-root-assertion-and-fail-fast-dispatch.md) - Centralized repository root assertion and fail-fast dispatch in `aapp`; purged redundant derivations and silent `\|\| pwd` / `\|\| true` fallbacks across `lib/`; fail-closed standalone library roots; `ARCHITECTURE.md` rule 9. |  |
| #74 | `High` | `TEST` | 2026-09-21 | 2026-09-22 | `c4fc5b2` | [P-26](done/P26-test-harness-isolation-and-worktree-hooks.md) - Standardized test suites with `test_helpers.sh` sandbox assertion, developer identity inheritance, GPG signing bypass, and wired universal worktree hooks via `git-common-dir`. |  |
| #75 | `Medium` | `CLI` | 2026-09-21 | 2026-09-22 | `d49d201` | [P-27](done/P27-tiered-cli-discovery-and-cheatsheet-sync.md) - Replaced the flat verb catalog with tiered `aapp help` output backed by `lib/verbs.tsv`, and restored cheatsheet parity to 33/33 verbs with automated drift tests. |  |
| #77 | `Medium` | `CLI` | 2026-09-22 | 2026-09-22 | `d49d201` | Updated `cmd_done` in `lib/cmd_plan.sh` to rewrite blueprint status header to Done and append completion entry to Change Log upon archival. |  |
| #70 | `Medium` | `CLI` | 2026-09-17 | 2026-09-21 | [P-29](done/P29-universal-skills-pruning-and-fallback-invariants.md) | Set `disable-model-invocation: false` across all retained universal skills in `templates/skills/`, restoring autocomplete in Antigravity IDE and Claude Code. |  |
| #72 | `Low` | `CLI` | 2026-09-19 | 2026-09-21 | [P-29](done/P29-universal-skills-pruning-and-fallback-invariants.md) | Implemented dynamic context-aware Next Action footer in `cmd_status.sh` and 3-tier fallback in `aapp-digest`, eliminating dead-end recommendations. |  |
| #69 | `High` | `CLI` | 2026-09-17 | 2026-09-20 | `f4be7cd` | **Superseded by P-22.** The archive-ledger scan containing the unquoted-backtick regex was removed entirely in favour of config-backed allocation (`aapp.planId`); the defective line was deleted rather than corrected. |  |
| #1 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `hookSpecificOutput.permissionDecision` JSON output and exit code 2 in `blast-radius-guard.sh`. |  |
| #2 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Stripped `$REPO_ROOT/` from absolute target file paths in `blast-radius-guard.sh`. |  |
| #3 | `Critical` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Used safe plumbing orphan branch creation in `cmd_init.sh` preventing uncommitted file destruction. |  |
| #4 | `High` | `SEC` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Changed directory to `$REPO_ROOT` in guard and pre-commit to prevent cwd-relative fail-open. |  |
| #5 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `D` (deletions) to `--diff-filter` to enforce Out-of-Bounds on deleted files. |  |
| #6 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Used NUL-delimited `find` iteration in `cmd_status.sh` for plan files containing spaces. |  |
| #7 | `High` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned `.claude/settings.json` hook configuration with valid PreToolUse schema in `MANUAL.md`. |  |
| #8 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Moved `SKIP_BLAST_RADIUS=1` bypass check to the top before CHANGELOG enforcement. |  |
| #9 | `Medium` | `SEC` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Added pure-POSIX JSON fallback in `deny_action()` when `python3` is missing. |  |
| #10 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Added warning notice in `cmd_init.sh` when `.claude/settings.json` merge is skipped without python3. |  |
| #11 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Briefing in `cmd_status.sh` reads both `ISSUES.md` and `issues_road_map.md`. |  |
| #12 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Filtered bracketed placeholder lines in `pickup.md` during status briefing. |  |
| #13 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Exported `AAPP_VERSION` outside subshell and suppressed consumer notice on upgrades. |  |
| #14 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Exempted `aapp-develop-kit` and `agent-planning-kit` in self-consumption check. |  |
| #15 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Handled standalone clone target detection in drop-in mode in `cmd_init.sh`. |  |
| #16 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Stamped protocol marker version dynamically from `AAPP_VERSION` at sync time. |  |
| #17 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Safeguarded against data loss on missing `<!-- AAPP-PROTOCOL:END -->` tag in `cmd_init.sh`. |  |
| #18 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Removed unused dead variables `IS_RESTORE` and `AAPP_IS_DROP_IN`. |  |
| #19 | `Medium` | `DOCS` | 2026-09-09 | 2026-09-09 | `dd351d5` (`v1.0.2`) | Softened direct shell redirection claims in `README.md`. |  |
| #20 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Regenerated Table of Contents and fixed broken section anchors in `README.md`. |  |
| #21 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Clarified master runner `.githooks/pre-commit` vs managed engine `.githooks/aapp-pre-commit`. |  |
| #22 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Synchronized test suite case counts across documentation. |  |
| #23 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned slash command lifecycle table in `README.md` with `AGENTS.md` protocol. |  |
| #24 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Synchronized Table of Contents and Section 7 sub-TOC anchors in `MANUAL.md`. |  |
| #25 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Corrected syntax validation claims in `MANUAL.md` to reflect Python, PHP, and JSON checkers. |  |
| #26 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Clarified No-Plan Grace Period description for active blueprints in `MANUAL.md`. |  |
| #27 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Aligned orphan branch plumbing documentation and exit code 2 error handling in `MANUAL.md`. |  |
| #28 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Fixed relative plan link path from `../.plans/current/` to `current/` in `templates/issues.md`. |  |
| #29 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Corrected structural mapping tree for `.plans/` files in `templates/architecture.md`. |  |
| #30 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Updated comment marker reference from `AAPP-INIT` to `aapp init` in `templates/AGENTS.md`. |  |
| #31 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Executed `call_guard_json` with absolute paths on every assertion in `tests/write-guard_test.sh`. |  |
| #32 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Verified `hookSpecificOutput.permissionDecision` in response schema in `tests/write-guard_test.sh`. |  |
| #33 | `Medium` | `TEST` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Cleaned up helper definitions and test assertions in `tests/write-guard_test.sh`. |  |
| #34 | `Medium` | `TEST` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Added regression test coverage for deletions, fallback init, and develop mode in `tests/`. |  |
| #35 | `Critical` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Fixed awk plan parser to strip backticked/unbackticked markers before target extraction. |  |
| #36 | `High` | `HOOK` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added `sh\|bash\|zsh` and extensionless binaries to `CORE_CODE_REGEX` in `templates/aapp-pre-commit`. |  |
| #37 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Supported bold markdown `\| **ISSUE-001** \|` and filtered `Resolved` status in `cmd_status.sh`. |  |
| #38 | `Medium` | `CLI` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added hook manager warning notice when custom non-shell hook exists in `cmd_init.sh`. |  |
| #39 | `Low` | `DOCS` | 2026-09-10 | 2026-09-10 | `11cc38b` (`v1.0.3`) | Modernized and renamed example blueprint to `example-plan-unified-install-and-upgrade.md`. |  |
| #40 | `Medium` | `TEST` | 2026-09-09 | 2026-09-09 | `9a4f92c` (`v1.0.1`) | Added regression test coverage for backticked `NEW FILE` and `MODIFY` markers in `tests/pre-commit_test.sh`. |  |
| #41 | `High` | `SEC` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Streamed JSON stdin to Python eliminating ARG_MAX crash on large writes in `blast-radius-guard.sh`. |  |
| #42 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Filtered resolved and done items in `issues_road_map.md` parser in `cmd_status.sh`. |  |
| #43 | `High` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Safely unlinked symlinks before installing to prevent deleting repo files in `cmd_install.sh`. |  |
| #44 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Stamped protocol version dynamically in awk avoiding non-portable sed -i in `cmd_init.sh`. |  |
| #45 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Cleaned up broken/dangling symlinks using -e \|\| -L checks in `cmd_uninstall.sh`. |  |
| #46 | `Medium` | `SEC` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Used POSIX head -n 1 and quoted REPO_ROOT in pattern expansion in `blast-radius-guard.sh`. |  |
| #47 | `Medium` | `CLI` | 2026-09-10 | 2026-09-10 | `6a3f0cc` | Supported dash plan status bullets and trimmed pickup idea whitespace in `cmd_status.sh`. |  |
| #53 | `High` | `SEC` | 2026-09-10 | 2026-09-15 | `7d00a00` | [`P9-guard-path-authorization.md`](P9-guard-path-authorization.md): Added `MultiEdit` to PreToolUse matcher across settings templates, init merger, and `.claude/settings.json`. |  |
| #54 | `High` | `SEC` | 2026-09-10 | 2026-09-15 | `7d00a00` | [`P9-guard-path-authorization.md`](P9-guard-path-authorization.md): Added `.git/config` and `*/.git/config` to Section 2 self-protection in `blast-radius-guard.sh`. |  |
| #61 | `High` | `CORE` | 2026-09-14 | 2026-09-14 | `12b2ba7` (`v1.1.0`) | Universal AAPP Skills in `templates/skills/`, bridged to `.claude/skills/`, decoupled settings. |  |
| #66 | `High` | `CORE` | 2026-09-15 | 2026-09-16 | `3ffa3cf` | [`P14-ai-attribution-suite.md`](P14-ai-attribution-suite.md): Safe-by-default attribution switchboard (`ai-commit`/`ai-notes`/`ai-off`), hook infrastructure, Option C staged notes, and history scrubber (partially delivered per §E.9). |  |
| #64 | `High` | `SEC` | 2026-09-14 | 2026-09-16 | `fc68376` | Filtered out incubator drafts (`🔴`, `🟡`) from active plans in write-guard and pre-commit, ensuring drafts do not lock commits. |  |
| #52 | `High` | `SEC` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Added `hookEventName: 'PreToolUse'` and `permissionDecisionReason` to `blast-radius-guard.sh` deny payload and mirrored reason to stderr. |  |
| #55 | `Medium` | `HOOK` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Removed non-deterministic 900s wall-clock mtime check for `.plans/CHANGELOG.md` in `aapp-pre-commit`, replacing with git-verified status. |  |
| #62 | `Medium` | `TEST` | 2026-09-10 | 2026-09-16 | `ae9b4dc` | Added assertions in `write-guard_test.sh` validating `hookEventName`, `permissionDecisionReason`, and mirrored stderr. |  |
| #56 | `Medium` | `SEC` | 2026-09-10 | 2026-09-17 | `c98c982` | [`P18-glob-path-traversal-precision.md`](P18-glob-path-traversal-precision.md): Implemented pure-Bash `glob_to_regex` compiler, safe bracket grammar (`[...]`), and 3-tier fast path matching in `blast-radius-guard.sh` and `aapp-pre-commit`. |  |
| #68 | `High` | `SEC` | 2026-09-16 | 2026-09-17 | `98bf317` | [`P16-frozen-plan-immutability.md`](P16-frozen-plan-immutability.md): Implemented Section 2b design-lock immutability engine in `templates/aapp-pre-commit`, refusing in-flight edits to §2 and §4 of frozen blueprints while keeping checkboxes and changelog writable. |  |
| #57 | `Medium` | `SEC` | 2026-09-10 | 2026-09-17 | `df1828b` | [`P17-blast-radius-precision-and-isolation.md`](P17-blast-radius-precision-and-isolation.md): Structurally dissolved by Single-Active-Plan Architecture and per-worktree pointer buffer isolation (`.git/aapp_active_plan`). |  |
| #50 | `High` | `CLI` | 2026-09-10 | 2026-09-17 | `46539f8` | Resolved target repository to project root when drop-in kit is executed outside kit directory. |  |
| #51 | `High` | `CLI` | 2026-09-10 | 2026-09-17 | `ac7d9a1` | Gated self-consumption on content signature and pristine git status, and added `--keep` flag to install and init. |  |
| #71 | `Medium` | `HOOK` | 2026-09-18 | 2026-09-18 | `1f92ce4` | Added Section 1b Portability & Relative Path Invariant check in `templates/aapp-pre-commit` and governance rules in `templates/AGENTS.md` and `.agents/AGENTS.md`, mechanically rejecting `file:///` URIs and absolute paths in staged files; 4 regression tests (68 pre-commit tests, 260 total passing). |  |
| #76 | `Low` | `HOOK` | 2026-09-21 | 2026-09-29 | `4e11c93` | [`P28-conciseness-enforcement-and-changelog-governance.md`](P28-conciseness-enforcement-and-changelog-governance.md): Enforced single-line changelog bullets (<= 300 chars) in `aapp-pre-commit` and commit body conciseness/line-width ceilings in `aapp-commit-msg`. |  |
