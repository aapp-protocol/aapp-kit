# 🗺️ Plan P-9: Guard Path Authorization — External Allowlist & Tool-Matcher Coverage
* **Created:** 2026-09-15 | **Last Refined:** 2026-09-15
* **Target Issue / Milestone:** `#65` (external-path false denial) — also closes the matcher half of `#53`
* **Plan ID:** P-9
* **Status:** ✅ Done
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### 🔒 Execution Note: engine copies are write-protected
> `blast-radius-guard` Section 2 hard-blocks `.githooks/*` and `.agents/skills/aapp-*`. Never edit those directly. Edit `templates/blast-radius-guard.sh` and run `aapp init` to propagate. **This plan modifies the guard itself** — after every guard change, re-run `aapp init` and re-run `tests/write-guard_test.sh` before continuing.

> ### 🚧 Do NOT introduce version numbers
> This project has no git tag and no release. `AAPP_VERSION` is a placeholder. Do not add, bump, or infer a version anywhere in this plan's execution.

---

## 1. Context & Architectural Goal

**What.** Close two related gaps in Layer 1 (the write-time blast-radius guard):

* **(a) False denial of every path outside the repository.** `blast-radius-guard` normalizes only paths under `$REPO_ROOT`. Anything absolute and external stays absolute, misses Sections 2–3, and falls into Section 4's deny branch. Verified 2026-09-15:

  ```
  /home/user/.claude/projects/x/memory/note.md   exit=2  "outside the declared Target Files"
  /home/user/.config/foo/bar.toml                exit=2  "outside the declared Target Files"
  /tmp/scratch/anything.txt                      exit=2  "outside the declared Target Files"
  /home/user/notes.md                            exit=2  "outside the declared Target Files"
  ```

  This is **not agent-specific**. Every coding agent persists memory, notes, or scratch state outside the project — Claude Code under `~/.claude/`, Codex under `~/.codex/`, Cursor under `~/.cursor/`, others under `$XDG_CONFIG_HOME` or `$TMPDIR`. In any AAPP-initialized repository, all of it is refused. This is an adoption defect that fires on first use for every adopter, on every agent.

* **(b) The `PreToolUse` matcher does not cover every write path.** `templates/claude/settings.json` and `lib/cmd_init.sh:401,455` register `"matcher": "Write|Edit|NotebookEdit"`. `MultiEdit` is absent (this is the standing half of `#53`) and `Bash` is absent, so any write performed via heredoc, `sed -i`, `tee`, or redirection is never evaluated by Layer 1.

**Why one plan.** Both are the same root shape: **the guard is tool-shaped, not path-shaped.** They also compound each other. Every false denial from (a) teaches an agent that the guard is noise and that the only route that works is a shell command — which is precisely the unguarded path in (b). Fixing (a) alone leaves the bypass open; fixing (b) alone converts a mild annoyance into a hard wall. Shipped together, Layer 1 denies less often and means more when it does.

**Constraints.**
* Zero dependency, POSIX-portable bash. No Python requirement beyond the existing optional JSON fast path.
* The guard's fail-open contract on malformed input is preserved (`blast-radius-guard.sh:8`).
* Allowlist locations **must** be user-configurable — install paths vary by operating system, agent, and personal preference. A hardcoded list cannot be correct for every adopter.
* Zero regression: all existing cases in `tests/write-guard_test.sh` must still pass.

**Non-goal.** This plan does not attempt to make Layer 1 a security boundary against a determined agent. Bash is not interceptable by path, so Layer 1 is and remains a guardrail against *accident and drift*; Layer 2 (`aapp-pre-commit`) stays the authoritative gate. The plan makes that boundary explicit rather than implied.

---

## 2. Technical Blueprint

### A. Verified Baseline (measured, not assumed)

| Probe | Current verdict | Denying section |
| :--- | :--- | :--- |
| `~/.claude/settings.json` | DENY | **Section 2** (self-protection) |
| `~/.claude/skills/aapp-done/SKILL.md` | DENY | **Section 2** (self-protection) |
| `~/.claude/projects/x/memory/n.md` | DENY | Section 4 (no active plan) ← *the false positive* |
| `~/.config/foo/bar.toml`, `/tmp/x`, `~/notes.md` | DENY | Section 4 (no active plan) ← *the false positive* |
| `src/totally_random.py` | DENY | Section 4 (correct) |

