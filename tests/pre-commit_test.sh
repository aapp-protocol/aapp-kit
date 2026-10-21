#!/usr/bin/env bash
# Core suite for the pre-commit hook (templates/aapp-pre-commit): the blast
# radius, plan statuses, changelog rules, branch protection, ledgers, the
# design lock, the active plan buffer, portability, the circuit breaker,
# reachability, failure-test declarations and commit modes.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
HOOK="${AAPP_HOOK:-$KIT/templates/aapp-pre-commit}"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

setup() {
  rm -rf "$R"/repo; mkdir -p "$R"/repo; cd "$R"/repo || exit 1
  git init -q .
  setup_test_git_identity "$R/repo"
  mkdir -p src .plans/current
  echo "x=1" > src/a.py; echo "secret=1" > src/secret.py; echo "# CL" > CHANGELOG.md
  git add -A >/dev/null; git commit -qm init
  cp "$HOOK" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
  # The hook sources aapp-lib.sh, and it plan_states.sh, from its own directory (P-37 §2.7, #85).
  cp "$(dirname "$HOOK")/aapp-lib.sh" .git/hooks/aapp-lib.sh
  cp "$KIT/lib/plan_states.sh" .git/hooks/plan_states.sh
}

# check <label> <PASS|BLOCK> <file>…: commits the files with a changelog line.
check() {
  local name="$1" expect="$2"; shift 2
  echo "- bump $(date +%s%N)" >> CHANGELOG.md
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$f")"
    [ -e "$f" ] && printf '# touch %s\n' "$(date +%s%N)" >> "$f" || echo "x=1" > "$f"
  done
  git add CHANGELOG.md "$@" 2>/dev/null
  local out rc got=BLOCK; out=$(git commit -m "t" 2>&1); rc=$?
  [ $rc -eq 0 ] && got=PASS
  [ "$got" = "$expect" ] || t_fail "$name: want $expect got $got $(echo "$out" | grep -E "❌|Staged file" | head -2 | tr '\n' ' ')"
  git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null
}

# commit_says <label> <PASS|BLOCK> <message> [pattern]: commits what is staged;
# the outcome must match, and the output hold <pattern> when given.
commit_says() {
  local name="$1" expect="$2" msg="$3" pat="${4:-}" out rc got=BLOCK
  out=$(git commit -m "$msg" 2>&1); rc=$?
  [ $rc -eq 0 ] && got=PASS
  [ "$got" = "$expect" ] || t_fail "$name: want $expect got $got $(echo "$out" | head -3 | tr '\n' ' ')"
  [ -z "$pat" ] || echo "$out" | grep -qiE "$pat" || t_fail "$name: output lacks [$pat]: $(echo "$out" | head -3 | tr '\n' ' ')"
  LAST_OUT="$out"
}

# Fixtures are §4 bodies: target headings count only inside `## 💥 4.` (P-37).
# A fixture's leading `* **Field:**` lines are its header: they go above §4, as in a real plan (#85).
plan() {
  mkdir -p .plans/current
  awk '!b && /^\* \*\*[^*]+:\*\*/ { print; next } { b = 1; body = body $0 "\n" }
       END { print "## 💥 4. Blast Radius & System Boundaries"; printf "%s", body }' > ".plans/current/$1"
}
plan_full() { mkdir -p .plans/current; cat > ".plans/current/$1"; }

echo "== target lines =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/my dir/c.py` -> new
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p "src/my dir"; echo "z=1" > "src/my dir/c.py"
check "spaced filename listed as target" PASS "src/my dir/c.py"
t_done test_spaced_target_path

setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> Refactor to use `src/legacy/old.py` helper.
- [ ] NEW FILE -> `src/new_mod.py` -> Fresh helper.
- [ ] `NEW FILE` -> `src/backticked_new.py` -> Fresh component.
- [ ] `MODIFY` -> `src/modified_target.py` -> Modify component.
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p src/legacy; echo "w=1" > src/legacy/old.py
check "path named only in prose stays blocked" BLOCK src/legacy/old.py
check "the real target still commits" PASS src/a.py
echo "def h(): pass" > src/new_mod.py
check "NEW FILE marker skipped, path taken" PASS src/new_mod.py
echo "def bn(): pass" > src/backticked_new.py
check "backticked NEW FILE marker resolves to path" PASS src/backticked_new.py
echo "def mt(): pass" > src/modified_target.py
check "backticked MODIFY marker resolves to path" PASS src/modified_target.py
t_done test_target_line_parsing

