# 🐛 Issues: Audit Trail & Technical Backlog

Canonical issue record for the AAPP kit itself. Findings from the 2026-09-09 full sweep of
`aapp`, `lib/`, `templates/`, `tests/`, `README.md`, and `MANUAL.md`.

**Status values:** 🟡 `Incubated` (recorded, unscheduled) · 🔵 `Planned` (promoted to a blueprint) · 🟠 `In Progress` · ✅ `Resolved`

**Verification:** all 3 suites pass (75/75). Every issue below was reproduced by hand.

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
| **ISSUE-007** | `MANUAL.md:416-429` | Documented `.claude/settings.json` puts `"command"` on the matcher object — invalid schema, hook silently never fires. Matcher also disagrees with `cmd_init.sh` (`Edit\|Write\|MultiEdit` vs `Write\|Edit\|NotebookEdit`). | Copy the real block from `cmd_init.sh:307-323`. | 🟡 `Incubated` |
| **ISSUE-008** | `MANUAL.md:261` vs `aapp-pre-commit:57` | `SKIP_BLAST_RADIUS=1` does **not** bypass CHANGELOG enforcement, which runs first and unconditionally (verified). Breaks the documented emergency-hotfix path. | Move the check inside the guard, or correct the sentence. | ✅ `Resolved` |
| **ISSUE-036** | `templates/aapp-pre-commit:24` | `CORE_CODE_REGEX` omits shell extensions (`.sh`, `.bash`, `.zsh`) and extensionless executables (`aapp`). Modifying shell scripts or CLI binaries never increments `STAGED_CORE_COUNT`, bypassing `CHANGELOG.md` enforcement entirely for shell-based repositories. | Add `sh\|bash\|zsh` to `CORE_CODE_REGEX` and support extensionless scripts. | ✅ `Resolved` |

---