**Load-bearing discovery:** Section 2's patterns are written with `*/` prefixes (`*/.claude/settings.json`, `*/.claude/skills/aapp-*`, `*/.githooks/*`), so they **already match absolute paths**. An allowlist inserted *after* Section 2 therefore cannot reopen hook configuration or governance skills, no matter how broad a prefix the user writes. This property is what makes a user-editable allowlist safe, and it must be asserted by tests so it cannot silently regress.

### B. New Evaluation Order

```text
1. Parse input (CLI arg or PreToolUse JSON)          [unchanged]
2. Canonicalize target path                          ← NEW  (§C)
3. Section 2  — Self-Protection            → DENY    [rules unchanged]
4. Section 2b — External Hard Deny         → DENY    ← NEW  (§E.2)
5. Section 2c — External Path Allowlist    → ALLOW   ← NEW  (§D)
6. Section 3  — Always-Allowed Invariants  → ALLOW   [unchanged]
7. Section 4  — Blast Radius validation    → ALLOW/DENY [unchanged]
```

**Ordering invariants (assert all three in tests):**
1. Self-protection precedes every allow rule. No allowlist entry can grant `~/.claude/settings.json`, `*/.agents/claude/*`, `*/.githooks/*`, or `*/skills/aapp-*`.
2. The external hard-deny list (§E.2) precedes the allowlist, so a broad user prefix such as `$HOME` still cannot reach credentials or shell rc files.
3. Canonicalization precedes all matching.

### C. Canonicalization — Mandatory Prerequisite

The guard contains **no `realpath` and no `readlink` anywhere today**. A prefix allowlist without canonicalization is a hole, not a feature:

```text
written:    /home/user/.claude/../000/agent-planning-kit/lib/cmd_init.sh
prefix `~/.claude/`  →  MATCHES  →  would be ALLOWED
resolves to: /home/user/000/agent-planning-kit/lib/cmd_init.sh
```

That is an engine file, outside every blast radius, reached through an allowlisted prefix. It is denied today only because no allowlist exists yet — the moment one is added without canonicalization, it becomes reachable.

**Implementation.** Mirror the existing optional-tool-with-POSIX-fallback idiom already used for JSON parsing (`blast-radius-guard.sh:34`):

```bash
canonicalize() {
    local p="$1"
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    if command -v realpath >/dev/null 2>&1; then
        realpath -m -- "$p" 2>/dev/null && return 0
    fi
    # POSIX fallback: collapse . and .. lexically, no filesystem access
    local out="" seg
    local IFS=/
    for seg in $p; do
        case "$seg" in
            ''|.) continue ;;
            ..)   out="${out%/*}" ;;
            *)    out="$out/$seg" ;;
        esac
    done
    printf '%s\n' "${out:-/}"
}
```

* Canonicalize **lexically**, not by resolving symlinks to their targets. Resolving symlinks would defeat Section 2's dual-path protection, which deliberately matches *both* ends of a symlink by string (see the inode-aliasing analysis in the archived skills blueprint). Lexical `..`/`.` collapse is exactly enough to close the traversal hole without reintroducing aliasing.
* Retain the **original, uncanonicalized string** for the denial message so the user sees the path they actually typed.
* Apply canonicalization to `$REPO_ROOT` as well before the prefix-strip, so a repo reached via a symlinked path still normalizes correctly.

### D. Allowlist Source & Precedence

The effective allowlist is the **union** of two tiers:

| Tier | Source | Purpose |
| :--- | :--- | :--- |
| 1 | Built-in defaults compiled into the guard (§E.1) | Zero-config correctness for the common agents |
| 2 | `git config --get-all aapp.allowPath` | Per-repo or global user additions for unusual layouts |

**Why `git config`.** It lives in `.git/config`, outside the working tree, so it is not reachable through `.agents/*` or `.plans/*` always-allow rules. It supports repeated keys natively (`--add` / `--get-all`), it is per-repo *and* globally overridable, and it is the idiom the lifecycle-hooks blueprint already selected for `aapp.hookTimeout`. Adding a second configuration mechanism would fragment the kit.

**Rejected locations, with reasons — do not revisit without new information:**

| Rejected | Reason |
| :--- | :--- |
| `.agents/guard-allowlist` | Section 3 makes `.agents/*` unconditionally always-allowed. An agent could widen its own allowlist in one edit. |
| `.plans/guard-allowlist` | Same defect: `.plans/*` is always-allowed. |
| `AAPP_ALLOW_PATHS` env var | An agent sets this in the same Bash invocation as its write. Not a boundary in any sense. |
| `.claude/settings.json` | Tool-specific. The kit is deliberately multi-agent; configuration must not live in one vendor's file. |

