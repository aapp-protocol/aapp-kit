#!/usr/bin/env bash
# Core suite for lib/aapp-lib.sh (P-37): plan-section parsing, section
# extraction, platform detection, plan commits, pickup entries, subject limit.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
LIB="$KIT/lib/aapp-lib.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

# shellcheck source=/dev/null
. "$LIB"

# expect_paths <label> <function> <file> <expected newline-separated paths>
expect_paths() { t_expect "$1" "$4" "$("$2" "$3")"; }

# Fixture: a plan whose §4 holds the given body.
plan4() {
  local f="$R/$1"
  { echo "## 🔨 3. Implementation Steps"; echo "## 💥 4. Blast Radius & System Boundaries"; cat; echo "## ❓ 5. Open Questions"; } > "$f"
  echo "$f"
}

echo "== target parsing boundaries =="

F=$(plan4 blockquote.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
> **Authoring rule:** the first `backticked path` on a line is the target.
>   - `src/quoted.py` indented quote
- [ ] `src/a.py` -> real target
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
t_done test_blockquote_not_parsed

F=$(plan4 foreign.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 📝 Implementation Notes
- `src/notes.py` -> not a target
#### 🔎 Deeper Note
- `src/deeper.py` -> not a target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
t_done test_foreign_subsection_ends_region

F=$(plan4 heading_after_oob.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
### 📝 Notes
- [ ] `src/notes.py` -> neither
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
expect_paths "out of bounds" parse_plan_oob_paths "$F" "src/secret.py"
t_done test_foreign_heading_after_oob

F=$(plan4 required_files.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🧪 Required Test Files
> Test files that must prove this plan's failure cases.
- `tests/a_test.sh`
- [x] `tests/b_test.sh`
### 🛑 Out of Bounds (Do Not Touch)
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py
tests/a_test.sh
tests/b_test.sh"
t_done test_required_test_files_is_parsed

F=$(plan4 required_tests.md <<'EOF'
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.sh::test_x` -> asserts x
### 🧪 Required Test Filesxyz
- `tests/near_miss.sh`
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
t_done test_required_tests_checklist_not_parsed

F=$(plan4 markers.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `src/new.py` -> created
- [x] `MODIFY` -> `src/mod.py` -> ticked and modified
- [ ] `DELETE` -> `src/gone.py` -> removed
- [ ] `ADD` -> `src/add.py` -> added
- [ ] `REPLACE` -> `src/rep.py` -> replaced
- [X] `src/plain.py` -> ticked plain target
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/new.py
src/mod.py
src/gone.py
src/add.py
src/rep.py
src/plain.py"
t_done test_new_file_marker_skipped

F=$(plan4 fenced.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 📝 Example For Authors
```markdown
### 🧪 Required Test Files
- `src/test/kotlin/AuthTest.kt`
```
EOF
)
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
t_done test_fenced_example_not_parsed

F="$R/outside4.md"
cat > "$F" <<'EOF'
## 2. Technical Blueprint
### 🧪 Required Test Files
- `tests/example_in_s2.sh`
### 📂 Target Files (Modifications & Additions)
- [ ] `src/example_in_s2.py`
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
## ❓ 5. Open Questions
### 📂 Target Files (Modifications & Additions)
- [ ] `src/after_s4.py`
EOF
expect_paths targets parse_plan_target_paths "$F" "src/a.py"
t_done test_heading_outside_section4_not_parsed

F=$(plan4 oob.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🛑 Out of Bounds (Do Not Touch)
> Quoted `src/quoted_oob.py` is prose.
- [ ] `src/secret.py` -> vetoed
- [ ] `.githooks/*` -> vetoed glob
### 📝 Later Notes
- `src/not_oob.py`
EOF
)
expect_paths "out of bounds" parse_plan_oob_paths "$F" "src/secret.py
.githooks/*"
t_done test_oob_paths_parsed

echo "== required test files parsing =="
F_REQ=$(plan4 req_tests.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🧪 Required Test Files
> Test files that prove this plan's failure cases.
- `tests/a_test.py`
- `tests/b_test.py`
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/secret_test.py`
EOF
)
expect_paths "required test files" parse_plan_required_test_files "$F_REQ" "tests/a_test.py
tests/b_test.py"
t_done test_parse_required_test_files

echo "== required tests parsing =="
F_TESTS="$R/plan_tests.md"
cat > "$F_TESTS" <<'EOF'
## 🔨 3. Implementation Steps & Execution Checklist
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.py::test_fail_early` -> asserts exit 1
- [x] `tests/b_test.py::test_boundary` -> asserts clean boundary
- [ ] tests/c_test.py::test_unbackticked -> asserts clean error
### Phase 1: Implementation
- [ ] Task 1.1: Do something
## 💥 4. Blast Radius & System Boundaries
EOF
expect_paths "required tests" parse_plan_required_tests "$F_TESTS" "tests/a_test.py
tests/b_test.py
tests/c_test.py"
t_done test_parse_required_tests

echo "== tdd correspondence validation =="
F_VALID="$R/tdd_valid.md"
cat > "$F_VALID" <<'EOF'
## 🔨 3. Implementation Steps & Execution Checklist
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.py::test_fail_early` -> asserts exit 1
- [x] `tests/b_test.py::test_boundary` -> asserts clean boundary
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🧪 Required Test Files
- `tests/a_test.py`
- `tests/b_test.py`
EOF
validate_plan_tdd_correspondence "$F_VALID" "Test" || t_fail "matching §3/§4 refused"
plan_has_required_test_files "$F_VALID" || t_fail "plan_has_required_test_files: want true"
t_done test_validate_tdd_correspondence_matches

F_OPT_OUT="$R/tdd_opt_out.md"
cat > "$F_OPT_OUT" <<'EOF'
## 🔨 3. Implementation Steps & Execution Checklist
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
EOF
validate_plan_tdd_correspondence "$F_OPT_OUT" "Test" || t_fail "opted-out plan refused"
plan_has_required_test_files "$F_OPT_OUT" && t_fail "plan_has_required_test_files: want false"
t_done test_validate_tdd_correspondence_opted_out

echo "== section extraction =="
got=$(printf '%s\n' "## 🔨 3. Steps" "- s3" "## 💥 4. Blast Radius" "### 📂 Target Files" "- [ ] \`src/a.py\`" "## ❓ 5. Questions" "- s5" | extract_plan_section 4)
want=$(printf '%s\n' "## 💥 4. Blast Radius" "### 📂 Target Files" "- [ ] \`src/a.py\`")
t_expect "section 4" "$want" "$got"
fenced=$(printf '%s\n' "## 2. Decisions" "- d" "## 4. Docs" '```markdown' "## ⚙️ 2. Codemap" "- c" '```' "## 5. Q")
t_expect "fenced heading is not section 2" "$(printf '%s\n' "## 2. Decisions" "- d")" "$(printf '%s\n' "$fenced" | extract_plan_section 2)"
t_expect "fenced heading does not end section 4" "$(printf '%s\n' "## 4. Docs" '```markdown' "## ⚙️ 2. Codemap" "- c" '```')" "$(printf '%s\n' "$fenced" | extract_plan_section 4)"
t_done test_extract_plan_section

echo "== platform detection =="
PV_LINUX="$R/proc_linux"; echo "Linux version 6.8.0 (gcc) #1 SMP" > "$PV_LINUX"
PV_WSL="$R/proc_wsl"; echo "Linux version 5.15.153.1-microsoft-standard-WSL2" > "$PV_WSL"
while IFS='|' read -r uname_s proc want; do
  t_expect "aapp_os '$uname_s'" "$want" "$(aapp_os "$uname_s" "$proc")"
done <<EOF
Linux|$PV_LINUX|linux
Linux|$PV_WSL|wsl
Linux|$R/no_such_file|linux
Darwin|$PV_LINUX|darwin
MINGW64_NT-10.0-19045|$PV_LINUX|windows
MSYS_NT-10.0|$PV_LINUX|windows
CYGWIN_NT-10.0|$PV_LINUX|windows
FreeBSD|$PV_LINUX|bsd
OpenBSD|$PV_LINUX|bsd
NetBSD|$PV_LINUX|bsd
SunOS|$PV_LINUX|unknown
EOF
case "$(aapp_os)" in linux|darwin|windows|wsl|bsd|unknown) ;; *) t_fail "live aapp_os -> $(aapp_os)";; esac
t_done test_aapp_os_branches

echo "== plan commits parsing =="
F_COMMITS="$R/commits_test.md"
cat > "$F_COMMITS" <<'EOF'
# Plan P-99: Test
* **Status:** ⚡ In Development
* **Commits:** `bca7d9a` (develop), `8c0c103` (feat/parser), `1a2b3c4` (detached)
EOF
t_expect "three commits" "$(printf "bca7d9a develop\n8c0c103 feat/parser\n1a2b3c4 detached")" "$(parse_plan_commits "$F_COMMITS")"
echo '* **Commits:** none' > "$F_COMMITS"
t_expect "none" "" "$(parse_plan_commits "$F_COMMITS")"
echo '* **Commits:** bca7d9a (develop), `8c0c103`, just prose' > "$F_COMMITS"
t_expect "unbackticked or branchless" "" "$(parse_plan_commits "$F_COMMITS")"
t_done test_parse_plan_commits

echo "== pickup entry split (P-96) =="
t_expect "title and text" "$(printf 'Verbosity Budget\tkeep agents to the essence: always.')" \
  "$(pickup_entry_split '- [ ] Verbosity Budget: keep agents to the essence: always.')"
t_expect "colon inside backticks" "$(printf 'Configuration Manager CLI (`aapp config: set`)\tadd a manifest')" \
  "$(pickup_entry_split '- [ ] Configuration Manager CLI (`aapp config: set`): add a manifest')"
t_expect "no title" "$(printf '\tan idea with no title at all')" "$(pickup_entry_split '- [ ] an idea with no title at all')"
t_expect "no marker" "$(printf 'Plain Title\ttext without the marker')" "$(pickup_entry_split 'Plain Title: text without the marker')"
t_done test_pickup_entry_split

echo "== subject max len (P-97) =="
S="$R/subj"; git init -q "$S"
t_expect "default" 72 "$(cd "$S" && aapp_subject_max_len)"
git -C "$S" config aapp.subjectMaxLen 50
t_expect "custom" 50 "$(cd "$S" && aapp_subject_max_len)"
git -C "$S" config aapp.subjectMaxLen "not-a-number"
t_expect "invalid" 72 "$(cd "$S" && aapp_subject_max_len)"
t_done test_subject_max_len

print_test_summary "$PASS" "$FAIL"
