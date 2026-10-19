#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: Kit on-release Action Delegate Hook (P-59)
#
# Covers:
#   1. Version extraction via POSIX Environment Variables (AAPP_RAW_VERSION)
#   2. Version extraction via STDIN JSON Dual Delivery payload
#   3. Atomic AAPP_VERSION synchronization in `aapp` CLI executable
#   4. Protocol delimiter synchronization in managed templates (`templates/*`)
#   5. Fail-closed rejection on missing payload or invalid version format
#   6. End-to-end integration with `aapp release` orchestrator
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

make_kit_mock_repo() {
  local dir="$1"
  mkdir -p "$dir/templates" "$dir/scripts"
  (
    cd "$dir" || exit 1
    git init -q .
    git config user.name "AAPP Tester"
    git config user.email "tester@aapp.dev"
    git config commit.gpgSign false

    # Mock aapp CLI
    cat <<'EOF' > aapp
#!/usr/bin/env bash
AAPP_VERSION="1.0.0"
echo "AAPP Kit $AAPP_VERSION"
EOF
    chmod +x aapp

    # Mock templates
    cat <<'EOF' > templates/AGENTS.md
# Project Rules
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Core Rules
<!-- AAPP-PROTOCOL:END -->
EOF

    cat <<'EOF' > templates/plan-template.md
# Blueprint
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Blueprint Details
<!-- AAPP-PROTOCOL:END -->
EOF

    cat <<'EOF' > templates/pickup.md
# Pickup
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Ideas
<!-- AAPP-PROTOCOL:END -->
EOF

    cat <<'EOF' > templates/release_checklist.md
# Checklist
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Checklist Items
<!-- AAPP-PROTOCOL:END -->
EOF

    cp "$KIT/scripts/kit-on-release.sh" scripts/kit-on-release.sh
    chmod +x scripts/kit-on-release.sh

    git add .
    git commit -qm "initial kit structure"
  )
}

echo "== 1. Environment Variable Dual Delivery =="
(
  REPO="$R/repo_env"
  make_kit_mock_repo "$REPO"
  cd "$REPO" || exit 1

  OUT="$(AAPP_RAW_VERSION="1.2.0" AAPP_RELEASE_VERSION="v1.2.0" ./scripts/kit-on-release.sh 2>&1)" && RC=0 || RC=$?
  report "hook exits 0 on valid environment variable" "0" "$RC" "$OUT"

  AAPP_LINE="$(grep '^AAPP_VERSION=' aapp)"
  report "aapp CLI AAPP_VERSION updated to 1.2.0" 'AAPP_VERSION="1.2.0"' "$AAPP_LINE"

  P_COUNT="$(grep -c '<!-- AAPP-PROTOCOL:START v1.2.0 -->' templates/*)"
  report "all 4 templates updated to v1.2.0" "4" "$(grep -l '<!-- AAPP-PROTOCOL:START v1.2.0 -->' templates/* | wc -l | tr -d ' ')"
)

echo "== 2. STDIN JSON Dual Delivery =="
(
  REPO="$R/repo_json"
  make_kit_mock_repo "$REPO"
  cd "$REPO" || exit 1

  OUT="$(printf '{"event":"on-release","tag":"v1.3.0","rawVersion":"1.3.0","version":"1.3.0"}\n' | ./scripts/kit-on-release.sh 2>&1)" && RC=0 || RC=$?
  report "hook exits 0 on valid STDIN JSON" "0" "$RC" "$OUT"

  AAPP_LINE="$(grep '^AAPP_VERSION=' aapp)"
  report "aapp CLI AAPP_VERSION updated to 1.3.0" 'AAPP_VERSION="1.3.0"' "$AAPP_LINE"

  report "all 4 templates updated to v1.3.0" "4" "$(grep -l '<!-- AAPP-PROTOCOL:START v1.3.0 -->' templates/* | wc -l | tr -d ' ')"
)

echo "== 3. Fail-Closed Error Validation =="
(
  REPO="$R/repo_err"
  make_kit_mock_repo "$REPO"
  cd "$REPO" || exit 1

  OUT="$(./scripts/kit-on-release.sh < /dev/null 2>&1)" && RC=0 || RC=$?
  report "hook fails when no version is supplied" "1" "$RC"

  OUT="$(AAPP_RAW_VERSION="invalid.version.format!!" ./scripts/kit-on-release.sh 2>&1)" && RC=0 || RC=$?
  report "hook fails when version syntax is invalid" "1" "$RC"
)

echo "== 4. End-to-End Release Integration =="
(
  REPO="$R/repo_e2e"
  make_kit_mock_repo "$REPO"
  cd "$REPO" || exit 1

  # Create full repo structure for aapp release
  mkdir -p .plans/done
  cat <<'EOF' > .plans/done/000-archive-ledger.md
# 🗄️ Master Archive Ledger
| Date | Plan ID | Blueprint / Specification | Target Issue / Milestone | Verification Commit | Impact Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF

  cat <<'EOF' > CHANGELOG.md
# Changelog
## [Unreleased]
### Added
- Sample feature
EOF

  git add .plans CHANGELOG.md
  git commit -qm "setup for release"

  # Register on-release hook
  git config aapp.hook.on-release "scripts/kit-on-release.sh"
  git config aapp.testCommand "true"
  git branch -M main

  # Execute aapp release 1.5.0
  OUT="$("$KIT/aapp" release 1.5.0 yes 2>&1)" && RC=0 || RC=$?
  report "aapp release triggers kit-on-release cleanly" "0" "$RC" "$OUT"

  AAPP_LINE="$(grep '^AAPP_VERSION=' aapp)"
  report "aapp CLI version bumped by release orchestrator" 'AAPP_VERSION="1.5.0"' "$AAPP_LINE"

  report "templates bumped to v1.5.0 by release orchestrator" "4" "$(grep -l '<!-- AAPP-PROTOCOL:START v1.5.0 -->' templates/* | wc -l | tr -d ' ')"
)

PASS="$(cat "$R/.pass")"
FAIL="$(cat "$R/.fail")"

echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ]