**Consequence:** because the allowlist now lives in `.git/config`, add `.git/config` and `*/.git/config` to Section 2 self-protection alongside `.git/hooks/*`. Without this, the file holding the allowlist is itself writable through the blast radius.

**Honest scope note for the executing agent:** none of the above is a boundary against a determined agent, because `Bash` is not intercepted (§F). The value of putting the list in `.git/config` is that it cannot be widened *by accident* or by an agent following the always-allow rules in good faith.

### E. Default Sets

#### E.1 Built-in allow defaults (multi-agent)

**These are candidates and MUST be empirically verified in Phase 0 — do not ship guessed paths.** Any path that cannot be confirmed against a real installation is dropped from the defaults and documented in `MANUAL.md` as a `git config` example instead.

| Prefix | Agent / purpose |
| :--- | :--- |
| `$HOME/.claude/` | Claude Code — per-project memory, todos, session state |
| `$HOME/.gemini/` | Google Antigravity — artifacts, brain transcripts, scratchpad state |
| `$HOME/.codex/` | OpenAI Codex CLI |
| `$HOME/.cursor/` | Cursor |
| `$HOME/.config/` and `$XDG_CONFIG_HOME` | XDG-conformant agents and tooling |
| `$HOME/.local/share/` and `$XDG_DATA_HOME` | XDG data, including `aapp-kit` itself |
| `$TMPDIR`, `/tmp/`, `/var/folders/` | Agent scratchpads (`/var/folders` is the macOS `$TMPDIR` root) |

**Prefix boundary hygiene:** Every directory prefix in the allowlist must be strictly normalized with a trailing `/` before evaluation. This prevents prefix aliasing where allowlisting `/home/user/.claude` might inadvertently match an unauthorized `/home/user/.claude_fake/*`.

Section 2 still wins inside these prefixes: `$HOME/.claude/settings.json`, `$HOME/.claude/skills/aapp-*`, and corresponding protected files remain hard-denied.

#### E.2 External hard deny (Section 2b) — never allowlistable

Users will write broad prefixes such as `$HOME`. These paths must be refused regardless of any allowlist entry:

```text
*/.ssh/*  */.gnupg/*  */.aws/*  */.azure/*  */.kube/*  */.docker/config.json
*/.netrc  */.npmrc  */.pypirc  */.git-credentials
*/.gitconfig  */.config/git/*
*/.bashrc  */.bash_profile  */.zshrc  */.zprofile  */.profile
*/.config/fish/*  */crontab  */.local/bin/*
```

Rationale: shell rc files and `~/.local/bin` are executable-on-next-login surfaces; the rest are credentials. An agent has no legitimate reason to write any of them under a planning protocol, and a user broadening their allowlist should not silently expose them.

### F. Tool-Matcher Coverage

* **`MultiEdit`** — add to the matcher in `templates/claude/settings.json` and both occurrences in `lib/cmd_init.sh` (lines 401 and 455). This closes the standing half of `#53`.
* **`Bash`** — a `PreToolUse` payload for `Bash` carries a command string, not a `file_path`. There is no reliable way to extract write targets from arbitrary shell (`sed -i`, `tee`, `>`, `>>`, `python -c`, `install`, `cp`, heredocs, and any of them behind a variable or a pipe). Attempting regex interception would produce both false negatives and false positives while implying a guarantee the guard cannot make.

  **Resolution: document the boundary rather than fake it.** `templates/AGENTS.md` must state plainly that Layer 1 evaluates file-writing *tools* only, that shell writes are not intercepted, and that Layer 2 (`aapp-pre-commit`) is the authoritative gate for anything reaching a commit. The existing "do not work around a refusal with a shell heredoc" instruction stays, now correctly framed as an honor-system rule with a named reason instead of an unexplained prohibition.

### G. Discoverability

`aapp init` prints the effective allowlist in its completion banner:

```text
➡️  Guard allowlist: 7 built-in + 2 from git config (aapp.allowPath)
```

Add one `MANUAL.md` example so users can extend it without reading the guard source:

```bash
git config --add aapp.allowPath "$HOME/.local/state/myagent/"
```

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: Empirical Verification (before any code)
- [x] Task 0.1: Confirm each candidate prefix in §E.1 against a real installation on this machine. Record what exists and what does not; drop every unverified path from the built-in defaults and move it to a documented `git config` example.
- [x] Task 0.2: Capture the current `tests/write-guard_test.sh` pass count as the regression baseline.
- [x] Task 0.3: Confirm the Section 2 absolute-path property from §A still holds (`~/.claude/settings.json` → Section 2, not Section 4). Every later ordering assertion depends on it.