## 🟡 3. Medium — scripts

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-009** | `blast-radius-guard.sh:31-41` | `python3` is a hard dependency for parsing and for emitting the decision; when absent the guard fails open silently. Contradicts `MANUAL.md:220` ("zero dependency"). | Add pure-POSIX JSON output & fallback in `deny_action()`. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-010** | `lib/cmd_init.sh:327` | Without `python3` the `.claude/settings.json` merge is a silent no-op — the user believes the guard is wired. | Warn when the merge is skipped. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-011** | `lib/cmd_status.sh:43-59` | `elif` means `ISSUES.md` is never read once `issues_road_map.md` exists (always, post-init). AGENTS.md specifies both. | Read both files in status briefing. | ✅ `Resolved` |
| **ISSUE-012** | `lib/cmd_status.sh:84` | Counts the pickup template's own placeholder — a fresh project always reports "1 unworked idea". | Skip bracketed placeholder lines in `pickup.md`. | ✅ `Resolved` |
| **ISSUE-013** | `lib/cmd_upgrade.sh:36,40` | `AAPP_VERSION` is set inside a subshell, so the completion line reports the **old** version. Upgrade also prints `🧹 Consumed installer directory '/tmp/aapp-upgrade-XXXX'`. | Capture version outside the subshell; suppress the consume notice on upgrade. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-014** | `cmd_install.sh:91`, `cmd_init.sh:398` | Self-consuming `rm -rf` is gated on the hardcoded name `agent-planning-kit`, documented nowhere; every documented flow clones to `aapp-kit` and is therefore always deleted. | Document the exemption, or add an explicit `--keep` flag. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-015** | `lib/cmd_init.sh:15-16` | Drop-in `init` always targets the **parent** repo. Inside a standalone kit clone it prints a misleading "No git repository here"; if the parent is a repo (e.g. dotfiles) it silently initializes that instead. | Detect and reject/confirm the surprising target. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-016** | `templates/AGENTS.md:11` vs `aapp:9` | Protocol marker version is hardcoded independently of `AAPP_VERSION`; `cmd_init.sh:212` can print "updated to v1.0.1" while writing a `v1.0.0` marker. | Stamp the marker from `$AAPP_VERSION` at sync time. | ✅ `Resolved` |
| **ISSUE-017** | `lib/cmd_init.sh:199-210` | A target `AGENTS.md` with a `START` marker but no `END` marker silently deletes everything after it. | Bail out when `END` is missing. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-018** | `lib/cmd_init.sh:56-63`, `cmd_upgrade.sh:35` | Dead code: `IS_RESTORE` and `AAPP_IS_DROP_IN` are set and never read (confirmed by shellcheck SC2034). | Remove dead variables. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-019** | `.claude/settings.json` matcher | `Bash` is unmatched, so `cat > file` walks past Layer 1. AGENTS.md handles this in prose; `README.md:37` overstates it as "refused at write-time and commit-time". | Soften the README claim. | 🔵 `Planned` -> [`current/plan-v1.0.2-cli-reliability-and-posix-fallback.md`](current/plan-v1.0.2-cli-reliability-and-posix-fallback.md) |
| **ISSUE-037** | `lib/cmd_status.sh:51` | `grep -E '^\| ISSUE-[0-9]+' ISSUES.md \| grep -v 'DONE'` fails on standard `templates/issues.md` rows. The template uses bold markdown (`\| **ISSUE-001** \| ...`), causing the regex to match 0 rows, and status is `Resolved` rather than `DONE`. | Update regex to `grep -E '^\s*\|\s*(\*\*)?ISSUE-[0-9]+'` and filter on `Resolved`. | ✅ `Resolved` |
| **ISSUE-038** | `lib/cmd_init.sh:259-291` | When `.githooks/pre-commit` is a non-shell script (Python/Perl/Node) and `core.hooksPath` is unset, `cmd_init.sh` configures `core.hooksPath .githooks` but leaves `HOOK_MANAGER_NOTICE=0` and skips auto-wiring. No warning is given that manual wiring is required, leaving enforcement dead. | Set `HOOK_MANAGER_NOTICE=1` when `.githooks/pre-commit` exists and is non-shell. | ✅ `Resolved` |

---

## 📘 4. Documentation drift & missing sections

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-020** | `README.md:18-19` | Two broken TOC anchors; `Conflict Handling & Silent-Skipping Warnings` **does not exist** (replaced by *Seamless Adoption & In-Place Protocol Upgrades*, itself absent from the TOC). | Regenerate the TOC. | 🟡 `Incubated` |
| **ISSUE-021** | `README.md:181` vs `cmd_init.sh:390` | README tells users to wire `aapp-pre-commit`; init actually prints `pre-commit`. Auto-wiring at `cmd_init.sh:264` uses `aapp-pre-commit` — the code disagrees with itself too. | Pick one (master runner preferred) and align all three. | 🟡 `Incubated` |
| **ISSUE-022** | `README.md:253,256,264` | Test counts stale: says 69 total / 26 write-guard; actual is **75 / 28**. | Update. | 🟡 `Incubated` |
| **ISSUE-023** | `README.md:222-228` | Command table out of sync with the AGENTS.md contract: `/digest` described wrongly; `/abort` listed but defined nowhere (only an empty `.plans/aborted/`); `/release` missing. | Sync with AGENTS.md, or implement `/abort`. | 🟡 `Incubated` |
| **ISSUE-024** | `MANUAL.md:19,36-41` | Broken §3 and §7 anchors; `Native Git Hooks` **section missing entirely**; Husky/Lefthook/Pre-Commit anchors all wrong; three existing §7 sections absent from the TOC. | Rewrite the §7 sub-TOC; add or drop *Native Git Hooks*. | 🟡 `Incubated` |
| **ISSUE-025** | `MANUAL.md:234` | Claims `bash -n` and `node --check` syntax validation. Neither exists — only python3, `php -l`, JSON (`aapp-pre-commit:204-234`). | Fix the claim, or implement the validators. | 🟡 `Incubated` |
| **ISSUE-026** | `MANUAL.md:262` | "No-Plan Grace Period … logs a notice" — nothing is logged. The "only templates/placeholders" clause has no implementation. | Correct the text. | 🟡 `Incubated` |
| **ISSUE-027** | `MANUAL.md:109-128`, `:189` | Documents an orphan-branch algorithm the code does not use (the documented one is safer — see ISSUE-003), and enshrines the bug as design: "Edit Denied (exit code 1 / hook error)". | Align after ISSUE-001/003. | 🟡 `Incubated` |
| **ISSUE-028** | `templates/issues.md:20` | Links `../.plans/current/…`, but `ISSUES.md` ships to the **repo root** — broken in every generated project. | Drop the `../`. | 🟡 `Incubated` |
| **ISSUE-029** | `templates/architecture.md:24-25` | Tree places `pickup.md` and `state_matrix.md` under `.plans/current/`; init writes them to `.plans/`. | Correct the tree. | 🟡 `Incubated` |
| **ISSUE-030** | `templates/AGENTS.md:12` | Says "MANAGED BY AAPP-INIT" — that binary no longer exists post-unification. | Say `aapp init`. | 🟡 `Incubated` |
| **ISSUE-039** | `examples/example_plan_unified_install_and_upgrade.md` | Inconsistent filename casing (`snake_case` vs `kebab-case`) and contains outdated references to standalone `aapp-init` / `aapp-install` binaries rather than the unified `aapp` CLI. | Rename file to `kebab-case` and update binary references to `aapp init` / `aapp install`. | 🟡 `Incubated` |

