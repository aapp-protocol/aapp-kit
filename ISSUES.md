# 🐛 Issues: Audit Trail & Technical Backlog

Canonical issue record for the AAPP kit itself. Findings from the 2026-09-09 full sweep of
`aapp`, `lib/`, `templates/`, `tests/`, `README.md`, and `MANUAL.md`.

**Status values:** 🟡 `Incubated` (recorded, unscheduled) · 🔵 `Planned` (promoted to a blueprint) · 🟠 `In Progress` · ✅ `Resolved`

> ### 📏 Issue Authoring Invariant (2–3 Sentences Max)
> Keep rows concise (2–3 sentences max per cell). Avoid lengthy essays. If a bug requires detailed architectural analysis or multi-step breakdown, summarize the symptom here and promote it to a plan (`/digest ISSUE-00X`).

**Verification:** all 3 suites pass (79/79). Every issue below was reproduced by hand.

---

## 🔴 1. Critical — Layer 1 enforcement does not work

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-001** | `templates/blast-radius-guard.sh:74-81`, `:209-217` | Deny payload uses `{"decision":"deny"}` — not a valid PreToolUse schema — and `exit 1`, which Claude Code treats as a *non-blocking* error. The write proceeds. Layer 1 is inert, self-protection included. | Emit `hookSpecificOutput.permissionDecision` and `exit 0`, or `exit 2`. | ✅ `Resolved` |
| **ISSUE-002** | `templates/blast-radius-guard.sh:55` | Only `./` is stripped; Claude Code sends **absolute** `file_path`. Every allow-case at `:87-97` matches relative paths only, so with an active plan even `CHANGELOG.md` and the plan file itself are denied. Must be fixed together with ISSUE-001. | Strip `$(git rev-parse --show-toplevel)/` before matching. | ✅ `Resolved` |
| **ISSUE-003** | `lib/cmd_init.sh:105-110` | Pre-2.42 git fallback runs `git rm -rf .` in the **main working tree**: uncommitted edits and staged new files are destroyed (verified). On a repo with zero commits, `git checkout $MAIN_BRANCH` fails and `set -e` aborts, leaving the repo on `plans`. | Require a clean tree, or use safe plumbing orphan branch creation. | ✅ `Resolved` |
| **ISSUE-035** | `blast-radius-guard.sh:120-126`, `aapp-pre-commit:75-81` | Backticked `NEW FILE` marker (e.g. `- [ ] `NEW FILE` -> `src/path`` in `plan-template.md:30`) is not stripped by `sub(/^[[:space:]]*NEW FILE[[:space:]]*->/, "", line)`. `match` captures `"NEW FILE"`, `item !~ /^(NEW FILE...)$/` evaluates to false, and the line is dropped without extracting the target file. Every new file target in blueprints following the official template is silently rejected. | Strip backticked and unbackticked markers: `sub(/^[[:space:]]*(`?(NEW FILE\|MODIFY\|DELETE\|ADD\|REPLACE)`?)?[[:space:]]*->[[:space:]]*/, "", line)`. | ✅ `Resolved` |

---