### Phase 1: Canonicalization
- [x] Task 1.1: Add `canonicalize()` to `templates/blast-radius-guard.sh` per §C, with `realpath -m` primary and lexical POSIX fallback. Do not resolve symlinks.
- [x] Task 1.2: Canonicalize both `$REPO_ROOT` and `$TARGET_FILE` before the existing prefix-strip; preserve the original string for denial messages.
- [x] Task 1.3: Run `aapp init` to propagate, then run `tests/write-guard_test.sh` and confirm the Phase 0 baseline still passes with zero regressions.

### Phase 2: Allowlist & Hard-Deny Engine
- [x] Task 2.1: Add Section 2b external hard-deny patterns (§E.2), evaluated immediately after existing Section 2.
- [x] Task 2.2: Add `.git/config` and `*/.git/config` to Section 2 self-protection.
- [x] Task 2.3: Implement `resolve_allowlist()` — built-in defaults union `git config --get-all aapp.allowPath`, with `$HOME`/`$XDG_*`/`$TMPDIR` expansion and strict trailing-slash prefix semantics (guarantee every prefix ends with `/` to prevent prefix aliasing). Empty or unset variables must never expand to a bare `/`.
- [x] Task 2.4: Add Section 2c allowlist evaluation between the hard-deny block and Section 3.
- [x] Task 2.5: Run `aapp init`; re-run the write-guard suite.

### Phase 3: Matcher Coverage & Propagation
- [x] Task 3.1: Add `MultiEdit` to the matcher in `templates/claude/settings.json` (closes the matcher half of `#53`).
- [x] Task 3.2: Add `MultiEdit` to both matcher strings in `lib/cmd_init.sh` (lines 401 and 455) and to the settings-merge logic so existing adopters are upgraded non-destructively.
- [x] Task 3.3: Add the effective-allowlist line to the `aapp init` completion banner (§G).
- [x] Task 3.4: Run `aapp init` and verify `.claude/settings.json` receives the new matcher without clobbering user keys.

### Phase 4: Tests & Documentation
- [x] Task 4.1: Extend `tests/write-guard_test.sh` using the existing `check_decision <name> ALLOW|DENY <path>` and `call_guard_json <tool> <path>` helpers:
  - ALLOW: an allowlisted external memory path (`$HOME/.claude/projects/x/memory/n.md`).
  - ALLOW: an allowlisted Antigravity brain/artifact path (`$HOME/.gemini/antigravity-ide/brain/test.md`).
  - ALLOW: a path added only via `git config --add aapp.allowPath`.
  - DENY: an external path matching no allowlist entry.
  - DENY: `$HOME/.claude/settings.json` — proves Section 2 precedence over the allowlist.
  - DENY: `$HOME/.claude/skills/aapp-done/SKILL.md` — same, for governance skills.
  - DENY: `$HOME/.ssh/authorized_keys` **with `$HOME` explicitly allowlisted** — proves the §E.2 hard-deny precedence.
  - DENY: `$HOME/.claude/../<repo>/lib/cmd_init.sh` **with `~/.claude/` allowlisted** — proves canonicalization closes traversal.
  - Route every new case through **both** `call_guard_cli` and `call_guard_json` (the JSON path is the one agents actually take; `#31` records what happens when only the CLI path is tested).
