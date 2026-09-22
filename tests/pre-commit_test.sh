#!/usr/bin/env bash
# Regression harness for templates/aapp-pre-commit
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
HOOK="${AAPP_HOOK:-$KIT/templates/aapp-pre-commit}"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

setup() {
  rm -rf "$R"/repo; mkdir -p "$R"/repo; cd "$R"/repo
  git init -q .
  setup_test_git_identity "$R/repo"
  mkdir -p src .plans/current
  echo "x=1" > src/a.py; echo "secret=1" > src/secret.py; echo "# CL" > CHANGELOG.md
  git add -A >/dev/null; git commit -qm init
  cp "$HOOK" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
}

check() {
  local name="$1" expect="$2"; shift 2
  echo "- bump $(date +%s%N)" >> CHANGELOG.md
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$f")"
    [ -e "$f" ] && printf '# touch %s\n' "$(date +%s%N)" >> "$f" || echo "x=1" > "$f"
  done
  git add CHANGELOG.md "$@" 2>/dev/null
  local out; out=$(git commit -m "t" 2>&1); local rc=$?
  local got=BLOCK; [ $rc -eq 0 ] && got=PASS
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-52s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    echo "$out" | grep -E "❌|Staged file" | head -2 | sed 's/^/       /'
  fi
  git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null
}

plan() { mkdir -p .plans/current; cat > ".plans/current/$1"; }

echo "== 1. filenames with spaces =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/my dir/c.py` -> new
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p "src/my dir"; echo "z=1" > "src/my dir/c.py"
check "spaced filename listed as target" PASS "src/my dir/c.py"

echo "== 2. prose backticks must not widen blast radius =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> Refactor to use `src/legacy/old.py` helper.
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p src/legacy; echo "w=1" > src/legacy/old.py
check "path named only in prose stays blocked" BLOCK src/legacy/old.py
check "the real target still commits" PASS src/a.py

echo "== 2b. NEW FILE marker still resolves to its path =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] NEW FILE -> `src/new_mod.py` -> Fresh helper.
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "def h(): pass" > src/new_mod.py
check "NEW FILE marker skipped, path taken" PASS src/new_mod.py

echo "== 2c. backticked marker resolves to path =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `src/backticked_new.py` -> Fresh component.
- [ ] `MODIFY` -> `src/modified_target.py` -> Modify component.
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "def bn(): pass" > src/backticked_new.py
check "backticked NEW FILE marker resolves to path" PASS src/backticked_new.py
echo "def mt(): pass" > src/modified_target.py
check "backticked MODIFY marker resolves to path" PASS src/modified_target.py

echo "== 3. concurrent plans must not cross-block =="
setup
plan a.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> change a
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/b.py` -> belongs to plan B
## end
EOF
plan b.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/b.py` -> change b
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "# Cheatsheet" > CHEATSHEET.md
check "invariant anchor CHEATSHEET.md passes without plan targets" PASS CHEATSHEET.md
echo "b" > .git/aapp_active_plan
echo "b=1" > src/b.py
check "plan B's own target not blocked by plan A" PASS src/b.py
echo "c=1" > src/c.py
check "file in no plan still blocked" BLOCK src/c.py
rm -f .git/aapp_active_plan
check "multiple in-development plans without buffer blocked" BLOCK src/b.py

echo "== 3b. a plan's own Out of Bounds still blocks it =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/` -> broad target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
echo "s=1" > src/secret.py
check "own out-of-bounds blocks own broad target" BLOCK src/secret.py
echo "ok=1" > src/ok.py
check "non-excluded file under target passes" PASS src/ok.py

echo "== 3c. out-of-bounds-only plan (no targets declared) =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/danger.py` -> strictly excluded
## end
EOF
echo "d=1" > src/danger.py
check "oob still enforced with no targets" BLOCK src/danger.py
echo "u=1" > src/unrelated.py
check "unrelated file allowed when no plan claims targets" PASS src/unrelated.py