## 🟠 2. High

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-004** | `blast-radius-guard.sh:102`, `aapp-pre-commit:60` | `ls -1 .plans/current/*.md` is cwd-relative; run from a subdirectory the guard silently fails open. | `cd "$(git rev-parse --show-toplevel)" \|\| exit 0`. | ✅ `Resolved` |
| **ISSUE-005** | `templates/aapp-pre-commit:16` | `--diff-filter=ACMR` excludes `D`. Deleting an explicitly Out-of-Bounds file commits cleanly, with no CHANGELOG required (verified). | Include `D` in the blast-radius check. | ✅ `Resolved` |
| **ISSUE-006** | `lib/cmd_status.sh:67` | Unquoted `for P in $CURRENT_PLANS` — a plan named `my plan.md` reports as two plans with fabricated statuses. Spaces are tested everywhere else in the kit. | Use `find -print0` / `while read -r`. | ✅ `Resolved` |
| **ISSUE-007** | `MANUAL.md:427-440` | Documented `.claude/settings.json` puts `"command"` on the matcher object — invalid schema, hook silently never fires. Matcher also disagrees with `cmd_init.sh` (`Edit\|Write\|MultiEdit` vs `Write\|Edit\|NotebookEdit`). | Copy the real block from `cmd_init.sh:307-323`. | ✅ `Resolved` |
| **ISSUE-008** | `MANUAL.md:261` vs `aapp-pre-commit:57` | `SKIP_BLAST_RADIUS=1` does **not** bypass CHANGELOG enforcement, which runs first and unconditionally (verified). Breaks the documented emergency-hotfix path. | Move the check inside the guard, or correct the sentence. | ✅ `Resolved` |
| **ISSUE-036** | `templates/aapp-pre-commit:24` | `CORE_CODE_REGEX` omits shell extensions (`.sh`, `.bash`, `.zsh`) and extensionless executables (`aapp`). Modifying shell scripts or CLI binaries never increments `STAGED_CORE_COUNT`, bypassing `CHANGELOG.md` enforcement entirely for shell-based repositories. | Add `sh\|bash\|zsh` to `CORE_CODE_REGEX` and support extensionless scripts. | ✅ `Resolved` |
| **ISSUE-041** | `templates/blast-radius-guard.sh:45` | Large JSON payloads passed via command argument `"$RAW_INPUT"` exceed system `ARG_MAX` (>256KB on macOS), causing Python to crash with exit code 126. Because of `2>/dev/null || true`, `$PARSED` is empty, causing the guard to fail open and allow writes to any file outside the Blast Radius. | Stream JSON payload to Python via `stdin` (`sys.stdin`) instead of CLI arguments. | 🟡 `Incubated` |
| **ISSUE-043** | `lib/cmd_install.sh:27` | Running `aapp install` after `aapp develop` executes `rm -rf "${SHARE_DIR:?}/lib"` through the symlink. This traverses into the development clone and destroys `lib/` in the active source repository. | Unlink `$SHARE_DIR` and `$BIN_DIR/aapp` symlinks before creating directories and copying. | 🟡 `Incubated` |

---