echo "== concurrent plans and shared docs =="
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
echo "# Cookbook" > COOKBOOK.md
check "invariant anchor COOKBOOK.md passes without plan targets" PASS COOKBOOK.md
mkdir -p docs/concepts; echo "# Concept" > docs/concepts/arch.md
check "shared documentation docs/* passes without plan targets" PASS docs/concepts/arch.md
echo "b" > .git/aapp_active_plan
echo "b=1" > src/b.py
check "plan B's own target not blocked by plan A" PASS src/b.py
echo "c=1" > src/c.py
check "file in no plan still blocked" BLOCK src/c.py
rm -f .git/aapp_active_plan
check "multiple in-development plans without buffer blocked" BLOCK src/b.py
t_done test_concurrent_plans_and_shared_docs

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
t_done test_own_out_of_bounds_wins

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
t_done test_out_of_bounds_only_plan

echo "== plan statuses =="
setup
plan blocked.md <<'EOF'
* **Status:** 🟥 BLOCKED
* **Blocked On:** BUG-042
### 📂 Target Files (Modifications & Additions)
- [ ] `src/blocked_target.py` -> would be allowed if not blocked
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "bt=1" > src/blocked_target.py
check "commit against a BLOCKED plan is refused" BLOCK src/blocked_target.py
t_done test_blocked_plan_refused

# Adopter statuses: the hook reads them as the verbs do (#85).
setup
git config aapp.planState.blocked "⛔|Halted|⛔ Halted|40"
git config aapp.planState.in-development "🚧|Building|🚧 Building|30"
plan halted.md <<'EOF'
* **Status:** ⛔ Halted
### 📂 Target Files (Modifications & Additions)
- [ ] `src/halted_target.py` -> would be allowed if not halted
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check "adopter blocked status" BLOCK src/halted_target.py
rm -f .plans/current/halted.md
plan building.md <<'EOF'
* **Plan ID:** P-40
* **Status:** 🚧 Building
### 📂 Target Files (Modifications & Additions)
- [ ] `src/building_target.py` -> the plan in development
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check "adopter in-development plan's target" PASS src/building_target.py
check "adopter in-development plan confines" BLOCK src/elsewhere.py
t_done test_hook_follows_adopter_statuses

echo "== staged content checks =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/my dir/bad.py` -> target with space
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p "src/my dir"; echo "def bad(: pass" > "src/my dir/bad.py"
check "broken python in spaced path is caught" BLOCK "src/my dir/bad.py"
t_done test_syntax_check_spaced_path

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
commit_says "deleting an out-of-bounds file" BLOCK "delete secret"
t_done test_deleting_out_of_bounds_file_refused

setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "hotfix=1" >> src/a.py; git add src/a.py
SKIP_BLAST_RADIUS=1 git commit -qm "emergency hotfix" >/dev/null 2>&1 || t_fail "SKIP_BLAST_RADIUS=1 did not bypass the changelog rule"
t_done test_skip_blast_radius_escape

echo "== changelog in .plans =="
setup
rm -f CHANGELOG.md
git commit -qm "remove root changelog" --allow-empty
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
touch .plans/CHANGELOG.md
echo "x=2" > src/a.py
git add src/a.py .plans/CHANGELOG.md
commit_says "staged .plans/CHANGELOG.md" PASS "code with .plans changelog"
# The .plans worktree's own status counts, not file times.
git init -q .plans
git -C .plans config user.email "test@example.com"; git -C .plans config user.name "Tester"
echo "uncommitted changelog entry" >> .plans/CHANGELOG.md
echo "x=3" > src/a.py; git add src/a.py
commit_says "changed .plans worktree changelog" PASS "code with .plans worktree changelog"
rm -rf .plans/.git
t_done test_plans_changelog_satisfies_rule

echo "== hook without its exec bit =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
mkdir -p .githooks
cp "$KIT/templates/aapp-pre-commit" .githooks/aapp-pre-commit
cp "$KIT/lib/aapp-lib.sh" "$KIT/lib/plan_states.sh" .githooks/
chmod -x .githooks/aapp-pre-commit
cp "$KIT/templates/pre-commit" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
echo "bad=1" > src/untracked.py
echo "- bump changelog" >> CHANGELOG.md
git add src/untracked.py CHANGELOG.md
commit_says "violation without +x" BLOCK "commit untracked" "Pre-Commit Blast Radius Violation"
t_done test_hook_runs_without_exec_bit

