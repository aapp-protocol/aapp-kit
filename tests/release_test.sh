#!/usr/bin/env bash
# Core suite for `aapp release` (P-38): version forms and bump tokens, the
# phase A gates, commit reachability and milestone bundling, the JSON
# contract, and rollback when the on-release hook fails.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_LIB="$KIT/lib"

# release_repo <dir>: a repository on main with an Unreleased changelog and
# empty archive ledgers; the shell is left inside it.
release_repo() {
  mkdir -p "$1" && cd "$1" || exit 1
  git init -q . && setup_test_git_identity "$1"
  git config aapp.tagPrefix v
  echo "print('hello')" > main.py
  printf '%s\n' '# Changelog' 'All notable changes to this project will be documented in this file.' '' \
    '## [Unreleased]' '### Added' '- Initial project structure.' > CHANGELOG.md
  git add . && git commit -qm "initial commit" && git branch -M main
  mkdir -p .plans/current .plans/done
  printf '%s\n' '# 🏛️ Archival Ledger (Completed Plans DB)' '' \
    '| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |' \
    '| :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-archive-ledger.md
  printf '%s\n' '# 🏛️ Master Issue Archive Ledger' '' \
    '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' \
    '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
}
release() { "$KIT/aapp" release "$@" 2>&1; }
rc_of() { release "$@" >/dev/null; echo $?; }
# json_field <field> <args…>: the first value of <field> in `release … json check`.
json_field() { local f="$1"; shift; release "$@" json check | grep "\"$f\"" | head -n 1 | sed -E 's/.*: "([^"]+)".*/\1/'; }

echo "== versions and bumps =="
release_repo "$R/versions"
for v in 1.0.0 v1.2.3 1.2 v1.2 1.0.1.alpha 1.0.0-rc.1; do t_expect "valid $v" 0 "$(rc_of "$v" check)"; done
for v in 1 v1 invalid 1.0.0-abcdefghijklmnopqrstuvwxyz0123456789; do t_expect "invalid $v" 1 "$(rc_of "$v" check)"; done
t_done test_version_forms

git tag v1.0.0
t_expect "patch" 1.0.1 "$(json_field version patch)"
t_expect "minor" 1.1.0 "$(json_field version minor)"
t_expect "major" 2.0.0 "$(json_field version major)"
git tag -d v1.0.0 >/dev/null; git tag v2.4.9
t_expect "patch past 9" 2.4.10 "$(json_field version patch)"
git tag -d v2.4.9 >/dev/null; git tag v1.2
t_expect "minor from two segments" 1.3.0 "$(json_field version minor)"
git tag -d v1.2 >/dev/null
t_done test_bump_tokens_from_last_tag

echo "== phase A gates =="
release_repo "$R/gates"
t_expect "check rc" 0 "$(rc_of 1.0.0 check)"
t_expect "check leaves no tag" "" "$(git tag -l v1.0.0)"
t_expect "non-interactive without yes rc" 0 "$(release 1.0.0 </dev/null >/dev/null; echo $?)"
t_expect "non-interactive leaves no tag" "" "$(git tag -l v1.0.0)"
echo "dirty modification" >> main.py
t_expect "dirty tree rc" 1 "$(rc_of 1.0.0 yes)"
git checkout -- main.py
git config aapp.testCommand "exit 1"
t_expect "failing test command rc" 1 "$(rc_of 1.0.0 yes)"
git config --unset aapp.testCommand
git rm -q CHANGELOG.md && git commit -qm "remove changelog for test"
t_expect "missing changelog rc" 1 "$(rc_of 1.0.0 check)"
t_expect "no-changelog rc" 0 "$(rc_of 1.0.0 check no-changelog)"
t_done test_phase_a_gates

echo "== reachability and bundling =="
release_repo "$R/bundle"
SHA="$(git rev-parse --short HEAD)"
# The body's example header lines are prose and never read (#173).
printf '%s\n' '# 🗺️ Plan P-10: Feature Plan' '* **Plan ID:** P-10' "* **Commits:** \`$SHA\` (main)" '* **Status:** ✅ Done' '' \
  '## 2. Technical Blueprint' '* **Plan ID:** P-X' '* **Commits:** `cafe123` (feat/example)' > .plans/done/P10-feature.md
echo '| #42 | `Low` | `CORE` | 2026-10-01 | 2026-10-05 | `0000000` | [`P10-feature.md`](done/P10-feature.md) |' >> .plans/done/000-issues-archive.md
t_expect "ancestor commit rc" 0 "$(rc_of 1.0.0 check)"
sed -i "s/\`$SHA\` (main)/\`deadbeef\` (main)/" .plans/done/P10-feature.md
t_expect "foreign commit rc" 1 "$(rc_of 1.0.0 check)"
t_expect "unverified rc" 0 "$(rc_of 1.0.0 check unverified)"
sed -i "s/\`deadbeef\` (main)/\`$SHA\` (main)/" .plans/done/P10-feature.md
out="$(release 1.0.0 yes)" || t_fail "release failed: $out"
t_expect "tag" v1.0.0 "$(git tag -l v1.0.0)"
B=.plans/release/v1.0.0
for f in plans/P10-feature.md 000-archive-ledger.md manifest.md manifest.json 000-issues-archive.md; do
  [ -f "$B/$f" ] || t_fail "bundle lacks $f"
done
[ -f .plans/done/P10-feature.md ] && t_fail "plan left in done/"
grep -q '^## 🏷️ Shipped Releases' .plans/done/000-archive-ledger.md || t_fail "no Shipped Releases section"
grep -q '\.\./release/v1\.0\.0/000-archive-ledger\.md' .plans/done/000-archive-ledger.md || t_fail "no link to the tag ledger"
grep -q '^## \[1\.0\.0\] -' CHANGELOG.md || t_fail "changelog not rolled up"
grep -q '^## \[Unreleased\]' CHANGELOG.md || t_fail "no new Unreleased section"
t_done test_reachability_and_bundling

echo "== JSON =="
release_repo "$R/json"
out="$(release 1.0.0 json check)"
t_expect "first line" "{" "$(echo "$out" | head -n 1)"
t_expect "schemaVersion" 1.0.0 "$(echo "$out" | grep '"schemaVersion"' | sed -E 's/.*: "([^"]+)".*/\1/')"
t_expect "tag" v1.0.0 "$(echo "$out" | grep '"tag"' | head -n 1 | sed -E 's/.*: "([^"]+)".*/\1/')"
t_expect "version" 1.0.0 "$(echo "$out" | grep '"version"' | head -n 1 | sed -E 's/.*: "([^"]+)".*/\1/')"
t_done test_json_contract

echo "== rollback =="
release_repo "$R/rollback"
mkdir -p .agents/skills/aapp-hooks
printf '#!/usr/bin/env bash\necho "Triggering intentional hook failure" >&2\nexit 1\n' > fail_hook.sh
chmod +x fail_hook.sh
printf 'on-release\tfail_hook.sh\tsha256:%s\t10\tgate\n' "$(sha256sum fail_hook.sh | awk '{print $1}')" > .agents/skills/aapp-hooks/registry.tsv
printf '%s\n' '# 🗺️ Plan P-20: Test' '* **Plan ID:** P-20' '* **Commits:** none' '* **Status:** ✅ Done' > .plans/done/P20-test.md
t_expect "rc" 1 "$(rc_of 1.0.0 yes)"
t_expect "tag left" "" "$(git tag -l v1.0.0)"
[ -d .plans/release/v1.0.0 ] && t_fail "bundle left behind"
t_done test_rollback_on_hook_failure

print_test_summary "$PASS" "$FAIL"