## 🟡 3. Medium — scripts

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-009** | `blast-radius-guard.sh:31-41` | `python3` is a hard dependency for parsing and for emitting the decision; when absent the guard fails open silently. Contradicts `MANUAL.md:220` ("zero dependency"). | Add pure-POSIX JSON output & fallback in `deny_action()`. | ✅ `Resolved` |
| **ISSUE-010** | `lib/cmd_init.sh:327` | Without `python3` the `.claude/settings.json` merge is a silent no-op — the user believes the guard is wired. | Warn when the merge is skipped. | ✅ `Resolved` |
| **ISSUE-011** | `lib/cmd_status.sh:43-59` | `elif` means `ISSUES.md` is never read once `issues_road_map.md` exists (always, post-init). AGENTS.md specifies both. | Read both files in status briefing. | ✅ `Resolved` |
| **ISSUE-012** | `lib/cmd_status.sh:84` | Counts the pickup template's own placeholder — a fresh project always reports "1 unworked idea". | Skip bracketed placeholder lines in `pickup.md`. | ✅ `Resolved` |
| **ISSUE-013** | `lib/cmd_upgrade.sh:36,40` | `AAPP_VERSION` is set inside a subshell, so the completion line reports the **old** version. Upgrade also prints `🧹 Consumed installer directory '/tmp/aapp-upgrade-XXXX'`. | Capture version outside the subshell; suppress the consume notice on upgrade. | ✅ `Resolved` |
| **ISSUE-014** | `cmd_install.sh:91`, `cmd_init.sh:398` | Self-consuming `rm -rf` is gated on hardcoded `agent-planning-kit`. Should also protect `aapp-develop-kit` development root without adding extra flags. | Exempt `aapp-develop-kit` and `agent-planning-kit` in self-consumption check. | ✅ `Resolved` |
| **ISSUE-015** | `lib/cmd_init.sh:15-16` | Drop-in `init` always targets the **parent** repo. Inside a standalone kit clone it prints a misleading "No git repository here"; if the parent is a repo (e.g. dotfiles) it silently initializes that instead. | Detect and reject/confirm the surprising target. | ✅ `Resolved` |
| **ISSUE-016** | `templates/AGENTS.md:11` vs `aapp:9` | Protocol marker version is hardcoded independently of `AAPP_VERSION`; `cmd_init.sh:212` can print "updated to v1.0.1" while writing a `v1.0.0` marker. | Stamp the marker from `$AAPP_VERSION` at sync time. | ✅ `Resolved` |
| **ISSUE-017** | `lib/cmd_init.sh:199-210` | A target `AGENTS.md` with a `START` marker but no `END` marker silently deletes everything after it. | Bail out when `END` is missing. | ✅ `Resolved` |
| **ISSUE-018** | `lib/cmd_init.sh:56-63`, `cmd_upgrade.sh:35` | Dead code: `IS_RESTORE` and `AAPP_IS_DROP_IN` are set and never read (confirmed by shellcheck SC2034). | Remove dead variables. | ✅ `Resolved` |
| **ISSUE-019** | `.claude/settings.json` matcher | `Bash` is unmatched, so `cat > file` walks past Layer 1. AGENTS.md handles this in prose; `README.md:37` overstates it as "refused at write-time and commit-time". | Soften the README claim. | ✅ `Resolved` |
| **ISSUE-037** | `lib/cmd_status.sh:51` | `grep -E '^\| ISSUE-[0-9]+' ISSUES.md \| grep -v 'DONE'` fails on standard `templates/issues.md` rows. The template uses bold markdown (`\| **ISSUE-001** \| ...`), causing the regex to match 0 rows, and status is `Resolved` rather than `DONE`. | Update regex to `grep -E '^\s*\|\s*(\*\*)?ISSUE-[0-9]+'` and filter on `Resolved`. | ✅ `Resolved` |
| **ISSUE-038** | `lib/cmd_init.sh:259-291` | When `.githooks/pre-commit` is a non-shell script (Python/Perl/Node) and `core.hooksPath` is unset, `cmd_init.sh` configures `core.hooksPath .githooks` but leaves `HOOK_MANAGER_NOTICE=0` and skips auto-wiring. No warning is given that manual wiring is required, leaving enforcement dead. | Set `HOOK_MANAGER_NOTICE=1` when `.githooks/pre-commit` exists and is non-shell. | ✅ `Resolved` |
| **ISSUE-042** | `lib/cmd_status.sh:56` | `TOP_ISSUES` greps `^[0-9]+\.|^- \[` in `issues_road_map.md` without filtering on `Resolved` or `DONE`. When roadmap issues are marked resolved, `aapp status` continues printing them as open bugs and masks clean status. | Add `grep -v -E '✅|Resolved|DONE|\[x\]|\[X\]'` to `TOP_ISSUES` pipeline. | 🟡 `Incubated` |
| **ISSUE-044** | `lib/cmd_init.sh:205` | Uses `sed -i` without an extension argument, which fails on macOS BSD `sed`. The error is swallowed by `|| true`, silently skipping dynamic version stamping in `.agents/AGENTS.md`. | Stamp protocol version dynamically during `awk` block extraction instead of `sed -i`. | 🟡 `Incubated` |
| **ISSUE-045** | `lib/cmd_uninstall.sh:16,23` | Tests `$BIN` and `$SHARE_DIR` with `[ -f ]` and `[ -d ]`, which evaluate to false on broken symlinks. If develop mode source was moved or deleted, broken symlinks in `~/.local/bin` and `~/.local/share` are left behind. | Use `[ -e "$BIN" ] || [ -L "$BIN" ]` and `[ -e "$SHARE_DIR" ] || [ -L "$SHARE_DIR" ]`. | 🟡 `Incubated` |
| **ISSUE-046** | `templates/blast-radius-guard.sh:52-53,62` | Uses deprecated POSIX `head -1` in POSIX fallback and unquoted `$REPO_ROOT` pattern expansion (SC2295). Paths with glob characters fail to strip the repository root. | Change to `head -n 1` and quote pattern `"${TARGET_FILE#"$REPO_ROOT"/}"`. | 🟡 `Incubated` |
| **ISSUE-047** | `lib/cmd_status.sh:89,106` | Plan status grep requires `* **Status:**`, falling back to `🟡 Active` for dash-listed plans. `pickup.md` counts completed `[x]` ideas, and `wc -l` on macOS emits leading spaces. | Support `-` and `*` bullets, filter `\[x\]`, and strip whitespace in pickup count. | 🟡 `Incubated` |
| **ISSUE-048** | `templates/pre-commit:14`, `aapp-pre-commit:265` | `[ -x ]` in `pre-commit` skips enforcement if execute bit was dropped on checkout. JSON schema check in `aapp-pre-commit` relies on system default locale instead of explicit UTF-8. | Execute via `bash "$REPO_ROOT/.githooks/aapp-pre-commit"` and specify `encoding='utf-8'`. | 🟡 `Incubated` |

---

