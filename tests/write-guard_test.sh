#!/usr/bin/env bash
# Regression test suite for blast-radius-guard (PreToolUse write-time guard)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="${AAPP_GUARD:-$KIT/templates/blast-radius-guard.sh}"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

setup() {
  rm -rf "$R"/repo; mkdir -p "$R"/repo; cd "$R"/repo
  git init -q .; git config user.email t@t; git config user.name T
  git config commit.gpgsign false; git config tag.gpgsign false
  mkdir -p src .plans/current .agents .githooks
  echo "x=1" > src/a.py; echo "# CL" > CHANGELOG.md; echo "# CM" > CODEMAP.md; echo "# AR" > ARCHITECTURE.md
  git add -A >/dev/null; git commit -qm init
  cp "$GUARD" .githooks/blast-radius-guard; chmod +x .githooks/blast-radius-guard
}

plan() { mkdir -p .plans/current; cat > ".plans/current/$1"; }

call_guard_cli() {
  local path="$1"
  "$GUARD" "$path" >/dev/null 2>&1
  return $?
}

call_guard_json() {
  local tool="$1" path="$2"
  local payload
  payload=$(python3 -c "import json; print(json.dumps({'tool_name': '$tool', 'tool_input': {'file_path': '$path'}}))")
  echo "$payload" | "$GUARD" >/dev/null 2>&1
  return $?
}

check_decision() {
  local name="$1" expect="$2" path="$3"
  local rc
  call_guard_cli "$path"
  rc=$?
  local got=DENY; [ $rc -eq 0 ] && got=ALLOW
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-48s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-48s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
  fi
}

echo "== enforcement =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
- [ ] `src/my dir/b.py` -> allowed with spaces
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
check_decision "declared target" ALLOW "src/a.py"
check_decision "file no plan targets" DENY "src/untracked.py"
check_decision "out of bounds" DENY "src/secret.py"
check_decision "path named only in prose" DENY "src/prose.py"
check_decision "agent may write plans" ALLOW ".plans/current/new.md"
check_decision "agent may write its rules" ALLOW ".agents/AGENTS.md"
check_decision "invariant anchor" ALLOW "CHANGELOG.md"
check_decision "second stray file" DENY "src/other.py"

echo "== self-protection: the agent cannot disable the guard =="
check_decision "settings that wire up the hook" DENY ".claude/settings.json"
check_decision "local settings override" DENY ".claude/settings.local.json"
check_decision "the commit-time hook" DENY ".githooks/pre-commit"
check_decision "the namespaced commit-time hook" DENY ".githooks/aapp-pre-commit"
check_decision "the guard itself" DENY ".githooks/blast-radius-guard"
check_decision "raw git hooks dir" DENY ".git/hooks/pre-commit"
check_decision "another agent's rule file" DENY ".cursor/rules/aapp.mdc"
check_decision "plans still writable" ALLOW ".plans/state_matrix.md"
check_decision "agent rules still writable" ALLOW ".agents/PROJECT.MD"

echo "== concurrent plans do not cross-block =="
setup
plan a.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed in a
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/b.py` -> plan A excludes B
## end
EOF
plan b.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/b.py` -> allowed in b
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check_decision "plan B's target, plan A's exclusion" ALLOW "src/b.py"

echo "== BLOCKED plan grants nothing =="
setup
plan blocked.md <<'EOF'
* **Status:** 🚫 BLOCKED
* **Blocked On:** BUG-042
### 📂 Target Files (Modifications & Additions)
- [ ] `src/blocked_target.py` -> would be allowed if not blocked
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check_decision "own target refused while BLOCKED" DENY "src/blocked_target.py"

echo "== fail-open (a guard must never brick the agent) =="
setup
check_decision "no active plans" ALLOW "src/any.py"
check_decision "self-protection holds with no plans" DENY ".githooks/blast-radius-guard"

# Garbage stdin -> exit 0
echo "invalid json" | "$GUARD" >/dev/null 2>&1
assert_rc() { [ $? -eq 0 ] && green "$1" "ALLOW" && PASS=$((PASS+1)) || { red "$1" "ALLOW" "FAIL"; FAIL=$((FAIL+1)); }; }
green() { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "$2"; }
red()   { printf "  \033[31m✘\033[0m %-48s want %s got %s\n" "$1" "$2" "$3"; }

echo "garbage json" | "$GUARD" >/dev/null 2>&1; assert_rc "garbage stdin"
echo "{}" | "$GUARD" >/dev/null 2>&1; assert_rc "empty object"
echo '{"tool_name":"Read","tool_input":{"file_path":"a.py"}}' | "$GUARD" >/dev/null 2>&1; assert_rc "non-file tool"
printf "" | "$GUARD" >/dev/null 2>&1; assert_rc "empty stdin"

SKIP_BLAST_RADIUS=1 call_guard_cli "src/forbidden.py"
[ $? -eq 0 ] && green "SKIP_BLAST_RADIUS=1 escape hatch" "ALLOW" && PASS=$((PASS+1)) || { red "SKIP_BLAST_RADIUS=1 escape hatch" "ALLOW" "FAIL"; FAIL=$((FAIL+1)); }

echo "== decision payload is valid JSON Claude Code can read =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> denied
## end
EOF
PAYLOAD=$(python3 -c "import json; print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': 'src/forbidden.py'}}))" | "$GUARD" 2>&1 || true)
VALID_JSON=$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print('OK' if d.get('decision') == 'deny' else 'ERR')" "$PAYLOAD" 2>/dev/null || echo "INVALID")
if [ "$VALID_JSON" = "OK" ]; then
  green "deny payload well-formed" "OK"; PASS=$((PASS+1))
else
  red "deny payload well-formed" "OK" "$VALID_JSON"; FAIL=$((FAIL+1))
fi

echo ""
echo "  passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]
