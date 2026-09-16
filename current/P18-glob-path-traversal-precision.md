# 🗺️ Plan P-18: Glob Path Traversal Precision & Bracket Syntax Safety
* **Created:** 2026-09-17 | **Last Refined:** 2026-09-17
* **Target Issue / Milestone:** #56
* **Plan ID:** P-18
* **Status:** 🟢 Ready for Execution
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent: Antigravity`, `AI-Vendor: Google`, `AI-Model: gemini-1.5-pro`). Synthetic or fake emails are strictly forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Fix the glob path traversal precision defect (`#56`) in the AAPP blast radius enforcement engines (`blast-radius-guard.sh` and `aapp-pre-commit`), establishing strict POSIX glob boundaries and safe bracket character classes:
  1. **Single-Segment Wildcard Precision (`*`)**: Prevent single-star wildcards from crossing path separators (`/`). A pattern like `src/*.py` must match `src/app.py` while strictly rejecting nested paths like `src/deep/nested/app.py`.
  2. **Recursive Directory Globstars (`**`)**: Support recursive globs like `src/**/*.py` to explicitly match across directory boundaries.
  3. **Parameterized Bracket Classes (`[...]`)**: Support safe POSIX character classes (e.g. `migrations/[0-9]*.sql`) with strict anti-"funny regex" syntax rules.
  4. **High-Performance 3-Tier Matching**: Implement an optimized fast path (Exact -> Prefix -> Regex) to ensure sub-millisecond evaluation with zero latency regression.
* **Why**:
  - In `templates/blast-radius-guard.sh:166` and `templates/aapp-pre-commit:148`, pattern matching relies on bash `[[ "$target" == $pattern ]]`. In Bash unquoted pattern matching, `*` matches arbitrary characters across slashes (`/`). This renders single-directory boundaries porous.
  - Resolving #56 independently establishes solid glob matching foundation prior to the multi-agent lifecycle switchboard (P-17).
* **Key Invariants & Constraints**:
  - **Zero External Dependencies**: Pure Bash implementation for both `blast-radius-guard.sh` and `aapp-pre-commit`. Zero subshells, Python, or AWK during runtime path matching.
  - **Sub-Millisecond Speed**: Exact path matches and directory prefixes evaluate instantly via Tier 1 and Tier 2 fast-paths before regex compilation.
  - **Pair 5 Compliance**: Under no circumstances may `.githooks/*` be listed in Target Files. Changes live in `templates/` and propagate via `aapp init`.

---

## 2. Technical Blueprint

### A. Pure-Bash POSIX Glob-to-Regex Translation Engine (`glob_to_regex`)
Currently, `match_pattern_list` executes:
```bash
if [[ "$target" == $pattern ]]; then
    return 0
fi
```
Because `$pattern` is unquoted in bash, `*` matches `/`.

We introduce an efficient pure-Bash helper `glob_to_regex` that translates standard glob expressions into anchored POSIX Extended Regular Expressions (ERE):
- `*` -> `[^/]*` (matches zero or more non-slash characters within a single path segment)
- `**` -> `.*` (matches zero or more characters across arbitrary directory depths)
- `/**/` -> `/(.*/)?` (matches zero or more directory levels cleanly)
- `?` -> `[^/]` (matches exactly one non-slash character)
- Metacharacters `\ . + ^ $ ( ) { } |` are escaped; standard POSIX bracket expressions (`[...]`) are preserved. Note: literal `[` in a filename is treated as a character class delimiter per standard POSIX glob behavior.

#### Translation Algorithm
```bash
glob_to_regex() {
    local p="$1"
    # 1. Escape regex metacharacters: \ . + ^ $ ( ) { } |
    p="${p//\\/\\\\}"
    p="${p//./\\.}"
    p="${p//+/\\+}"
    p="${p//^/\\^}"
    p="${p//\$/\\\$}"
    p="${p//(/\\(}"
    p="${p//)/\\)}"
    p="${p//\{/\\\{}"
    p="${p//\}/\\\}}"
    p="${p//|/\\|}"

    # 2. Protect multi-segment globstars using collision-free sentinels
    p="${p//\/\*\*\//__SLASH_GLOBSTAR_SLASH__}"
    p="${p//\*\*/__GLOBSTAR__}"

    # 3. Translate single-segment wildcard and single-char tokens
    p="${p//\*/[^/]*}"
    p="${p//\?/[^/]}"

    # 4. Expand sentinels into POSIX regex
    p="${p//__SLASH_GLOBSTAR_SLASH__/\/(.*\/)?}"
    p="${p//__GLOBSTAR__/.*}"

    echo "^${p}\$"
}
```

### B. Parameterized Bracket Grammar & Syntax Safety Rules (`[...]`)
To prevent "funny regex file names" or arbitrary regex injection into target declarations:
1. **Permitted Pattern Grammar**:
   - Repository-relative paths composed of standard path characters: `[a-zA-Z0-9._/-]`.
   - Wildcards: `*` (single segment, non-slash), `**` (recursive directory tree), `?` (single character, non-slash).
   - Character classes: `[...]` within a path segment.
