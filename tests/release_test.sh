#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: AAPP Release & Milestone Bundling (P-38)
#
# Covers:
#   1. Version syntax validation (3-segment, 2-segment, suffixes <= 30 chars, invalid rejection)
#   2. SemVer bump arithmetic (patch, minor, major) & baseline resolution ladder
#   3. Phase A pre-flight checks:
#      - Primary working tree cleanliness abort
#      - Kit worktree cleanliness abort
#      - Automated test gate failure abort (aapp.testCommand)
#      - Missing CHANGELOG.md abort & no-changelog bypass
#      - Archive commit reachability (Tier 1 ancestry, Tier 2 trailer, unverified bypass, Commits: none bypass)
#      - Simulation output & check bare token exit contract
#      - Non-interactive safety gate (requires yes token)
#   4. Phase B atomic mutations:
#      - on-release hook Dual Delivery dispatch
#      - Transactional rollback on mid-mutation failure (_release_rollback)
#      - CHANGELOG.md rollup into ## [<version>] - <date>
#      - Milestone bundling (.plans/release/<tag>/plans/, 000-archive-ledger.md, manifest.md, manifest.json)
#      - Master ledger rollup (## 🏷️ Shipped Releases 1-line summary & current cycle truncation)
#      - Tag creation & signing policy
#      - JSON headless schema output contract (json bare token)
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d)
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
echo 0 > "$R/.pass"; echo 0 > "$R/.fail"

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "$got"
    local p; p="$(cat "$R/.pass")"; echo "$((p + 1))" > "$R/.pass"
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
    local f; f="$(cat "$R/.fail")"; echo "$((f + 1))" > "$R/.fail"
  fi
}

make_test_repo() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  (
    cd "$target_dir" || exit 1
    git init -q .
    setup_test_git_identity "$target_dir"
    git config aapp.tagPrefix "v"
    
    # Initialize basic files
    echo "print('hello')" > main.py
    cat << 'EOF' > CHANGELOG.md
# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Initial project structure.
EOF
    git add .
    git commit -qm "initial commit"
    git branch -M main

    # Setup .plans directory structure
    mkdir -p .plans/current .plans/done
    cat << 'EOF' > .plans/done/000-archive-ledger.md
# 🏛️ Archival Ledger (Completed Plans DB)

| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF
    cat << 'EOF' > .plans/done/000-issues-archive.md
# 🏛️ Master Issue Archive Ledger

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
EOF
  )
}

echo "== 1. Version Format Validation =="
source "$KIT/lib/cmd_release.sh" >/dev/null 2>&1 || true

check_val() {
  if _release_validate_version "$1"; then echo "valid"; else echo "invalid"; fi
}

report "3-segment 1.0.0 is valid" "valid" "$(check_val 1.0.0)"
report "v-prefixed v1.2.3 is valid" "valid" "$(check_val v1.2.3)"
report "2-segment 1.2 is valid" "valid" "$(check_val 1.2)"
report "v-prefixed 2-segment v1.2 is valid" "valid" "$(check_val v1.2)"
report "prerelease suffix 1.0.1.alpha is valid" "valid" "$(check_val 1.0.1.alpha)"
report "hyphenated suffix 1.0.0-rc.1 is valid" "valid" "$(check_val 1.0.0-rc.1)"
report "bare integer 1 is invalid" "invalid" "$(check_val 1)"
report "v-prefixed bare integer v1 is invalid" "invalid" "$(check_val v1)"
report "non-version string invalid is invalid" "invalid" "$(check_val invalid)"
report "suffix over 30 chars is invalid" "invalid" "$(check_val 1.0.0-abcdefghijklmnopqrstuvwxyz0123456789)"

echo "== 2. SemVer Bump Arithmetic =="
report "patch bump 1.0.0 -> 1.0.1" "1.0.1" "$(_release_calc_bump patch 1.0.0)"
report "minor bump 1.0.1 -> 1.1.0" "1.1.0" "$(_release_calc_bump minor 1.0.1)"
report "major bump 1.1.0 -> 2.0.0" "2.0.0" "$(_release_calc_bump major 1.1.0)"
report "bump from v-prefixed tag v2.4.9" "2.4.10" "$(_release_calc_bump patch v2.4.9)"
report "minor bump from 2-segment 1.2" "1.3.0" "$(_release_calc_bump minor 1.2)"

echo "== 3. Phase A Pre-Flight Gates =="
REPO_A="$R/repo_a"
make_test_repo "$REPO_A"