echo "== branch protection =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=10" > src/a.py
check "single-branch repo allows commit on main" PASS src/a.py
git branch develop
echo "x=11" > src/a.py
git add src/a.py CHANGELOG.md
commit_says "direct commit on main with develop present" BLOCK "direct to main" "Direct commits to 'main' are prohibited"
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
git checkout -q develop
echo "x=12" > src/a.py
check "commit on develop branch succeeds" PASS src/a.py
git checkout -q main
echo "x=13" > src/a.py; echo "- emergency fix" >> CHANGELOG.md; git add src/a.py CHANGELOG.md
ALLOW_MAIN_COMMIT=1 git commit -qm "emergency commit on main" >/dev/null 2>&1 || t_fail "ALLOW_MAIN_COMMIT=1 refused"
git config --bool aapp.protectStable false
echo "x=14" > src/a.py; echo "- bump" >> CHANGELOG.md; git add src/a.py CHANGELOG.md
commit_says "aapp.protectStable false" PASS "commit on main with protectStable=false"
git config --unset aapp.protectStable
setup
git branch staging
git config aapp.devBranch staging
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=15" > src/a.py; echo "- bump" >> CHANGELOG.md; git add src/a.py CHANGELOG.md
commit_says "custom devBranch protects main" BLOCK "direct to main with staging dev" "staging"
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
git checkout -q staging
echo "x=16" > src/a.py
check "commit on custom dev branch staging succeeds" PASS src/a.py
t_done test_branch_protection

echo "== issue ledgers =="
setup
cat > .plans/issues_road_map.md <<'EOF'
# 🗺️ Issue Work Queue
> **Role:** Resolved issues are auto-pruned.
## 📋 Queued
1. `ISSUE-001` -> Still open
2. `ISSUE-002` -> All done ✅ `Resolved`
- [ ] `ISSUE-003` -> Open edge case
3. #2 -> All done ✅ Resolved
- [ ] #3 -> Done Resolved
EOF
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=20" > src/a.py; echo "- bump" >> CHANGELOG.md; git add src/a.py CHANGELOG.md
commit_says "commit with resolved road map lines" PASS "commit with resolved issue in roadmap"
for gone in ISSUE-002 '#2 ' '#3 '; do grep -qF -- "$gone" .plans/issues_road_map.md && t_fail "resolved line [$gone] kept"; done
for kept in ISSUE-001 ISSUE-003 "Resolved issues are auto-pruned"; do grep -qF -- "$kept" .plans/issues_road_map.md || t_fail "line [$kept] pruned"; done
t_done test_roadmap_auto_prune

setup
cat > .plans/ISSUES.md <<'EOF'
# 🐛 Issues: Active Technical Backlog
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `SEC` | 2026-09-09 | `src/a.py:1` | Issue symptom. |  | ✅ `Resolved` |
EOF
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "x=22" > src/a.py; echo "- bump" >> CHANGELOG.md; git add src/a.py CHANGELOG.md
commit_says "resolved row in active ISSUES.md" BLOCK "commit with resolved issue in ISSUES.md" "Found resolved issue in active"
t_done test_resolved_issue_row_refused

echo "== glob targets =="
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
t_done test_glob_targets