2. **Permitted Bracket Expressions**:
   - Digit ranges: `[0-9]` (e.g. `migrations/[0-9]*.sql`)
   - Letter ranges: `[a-z]`, `[A-Z]`, `[a-zA-Z]`
   - Alphanumeric ranges: `[a-zA-Z0-9]`
   - Discrete character sets: `[abc]`, `[01]`, `[a-f0-9]`
   - Negated classes: Leading `^` or `!` (e.g. `[^0-9]`, `[!a-z]`)
3. **Strict Invariants to Prevent "Funny Regex" Names**:
   - **Path Separator Prohibition**: A slash `/` is **strictly forbidden** inside bracket expressions (e.g. `[a/b]` is an error). Path segments must always be explicitly delimited by literal `/`.
   - **No Raw Regex Quantifiers / Repetition**: `+`, `{1,3}`, `*?` are forbidden. Patterns are **POSIX globs, never raw regular expressions**.
   - **No Alternation or Grouping**: `(foo|bar)`, `foo|bar`, or parentheses `(...)` are forbidden. If multiple files or extensions are needed, list them on separate lines.
   - **No Shell Brace Expansion**: `{ts,js}` is forbidden. Declare distinct lines in `### 📂 Target Files`.
   - **No Regex Shorthand Classes**: `\d`, `\w`, `\s` are forbidden. Use explicit POSIX classes (`[0-9]`, `[a-zA-Z0-9]`).
4. **Well-Formedness & Planning Health Validation**:
   - Brackets must be balanced and non-empty. Unclosed brackets (`foo/[a-z.py`), empty brackets (`[]`), or nested brackets (`[[0-9]]`) are caught and rejected.

### C. Fast-Path Optimized `match_pattern_list`
To guarantee zero performance degradation for literal paths and directory prefixes, `match_pattern_list` executes a 3-tier fast path:
1. **Tier 1 (Exact Match)**: `[ "$target" = "$pattern" ]` -> return 0.
2. **Tier 2 (Directory Prefix)**: If `pattern` ends in `/`, check `[[ "$target" == "$pattern"* ]]` -> return 0.
3. **Tier 3 (Glob / Regex Match)**: If pattern contains `*`, `?`, or `[`, compile via `glob_to_regex` and match via `[[ "$target" =~ $regex ]]`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pure-Bash Regex Engine Implementation
- [ ] Task 1.1: Implement `glob_to_regex` helper and 3-tier fast-path matching in `templates/blast-radius-guard.sh`.
- [ ] Task 1.2: Implement `glob_to_regex` helper and 3-tier fast-path matching in `templates/aapp-pre-commit`.

### Phase 2: Automated Test Suites & Hook Verification
- [ ] Task 2.1: Add glob precision unit tests to `tests/write-guard_test.sh`:
  - Verify `src/*.py` matches `src/a.py` and blocks `src/sub/a.py`.
  - Verify `src/**/*.py` matches `src/sub/a.py` and `src/sub/deep/a.py`.
  - Verify `src/?.py` matches single-character filenames and blocks multi-character filenames.
  - Verify `migrations/[0-9]*.sql` matches digit-prefixed SQL files and blocks letter-prefixed files.
  - Verify directory prefix `src/` matches all files under `src/`.
- [ ] Task 2.2: Add matching pre-commit tests to `tests/pre-commit_test.sh`.
- [ ] Task 2.3: Sync active hooks via `./aapp init` and run all regression suites.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **LOCKED** — greenlit for execution)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Implement `glob_to_regex` and 3-tier fast path matching.
- [ ] `templates/aapp-pre-commit` -> Implement `glob_to_regex` and 3-tier fast path matching in pre-commit.
- [ ] `tests/write-guard_test.sh` -> Add glob precision, recursive globstar, and bracket test cases.
- [ ] `tests/pre-commit_test.sh` -> Add pre-commit glob precision regression tests.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection (managed via `templates/` and `aapp init`).
- [ ] `.agents/skills/*` -> Governance skills are locked.
- [ ] `.claude/*` -> Section 2 self-protection.
- [ ] `lib/*` -> CLI and resolver libraries outside hook engine scope.
- [ ] `src/*` -> Application source code.

---

## ❓ 5. Open Questions (Optional / Gate)
*None. All architectural patterns and bracket rules are settled and verified.*

---

## 📦 6. Change Log & Refinement History
* **2026-09-17:** Plan frozen and greenlit for execution via `/aapp-freeze P-18`. Blast radius locked to 4 target files.
* **2026-09-17:** Plan scaffolded as a dedicated, focused security fix for Issue #56, decoupled from P-17 following red team evaluation. Delivers pure-Bash `glob_to_regex` engine, bracket class syntax rules, and Tier 1-3 fast path in a compact 4-file blast radius.
