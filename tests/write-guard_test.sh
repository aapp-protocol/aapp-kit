#!/usr/bin/env bash
# Regression test suite for blast-radius-guard (PreToolUse write-time guard)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="${AAPP_GUARD:-$KIT/templates/blast-radius-guard.sh}"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

green() { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "$2"; }
red()   { printf "  \033[31m✘\033[0m %-48s want %s got %s\n" "$1" "$2" "$3"; }
assert_rc() { [ $? -eq 0 ] && green "$1" "ALLOW" && PASS=$((PASS+1)) || { red "$1" "ALLOW" "FAIL"; FAIL=$((FAIL+1)); }; }

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
  local rc_cli rc_json
  call_guard_cli "$path"
  rc_cli=$?
  local got_cli=DENY; [ $rc_cli -eq 0 ] && got_cli=ALLOW
  
  # Also test with Claude Code JSON payload and absolute path
  local abs_path="$path"
  [[ "$path" != /* ]] && abs_path="$(pwd)/$path"
  call_guard_json "Edit" "$abs_path"
  rc_json=$?
  local got_json=DENY; [ $rc_json -eq 0 ] && got_json=ALLOW

  if [ "$got_cli" = "$expect" ] && [ "$got_json" = "$expect" ]; then
    green "$name (CLI & JSON payload)" "$got_cli"; PASS=$((PASS+1))
  else
    red "$name" "$expect" "cli=$got_cli json=$got_json"; FAIL=$((FAIL+1))
  fi
}

echo "== enforcement =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
- [ ] `NEW FILE` -> `src/new_mod.py` -> allowed with backticks
- [ ] `src/my dir/b.py` -> allowed with spaces
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
check_decision "declared target" ALLOW "src/a.py"
check_decision "backticked new target" ALLOW "src/new_mod.py"
check_decision "file no plan targets" DENY "src/untracked.py"
check_decision "out of bounds" DENY "src/secret.py"
check_decision "path named only in prose" DENY "src/prose.py"
check_decision "agent may write plans" ALLOW ".plans/current/new.md"
check_decision "agent may write its rules" ALLOW ".agents/AGENTS.md"
check_decision "invariant anchor" ALLOW "CHANGELOG.md"
check_decision "invariant anchor CHEATSHEET.md" ALLOW "CHEATSHEET.md"
check_decision "second stray file" DENY "src/other.py"

echo "== self-protection: the agent cannot disable the guard =="
check_decision "settings that wire up the hook" DENY ".claude/settings.json"
check_decision "local settings override" DENY ".claude/settings.local.json"
check_decision "canonical claude settings" DENY ".agents/claude/settings.json"
check_decision "canonical aapp governance skill" DENY ".agents/skills/aapp-freeze/SKILL.md"
check_decision "bridged aapp governance skill" DENY ".claude/skills/aapp-freeze/SKILL.md"
check_decision "canonical plan governance skill" DENY ".agents/skills/plan/SKILL.md"
check_decision "bridged plan governance skill" DENY ".claude/skills/plan/SKILL.md"
check_decision "user custom skill allowed" ALLOW ".agents/skills/custom-deploy/SKILL.md"
check_decision "the commit-time hook" DENY ".githooks/pre-commit"
check_decision "the namespaced commit-time hook" DENY ".githooks/aapp-pre-commit"
check_decision "the guard itself" DENY ".githooks/blast-radius-guard"
check_decision "raw git hooks dir" DENY ".git/hooks/pre-commit"
check_decision "another agent's rule file" DENY ".cursor/rules/aapp.mdc"
check_decision "plans still writable" ALLOW ".plans/state_matrix.md"
check_decision "agent rules still writable" ALLOW ".agents/PROJECT.MD"

echo "== concurrent plans do not cross-block via active buffer =="
setup
plan a.md <<'EOF'
* **Plan ID:** P-1
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed in a
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/b.py` -> plan A excludes B
## end
EOF
plan b.md <<'EOF'
* **Plan ID:** P-2
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/b.py` -> allowed in b
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "P-2" > .git/aapp_active_plan
check_decision "plan B active in buffer: Plan B target allowed, Plan A exclusion ignored" ALLOW "src/b.py"
check_decision "plan B active in buffer: Plan A target denied" DENY "src/a.py"

echo "P-1" > .git/aapp_active_plan
check_decision "plan A active in buffer: Plan A target allowed" ALLOW "src/a.py"
check_decision "plan A active in buffer: Plan A exclusion enforced" DENY "src/b.py"

rm -f .git/aapp_active_plan
check_decision "multiple in-development plans without buffer denied" DENY "src/b.py"

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
ERR_LOG=$(mktemp)
PAYLOAD=$(python3 -c "import json; print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': '$R/repo/src/forbidden.py'}}))" | "$GUARD" 2>"$ERR_LOG" || true)
VALID_JSON=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    hso = d.get('hookSpecificOutput', {})
    if (d.get('decision') == 'deny' and
        d.get('reason') and
        hso.get('hookEventName') == 'PreToolUse' and
        hso.get('permissionDecision') == 'deny' and
        hso.get('permissionDecisionReason') == d.get('reason')):
        print('OK')
    else:
        print('SCHEMA_MISMATCH')
except Exception as e:
    print('INVALID_JSON')
" "$PAYLOAD" 2>/dev/null || echo "INVALID")
if [ "$VALID_JSON" = "OK" ] && grep -q "Blast Radius Guard Violation" "$ERR_LOG"; then
  green "deny payload schema includes hookSpecificOutput" "OK"; PASS=$((PASS+1))
else
  red "deny payload schema includes hookSpecificOutput" "OK" "$VALID_JSON"; FAIL=$((FAIL+1))
fi
rm -f "$ERR_LOG"

echo "== POSIX fallback JSON output without python3 =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> denied
## end
EOF

NO_PY_DIR=$(mktemp -d)
mkdir -p "$NO_PY_DIR/bin"
for cmd in sh bash sed awk grep ls cat mktemp printf cut head tail; do
  cmd_path=$(command -v "$cmd" 2>/dev/null || true)
  [ -n "$cmd_path" ] && ln -sf "$cmd_path" "$NO_PY_DIR/bin/$cmd"
done

POSIX_OUTPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/repo/src/forbidden.py"}}\n' "$R" | PATH="$NO_PY_DIR/bin" "$GUARD" 2>&1 || true)
rm -rf "$NO_PY_DIR"

if echo "$POSIX_OUTPUT" | grep -q '"decision"[[:space:]]*:[[:space:]]*"deny"' && \
   echo "$POSIX_OUTPUT" | grep -q '"hookEventName"[[:space:]]*:[[:space:]]*"PreToolUse"' && \
   echo "$POSIX_OUTPUT" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' && \
   echo "$POSIX_OUTPUT" | grep -q '"permissionDecisionReason"[[:space:]]*:'; then
  green "deny payload valid JSON via POSIX fallback" "OK"; PASS=$((PASS+1))
else
  red "deny payload valid JSON via POSIX fallback" "OK" "$POSIX_OUTPUT"; FAIL=$((FAIL+1))
fi

echo "== large JSON payload (>300KB) does not fail-open via ARG_MAX =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> denied
## end
EOF
LARGE_PAYLOAD=$(python3 -c "import json; print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': '$R/repo/src/forbidden.py', 'content': 'x' * 350000}}))")
rc_large=0
echo "$LARGE_PAYLOAD" | "$GUARD" >/dev/null 2>&1 || rc_large=$?
if [ $rc_large -eq 2 ]; then
  green "large payload (>300KB) blocked with exit code 2" "DENY"; PASS=$((PASS+1))
else
  red "large payload (>300KB) blocked with exit code 2" "DENY" "rc=$rc_large"; FAIL=$((FAIL+1))
fi

echo "== external path authorization & precedence =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> forbidden
## end
EOF

# 1. ALLOW: allowlisted external memory & scratch paths
check_decision "claude memory path allowlisted" ALLOW "$HOME/.claude/projects/test/memory/note.md"
check_decision "antigravity brain path allowlisted" ALLOW "$HOME/.gemini/antigravity-ide/brain/test.md"
check_decision "temp scratchpad allowlisted" ALLOW "/tmp/scratchpad_aapp_test.txt"

# 2. ALLOW: path added only via git config --add aapp.allowPath
CUSTOM_EXT_DIR="$R/custom_external"
mkdir -p "$CUSTOM_EXT_DIR"
git config --add aapp.allowPath "$CUSTOM_EXT_DIR"
check_decision "custom git config allowPath" ALLOW "$CUSTOM_EXT_DIR/notes.md"

# 3. DENY: external path matching no allowlist entry
check_decision "external path without allowlist entry" DENY "/var/data/arbitrary/file.txt"

# 4. DENY: Section 2 self-protection precedence over allowlist
check_decision "section 2 claude settings precedence" DENY "$HOME/.claude/settings.json"
check_decision "section 2 governance skill precedence" DENY "$HOME/.claude/skills/aapp-done/SKILL.md"
check_decision "section 2 git config precedence" DENY "$R/repo/.git/config"

# 5. DENY: Section 2b hard-deny precedence even if $HOME is explicitly allowlisted
git config --add aapp.allowPath "$HOME"
check_decision "section 2b ssh key denied despite HOME in allowlist" DENY "$HOME/.ssh/authorized_keys"
check_decision "section 2b shell rc denied despite HOME in allowlist" DENY "$HOME/.bashrc"
check_decision "section 2b local bin denied despite HOME in allowlist" DENY "$HOME/.local/bin/evil_script"

# 6. DENY: Traversal attempt through allowlisted prefix into repo
check_decision "canonicalization closes traversal into repo" DENY "/tmp/..$R/repo/src/forbidden.py"

# 7. Matcher coverage: MultiEdit tool support
call_guard_json "MultiEdit" "$R/repo/src/forbidden.py"
rc_multiedit=$?
if [ $rc_multiedit -eq 2 ]; then
  green "MultiEdit tool intercepted and enforced" "DENY"; PASS=$((PASS+1))
else
  red "MultiEdit tool intercepted and enforced" "DENY" "rc=$rc_multiedit"; FAIL=$((FAIL+1))
fi

call_guard_json "MultiEdit" "$R/repo/src/a.py"
rc_multiedit_allow=$?
if [ $rc_multiedit_allow -eq 0 ]; then
  green "MultiEdit tool allowed for target file" "ALLOW"; PASS=$((PASS+1))
else
  red "MultiEdit tool allowed for target file" "ALLOW" "rc=$rc_multiedit_allow"; FAIL=$((FAIL+1))
fi

echo "== glob path traversal precision & bracket safety =="
setup
plan glob.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/*.py` -> single segment wildcard
- [ ] `pkg/**/*.go` -> recursive wildcard
- [ ] `scripts/?.sh` -> single character wildcard
- [ ] `migrations/[0-9]*.sql` -> bracket class range
- [ ] `docs/` -> recursive directory prefix
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden_*.py` -> single segment oob wildcard
## end
EOF
check_decision "single segment glob matches in directory" ALLOW "src/app.py"
check_decision "single segment wildcard rejects nested subdirectories" DENY "src/deep/nested/app.py"
check_decision "recursive globstar matches root of glob" ALLOW "pkg/main.go"
check_decision "recursive globstar matches nested subdirectory" ALLOW "pkg/sub/deep/worker.go"
check_decision "single char wildcard matches single char" ALLOW "scripts/a.sh"
check_decision "single char wildcard rejects multiple chars" DENY "scripts/ab.sh"
check_decision "bracket class range matches digit" ALLOW "migrations/001_init.sql"
check_decision "bracket class range rejects non-digit" DENY "migrations/test.sql"
check_decision "directory prefix matches subfiles" ALLOW "docs/guide.md"
check_decision "directory prefix matches nested subfiles" ALLOW "docs/api/v1/spec.md"
check_decision "single segment oob wildcard blocks match" DENY "src/forbidden_test.py"

echo "== plan lifecycle enforcement (🔷 Frozen grants zero rights, ⚡ In Development enforces targets) =="
setup
plan frozen.md <<'EOF'
* **Plan ID:** P-10
* **Status:** 🔷 Frozen
### 📂 Target Files (Modifications & Additions)
- [ ] `src/frozen_target.py` -> in backlog, not in dev
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check_decision "frozen backlog plan grants zero write rights (no buffer)" DENY "src/frozen_target.py"

plan active.md <<'EOF'
* **Plan ID:** P-11
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/active_target.py` -> in flight
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check_decision "⚡ in-development plan target is allowed" ALLOW "src/active_target.py"
check_decision "frozen backlog plan target remains denied while other plan is in dev" DENY "src/frozen_target.py"

# Clean Break: legacy 🟠 In Development is refused
rm -f .plans/current/active.md
plan legacy.md <<'EOF'
* **Plan ID:** P-11
* **Status:** 🟠 In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/legacy_target.py` -> legacy in flight
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check_decision "legacy 🟠 is refused (clean break enforced)" DENY "src/legacy_target.py"

echo "== active plan buffer switchboard (aapp active, active swap, active clear) =="
setup
plan p1.md <<'EOF'
* **Plan ID:** P-20
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/p1_target.py` -> plan 1
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
plan p2.md <<'EOF'
* **Plan ID:** P-21
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/p2_target.py` -> plan 2
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF

# Use kit aapp CLI
AAPP_CLI="$KIT/aapp"
"$AAPP_CLI" active P-20 >/dev/null 2>&1
check_decision "active set to P-20: p1 target allowed" ALLOW "src/p1_target.py"
check_decision "active set to P-20: p2 target denied" DENY "src/p2_target.py"

"$AAPP_CLI" active P-21 >/dev/null 2>&1
check_decision "active set to P-21: p2 target allowed" ALLOW "src/p2_target.py"
check_decision "active set to P-21: p1 target denied" DENY "src/p1_target.py"

"$AAPP_CLI" active swap >/dev/null 2>&1
check_decision "active swap returns to P-20: p1 target allowed" ALLOW "src/p1_target.py"
check_decision "active swap returns to P-20: p2 target denied" DENY "src/p2_target.py"

"$AAPP_CLI" active clear >/dev/null 2>&1
check_decision "active clear reverts to auto-discovery (multiple dev plans denied)" DENY "src/p1_target.py"

echo "== atomic workflow accelerator (aapp freeze-start) =="
setup
plan draft.md <<'EOF'
* **Plan ID:** P-30
* **Status:** 🟡 Refining
### 📂 Target Files (Modifications & Additions)
- [ ] `src/fast_feature.py` -> feature target
### 🛑 Out of Bounds (Do Not Touch)
## ❓ 5. Open Questions
* [x] Question 1 resolved
## 📦 6. Change Log
EOF
"$AAPP_CLI" freeze-start P-30 >/dev/null 2>&1
check_decision "freeze-start activates plan: target allowed immediately" ALLOW "src/fast_feature.py"
check_decision "freeze-start activates plan: undeclared file denied" DENY "src/other.py"

echo "== linked worktree resolution & fail-closed quarantine =="
setup
plan p_wt.md <<'EOF'
* **Plan ID:** P-40
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/wt_target.py` -> worktree feature target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
git add -A >/dev/null; git commit -qm "add wt plan"
# Create a git linked worktree
git worktree add -q "$R/wt-agent2" HEAD >/dev/null 2>&1
cd "$R/wt-agent2"
# Set active plan in wt-agent2
"$AAPP_CLI" plan P-40 >/dev/null 2>&1
check_decision "linked worktree resolves primary .plans and allows declared target" ALLOW "src/wt_target.py"
check_decision "linked worktree denies undeclared file" DENY "src/secret_wt.py"

cd "$R/repo"
rm -rf "$R/wt-agent2"
git worktree prune >/dev/null 2>&1

echo "== project circuit breaker (aapp pause & resume) =="
setup
plan p_pause.md <<'EOF'
* **Plan ID:** P-50
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/paused_target.py` -> target file
### 🛑 Out of Bounds (Do Not Touch)
EOF
"$AAPP_CLI" active P-50 >/dev/null 2>&1
check_decision "before pause: declared target allowed" ALLOW "src/paused_target.py"

# Engage pause
"$AAPP_CLI" pause "away on vacation" >/dev/null 2>&1
check_decision "while paused: declared target denied" DENY "src/paused_target.py"
check_decision "while paused: untracked codebase file denied" DENY "src/random.py"
check_decision "while paused: anchor README.md denied" DENY "README.md"
check_decision "while paused: plans ISSUES still writable" ALLOW ".plans/ISSUES.md"
check_decision "while paused: plans issues_road_map still writable" ALLOW ".plans/issues_road_map.md"
check_decision "while paused: plans pickup still writable" ALLOW ".plans/pickup.md"
check_decision "while paused: plans pickup subfolder writable" ALLOW ".plans/pickup/note.md"
check_decision "while paused: plans current still writable" ALLOW ".plans/current/P99.md"
check_decision "while paused: plans done denied" DENY ".plans/done/000-archive-ledger.md"
check_decision "while paused: plans state_matrix denied" DENY ".plans/state_matrix.md"
check_decision "while paused: agents rules denied" DENY ".agents/AGENTS.md"
check_decision "while paused: agents codemap denied" DENY ".agents/CODEMAP.md"
check_decision "while paused: external scratchpad allowed" ALLOW "/tmp/scratch.txt"

# Resume
"$AAPP_CLI" resume >/dev/null 2>&1
check_decision "after resume: declared target allowed again" ALLOW "src/paused_target.py"

echo ""
echo "  passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]