echo "== design lock =="
setup
create_and_commit_plan() {
  cat > .plans/current/p.md <<EOF
# 🗺️ Plan P-1: Test Plan
* **Plan ID:** P-1
* **Status:** $1

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
  git commit -qm "add plan with status $1"
  BASE_COMMIT=$(git rev-parse HEAD)
}
# check_plans_commit <label> <PASS|BLOCK> <plan file>…: commits the plan files, then resets.
check_plans_commit() {
  local name="$1" expect="$2" f; shift 2
  for f in "$@"; do git add ".plans/current/$f"; done
  local out rc got=BLOCK; out=$(git commit -m "update plans" 2>&1); rc=$?
  [ $rc -eq 0 ] && got=PASS
  [ "$got" = "$expect" ] || t_fail "$name: want $expect got $got $(echo "$out" | grep -E "❌|Violation" | head -2 | tr '\n' ' ')"
  git reset -q --hard "$BASE_COMMIT" 2>/dev/null
}
create_and_commit_plan "🔷 Frozen"
sed -i 's/- \[ \] Task 1.1/- [x] Task 1.1/' .plans/current/p.md
check_plans_commit "checkbox tick on frozen plan" PASS p.md
echo "* 2026-09-17: Verified phase 1." >> .plans/current/p.md
check_plans_commit "changelog append on frozen plan" PASS p.md
sed -i 's/\* \[ \] Question 1/* [x] Question 1: answered/' .plans/current/p.md
check_plans_commit "open question update on frozen plan" PASS p.md
sed -i 's/Original technical blueprint architecture./Tampered architecture./' .plans/current/p.md
check_plans_commit "blueprint edit on frozen plan" BLOCK p.md
sed -i 's/src\/a\.py/src\/extra\.py/' .plans/current/p.md
check_plans_commit "blast radius edit on frozen plan" BLOCK p.md
sed -i 's/🔷 Frozen/📝 Refining/' .plans/current/p.md
check_plans_commit "unfreeze without design change" PASS p.md
sed -i 's/🔷 Frozen/📝 Refining/; s/Original technical blueprint architecture./Smuggled architecture./' .plans/current/p.md
check_plans_commit "blueprint edit smuggled into an unfreeze" BLOCK p.md
create_and_commit_plan "🟣 Under Review"
sed -i 's/Original technical blueprint architecture./Refined draft architecture./' .plans/current/p.md
check_plans_commit "blueprint edit on draft plan" PASS p.md
sed -i 's/src\/a\.py/src\/draft\.py/' .plans/current/p.md
check_plans_commit "blast radius edit on draft plan" PASS p.md
t_done test_frozen_design_lock

# P-99: a group's Architecture & Codemap and an amendments member's Target Files.
git rm -q .plans/current/p.md && git commit -qm "drop p" >/dev/null 2>&1
mkdir -p .plans/current
cat > .plans/current/g.md <<'EOF'
# 🧩 Group Plan P-2: Grp
* **Plan ID:** P-2
* **Status:** ⚡ In Development

## 1. Goal
Group goal.

## Architecture & Codemap
### ARCHITECTURE.md
<!-- aapp-base: new -->
````markdown
## Sec One
text one
````

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `ARCHITECTURE.md`
### 🛑 Out of Bounds

## 📦 6. Change Log & Refinement History
* 2026-10-17: Initial entry.
EOF
cat > .plans/current/a.md <<'EOF'
# 🗺️ Plan P-3: Grp Amendments
* **Plan ID:** P-3
* **Kind:** amendments
* **Group:** P-2
* **Status:** ⚡ In Development

## 2. Technical Blueprint
Amendments.

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `src/x.py` -> approved R1
### 🛑 Out of Bounds

## 📦 6. Change Log & Refinement History
* 2026-10-17: Initial entry.

## Decisions
EOF
git add .plans/current/g.md .plans/current/a.md && git commit -qm "group and amendments" >/dev/null 2>&1
BASE_COMMIT=$(git rev-parse HEAD)
sed -i 's/^text one$/text two/' .plans/current/g.md
check_plans_commit "group section change alone" BLOCK g.md
sed -i 's/^text one$/text two/' .plans/current/g.md
echo "- **D1** 2026-10-17 · § Sec One · R1 · reason" >> .plans/current/a.md
check_plans_commit "group section change with its decision" PASS g.md a.md
sed -i 's/^text one$/text two/' .plans/current/g.md
echo "- **D1** 2026-10-17 · § Other Sec · R1 · reason" >> .plans/current/a.md
check_plans_commit "group section change with a decision for another heading" BLOCK g.md a.md
sed -i 's/^Group goal\.$/Group goal, reworded./' .plans/current/g.md
check_plans_commit "group text outside the section" PASS g.md
sed -i 's/^### 🛑 Out of Bounds$/- [ ] `src\/y.py` -> approved R2\n### 🛑 Out of Bounds/' .plans/current/a.md
check_plans_commit "amendments target added" PASS a.md
sed -i 's/src\/x\.py/src\/z.py/' .plans/current/a.md
check_plans_commit "amendments target changed" BLOCK a.md
sed -i 's/^Amendments\.$/Amendments, reworded./' .plans/current/a.md
check_plans_commit "amendments blueprint changed" BLOCK a.md
sed -i 's/^### 🛑 Out of Bounds$/- [ ] `ARCHITECTURE2.md`\n### 🛑 Out of Bounds/' .plans/current/g.md
check_plans_commit "target added to another plan in development" BLOCK g.md
t_done test_group_and_amendments_lock