## 📘 4. Documentation drift & missing sections

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-020** | `README.md:18-19` | Two broken TOC anchors; `Conflict Handling & Silent-Skipping Warnings` **does not exist** (replaced by *Seamless Adoption & In-Place Protocol Upgrades*, itself absent from the TOC). | Regenerate the TOC. | ✅ `Resolved` |
| **ISSUE-021** | `README.md:181` vs `cmd_init.sh:390` | README tells users to wire `aapp-pre-commit`; init actually prints `pre-commit`. Auto-wiring at `cmd_init.sh:264` uses `aapp-pre-commit` — the code disagrees with itself too. | Pick one (master runner preferred) and align all three. | ✅ `Resolved` |
| **ISSUE-022** | `README.md:253,256,264` | Test counts stale: says 69 total / 26 write-guard; actual is **75 / 28**. | Update. | ✅ `Resolved` |
| **ISSUE-023** | `README.md:222-228` | Command table out of sync with the AGENTS.md contract: `/digest` described wrongly; `/abort` listed but defined nowhere (only an empty `.plans/aborted/`); `/release` missing. | Sync with AGENTS.md, or implement `/abort`. | ✅ `Resolved` |
| **ISSUE-024** | `MANUAL.md:19,36-41` | Broken §3 and §7 anchors; `Native Git Hooks` **section missing entirely**; Husky/Lefthook/Pre-Commit anchors all wrong; three existing §7 sections absent from the TOC. | Rewrite the §7 sub-TOC; add or drop *Native Git Hooks*. | ✅ `Resolved` |
| **ISSUE-025** | `MANUAL.md:234` | Claims `bash -n` and `node --check` syntax validation. Neither exists — only python3, `php -l`, JSON (`aapp-pre-commit:204-234`). | Fix the claim, or implement the validators. | ✅ `Resolved` |
| **ISSUE-026** | `MANUAL.md:262` | "No-Plan Grace Period … logs a notice" — nothing is logged. The "only templates/placeholders" clause has no implementation. | Correct the text. | ✅ `Resolved` |
| **ISSUE-027** | `MANUAL.md:109-128`, `:189` | Documents an orphan-branch algorithm the code does not use (the documented one is safer — see ISSUE-003), and enshrines the bug as design: "Edit Denied (exit code 1 / hook error)". | Align after ISSUE-001/003. | ✅ `Resolved` |
| **ISSUE-028** | `templates/issues.md:20` | Links `../.plans/current/…`, but `ISSUES.md` ships to the **repo root** — broken in every generated project. | Drop the `../`. | ✅ `Resolved` |
| **ISSUE-029** | `templates/architecture.md:24-25` | Tree places `pickup.md` and `state_matrix.md` under `.plans/current/`; init writes them to `.plans/`. | Correct the tree. | ✅ `Resolved` |
| **ISSUE-030** | `templates/AGENTS.md:12` | Says "MANAGED BY AAPP-INIT" — that binary no longer exists post-unification. | Say `aapp init`. | ✅ `Resolved` |
| **ISSUE-039** | `examples/example_plan_unified_install_and_upgrade.md` | Inconsistent filename casing (`snake_case` vs `kebab-case`) and contains outdated references to standalone `aapp-init` / `aapp-install` binaries rather than the unified `aapp` CLI. | Rename file to `kebab-case` and update binary references to `aapp init` / `aapp install`. | ✅ `Resolved` |

---

## 🧪 5. Test-suite gaps (why the above went unnoticed)

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-031** | `tests/write-guard_test.sh:26-32` | `call_guard_json` is defined and **never called** — every assertion uses relative CLI args, the one path Claude Code never takes. This single gap hides ISSUE-001 and ISSUE-002. | Route `check_decision` through the JSON payload with absolute paths. | ✅ `Resolved` |
| **ISSUE-032** | `tests/write-guard_test.sh:134` | Asserts `decision == 'deny'` — pins the invalid schema as correct. | Assert on `hookSpecificOutput`. | ✅ `Resolved` |
| **ISSUE-033** | `tests/write-guard_test.sh:112-117` | Guard is run against garbage stdin, then `assert_rc` is *defined* on the next line — that first invocation asserts nothing; line 117 duplicates it. | Delete the dead call; hoist the helpers. | ✅ `Resolved` |
| **ISSUE-034** | `tests/` | No coverage for the pre-2.42 git fallback (ISSUE-003), deletions (ISSUE-005), or a non-root cwd (ISSUE-004). | Add regression cases. | ✅ `Resolved` |
| **ISSUE-040** | `tests/pre-commit_test.sh:66` | Test 2b tests unbackticked `- [ ] NEW FILE -> `src/new_mod.py``, masking the parser bug where backticked `` `NEW FILE` `` (from `plan-template.md`) drops declared target files. | Add test assertions for backticked markers (` `NEW FILE` `, ` `MODIFY` `, etc.). | ✅ `Resolved` |

---

## 📦 6. Resolved Issues & Fix History