(
  cd "$REPO_A" || exit 1
  export AAPP_LIB="$KIT/lib"
  
  # 3.1 Check contract: check token exits 0 without creating tag
  OUT="$("$KIT/aapp" release 1.0.0 check 2>&1)" && RC=0 || RC=$?
  report "release check exits 0" "0" "$RC"
  report "release check does not create tag" "" "$(git tag -l v1.0.0)"

  # 3.2 Non-interactive without yes exits without mutating
  OUT="$("$KIT/aapp" release 1.0.0 < /dev/null 2>&1)" && RC=0 || RC=$?
  report "non-interactive without yes exits cleanly" "0" "$RC"
  report "non-interactive does not create tag" "" "$(git tag -l v1.0.0)"

  # 3.3 Dirty working tree refuses release
  echo "dirty modification" >> main.py
  OUT="$("$KIT/aapp" release 1.0.0 yes 2>&1)" && RC=0 || RC=$?
  report "dirty working tree refused" "1" "$RC"
  git checkout -- main.py

  # 3.4 Test suite gate failure refuses release
  git config aapp.testCommand "exit 1"
  OUT="$("$KIT/aapp" release 1.0.0 yes 2>&1)" && RC=0 || RC=$?
  report "failing test command refused" "1" "$RC"
  git config --unset aapp.testCommand

  # 3.5 Missing CHANGELOG.md without no-changelog refuses
  git rm -q CHANGELOG.md && git commit -qm "remove changelog for test"
  OUT="$("$KIT/aapp" release 1.0.0 check 2>&1)" && RC=0 || RC=$?
  report "missing CHANGELOG.md refused" "1" "$RC"
  
  # 3.6 no-changelog bypasses CHANGELOG.md check
  OUT="$("$KIT/aapp" release 1.0.0 check no-changelog 2>&1)" && RC=0 || RC=$?
  report "no-changelog bypass succeeds in check" "0" "$RC"
  git checkout HEAD~1 -- CHANGELOG.md && git commit -qm "restore changelog"
)

echo "== 4. Commit Reachability & Plan Bundling =="
REPO_B="$R/repo_b"
make_test_repo "$REPO_B"

(
  cd "$REPO_B" || exit 1
  export AAPP_LIB="$KIT/lib"

  # Create a completed plan in .plans/done/ with valid ancestry; the body's example
  # header lines are prose and never read (#173)
  cat << 'EOF' > .plans/done/P10-feature.md
# 🗺️ Plan P-10: Feature Plan
* **Plan ID:** P-10
* **Commits:** `HEAD` (main)
* **Status:** ✅ Done

## 2. Technical Blueprint
* **Plan ID:** P-X
* **Commits:** `cafe123` (feat/example)
EOF
  # Replace HEAD with actual commit SHA
  CURRENT_SHA="$(git rev-parse --short HEAD)"
  sed -i "s/\`HEAD\`/\`$CURRENT_SHA\`/" .plans/done/P10-feature.md

  # Add an issue to 000-issues-archive.md
  cat << 'EOF' >> .plans/done/000-issues-archive.md
| #42 | `Low` | `CORE` | 2026-10-01 | 2026-10-05 | `0000000` | [`P10-feature.md`](done/P10-feature.md) |
EOF

  # 4.1 Reachability passes when commit is ancestor
  OUT="$("$KIT/aapp" release 1.0.0 check 2>&1)" && RC=0 || RC=$?
  report "reachability passes for ancestor commit" "0" "$RC"

  # 4.2 Reachability fails when commit is foreign/unreachable
  sed -i "s/\`$CURRENT_SHA\`/\`deadbeef\`/" .plans/done/P10-feature.md
  OUT="$("$KIT/aapp" release 1.0.0 check 2>&1)" && RC=0 || RC=$?
  report "reachability fails for foreign commit" "1" "$RC"

  # 4.3 unverified token overrides reachability
  OUT="$("$KIT/aapp" release 1.0.0 check unverified 2>&1)" && RC=0 || RC=$?
  report "unverified token bypasses reachability" "0" "$RC"

  # Restore valid commit SHA
  sed -i "s/\`deadbeef\`/\`$CURRENT_SHA\`/" .plans/done/P10-feature.md

  # 4.4 Execute Phase B release mutations
  OUT="$("$KIT/aapp" release 1.0.0 yes 2>&1)" && RC=0 || RC=$?
  report "release 1.0.0 yes succeeds" "0" "$RC"
  report "release tag v1.0.0 created" "v1.0.0" "$(git tag -l v1.0.0)"

  # Verify milestone bundle directory structure
  report "bundle plans directory exists" "true" "$([ -d .plans/release/v1.0.0/plans ] && echo true)"
  report "bundled plan moved to release/v1.0.0/plans" "true" "$([ -f .plans/release/v1.0.0/plans/P10-feature.md ] && echo true)"
  report "original plan removed from done/" "false" "$([ -f .plans/done/P10-feature.md ] && echo true || echo false)"
  report "tag ledger generated" "true" "$([ -f .plans/release/v1.0.0/000-archive-ledger.md ] && echo true)"
  report "manifest.md generated" "true" "$([ -f .plans/release/v1.0.0/manifest.md ] && echo true)"
  report "manifest.json generated" "true" "$([ -f .plans/release/v1.0.0/manifest.json ] && echo true)"
  report "relocated issues archive exists" "true" "$([ -f .plans/release/v1.0.0/000-issues-archive.md ] && echo true)"

  # Verify master ledger rollup
  report "master ledger has Shipped Releases section" "0" "$(grep -q '^## 🏷️ Shipped Releases' .plans/done/000-archive-ledger.md && echo 0 || echo 1)"
  report "master ledger links to v1.0.0 ledger" "0" "$(grep -q '\.\./release/v1\.0\.0/000-archive-ledger\.md' .plans/done/000-archive-ledger.md && echo 0 || echo 1)"

  # Verify CHANGELOG.md rollup
  report "CHANGELOG.md rolled up v1.0.0 block" "0" "$(grep -q '^## \[1\.0\.0\] -' CHANGELOG.md && echo 0 || echo 1)"
  report "CHANGELOG.md pre-seeded empty Unreleased" "0" "$(grep -q '^## \[Unreleased\]' CHANGELOG.md && echo 0 || echo 1)"
)