---

## 🧪 5. Test-suite gaps (why the above went unnoticed)

| ID | Location | Problem | Fix | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-031** | `tests/write-guard_test.sh:26-32` | `call_guard_json` is defined and **never called** — every assertion uses relative CLI args, the one path Claude Code never takes. This single gap hides ISSUE-001 and ISSUE-002. | Route `check_decision` through the JSON payload with absolute paths. | ✅ `Resolved` |
| **ISSUE-032** | `tests/write-guard_test.sh:134` | Asserts `decision == 'deny'` — pins the invalid schema as correct. | Assert on `hookSpecificOutput`. | ✅ `Resolved` |
| **ISSUE-033** | `tests/write-guard_test.sh:112-117` | Guard is run against garbage stdin, then `assert_rc` is *defined* on the next line — that first invocation asserts nothing; line 117 duplicates it. | Delete the dead call; hoist the helpers. | 🟡 `Incubated` |
| **ISSUE-034** | `tests/` | No coverage for the pre-2.42 git fallback (ISSUE-003), deletions (ISSUE-005), or a non-root cwd (ISSUE-004). | Add regression cases. | 🟡 `Incubated` |
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
| **ISSUE-008** | `aapp-pre-commit` | Moved `SKIP_BLAST_RADIUS=1` bypass check to the top before CHANGELOG check. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-035** | `blast-radius-guard` / `aapp-pre-commit` | Fixed awk plan parser to strip backticked/unbackticked markers before target extraction. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-036** | `aapp-pre-commit` | Added `sh\|bash\|zsh` and extensionless binaries to `CORE_CODE_REGEX`. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-037** | `cmd_status` | Supported bold markdown `| **ISSUE-001** |` and filtered `Resolved` status. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-038** | `cmd_init` | Added hook manager warning notice when custom non-shell hook exists. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-031** | `write-guard_test` | Executed `call_guard_json` with absolute paths on every assertion. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-032** | `write-guard_test` | Verified `hookSpecificOutput.permissionDecision` in response schema. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
| **ISSUE-040** | `pre-commit_test` | Added regression test coverage for backticked `NEW FILE` and `MODIFY` markers. | `plan-v1.0.1-core-fixes` | 2026-09-09 |