echo "== active plan buffer =="
setup
touch aapp
rm -rf .plans/current
echo "bad=1" > src/a.py
check "missing .plans/current in a kit repo quarantines" BLOCK src/a.py
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
check "frozen backlog plan restricts nothing (#98)" PASS src/p17.py
"$KIT/aapp" start 17 >/dev/null 2>&1
check "started plan commits" PASS src/p17.py
"$KIT/aapp" plan-clear >/dev/null 2>&1
check "single in-development plan found without buffer" PASS src/p17.py
plan p18.md <<'EOF'
* **Plan ID:** P-18
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/p18.py` -> plan 18 target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "p18=1" > src/p18.py
check "two plans in development without buffer" BLOCK src/p18.py
"$KIT/aapp" active 18 >/dev/null 2>&1
check "buffer P-18: its target" PASS src/p18.py
check "buffer P-18: P-17's target" BLOCK src/p17.py
"$KIT/aapp" active swap >/dev/null 2>&1
check "swapped to P-17: its target" PASS src/p17.py
check "swapped to P-17: P-18's target" BLOCK src/p18.py
t_done test_active_plan_buffer

echo "== portability =="
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
# doc_says <label> <PASS|BLOCK> <doc.md text>
doc_says() {
  echo "$3" > doc.md; echo "- bump $(date +%s%N)" >> CHANGELOG.md
  git add CHANGELOG.md doc.md
  commit_says "$1" "$2" t
  git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null; git clean -qfd -e .plans 2>/dev/null
}
doc_says "file:/// URI" BLOCK "See [doc](file:///home/user/repo/doc.md)"
doc_says "/home/ link" BLOCK "See [doc](/home/user/repo/doc.md)"
doc_says "relative links" PASS "See [doc](doc.md) and [other](../other.md)"
doc_says "file:// named in prose" PASS "Never use file:// URIs in repository files."
t_done test_portability_paths

echo "== circuit breaker =="
setup
plan p_pause.md <<'EOF'
* **Plan ID:** P-60
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/pause_code.py` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
echo "def f(): pass" > src/pause_code.py; echo "- entry" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md .plans
commit_says "before pause" PASS "feat: add pause target"
"$KIT/aapp" pause "focusing on another project" >/dev/null 2>&1
echo "def f2(): pass" >> src/pause_code.py; echo "- bump" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md
commit_says "code while paused" BLOCK "feat: modify code while paused" "Project Circuit Breaker"
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
echo "new note" > .plans/pickup.md; git add .plans/pickup.md
commit_says ".plans/pickup while paused" PASS "chore(plans): add note while paused"
mkdir -p .agents; echo "rule" > .agents/AGENTS.md; git add .agents/AGENTS.md
commit_says ".agents while paused" BLOCK "chore(agents): add rule while paused" "Project Circuit Breaker"
git reset -q .agents/AGENTS.md >/dev/null 2>&1; rm -rf .agents
mkdir -p .plans/done; echo "done plan" > .plans/done/P01.md; git add .plans/done/P01.md
commit_says ".plans/done while paused" BLOCK "chore(plans): archive while paused" "Project Circuit Breaker"
git reset -q .plans/done/P01.md >/dev/null 2>&1; rm -rf .plans/done
"$KIT/aapp" resume >/dev/null 2>&1
touch "$(git rev-parse --git-path MERGE_HEAD)"
"$KIT/aapp" pause "in-flight test" >/dev/null 2>&1 && t_fail "pause ran during a merge"
rm -f "$(git rev-parse --git-path MERGE_HEAD)"
echo "def f3(): pass" >> src/pause_code.py; echo "- bump resume" >> CHANGELOG.md
git add src/pause_code.py CHANGELOG.md
commit_says "after resume" PASS "feat: commit after resume"
t_done test_pause_blocks_code_commits

