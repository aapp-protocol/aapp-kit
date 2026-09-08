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
  echo "x=1" > src/a.py; echo "# CL" > CHANGELOG.md
  git add -A >/dev/null; git commit -qm init
  cp "$HOOK" .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
}

check() {
  local name="$1" expect="$2"; shift 2
  echo "- bump $(date +%s%N)" >> CHANGELOG.md
  local f
  for f in "$@"; do
    [ -e "$f" ] && printf '# touch %s\n' "$(date +%s%N)" >> "$f"
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

echo ""
echo "  passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]
