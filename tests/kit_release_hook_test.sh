#!/usr/bin/env bash
# Core suite for the kit's own on-release hook (scripts/kit-on-release.sh,
# P-59): the version from the environment or stdin JSON is written into the
# CLI and every managed template, and `aapp release` runs it.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

# kit_repo <dir>: a mock kit at version 1.0.0 with four managed templates.
kit_repo() {
  local dir="$1" t
  mkdir -p "$dir/templates" "$dir/scripts"
  git init -q "$dir"
  printf '#!/usr/bin/env bash\nAAPP_VERSION="1.0.0"\necho "AAPP Kit $AAPP_VERSION"\n' > "$dir/aapp"
  chmod +x "$dir/aapp"
  for t in AGENTS plan-template pickup release_checklist; do
    printf '# %s\n<!-- AAPP-PROTOCOL:START v1.0.0 -->\nBody\n<!-- AAPP-PROTOCOL:END -->\n' "$t" > "$dir/templates/$t.md"
  done
  cp "$KIT/scripts/kit-on-release.sh" "$dir/scripts/kit-on-release.sh"
  chmod +x "$dir/scripts/kit-on-release.sh"
  git -C "$dir" add . && git -C "$dir" commit -qm "initial kit structure"
}
# bumped <dir> <version>: the CLI and all four templates carry <version>.
bumped() {
  t_expect "CLI version" "AAPP_VERSION=\"$2\"" "$(grep '^AAPP_VERSION=' "$1/aapp")"
  t_expect "templates at v$2" 4 "$(grep -l "<!-- AAPP-PROTOCOL:START v$2 -->" "$1"/templates/* | wc -l | tr -d ' ')"
}

echo "== version from the environment =="
kit_repo "$R/env"
out="$(cd "$R/env" && AAPP_RAW_VERSION=1.2.0 AAPP_RELEASE_VERSION=v1.2.0 ./scripts/kit-on-release.sh 2>&1)" || t_fail "hook failed: $out"
bumped "$R/env" 1.2.0
t_done test_version_from_environment

echo "== version from stdin JSON =="
kit_repo "$R/json"
out="$(cd "$R/json" && printf '{"event":"on-release","tag":"v1.3.0","rawVersion":"1.3.0","version":"1.3.0"}\n' | ./scripts/kit-on-release.sh 2>&1)" || t_fail "hook failed: $out"
bumped "$R/json" 1.3.0
t_done test_version_from_stdin_json

echo "== refusals =="
kit_repo "$R/err"
t_expect "no version rc" 1 "$(cd "$R/err" && ./scripts/kit-on-release.sh </dev/null >/dev/null 2>&1; echo $?)"
t_expect "invalid version rc" 1 "$(cd "$R/err" && AAPP_RAW_VERSION='invalid.version.format!!' ./scripts/kit-on-release.sh >/dev/null 2>&1; echo $?)"
bumped "$R/err" 1.0.0
t_done test_refuses_missing_or_invalid_version

echo "== aapp release =="
kit_repo "$R/e2e"
cd "$R/e2e" || exit 1
mkdir -p .plans/done
printf '%s\n' '# 🗄️ Master Archive Ledger' '| Date | Plan ID | Blueprint / Specification | Target Issue / Milestone | Verification Commit | Impact Summary |' \
  '| :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-archive-ledger.md
printf '%s\n' '# Changelog' '## [Unreleased]' '### Added' '- Sample feature' > CHANGELOG.md
git add .plans CHANGELOG.md && git commit -qm "setup for release"
git config aapp.hook.on-release scripts/kit-on-release.sh
git config aapp.testCommand true
git branch -M main
out="$("$KIT/aapp" release 1.5.0 yes 2>&1)" || t_fail "release failed: $out"
bumped "$R/e2e" 1.5.0
t_done test_release_runs_kit_hook

print_test_summary "$PASS" "$FAIL"