| Issue ID | Component | Summary & Resolution | Resolved In | Date |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-001** | `blast-radius-guard` | Added `hookSpecificOutput.permissionDecision` JSON output and exit code 2. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-002** | `blast-radius-guard` | Stripped `$REPO_ROOT/` from absolute target file paths. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-003** | `cmd_init` | Used non-destructive git plumbing `commit-tree` orphan branch creation. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-004** | `blast-radius-guard` / `aapp-pre-commit` | Changed directory to `$REPO_ROOT` to prevent cwd-relative fail-open. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-005** | `aapp-pre-commit` | Added `D` (deletions) to `--diff-filter` to enforce Out-of-Bounds on deleted files. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-006** | `cmd_status` | Used NUL-delimited `find` iteration for plan files with spaces. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-007** | `MANUAL.md` | Aligned `.claude/settings.json` hook configuration with valid PreToolUse schema. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-008** | `aapp-pre-commit` | Moved `SKIP_BLAST_RADIUS=1` bypass check to the top before CHANGELOG check. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-009** | `blast-radius-guard` | Added pure-POSIX JSON fallback when `python3` is missing. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-010** | `cmd_init` | Added warning notice when `.claude/settings.json` merge is skipped without python3. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-011** | `cmd_status` | Briefing reads both `ISSUES.md` and `issues_road_map.md`. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-012** | `cmd_status` | Filtered bracketed placeholders in `pickup.md`. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-013** | `cmd_upgrade` | Exported `AAPP_VERSION` and suppressed consumer notice on upgrades. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-014** | `cmd_install` / `cmd_init` | Exempted `aapp-develop-kit` and `agent-planning-kit` in self-consumption check. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-015** | `cmd_init` | Handled standalone clone target detection in drop-in mode. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-016** | `cmd_init` | Stamped protocol marker version dynamically from `AAPP_VERSION`. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-017** | `cmd_init` | Safeguarded against data loss on missing `<!-- AAPP-PROTOCOL:END -->` tag. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-018** | `cmd_init` / `cmd_upgrade` | Removed unused dead variables `IS_RESTORE` and `AAPP_IS_DROP_IN`. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-019** | `README.md` | Softened direct shell redirection claims. | `plan-v1.0.2-cli-reliability-and-posix-fallback` | 2026-09-09 |
| **ISSUE-020** | `README.md` | Regenerated Table of Contents and fixed broken section anchors. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-021** | `README.md` / `MANUAL.md` | Clarified master runner `.githooks/pre-commit` vs managed engine `.githooks/aapp-pre-commit`. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-022** | `README.md` / `MANUAL.md` | Synchronized test suite case counts across documentation (80 total). | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-023** | `README.md` | Aligned slash command lifecycle table with AGENTS.md protocol. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-024** | `MANUAL.md` | Synchronized Table of Contents and Section 7 sub-TOC anchors. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-025** | `MANUAL.md` | Corrected syntax validation claims to reflect Python, PHP, and JSON checkers. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-026** | `MANUAL.md` | Clarified No-Plan Grace Period description for active blueprints. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-027** | `MANUAL.md` | Aligned orphan branch plumbing documentation and exit code 2 error handling. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-028** | `templates/issues.md` | Fixed relative plan link path from `../.plans/current/` to `current/`. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-029** | `templates/architecture.md` | Corrected structural mapping tree for `.plans/` files. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-030** | `templates/AGENTS.md` | Updated comment marker reference from `AAPP-INIT` to `aapp init`. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-031** | `write-guard_test` | Executed `call_guard_json` with absolute paths on every assertion. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-032** | `write-guard_test` | Verified `hookSpecificOutput.permissionDecision` in response schema. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-033** | `write-guard_test` | Cleaned up helper definitions and test assertions. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-034** | `tests/` | Added regression test coverage for deletions, fallback init, and develop mode. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-035** | `blast-radius-guard` / `aapp-pre-commit` | Fixed awk plan parser to strip backticked/unbackticked markers before target extraction. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-036** | `aapp-pre-commit` | Added `sh\|bash\|zsh` and extensionless binaries to `CORE_CODE_REGEX`. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-037** | `cmd_status` | Supported bold markdown `| **ISSUE-001** |` and filtered `Resolved` status. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-038** | `cmd_init` | Added hook manager warning notice when custom non-shell hook exists. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-039** | `examples/` | Modernized and renamed example blueprint to `example-plan-unified-install-and-upgrade.md`. | `plan-v1.0.3-docs-templates-and-test-alignment` | 2026-09-10 |
| **ISSUE-040** | `pre-commit_test` | Added regression test coverage for backticked `NEW FILE` and `MODIFY` markers. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