echo "== 4. BLOCKED plans are not executable =="
setup
plan blocked.md <<'EOF'
* **Status:** 🚫 BLOCKED
* **Blocked On:** BUG-042
### 📂 Target Files (Modifications & Additions)
- [ ] `src/blocked_target.py` -> would be allowed if not blocked
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "bt=1" > src/blocked_target.py
check "commit against a BLOCKED plan is refused" BLOCK src/blocked_target.py

echo "== 5. syntax checks survive spaces =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/my dir/bad.py` -> target with space
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p "src/my dir"; echo "def bad(: pass" > "src/my dir/bad.py"
check "broken python in spaced path is caught" BLOCK "src/my dir/bad.py"

echo "== 6. deleting explicitly out-of-bounds file is blocked =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> forbidden to modify or delete
## end
EOF
git rm -q src/secret.py
echo "- bump changelog" >> CHANGELOG.md; git add CHANGELOG.md
rc_del=0
out_del=$(git commit -m "delete secret" 2>&1) || rc_del=$?
if [ $rc_del -ne 0 ]; then
  got_del=BLOCK
else
  got_del=PASS
fi
if [ "$got_del" = "BLOCK" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "deleting out-of-bounds file is blocked" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got %s\n" "deleting out-of-bounds file is blocked" "$got_del"; FAIL=$((FAIL+1))
fi

echo "== 7. SKIP_BLAST_RADIUS=1 bypasses even without CHANGELOG =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "hotfix=1" >> src/a.py
git add src/a.py
rc_skip=0
out_skip=$(SKIP_BLAST_RADIUS=1 git commit -m "emergency hotfix" 2>&1) || rc_skip=$?
if [ $rc_skip -eq 0 ]; then
  got_skip=PASS
else
  got_skip=FAIL
fi
if [ "$got_skip" = "PASS" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "SKIP_BLAST_RADIUS=1 bypasses without CHANGELOG" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got %s\n" "SKIP_BLAST_RADIUS=1 bypasses without CHANGELOG" "$got_skip"; FAIL=$((FAIL+1))
fi

echo "== 8. .plans/CHANGELOG.md satisfies changelog requirement =="
setup
rm -f CHANGELOG.md
git commit -qm "remove root changelog" --allow-empty
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p .plans
touch .plans/CHANGELOG.md
echo "x=2" > src/a.py
git add src/a.py .plans/CHANGELOG.md
rc_plan_cl=0
out_plan_cl=$(git commit -m "code with .plans changelog" 2>&1) || rc_plan_cl=$?
if [ $rc_plan_cl -eq 0 ]; then
  got_plan_cl=PASS
else
  got_plan_cl=FAIL
fi
if [ "$got_plan_cl" = "PASS" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" ".plans/CHANGELOG.md satisfies changelog requirement" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got %s\n" ".plans/CHANGELOG.md satisfies changelog requirement" "$got_plan_cl"; FAIL=$((FAIL+1))
fi

# 8b. .plans worktree git status verification (no mtime reliance)
git init -q .plans
git -C .plans config user.email "test@example.com"
git -C .plans config user.name "Tester"
echo "uncommitted changelog entry" >> .plans/CHANGELOG.md
echo "x=3" > src/a.py
git add src/a.py
rc_wt=0
out_wt=$(git commit -m "code with .plans worktree changelog" 2>&1) || rc_wt=$?
if [ $rc_wt -eq 0 ]; then
  got_wt=PASS
else
  got_wt=FAIL
fi
if [ "$got_wt" = "PASS" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" ".plans worktree status satisfies changelog requirement" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got %s\n" ".plans worktree status satisfies changelog requirement" "$got_wt"; FAIL=$((FAIL+1))
fi
rm -rf .plans/.git

echo "== 9. pre-commit executes even if aapp-pre-commit lost execute bit (+x) =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p .githooks
cp "$KIT/templates/aapp-pre-commit" .githooks/aapp-pre-commit
chmod -x .githooks/aapp-pre-commit
cp "$KIT/templates/pre-commit" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "bad=1" > src/untracked.py
echo "- bump changelog" >> CHANGELOG.md
git add src/untracked.py CHANGELOG.md
rc_non_exec=0
out_non_exec=$(git commit -m "commit untracked" 2>&1) || rc_non_exec=$?
if [ $rc_non_exec -ne 0 ] && echo "$out_non_exec" | grep -q "Pre-Commit Blast Radius Violation"; then
  got_non_exec=BLOCK
else
  got_non_exec=PASS
fi
if [ "$got_non_exec" = "BLOCK" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "pre-commit catches violation without +x bit" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got %s\n" "pre-commit catches violation without +x bit" "$got_non_exec"; FAIL=$((FAIL+1))
fi

echo "== 10. adaptive branch protection guard =="
setup
# 10a. Single-branch repository (main only) allows commits
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=10" > src/a.py
check "single-branch repo allows commit on main" PASS src/a.py

# 10b. Dual-branch repository (main + develop) blocks direct commits on main
git branch develop
echo "x=11" > src/a.py
git add src/a.py CHANGELOG.md
rc_main=0
out_main=$(git commit -m "direct to main" 2>&1) || rc_main=$?
if [ $rc_main -ne 0 ] && echo "$out_main" | grep -q "Direct commits to 'main' are prohibited"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "dual-branch blocks direct commit on main" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "dual-branch blocks direct commit on main" "$rc_main"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null

# 10c. Commits on develop branch succeed
git checkout -q develop
echo "x=12" > src/a.py
check "commit on develop branch succeeds" PASS src/a.py

# 10d. Emergency bypass ALLOW_MAIN_COMMIT=1 permits commit on main
git checkout -q main
echo "x=13" > src/a.py
echo "- emergency fix" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_bypass=0
out_bypass=$(ALLOW_MAIN_COMMIT=1 git commit -m "emergency commit on main" 2>&1) || rc_bypass=$?
if [ $rc_bypass -eq 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "ALLOW_MAIN_COMMIT=1 permits commit on main" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "ALLOW_MAIN_COMMIT=1 permits commit on main" "$rc_bypass"; FAIL=$((FAIL+1))
fi

# 10e. Opt-out via git config aapp.protectStable false permits commit on main
git config --bool aapp.protectStable false
echo "x=14" > src/a.py
echo "- bump" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_optout=0
out_optout=$(git commit -m "commit on main with protectStable=false" 2>&1) || rc_optout=$?
if [ $rc_optout -eq 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "aapp.protectStable false permits commit on main" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "aapp.protectStable false permits commit on main" "$rc_optout"; FAIL=$((FAIL+1))
fi
git config --unset aapp.protectStable

# 10f. Custom dev branch config (aapp.devBranch)
setup
git branch staging
git config aapp.devBranch "staging"
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=15" > src/a.py
echo "- bump" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_custom=0
out_custom=$(git commit -m "direct to main with staging dev" 2>&1) || rc_custom=$?
if [ $rc_custom -ne 0 ] && echo "$out_custom" | grep -q "staging"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "custom devBranch staging triggers protection" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "custom devBranch staging triggers protection" "$rc_custom"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
git checkout -q staging
echo "x=16" > src/a.py
check "commit on custom dev branch staging succeeds" PASS src/a.py

echo "== 11. issue roadmap hygiene (auto-prune resolved items) =="
setup
mkdir -p .plans
cat > .plans/issues_road_map.md <<'EOF'
# 🗺️ Issue Priority Board
1. `ISSUE-001` -> Still open
2. `ISSUE-002` -> All done ✅ `Resolved`
- [ ] `ISSUE-003` -> Open edge case
EOF
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=20" > src/a.py
echo "- bump" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_prune=0
out_prune=$(git commit -m "commit with resolved issue in roadmap" 2>&1) || rc_prune=$?
if [ $rc_prune -eq 0 ] && ! grep -q "ISSUE-002" .plans/issues_road_map.md && grep -q "ISSUE-001" .plans/issues_road_map.md; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "pre-commit auto-prunes resolved issue from roadmap" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS (pruned) got rc=%d\n" "pre-commit auto-prunes resolved issue from roadmap" "$rc_prune"; FAIL=$((FAIL+1))
fi

echo "== 11b. POSIX ID-anchored roadmap auto-pruning preserves prose =="
setup
mkdir -p .plans
cat > .plans/issues_road_map.md <<'EOF'
# 🗺️ Issue Priority Board
> **Role:** Resolved issues are auto-pruned.
## 🔴 High Priority
1. #1 -> Still open
2. #2 -> All done ✅ Resolved
- [ ] #3 -> Done Resolved
EOF
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=21" > src/a.py
echo "- bump" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_posix_prune=0
out_posix_prune=$(git commit -m "commit with prose containing resolved" 2>&1) || rc_posix_prune=$?
if [ $rc_posix_prune -eq 0 ] && \
   grep -q "Resolved issues are auto-pruned" .plans/issues_road_map.md && \
   grep -q "#1" .plans/issues_road_map.md && \
   ! grep -q "#2" .plans/issues_road_map.md && \
   ! grep -q "#3" .plans/issues_road_map.md; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "POSIX auto-prune preserves prose with 'resolved'" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "POSIX auto-prune preserves prose with 'resolved'" "$rc_posix_prune"; FAIL=$((FAIL+1))
fi

echo "== 12. Relocation Invariant detect-and-block for active ISSUES.md =="
setup
mkdir -p .plans
cat > .plans/ISSUES.md <<'EOF'
# 🐛 Issues: Active Technical Backlog
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `SEC` | 2026-09-09 | `src/a.py:1` | Issue symptom. | Fix. | ✅ `Resolved` |
EOF
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=22" > src/a.py
echo "- bump" >> CHANGELOG.md
git add src/a.py CHANGELOG.md
rc_reloc=0
out_reloc=$(git commit -m "commit with resolved issue in ISSUES.md" 2>&1) || rc_reloc=$?
if [ $rc_reloc -ne 0 ] && echo "$out_reloc" | grep -q "Found resolved issue in active"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "pre-commit blocks resolved row in active ISSUES.md" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "pre-commit blocks resolved row in active ISSUES.md" "$rc_reloc"; FAIL=$((FAIL+1))
fi

echo "== 13. Planning Health Integrity Engine validations =="
setup
mkdir -p .plans .plans/done
cat > .plans/ISSUES.md <<'EOF'
# 🐛 Issues: Active Technical Backlog
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `CORE` | 2026-09-10 | `src/a.py:1` | Issue symptom. | Fix. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# 🏛️ Master Issue Archive Ledger
| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #2 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `commit` | Resolved description. |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# 🗺️ Issue Priority Board
1. #1 -> Active issue
EOF

source "$KIT/lib/planning_health.sh"
if check_planning_health "$PWD" >/dev/null 2>&1; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "planning_health passes on valid state" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "planning_health passes on valid state"; FAIL=$((FAIL+1))
fi

# Detect collision (ID #1 in both)
echo '| #1 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `commit` | Collision summary. |' >> .plans/done/000-issues-archive.md
if ! check_planning_health "$PWD" >/dev/null 2>&1; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "planning_health blocks ID collision in active/archive" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "planning_health blocks ID collision in active/archive"; FAIL=$((FAIL+1))
fi

# Reset archive for Pair 4 & Pair 5 checks
sed -i '/Collision summary/d' .plans/done/000-issues-archive.md

# Pair 4: Plan ID collision in active plans
cat > .plans/current/P1-feature.md <<'EOF'
# 🗺️ Plan P-1: Feature
* **Plan ID:** P-1
* **Status:** 🔴 Under Review
EOF
cat > .plans/current/P1-conflict.md <<'EOF'
# 🗺️ Plan P-1: Conflict
* **Plan ID:** P-1
* **Status:** 🔴 Under Review
EOF

if ! check_pair4_plan_id_integrity "$PWD" >/dev/null 2>&1; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "planning_health blocks duplicate Plan ID in active plans" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "planning_health blocks duplicate Plan ID in active plans"; FAIL=$((FAIL+1))
fi
rm -f .plans/current/P1-conflict.md

# Pair 5: Plan declaring Section 2 self-protection in Target Files
cat > .plans/current/P2-bad.md <<'EOF'
# 🗺️ Plan P-2: Bad Plan
* **Plan ID:** P-2
* **Status:** 🔴 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `.githooks/aapp-pre-commit` -> Illegal direct hook edit
EOF

if ! check_pair5_target_files_self_protection "$PWD" >/dev/null 2>&1; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "planning_health blocks Section 2 target in Pair 5" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "planning_health blocks Section 2 target in Pair 5"; FAIL=$((FAIL+1))
fi
rm -f .plans/current/P1-feature.md .plans/current/P2-bad.md

echo "== 14. glob path traversal precision & bracket safety =="
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
check "single segment glob passes in directory" PASS "src/app.py"
check "single segment wildcard blocks nested subdirectories" BLOCK "src/deep/nested/app.py"
check "recursive globstar passes root of glob" PASS "pkg/main.go"
check "recursive globstar passes nested subdirectory" PASS "pkg/sub/deep/worker.go"
check "single char wildcard passes single char" PASS "scripts/a.sh"
check "single char wildcard blocks multiple chars" BLOCK "scripts/ab.sh"
check "bracket class range passes digit" PASS "migrations/001_init.sql"
check "bracket class range blocks non-digit" BLOCK "migrations/test.sql"
check "directory prefix passes subfiles" PASS "docs/guide.md"
check "directory prefix passes nested subfiles" PASS "docs/api/v1/spec.md"
check "single segment oob wildcard blocks match" BLOCK "src/forbidden_test.py"

echo "== 15. frozen plan immutability & design-lock enforcement =="
setup

create_and_commit_plan() {
  local status="$1"
  cat > .plans/current/p.md <<EOF
# 🗺️ Plan P-1: Test Plan
* **Plan ID:** P-1
* **Status:** $status

## 1. Context & Goal
Original context.

## 2. Technical Blueprint
Original technical blueprint architecture.

## 🔨 3. Implementation Steps & Checklist
- [ ] Task 1.1
- [ ] Task 1.2

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] \`src/a.py\`
### 🛑 Out of Bounds
- [ ] \`src/secret.py\`

## ❓ 5. Open Questions
* [ ] Question 1

## 📦 6. Change Log & Refinement History
* 2026-09-17: Initial entry.
EOF
  git add .plans/current/p.md >/dev/null 2>&1
  git commit -qm "add plan with status $status"
  BASE_COMMIT=$(git rev-parse HEAD)
}

check_plan_commit() {
  local name="$1" expect="$2"
  git add .plans/current/p.md 2>/dev/null
  local out; out=$(git commit -m "update plan" 2>&1); local rc=$?
  local got=BLOCK; [ $rc -eq 0 ] && got=PASS
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-52s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    echo "$out" | grep -E "❌|Violation|Staged" | head -2 | sed 's/^/       /'
  fi
  git reset -q --hard "$BASE_COMMIT" 2>/dev/null
}

# 1. Tests on 🔷 Frozen plan
create_and_commit_plan "🔷 Frozen"

# Task checkbox tick in Sec 3: PASS
sed -i 's/- \[ \] Task 1.1/- [x] Task 1.1/' .plans/current/p.md
check_plan_commit "checkbox tick on frozen plan is permitted" PASS

# Change log append in Sec 6: PASS
echo "* 2026-09-17: Verified phase 1." >> .plans/current/p.md
check_plan_commit "changelog append on frozen plan is permitted" PASS

# Open question update in Sec 5: PASS
sed -i 's/\* \[ \] Question 1/* [x] Question 1: answered/' .plans/current/p.md
check_plan_commit "open question update on frozen plan is permitted" PASS

# Sec 2 edit on 🔷 plan: BLOCK
sed -i 's/Original technical blueprint architecture./Tampered architecture./' .plans/current/p.md
check_plan_commit "editing blueprint on frozen plan is blocked" BLOCK

# Sec 4 edit on 🔷 plan: BLOCK
sed -i 's/src\/a\.py/src\/extra\.py/' .plans/current/p.md
check_plan_commit "editing blast radius on frozen plan is blocked" BLOCK

# Unfreeze (status changed to 📝 Refining with untouched Sec 2/4): PASS
sed -i 's/🔷 Frozen/📝 Refining/' .plans/current/p.md
check_plan_commit "unfreezing status to 📝 Refining without design change is permitted" PASS

# Smuggled unfreeze (status changed to 📝 Refining AND Sec 2 modified): BLOCK
sed -i 's/🔷 Frozen/📝 Refining/' .plans/current/p.md
sed -i 's/Original technical blueprint architecture./Smuggled architecture./' .plans/current/p.md
check_plan_commit "smuggling blueprint edit during unfreeze is blocked" BLOCK

# 2. Tests on 🔴 Under Review plan
create_and_commit_plan "🔴 Under Review"

# Sec 2 edit on 🔴 plan: PASS
sed -i 's/Original technical blueprint architecture./Refined draft architecture./' .plans/current/p.md
check_plan_commit "editing blueprint on draft plan is permitted" PASS

# Sec 4 edit on 🔴 plan: PASS
sed -i 's/src\/a\.py/src\/draft\.py/' .plans/current/p.md
check_plan_commit "editing blast radius on draft plan is permitted" PASS

echo "== 16. multi-agent worktree isolation & fail-closed quarantine =="
setup
# Mark as AAPP repo
touch aapp
# Fail-closed quarantine when .plans/current is missing in AAPP repo:
rm -rf .plans/current
echo "bad=1" > src/a.py
check "missing .plans/current in AAPP repo triggers fail-closed quarantine" BLOCK src/a.py

# Restore .plans/current and test frozen backlog vs start
mkdir -p .plans/current
plan p17.md <<'EOF'
* **Plan ID:** P-17
* **Status:** 🔷 Frozen
### 📂 Target Files (Modifications & Additions)
- [ ] `src/p17.py` -> plan 17 target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "p17=1" > src/p17.py
check "frozen backlog plan without active buffer is blocked" BLOCK src/p17.py

# Start plan P-17
"$KIT/aapp" start 17 >/dev/null 2>&1
check "started plan is in development and allowed to commit" PASS src/p17.py

# Clear buffer: single dev plan auto-discovered
"$KIT/aapp" plan-clear >/dev/null 2>&1
check "single in-development plan auto-discovered without buffer" PASS src/p17.py

# Add second plan P-18 in development
plan p18.md <<'EOF'
* **Plan ID:** P-18
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/p18.py` -> plan 18 target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "p18=1" > src/p18.py
check "two dev plans without buffer blocked" BLOCK src/p18.py

# Designate plan 18
"$KIT/aapp" active 18 >/dev/null 2>&1
check "active plan 18 buffer allows plan 18 commit" PASS src/p18.py
check "active plan 18 buffer blocks plan 17 commit" BLOCK src/p17.py

# Swap back to plan 17
"$KIT/aapp" active swap >/dev/null 2>&1
check "swapped active plan buffer allows plan 17 commit" PASS src/p17.py
check "swapped active plan buffer blocks plan 18 commit" BLOCK src/p18.py

echo "== 16. portability & machine-agnostic path enforcement =="
setup
plan p_port.md <<'EOF'
* **Plan ID:** P-30
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `doc.md` -> doc target
- [ ] `README.md` -> readme target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
"$KIT/aapp" active 30 >/dev/null 2>&1

# 1. BLOCK: staged doc containing file:/// URI
echo "See [doc](file:///home/user/repo/doc.md)" > doc.md
echo "- bump $(date +%s%N)" >> CHANGELOG.md
git add CHANGELOG.md doc.md
out=$(git commit -m "t" 2>&1); rc=$?
got=BLOCK; [ $rc -eq 0 ] && got=PASS
if [ "$got" = "BLOCK" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "staged markdown with file:/// URI is blocked" "$got"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "staged markdown with file:/// URI is blocked"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null

# 2. BLOCK: staged doc containing /home/ path in link
echo "See [doc](/home/user/repo/doc.md)" > doc.md
echo "- bump $(date +%s%N)" >> CHANGELOG.md
git add CHANGELOG.md doc.md
out=$(git commit -m "t" 2>&1); rc=$?
got=BLOCK; [ $rc -eq 0 ] && got=PASS
if [ "$got" = "BLOCK" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "staged markdown with /home/ absolute link is blocked" "$got"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "staged markdown with /home/ absolute link is blocked"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null

# 3. PASS: staged doc with relative link
echo "See [doc](doc.md) and [other](../other.md)" > doc.md
echo "- bump $(date +%s%N)" >> CHANGELOG.md
git add CHANGELOG.md doc.md
out=$(git commit -m "t" 2>&1); rc=$?
got=BLOCK; [ $rc -eq 0 ] && got=PASS
if [ "$got" = "PASS" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "staged markdown with relative link is allowed" "$got"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got BLOCK\n" "staged markdown with relative link is allowed"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null

# 4. PASS: staged doc mentioning file:// in prose without URI
echo "Never use file:// URIs in repository files." > doc.md
echo "- bump $(date +%s%N)" >> CHANGELOG.md
git add CHANGELOG.md doc.md
out=$(git commit -m "t" 2>&1); rc=$?
got=BLOCK; [ $rc -eq 0 ] && got=PASS
if [ "$got" = "PASS" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "staged markdown mentioning file:// in prose passes" "$got"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got BLOCK\n" "staged markdown mentioning file:// in prose passes"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null

echo "== 17. project circuit breaker & multi-worktree pause/resume =="
setup
plan p_pause.md <<'EOF'
* **Plan ID:** P-60
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/pause_code.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "def f(): pass" > src/pause_code.py
echo "- entry" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md .plans
out=$(git commit -m "feat: add pause target" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "commit before pause succeeds" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "commit before pause succeeds" "$rc"; FAIL=$((FAIL+1))
fi

# 1. Engage pause
"$KIT/aapp" pause "focusing on another project" >/dev/null 2>&1

# 2. Attempting to commit code while paused is refused
echo "def f2(): pass" >> src/pause_code.py
echo "- bump" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md
out=$(git commit -m "feat: modify code while paused" 2>&1)
rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q "Project Circuit Breaker"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "code commit while paused is refused" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "code commit while paused is refused" "$rc"; FAIL=$((FAIL+1))
fi
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null

# 3. Committing within .plans (pickup) while paused is permitted
echo "new note" > .plans/pickup.md
git add .plans/pickup.md 2>/dev/null || true
out=$(git commit -m "chore(plans): add note while paused" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "committing .plans/pickup while paused is permitted" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "committing .plans/pickup while paused is permitted" "$rc"; FAIL=$((FAIL+1))
fi

# 3b. Committing outside pickup/issues/current (.agents) while paused is refused
mkdir -p .agents
echo "rule" > .agents/AGENTS.md
git add .agents/AGENTS.md 2>/dev/null || true
out=$(git commit -m "chore(agents): add rule while paused" 2>&1)
rc=$?
git reset -q .agents/AGENTS.md >/dev/null 2>&1; rm -rf .agents
if [ $rc -ne 0 ] && echo "$out" | grep -q "Project Circuit Breaker"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "committing .agents while paused is refused" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "committing .agents while paused is refused" "$rc"; FAIL=$((FAIL+1))
fi

# 3c. Committing outside pickup/issues/current (.plans/done) while paused is refused
mkdir -p .plans/done
echo "done plan" > .plans/done/P01.md
git add .plans/done/P01.md 2>/dev/null || true
out=$(git commit -m "chore(plans): archive while paused" 2>&1)
rc=$?
git reset -q .plans/done/P01.md >/dev/null 2>&1; rm -rf .plans/done
if [ $rc -ne 0 ] && echo "$out" | grep -q "Project Circuit Breaker"; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "committing .plans/done while paused is refused" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "committing .plans/done while paused is refused" "$rc"; FAIL=$((FAIL+1))
fi

# 4. In-flight operation guard refusal
touch "$(git rev-parse --git-path MERGE_HEAD)"
out=$("$KIT/aapp" pause "in-flight test" 2>&1)
rc=$?
rm -f "$(git rev-parse --git-path MERGE_HEAD)"
if [ $rc -ne 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "pause refused when in-flight merge active" "BLOCK"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want BLOCK got rc=%d\n" "pause refused when in-flight merge active" "$rc"; FAIL=$((FAIL+1))
fi

# 5. Resume disengages brake and allows code commits
"$KIT/aapp" resume >/dev/null 2>&1
echo "def f3(): pass" >> src/pause_code.py
echo "- bump resume" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md
out=$(git commit -m "feat: commit after resume" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "code commit after resume succeeds" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want PASS got rc=%d\n" "code commit after resume succeeds" "$rc"; FAIL=$((FAIL+1))
fi

# 6. Multi-worktree dynamic stash quarantine and clean restore
git worktree add -q "$R/wt-branch2" -b branch2 >/dev/null 2>&1
echo "dirty develop" > src/dirty_dev.txt
echo "dirty wt2" > "$R/wt-branch2/src/dirty_wt.txt"
# Pause quarantines changes across both worktrees
"$KIT/aapp" pause "quarantine multi-worktree" >/dev/null 2>&1
status_dev=$(git status --porcelain)
status_wt2=$(git -C "$R/wt-branch2" status --porcelain)
if [ -z "$status_dev" ] && [ -z "$status_wt2" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "pause leaves all worktrees clean" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want clean worktrees got dev='%s' wt2='%s'\n" "pause leaves all worktrees clean" "$status_dev" "$status_wt2"; FAIL=$((FAIL+1))
fi

# Resume restores changes in both worktrees
"$KIT/aapp" resume >/dev/null 2>&1
if [ -f src/dirty_dev.txt ] && [ -f "$R/wt-branch2/src/dirty_wt.txt" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "resume restores changes across all worktrees" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want restored files across worktrees\n" "resume restores changes across all worktrees"; FAIL=$((FAIL+1))
fi
rm -f src/dirty_dev.txt "$R/wt-branch2/src/dirty_wt.txt"
rm -rf "$R/wt-branch2"
git worktree prune >/dev/null 2>&1

# 7. No-loss conflict guarantee & buffer survival
echo "conflict base" > src/conflict.txt
git add src/conflict.txt; git commit -qm "add conflict base"
echo "modified for stash" > src/conflict.txt
"$KIT/aapp" pause "conflict test" >/dev/null 2>&1
# Introduce conflicting commit while paused via --no-verify bypass
echo "conflicting change while away" > src/conflict.txt
git commit --no-verify -am "upstream conflicting commit" >/dev/null 2>&1
# Resume will conflict
rc_resume=0
out_resume=$("$KIT/aapp" resume 2>&1) || rc_resume=$?
# Stash must be preserved and pause file must still exist
stashes_after=$(git stash list)
common_dir=$(git rev-parse --git-common-dir)
if [ $rc_resume -ne 0 ] && [ -f "$common_dir/aapp_paused" ] && [ -n "$stashes_after" ]; then
  printf "  \033[32m✔\033[0m %-52s %s\n" "resume conflict keeps pause buffer and stash stack" "PASS"; PASS=$((PASS+1))
else
  printf "  \033[31m✘\033[0m %-52s want buffer survival and preserved stash\n" "resume conflict keeps pause buffer and stash stack"; FAIL=$((FAIL+1))
fi
# Clean up conflict test state
rm -f "$common_dir/aapp_paused"
git stash clear >/dev/null 2>&1
git reset --hard HEAD~1 >/dev/null 2>&1

print_test_summary "$PASS" "$FAIL"