git worktree add -q "$R/wt-branch2" -b branch2 >/dev/null 2>&1
echo "dirty develop" > src/dirty_dev.txt
echo "dirty wt2" > "$R/wt-branch2/src/dirty_wt.txt"
"$KIT/aapp" pause "quarantine multi-worktree" >/dev/null 2>&1
t_expect "main checkout after pause" "" "$(git status --porcelain)"
t_expect "second worktree after pause" "" "$(git -C "$R/wt-branch2" status --porcelain)"
"$KIT/aapp" resume >/dev/null 2>&1
[ -f src/dirty_dev.txt ] && [ -f "$R/wt-branch2/src/dirty_wt.txt" ] || t_fail "resume did not restore both worktrees"
rm -f src/dirty_dev.txt "$R/wt-branch2/src/dirty_wt.txt"
rm -rf "$R/wt-branch2"; git worktree prune >/dev/null 2>&1
t_done test_pause_quarantines_every_worktree

echo "conflict base" > src/conflict.txt
git add src/conflict.txt; git commit -qm "add conflict base"
echo "modified for stash" > src/conflict.txt
"$KIT/aapp" pause "conflict test" >/dev/null 2>&1
echo "conflicting change while away" > src/conflict.txt
git commit --no-verify -qam "upstream conflicting commit" >/dev/null 2>&1
"$KIT/aapp" resume >/dev/null 2>&1 && t_fail "conflicting resume passed"
[ -f "$(git rev-parse --git-common-dir)/aapp_paused" ] || t_fail "pause buffer lost"
[ -n "$(git stash list)" ] || t_fail "stash lost"
rm -f "$(git rev-parse --git-common-dir)/aapp_paused"
git stash clear >/dev/null 2>&1
git reset --hard HEAD~1 >/dev/null 2>&1
t_done test_resume_conflict_loses_nothing

echo "== reachability =="
setup
plan p_reach.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/reach.py` -> reachability test
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
empty_home="$R/reach_empty_home"; mkdir -p "$empty_home"
cp "$HOME/.gitconfig" "$empty_home/.gitconfig" 2>/dev/null
# reach <n> <changelog?> <env…> -- <git commit args…>: stages a change, then commits under the environment.
stage_reach() { echo "reach=$1" > src/reach.py; [ "$2" = cl ] && echo "- bump reach $1" >> CHANGELOG.md; git add src/reach.py CHANGELOG.md; }
stage_reach 1 cl
out=$(HOME="$empty_home" PATH="$SANDBOX_CLEAN_PATH" git commit -m "feat: reach neg" 2>&1) && t_fail "no aapp reachable: commit passed"
echo "$out" | grep -q "INSPECTION-ONLY mode" || t_fail "no inspection-only notice: $(echo "$out" | head -2)"
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
stage_reach 2 cl
out=$(HOME="$empty_home" PATH="$SANDBOX_CLEAN_PATH" SKIP_BLAST_RADIUS=1 git commit -m "feat: reach skip" 2>&1) && t_fail "SKIP_BLAST_RADIUS bypassed reachability"
echo "$out" | grep -q "INSPECTION-ONLY mode" || t_fail "skip: no inspection-only notice"
git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
stage_reach 3 cl
git commit -qm "feat: reach positive" >/dev/null 2>&1 || t_fail "aapp on the path: commit refused"
stage_reach 4 cl
PATH="$SANDBOX_CLEAN_PATH" git commit -qm "feat: reach fallback" >/dev/null 2>&1 || t_fail "~/.local/bin/aapp fallback refused"
stage_reach 5 no
HOME="$empty_home" PATH="$SANDBOX_CLEAN_PATH" git commit --no-verify -qm "feat: reach native bypass" >/dev/null 2>&1 || t_fail "--no-verify refused"
t_done test_runtime_reachability

echo "== parser boundaries (#82, P-37) =="
setup
plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
> **Authoring rule:** a quoted `src/quoted.py` in blockquote prose is never a target.
- [ ] `src/a.py` -> allowed
### 📝 Implementation Notes
- `src/notes.py` -> named under a non-target heading
### 🧪 Required Test Files
> Test files that must prove this plan's failure cases.
- `tests/boundary_test.sh`
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
check "blockquote path" BLOCK src/quoted.py
check "foreign subsection path" BLOCK src/notes.py
check "Required Test Files path" PASS tests/boundary_test.sh
check "declared target still committable beside them" PASS src/a.py
t_done test_parser_boundaries

echo "== fail-closed library load (P-37, #85) =="
for lib in aapp-lib.sh plan_states.sh; do
  setup
  rm -f ".git/hooks/$lib"
  plan p.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
## end
EOF
  check "missing $lib" BLOCK src/a.py
  out=$(git commit --allow-empty -m "t" 2>&1)
  case "$lib" in
    aapp-lib.sh) echo "$out" | grep -q "Shared library or status registry missing or unreadable" || t_fail "missing $lib: no diagnostic" ;;
    *) echo "$out" | grep -q "plan_states.sh" || t_fail "missing $lib: not named" ;;
  esac
done
t_done test_missing_library_refuses_commit

echo "== failure-test declarations (P-35) =="
setup
plan no_tdd.md <<'EOF'
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
EOF
check "plan without required tests" PASS src/a.py
tdd_plan() {  # tdd_plan <status> <§3 test file> <§4 test file lines…>
  local status="$1" s3="$2"; shift 2
  setup
  { printf '* **Status:** %s\n## 🔨 3. Implementation Steps & Execution Checklist\n### 🧪 Required Tests (Failure & Boundary Assertions)\n' "$status"
    printf -- '- [ ] `%s::test_fail` -> asserts error\n' "$s3"
    printf '## 💥 4. Blast Radius & System Boundaries\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py`\n### 🧪 Required Test Files\n'
    local f; for f in "$@"; do printf -- '- `%s`\n' "$f"; done
    printf '### 🛑 Out of Bounds (Do Not Touch)\n'; } | plan_full tdd.md
}
tdd_plan "⚡ In Development" tests/b_test.py tests/a_test.py
mkdir -p tests; touch tests/a_test.py tests/b_test.py
check "§3 test not in §4" BLOCK src/a.py
tdd_plan "⚡ In Development" tests/a_test.py tests/a_test.py tests/b_test.py
mkdir -p tests; touch tests/a_test.py tests/b_test.py
check "§4 file not in §3" BLOCK src/a.py
tdd_plan "📝 Refining" tests/a_test.py tests/a_test.py
check "refining plan with unwritten tests" PASS src/a.py
tdd_plan "⚡ In Development" tests/a_test.py tests/a_test.py
check "in development with a missing test file" BLOCK src/a.py
t_done test_failure_test_declaration