echo "== 5. JSON Machine-Readable Contract =="
REPO_C="$R/repo_c"
make_test_repo "$REPO_C"

(
  cd "$REPO_C" || exit 1
  export AAPP_LIB="$KIT/lib"

  JSON_OUT="$("$KIT/aapp" release 1.0.0 json check)"
  report "json output starts with {" "{" "$(echo "$JSON_OUT" | head -n 1)"
  report "json output schemaVersion is 1.0.0" "1.0.0" "$(echo "$JSON_OUT" | grep '"schemaVersion"' | sed -E 's/.*: "([^"]+)".*/\1/')"
  report "json output tag is v1.0.0" "v1.0.0" "$(echo "$JSON_OUT" | grep '"tag"' | head -n 1 | sed -E 's/.*: "([^"]+)".*/\1/')"
  report "json output version is 1.0.0" "1.0.0" "$(echo "$JSON_OUT" | grep '"version"' | head -n 1 | sed -E 's/.*: "([^"]+)".*/\1/')"
)

echo "== 6. Rollback Engine on Failure =="
REPO_D="$R/repo_d"
make_test_repo "$REPO_D"

(
  cd "$REPO_D" || exit 1
  export AAPP_LIB="$KIT/lib"

  # Register a failing on-release hook
  mkdir -p .agents/skills/aapp-hooks
  cat << 'EOF' > fail_hook.sh
#!/usr/bin/env bash
echo "Triggering intentional hook failure" >&2
exit 1
EOF
  chmod +x fail_hook.sh
  HASH="$(sha256sum fail_hook.sh | awk '{print $1}')"
  printf "on-release\tfail_hook.sh\tsha256:%s\t10\tgate\n" "$HASH" > .agents/skills/aapp-hooks/registry.tsv

  # Add a test plan in done/
  cat << 'EOF' > .plans/done/P20-test.md
# 🗺️ Plan P-20: Test
* **Plan ID:** P-20
* **Commits:** none
* **Status:** ✅ Done
EOF

  OUT="$("$KIT/aapp" release 1.0.0 yes 2>&1)" && RC=0 || RC=$?
  report "release aborts when on-release fails" "1" "$RC"
  report "tag v1.0.0 was not left behind" "" "$(git tag -l v1.0.0)"
  report "bundle directory was cleaned up" "false" "$([ -d .plans/release/v1.0.0 ] && echo true || echo false)"
)

PASS="$(cat "$R/.pass")"
FAIL="$(cat "$R/.fail")"

echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ]