- [x] Task 4.2: Add a `MultiEdit` assertion to the matcher coverage tests.
- [x] Task 4.3: Document in `MANUAL.md` — the evaluation order, the built-in defaults, `git config --add aapp.allowPath`, the hard-deny list, and the explicit statement that Layer 1 is write-tool-scoped while Layer 2 is authoritative.
- [x] Task 4.4: Update `README.md` guard overview with the allowlist concept in one short paragraph.
- [x] Task 4.5: Update `templates/AGENTS.md` per §F to state the shell-write boundary and the reason behind the no-workaround rule.
- [x] Task 4.6: Run all four suites (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`, `plan_resolver_test.sh`); report actual pass counts against the Phase 0 baseline. Do not assert a target number in advance.
- [x] Task 4.7: Update `CHANGELOG.md` under `## [Unreleased]`. **No version number.**

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **LOCKED** — greenlit for code execution)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Canonicalization, Section 2b hard-deny, Section 2c allowlist, `.git/config` self-protection.
- [ ] `templates/claude/settings.json` -> Add `MultiEdit` to the PreToolUse matcher.
- [ ] `lib/cmd_init.sh` -> Add `MultiEdit` to both matcher strings and the merge path; print effective allowlist in the completion banner.
- [ ] `templates/AGENTS.md` -> Document the Layer 1 / Layer 2 boundary and the reason for the no-workaround rule.
- [ ] `tests/write-guard_test.sh` -> Allowlist, precedence, traversal, and matcher assertions via both CLI and JSON entry points.
- [ ] `MANUAL.md` -> Guard evaluation order, defaults, `aapp.allowPath`, hard-deny list.
- [ ] `README.md` -> Short allowlist paragraph in the guard overview.
- [ ] `CHANGELOG.md` -> Unreleased entry citing `#65` and the matcher half of `#53`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/blast-radius-guard` -> Section 2 protected. Propagated from `templates/` via `aapp init`.
- [ ] `.agents/skills/aapp-*` -> Section 2 protected. Propagated via `aapp init`.
- [ ] `templates/aapp-pre-commit` -> Layer 2 commit-time verification is unaffected by this plan.
- [ ] `lib/cmd_status.sh` -> Status reporting is unaffected by this plan.
- [ ] `.plans/ISSUES.md`, `.plans/issues_road_map.md` -> Issue records are managed in the issue lane.
- [ ] `aapp` -> No dispatcher verb is added by this plan.
- [ ] `lib/cmd_upgrade.sh`, `lib/cmd_install.sh`, `lib/cmd_develop.sh` -> Unrelated surfaces.

> **Concurrent Plan Alignment**: Prior plans `P-8` (flat issues & archival) and `P-13` (Plan IDs & resolver) are fully verified and archived in `000-archive-ledger.md`. `P-9` has zero concurrent lock contention on target files.

---

## ❓ 5. Open Questions (Resolved)

* [x] **Question 1 — `Bash` interception.** Should the guard attempt heuristic interception of shell writes (matching `>`, `>>`, `tee`, `sed -i` against repo paths), or formally document Layer 1 as write-tool-scoped with Layer 2 authoritative?
  - **Decision:** Document the boundary. Formally declare Layer 1 as write-tool-scoped and Layer 2 (`aapp-pre-commit`) as authoritative. Avoid brittle shell regex parsing that leads to false bypass heuristics.
* [x] **Question 2 — Default allowlist breadth.** Ship the §E.1 built-in defaults, or ship an empty list requiring explicit opt-in?
  - **Decision:** Ship built-in defaults (including Claude, Antigravity, Codex, Cursor, XDG, tmp) for out-of-the-box multi-agent usability.
* [x] **Question 3 — Management UX.** Is `git config --add aapp.allowPath` sufficient, or should `aapp` gain a `guard allow` / `guard list` verb?
  - **Decision:** Stick to `git config --add aapp.allowPath` for now to keep CLI dispatcher lean.
* [x] **Question 4 — Scope of `$HOME/.config/`.** Defaulting this prefix is broad — it covers unrelated application configuration, not just agents. Narrow to specific known agent subdirectories, or accept the breadth given §E.2 protects the dangerous paths?
  - **Decision:** Accept `$HOME/.config/` breadth; Section 2b hard-denies `*/.config/git/*` and other sensitive targets.

---

## 📦 6. Change Log & Refinement History
* **2026-09-15 (Refinement):** Refined blueprint based on architectural review: added Google Antigravity (`$HOME/.gemini/`) to §E.1 built-in defaults for multi-agent parity; formalized strict trailing-slash prefix normalization to eliminate prefix-aliasing vulnerabilities; updated Out of Bounds and Concurrent Alignment to reflect completed archival of `P-8` and `P-13`; fully resolved Open Questions 1–4; advanced status to `🟡 Refining`.
* **2026-09-15 (Initial Draft):** Plan initialized. Scoped from an adoption defect surfaced live: a write to `~/.claude/projects/<slug>/memory/` was denied by Section 4, and probing showed every external absolute path (`~/.config`, `/tmp`, `~/notes.md`) denies identically — an all-agents defect, not a vendor quirk. Blueprint records the verified Section 2 absolute-path property that makes a user-editable allowlist safe, the traversal hazard that makes canonicalization mandatory, the configuration-location analysis rejecting `.agents/`, `.plans/`, and env vars, and the honest limits of Layer 1 given `Bash` is not interceptable.
