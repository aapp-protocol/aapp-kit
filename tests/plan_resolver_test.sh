#!/usr/bin/env bash
# Core suite for lib/plan_resolver.sh and lib/planning_health.sh: plan
# resolution, plan and issue id counters, and the planning health pairs.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

source "$KIT/lib/plan_resolver.sh"
source "$KIT/lib/planning_health.sh"
source "$KIT/tests/test_helpers.sh"

TEST_DIR=$(mktemp -d /tmp/aapp-plan-resolver-test-XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR" || exit 1
git init -q
setup_test_git_identity "$TEST_DIR"
git branch -M main
mkdir -p .plans/current .plans/done

cat > .plans/current/P9-guard-path-authorization.md << 'EOF'
# 🗺️ Plan P-9: Guard Path Authorization
* **Plan ID:** P-9
* **Status:** 🟣 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/guard.sh` -> Guard updates.
EOF
cat > .plans/current/P13-plan-ids-and-shorthand-resolution.md << 'EOF'
# 🗺️ Plan P-13: Plan IDs and Shorthand Resolution
* **Plan ID:** P-13
* **Status:** 🔷 Frozen

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Resolver engine.
EOF
cat > .plans/done/plan-feature-aapp-slash-commands.md << 'EOF'
# 🗺️ Plan: Universal Slash Commands
* **Plan ID:** P-7
* **Status:** ✅ Done
EOF
P13=".plans/current/P13-plan-ids-and-shorthand-resolution.md"

# rc <command…>: prints the command's exit code, its output discarded.
rc() { "$@" >/dev/null 2>&1; echo $?; }
# verdict <command…>: prints `passed` or `refused`, its output discarded.
verdict() { "$@" >/dev/null 2>&1 && echo passed || echo refused; }
# issue_ledgers: active ids #93 and #76, archived #91 and #97.
issue_ledgers() {
  cat > .plans/ISSUES.md << 'EOF'
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #93 | `Low` | `CLI` | 2026-09-28 | `a` | top by priority |  | 🟡 `Incubated` |
| #76 | `Low` | `CLI` | 2026-09-21 | `b` | bottom row, lower id |  | 🟡 `Incubated` |
EOF
  cat > .plans/done/000-issues-archive.md << 'EOF'
| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #91 | `Low` | `CORE` | 2026-09-28 | 2026-09-28 | `0000000` | archived |
| #97 | `Low` | `CORE` | 2026-09-28 | 2026-09-28 | `0000000` | highest id is archived |
EOF
}

echo "== plan resolution =="
t_expect "relative path" "$P13" "$(resolve_plan_path "$P13" inspect current "$PWD")"
t_expect "bare filename" "$P13" "$(resolve_plan_path P13-plan-ids-and-shorthand-resolution.md inspect current "$PWD")"
t_done test_resolve_exact_path_and_filename

for q in P-13 p-13 P13 p13 13 P013 P-013; do
  t_expect "query $q" "$P13" "$(resolve_plan_path "$q" inspect current "$PWD")"
done
t_done test_resolve_numeric_id_forms

t_expect "slug" ".plans/current/P9-guard-path-authorization.md" "$(resolve_plan_path guard-path inspect current "$PWD")"
t_done test_resolve_slug_substring

out="$(resolve_plan_path "#13" freeze current "$PWD" 2>&1)"
echo "$out" | grep -q "is an Issue reference" && echo "$out" | grep -q "Did you mean 'P-13'" || t_fail "out=$out"
t_done test_resolve_refuses_issue_reference

for verb in freeze done; do
  out="$(resolve_plan_path "" "$verb" current "$PWD" 2>&1)"
  echo "$out" | grep -q "You must explicitly specify a target plan for '$verb'" || t_fail "$verb: $out"
done
t_done test_resolve_refuses_empty_query_on_transitions

t_expect "plan id" P-9 "$(get_plan_id .plans/current/P9-guard-path-authorization.md)"
t_done test_get_plan_id

cat > .plans/current/fix-98.md << 'EOF'
* **Plan ID:** #98
* **Target Issue / Milestone:** #98
* **Status:** ⚡ In Development
EOF
[ "$(resolve_plan_path fix inspect current "$PWD" 2>/dev/null)" = ".plans/current/fix-98.md" ] && t_fail "resolver picked fix-98.md"
check_pair4_plan_id_integrity "$PWD" 2>&1 | grep -q "fix-98" && t_fail "pair 4 named fix-98.md"
rm -f .plans/current/fix-98.md
t_done test_mini_plans_are_not_plans

echo "== plan id counter (P-22) =="
git config --unset aapp.planId
t_expect "unset" P-1 "$(get_next_plan_id)"
git config aapp.planId 25
t_expect "peek twice, counter" "P-25 P-25 25" "$(get_next_plan_id) $(get_next_plan_id) $(git config --get aapp.planId)"
t_expect "peek stderr" "" "$(get_next_plan_id 2>&1 >/dev/null)"
t_expect "allocate" P-25 "$(allocate_plan_id)"
t_expect "counter after allocate" 26 "$(git config --get aapp.planId)"
t_expect "allocate again" P-26 "$(allocate_plan_id)"
git config aapp.planId corrupt
t_expect "allocate corrupt" refused "$(verdict allocate_plan_id)"
t_expect "corrupt untouched" corrupt "$(git config --get aapp.planId)"
t_expect "peek corrupt" refused "$(verdict get_next_plan_id)"
git config --unset aapp.planId
t_done test_plan_counter_peek_and_allocate

t_expect "P-42" P-42 "$(normalize_plan_id P-42)"
t_expect "42" P-42 "$(normalize_plan_id 42)"
t_expect "non-integer" refused "$(verdict normalize_plan_id not-an-int)"
t_expect "empty" refused "$(verdict normalize_plan_id '')"
t_done test_normalize_plan_id

git config aapp.planId 30
t_expect "no provider" P-30 "$(allocate_plan_id)"
PROVIDER_DIR="$PWD/.agents/skills/aapp-planid"
mkdir -p "$PROVIDER_DIR"
cat > "$PROVIDER_DIR/run" <<EOF
#!/bin/sh
cat > "$TEST_DIR/planid.stdin"
echo '{"id": "P-88", "extra": {"k": 1}}'
EOF
chmod +x "$PROVIDER_DIR/run"
t_expect "provider id" P-88 "$(allocate_plan_id)"
t_expect "counter ratchets" 89 "$(git config --get aapp.planId)"
t_expect "event" 1 "$(grep -c '"event": "plan.allocate"' "$TEST_DIR/planid.stdin")"
t_expect "reserved extra" 1 "$(grep -c '"extra": {}' "$TEST_DIR/planid.stdin")"
printf '#!/bin/sh\necho %s\n' "'{\"id\": 90}'" > "$PROVIDER_DIR/run"
t_expect "bare integer" P-90 "$(allocate_plan_id)"
printf '#!/bin/sh\necho P-91\n' > "$PROVIDER_DIR/run"
t_expect "plain text" refused "$(verdict allocate_plan_id)"
printf '#!/bin/sh\necho %s\nexit 1\n' "'{\"error\": \"authority offline\"}'" > "$PROVIDER_DIR/run"
t_expect "error text shown" 1 "$(allocate_plan_id 2>&1 | grep -c 'authority offline')"
printf '#!/bin/sh\nexit 3\n' > "$PROVIDER_DIR/run"
t_expect "failing provider" refused "$(verdict allocate_plan_id)"
t_expect "no local fallback" 91 "$(git config --get aapp.planId)"
printf '#!/bin/sh\necho garbage\n' > "$PROVIDER_DIR/run"
t_expect "malformed id" refused "$(verdict allocate_plan_id)"
rm -rf "$PWD/.agents"
git config --unset aapp.planId
t_done test_plan_id_provider

echo "== issue id counter (P-32) =="
git config aapp.issueId 7
git config aapp.planId 3
t_expect "peek" "#7" "$(get_next_issue_id)"
t_expect "allocate" "#7" "$(allocate_issue_id)"
t_expect "issue counter, plan counter" "8 3" "$(git config --get aapp.issueId) $(git config --get aapp.planId)"
git config --unset aapp.issueId; git config --unset aapp.planId
t_done test_issue_counter_peek_and_allocate

t_expect "no ledgers rc" 2 "$(rc seed_issue_id .plans)"
cp "$KIT/templates/issues.md" .plans/ISSUES.md
cp "$KIT/templates/done-issues-archive.md" .plans/done/000-issues-archive.md
t_expect "template rows" 1 "$(seed_issue_id .plans)"
issue_ledgers
t_expect "numeric max across ledgers" 98 "$(seed_issue_id .plans)"
rm -f .plans/ISSUES.md .plans/done/000-issues-archive.md
t_done test_seed_issue_id

echo "== planning health =="
t_expect "unique ids" passed "$(verdict check_pair4_plan_id_integrity "$PWD")"
cat > .plans/current/P9-duplicate.md << 'EOF'
# 🗺️ Plan: Duplicate Test
* **Plan ID:** P-9
* **Status:** 🟣 Under Review
EOF
t_expect "duplicate" refused "$(verdict check_pair4_plan_id_integrity "$PWD")"
rm -f .plans/current/P9-duplicate.md
t_done test_pair4_plan_id_integrity

t_expect "safe targets" passed "$(verdict check_pair5_target_files_self_protection "$PWD")"
cat > .plans/current/P99-bad-target.md << 'EOF'
# 🗺️ Plan P-99: Bad Target Test
* **Plan ID:** P-99
* **Status:** 🟣 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `.agents/skills/aapp-freeze/SKILL.md` -> Attempted direct skill edit.
EOF
t_expect "self-protected target" refused "$(verdict check_pair5_target_files_self_protection "$PWD")"
rm -f .plans/current/P99-bad-target.md
t_done test_pair5_self_protection

git add -A >/dev/null && git commit -qm "fixture commit"
SHA=$(git rev-parse --short HEAD)
ledger() {
  printf '%s\n' '# 🏛️ Archival Ledger' '| Date Completed | Plan ID | Plan File | Target Issue | Verification Commit | Impact Summary |' \
    '| :--- | :--- | :--- | :--- | :--- | :--- |' "| 2026-09-15 | \`P-7\` | [\`plan.md\`](plan.md) | \`#61\` | \`$1\` | Completed feature. |" > .plans/done/000-archive-ledger.md
}
ledger "$SHA"
t_expect "valid ledger SHA" passed "$(verdict check_pair6_recorded_sha_integrity "$PWD")"
ledger deadbeef12
t_expect "dangling ledger SHA" refused "$(verdict check_pair6_recorded_sha_integrity "$PWD")"
ledger "$SHA"
printf '# Changelog\n## [Unreleased]\n- Bugfix recorded in commit `cafebabe99`.\n' > CHANGELOG.md
t_expect "dangling changelog SHA" refused "$(verdict check_pair6_recorded_sha_integrity "$PWD")"
printf '# Changelog\n## [Unreleased]\n- Bugfix recorded in commit `%s`.\n' "$SHA" > CHANGELOG.md
t_expect "valid changelog SHA" passed "$(verdict check_pair6_recorded_sha_integrity "$PWD")"
rm -f .plans/done/000-archive-ledger.md CHANGELOG.md
t_done test_pair6_recorded_sha_integrity

p7_plan() {  # p7_plan <num> <code-file>
  cat > ".plans/current/P$1-p7.md" << EOF
# 🗺️ Plan P-$1: Pair 7 fixture
* **Plan ID:** P-$1
* **Status:** ⚡ In Development

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] \`$2\` -> Code.
- [ ] \`CHANGELOG.md\` -> Record.
- [ ] \`.agents/CODEMAP.md\` -> Map.
EOF
}
p7_plan 90 lib/a.sh; p7_plan 91 lib/b.sh
out="$(check_pair7_inflight_boundary_collision "$PWD" 2>&1)"; p7rc=$?
t_expect "shared docs only rc" 0 "$p7rc"
t_expect "shared-doc notice" 1 "$(printf '%s\n' "$out" | grep -c 'Shared Doc.*CHANGELOG.md')"
t_expect "nested shared doc" 0 "$(rc aapp_is_shared_doc .agents/CODEMAP.md)"
t_expect "code and manifests" "1 1" "$(rc aapp_is_shared_doc lib/a.sh) $(rc aapp_is_shared_doc package.json)"
p7_plan 92 lib/a.sh
t_expect "shared code file" refused "$(verdict check_pair7_inflight_boundary_collision "$PWD")"
rm -f .plans/current/P9[012]-p7.md
t_done test_pair7_shared_docs_exempt

issue_ledgers
t_expect "unique issue ids" passed "$(verdict check_pair8_issue_id_integrity .plans/ISSUES.md .plans/done/000-issues-archive.md)"
echo '| #93 | `Low` | `CLI` | 2026-09-29 | `c` | reused id | fix | 🟡 `Incubated` |' >> .plans/ISSUES.md
out="$(check_pair8_issue_id_integrity .plans/ISSUES.md .plans/done/000-issues-archive.md 2>&1)" && t_fail "active duplicate passed"
echo "$out" | grep -q 'Issue #93 appears more than once in active' || t_fail "active: $out"
sed -i '/reused id/d' .plans/ISSUES.md
echo '| #91 | `Low` | `CORE` | 2026-09-29 | 2026-09-29 | `0000000` | reused archived id |' >> .plans/done/000-issues-archive.md
out="$(check_pair8_issue_id_integrity .plans/ISSUES.md .plans/done/000-issues-archive.md 2>&1)" && t_fail "archive duplicate passed"
echo "$out" | grep -q 'Issue #91 appears more than once in archive' || t_fail "archive: $out"
rm -f .plans/ISSUES.md .plans/done/000-issues-archive.md
t_done test_pair8_issue_id_integrity

echo "== release bundles (P-38) =="
mkdir -p .plans/release/v1.0.0/plans
cat > .plans/release/v1.0.0/plans/P99-release-test.md << 'EOF'
# Plan P-99: Release Test
* **Plan ID:** P-99
* **Status:** ✅ Done
EOF
cat > .plans/release/v1.0.0/000-issues-archive.md << 'EOF'
| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #150 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Released fix. |
EOF
REL=".plans/release/v1.0.0/plans/P99-release-test.md"
t_expect "id, done scope" "$REL" "$(resolve_plan_path P-99 inspect done "$TEST_DIR" 2>/dev/null)"
t_expect "slug, all scope" "$REL" "$(resolve_plan_path release-test inspect all "$TEST_DIR" 2>/dev/null)"
t_expect "issue seed" 151 "$(seed_issue_id .plans)"
rm -rf .plans/release
t_done test_release_bundles_resolved_and_seeded

print_test_summary "$PASS" "$FAIL"
