#!/usr/bin/env bash
# Regression harness for templates/aapp-pre-commit
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${AAPP_HOOK:-$KIT/templates/aapp-pre-commit}"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

setup() {
  rm -rf "$R"/repo; mkdir -p "$R"/repo; cd "$R"/repo
  git init -q .; git config user.email t@t; git config user.name T
  git config commit.gpgsign false; git config tag.gpgsign false
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
echo "b=1" > src/b.py
check "plan B's own target not blocked by plan A" PASS src/b.py
echo "c=1" > src/c.py
check "file in no plan still blocked" BLOCK src/c.py

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
git add src/a.py
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

echo ""
echo "  passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]