echo "== commit helper reminder (P-39) =="
setup
plan_full p_remind.md <<'EOF'
# Plan P-12: Reminder Test
* **Plan ID:** P-12
* **Status:** ⚡ In Development
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🛑 Out of Bounds (Do Not Touch)
EOF
echo "P-12" > .git/aapp_active_plan
echo "- change" >> CHANGELOG.md; echo "# change" >> src/a.py; git add src/a.py CHANGELOG.md
commit_says "raw commit" PASS "raw commit" '(record this commit with|aapp commit adopt)'
echo "- change 2" >> CHANGELOG.md; echo "# change 2" >> src/a.py; git add src/a.py CHANGELOG.md
out=$(AAPP_COMMIT_HELPER=1 git commit -m "helper commit" 2>&1) || t_fail "helper commit refused"
echo "$out" | grep -qiE '(record this commit with|aapp commit adopt)' && t_fail "helper commit printed the reminder"
t_done test_reminder_outside_helper_is_warning_only

echo "== changelog bullets (P-28) =="
# bullet_says <label> <PASS|BLOCK> <pattern> <line>…: commits CHANGELOG.md with the lines added.
bullet_says() {
  local name="$1" expect="$2" pat="$3"; shift 3
  setup
  printf '%s\n' "$@" >> CHANGELOG.md; git add CHANGELOG.md
  commit_says "$name" "$expect" "changelog" "$pat"
}
bullet_says "short bullet" PASS "" "- short valid bullet within limits"
long_bullet="- long bullet: "; while [ "${#long_bullet}" -lt 350 ]; do long_bullet="${long_bullet}word "; done
bullet_says "bullet over 300" BLOCK "Changelog bullet exceeds maximum length" "$long_bullet"
bullet_says "unbulleted continuation" BLOCK "unbulleted continuation line" "- valid bullet" "  unbulleted continuation line that should be refused"
setup
git config aapp.changelogMaxLen 80
echo "- mid length bullet that easily exceeds eighty characters in total length for this test" >> CHANGELOG.md; git add CHANGELOG.md
commit_says "bullet over aapp.changelogMaxLen" BLOCK "custom threshold changelog" "Changelog bullet exceeds maximum length"
t_done test_changelog_bullet_rules

