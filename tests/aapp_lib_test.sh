#!/usr/bin/env bash
# Unit suite for lib/aapp-lib.sh (P-37): plan-section parsing, section
# extraction, platform detection, structural single-ownership and inertness.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
LIB="$KIT/lib/aapp-lib.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

# shellcheck source=/dev/null
. "$LIB"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# expect_paths <name> <function> <file> <expected newline-separated paths>
expect_paths() {
  local name="$1" fn="$2" file="$3" want="$4" got
  got="$("$fn" "$file")"
  if [ "$got" = "$want" ]; then ok "$name"; else bad "$name" "want [$(echo $want)] got [$(echo $got)]"; fi
}

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
expect_paths "test_blockquote_not_parsed" parse_plan_target_paths "$F" "src/a.py"

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
expect_paths "test_foreign_subsection_ends_region" parse_plan_target_paths "$F" "src/a.py"

F=$(plan4 hotfix.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🚨 Emergency Hotfix Extensions
- [ ] `src/hotfix.py` -> blocking fix
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
EOF
)
expect_paths "test_emergency_hotfix_is_parsed" parse_plan_target_paths "$F" "src/a.py
src/hotfix.py"

F=$(plan4 hotfix_after_oob.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
### 🚨 Emergency Hotfix Extensions
- [ ] `src/hotfix.py` -> blocking fix
EOF
)
expect_paths "test_emergency_hotfix_after_oob" parse_plan_target_paths "$F" "src/a.py
src/hotfix.py"
expect_paths "oob region ends at a later hotfix heading" parse_plan_oob_paths "$F" "src/secret.py"

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
expect_paths "test_required_test_files_is_parsed" parse_plan_target_paths "$F" "src/a.py
tests/a_test.sh
tests/b_test.sh"

F=$(plan4 required_tests.md <<'EOF'
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.sh::test_x` -> asserts x
### 🧪 Required Test Filesxyz
- `tests/near_miss.sh`
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
EOF
)
expect_paths "test_required_tests_checklist_not_parsed" parse_plan_target_paths "$F" "src/a.py"

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
expect_paths "test_new_file_marker_skipped" parse_plan_target_paths "$F" "src/new.py
src/mod.py
src/gone.py
src/add.py
src/rep.py
src/plain.py"

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
expect_paths "test_fenced_example_not_parsed" parse_plan_target_paths "$F" "src/a.py"

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
expect_paths "test_heading_outside_section4_not_parsed" parse_plan_target_paths "$F" "src/a.py"

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
expect_paths "test_oob_paths_parsed" parse_plan_oob_paths "$F" "src/secret.py
.githooks/*"

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
expect_paths "test_parse_required_test_files" parse_plan_required_test_files "$F_REQ" "tests/a_test.py
tests/b_test.py"

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
expect_paths "test_parse_required_tests" parse_plan_required_tests "$F_TESTS" "tests/a_test.py
tests/b_test.py
tests/c_test.py"

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
if validate_plan_tdd_correspondence "$F_VALID" "Test"; then
  ok "test_validate_tdd_correspondence_matches"
else
  bad "test_validate_tdd_correspondence_matches" "unexpected failure"
fi

if plan_has_required_test_files "$F_VALID"; then
  ok "test_plan_has_required_test_files_true"
else
  bad "test_plan_has_required_test_files_true" "expected true"
fi

F_OPT_OUT="$R/tdd_opt_out.md"
cat > "$F_OPT_OUT" <<'EOF'
## 🔨 3. Implementation Steps & Execution Checklist
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
EOF
if validate_plan_tdd_correspondence "$F_OPT_OUT" "Test" && ! plan_has_required_test_files "$F_OPT_OUT"; then
  ok "test_validate_tdd_correspondence_opted_out"
else
  bad "test_validate_tdd_correspondence_opted_out" "failed on opted-out plan"
fi

echo "== section extraction =="
got=$(printf '%s\n' "## 🔨 3. Steps" "- s3" "## 💥 4. Blast Radius" "### 📂 Target Files" "- [ ] \`src/a.py\`" "## ❓ 5. Questions" "- s5" | extract_plan_section 4)
want=$(printf '%s\n' "## 💥 4. Blast Radius" "### 📂 Target Files" "- [ ] \`src/a.py\`")
if [ "$got" = "$want" ]; then ok "test_extract_plan_section"; else bad "test_extract_plan_section" "got [$got]"; fi

echo "== platform detection =="
PV_LINUX="$R/proc_linux"; echo "Linux version 6.8.0 (gcc) #1 SMP" > "$PV_LINUX"
PV_WSL="$R/proc_wsl"; echo "Linux version 5.15.153.1-microsoft-standard-WSL2" > "$PV_WSL"
os_ok=1
while IFS='|' read -r uname_s proc want; do
  got="$(aapp_os "$uname_s" "$proc")"
  if [ "$got" != "$want" ]; then os_ok=0; echo "       aapp_os '$uname_s' -> $got (want $want)"; fi
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
case "$(aapp_os)" in linux|darwin|windows|wsl|bsd|unknown) ;; *) os_ok=0; echo "       live aapp_os -> $(aapp_os)";; esac
if [ "$os_ok" -eq 1 ]; then ok "test_aapp_os_branches"; else bad "test_aapp_os_branches" "branch mismatch"; fi

echo "== single ownership & inertness =="
# Parser forms that must exist only in lib/aapp-lib.sh. Pair 5's bash parser is
# tracked separately (#86) and does not use these forms.
foreign=$(cd "$KIT" && grep -rnF \
  -e "/^### 📂 Target Files" -e "'^### 📂 Target Files" \
  -e "/^### 🛑 Out of Bounds" -e "'^### 🛑 Out of Bounds" \
  -e "^### 🚨 Emergency Hotfix" -e "Required Test Files/" \
  -e '"^## ([^0-9]*[[:space:]])?"' \
  lib templates aapp 2>/dev/null | grep -v -e "^lib/aapp-lib.sh:" -e "^templates/aapp-lib.sh:")
if [ -z "$foreign" ]; then ok "test_no_foreign_target_parsers_in_repo"; else bad "test_no_foreign_target_parsers_in_repo" "found copies"; echo "$foreign" | sed 's/^/       /'; fi

inert=$(bash -c '
  before="$(set +o; shopt -p)"
  out="$(. "$1")"
  . "$1"
  after="$(set +o; shopt -p)"
  [ -z "$out" ] && [ "$before" = "$after" ] && declare -f aapp_lib_loaded >/dev/null && echo INERT
' _ "$LIB")
if [ "$inert" = "INERT" ]; then ok "test_source_is_inert"; else bad "test_source_is_inert" "output or option change on source"; fi

print_test_summary "$PASS" "$FAIL"