echo "== plan-declared changelog entry (P-48) =="
# commit_code <label> <PASS|BLOCK>: commits a change to src/a.py WITHOUT touching CHANGELOG.md.
commit_code() {
  printf '# touch %s\n' "$(date +%s%N)" >> src/a.py; git add src/a.py
  commit_says "$1" "$2" t
  git reset -q >/dev/null 2>&1; git checkout -q . 2>/dev/null
}
setup
plan P7-entry.md <<'EOF'
* **Plan ID:** P-7
* **Status:** ⚡ In Development
* **Changelog:** Added: Entry thing
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> change a
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
printf '# Changelog\n\n## [Unreleased]\n\n### Added\n- Other thing (`P-3`)\n' > CHANGELOG.md
git add CHANGELOG.md; git commit -qm "changelog without P-7" --no-verify
# The hook accepts a commit right after one that touched CHANGELOG.md; keep it out of these cases.
git commit -q --allow-empty -m "spacer" --no-verify
commit_code "plan mode, no entry" BLOCK
echo "$LAST_OUT" | grep -q "aapp commit" || t_fail "refusal does not name 'aapp commit'"
printf -- '- Entry thing (`P-7`)\n' >> CHANGELOG.md
git add CHANGELOG.md; git commit -qm "add P-7 entry" --no-verify
git commit -q --allow-empty -m "spacer" --no-verify
commit_code "plan mode, entry present" PASS
git config aapp.changelogMode commit
commit_code "commit mode, entry present" BLOCK
git config --unset aapp.changelogMode
rm -f .plans/current/P7-entry.md
commit_code "no active plan" BLOCK
t_done test_plan_declared_changelog_entry

echo "== plans held by another worktree (P-52) =="
setup
plan p60.md <<'EOF'
* **Plan ID:** P-60
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/held.py` -> held elsewhere
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
git add -A >/dev/null; git commit -qm "add p60" >/dev/null 2>&1
git worktree add -q "$R/wt-held" HEAD >/dev/null 2>&1
( cd "$R/wt-held" && "$KIT/aapp" active P-60 >/dev/null 2>&1 )
check "held plan's file from an unbound checkout" BLOCK src/held.py
check "other files from an unbound checkout" PASS src/free.py
rm -rf "$R/wt-held"; git worktree prune >/dev/null 2>&1
t_done test_plans_held_by_another_worktree

echo "== .gitattributes (#97) =="
setup
plan p97.md <<'EOF'
* **Plan ID:** P-97
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/other.py` -> unrelated target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check ".gitattributes while a plan is in development" PASS .gitattributes
t_done test_gitattributes_always_allowed

echo "== commit modes (P-51) =="
setup
git config aapp.commitMode atomic
cat > .plans/current/p51.md <<EOF
* **Plan ID:** P-51
* **Status:** ⚡ In Development
* **Commits:** \`$(git rev-parse --short HEAD)\` ($(git branch --show-current))

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] \`src/a.py\` -> target
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
check "atomic: raw commit once the plan has one" BLOCK src/a.py
AAPP_COMMIT_HELPER=1 check "atomic: helper commit" PASS src/a.py
git config aapp.commitMode microcommits
check "microcommits: raw commit" PASS src/a.py
git config aapp.commitMode atomic
rm -f .plans/current/p51.md
check "atomic with no plan in development" PASS src/a.py
t_done test_atomic_commit_mode

echo "== group members and ARCHITECTURE.md (P-64) =="
setup
git config aapp.commitMode microcommits
plan_with_group() {
  { echo "* **Plan ID:** P-71"; echo "* **Status:** ⚡ In Development"; [ -n "$1" ] && echo "* **Group:** $1"
    echo "## 💥 4. Blast Radius & System Boundaries"; echo "### 📂 Target Files (Modifications & Additions)"
    echo "- [ ] \`src/a.py\` -> target"; echo "### 🛑 Out of Bounds (Do Not Touch)"; echo "## end"; } | plan_full p71.md
}
plan_with_group P-70
echo "- bump" >> CHANGELOG.md; echo "# arch" >> ARCHITECTURE.md; git add CHANGELOG.md ARCHITECTURE.md
commit_says "member commits ARCHITECTURE.md" BLOCK t "P-70"
git reset -q; git checkout -q . 2>/dev/null; rm -f ARCHITECTURE.md
plan_with_group ""
check "plan without a group commits ARCHITECTURE.md" PASS ARCHITECTURE.md
t_done test_member_leaves_architecture_to_group

print_test_summary "$PASS" "$FAIL"
