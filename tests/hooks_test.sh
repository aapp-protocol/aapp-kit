#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: Lifecycle Plugin Hooks (Plan P-12)
# Covers:
#   - POSIX dash shell compatibility and strict 5-column TSV parsing
#   - Portable SHA256 resolution chain (fail-closed)
#   - SHA256 hash-lock verification and tamper-evidence aborts
#   - Exit code handling (0=proceed, 1=halt for gate / warn for notify, 2=warning)
#   - Timeout watchdog (gate aborts, notify warns)
#   - Local git config overrides (mode=notify only, cannot gate)
#   - CI confinement (aapp.allowLocalHooks false)
#   - Dedicated CLI commands: aapp hooks, aapp plugins, aapp hook-test, aapp hook-hash
#   - Dual Delivery Contract: STDIN JSON envelope + exported POSIX environment variables
#   - Transparent command fallthrough for action plugins (extensionless and arbitrary extensions)
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
  fi
}

make_kit_clone() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$KIT/aapp" "$target_dir/"
  chmod +x "$target_dir/aapp"
  cp -r "$KIT/lib" "$KIT/templates" "$target_dir/"
  [ -d "$KIT/examples" ] && cp -r "$KIT/examples" "$target_dir/"
  (
    cd "$target_dir" || exit 1
    git init -q .
    git config user.email t@t; git config user.name T
    git config commit.gpgsign false; git config tag.gpgsign false
    git add . >/dev/null 2>&1
    git commit -qm "kit clone" >/dev/null 2>&1 || true
  )
}

make_project() {
  local proj_dir="$1"
  mkdir -p "$proj_dir"
  (
    cd "$proj_dir" || exit 1
    git init -q .
    git config user.email t@t; git config user.name T
    git config commit.gpgsign false; git config tag.gpgsign false
    echo "print('hello')" > main.py
    git add main.py
    git commit -qm "initial commit"
  )
}

echo "============================================================"
echo "🧪 Running Test Suite: Lifecycle Plugin Hooks (Plan P-12)"
echo "============================================================"

KIT_DIR="$R/agent-planning-kit"
make_kit_clone "$KIT_DIR"

PROJ_DIR="$R/proj1"
make_project "$PROJ_DIR"

(
  cd "$PROJ_DIR" || exit 1
  "$KIT_DIR/aapp" init >/dev/null 2>&1
)

TAB="$(printf '\t')"
REG_FILE="$PROJ_DIR/.agents/skills/aapp-hooks/registry.tsv"
mkdir -p "$(dirname "$REG_FILE")"

# ------------------------------------------------------------------------------
# Test 1: Portable SHA256 calculation
# ------------------------------------------------------------------------------
TEST_FILE="$PROJ_DIR/test_script.sh"
echo 'echo "hello"' > "$TEST_FILE"
chmod +x "$TEST_FILE"

# shellcheck source=/dev/null
source "$KIT_DIR/lib/hook_dispatcher.sh"
sha_out="$(compute_file_sha256 "$TEST_FILE")"
if [ -n "$sha_out" ] && [ ${#sha_out} -eq 64 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "compute_file_sha256 resolves portable host SHA256 hex" "PASS" "$got" "$sha_out"

# ------------------------------------------------------------------------------
# Test 2: aapp hook-hash helper formats 5-column TSV line
# ------------------------------------------------------------------------------
hash_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-hash test_script.sh on-freeze 25 gate 2>&1)"
if echo "$hash_out" | grep -q "^on-freeze${TAB}test_script.sh${TAB}sha256:$sha_out${TAB}25${TAB}gate"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp hook-hash formats 5-column TSV line with valid hash" "PASS" "$got" "$hash_out"

# ------------------------------------------------------------------------------
# Test 3: Exit code 0 allows lifecycle transition & Dual Delivery verified
# ------------------------------------------------------------------------------
HOOK_PASS="$PROJ_DIR/hook_pass.sh"
cat << 'EOF' > "$HOOK_PASS"
#!/bin/sh
INPUT="$(cat)"
echo "PASS_HOOK: event=$AAPP_EVENT mode=$AAPP_MODE plan=$AAPP_PLAN_ID"
echo "PAYLOAD: $INPUT"
exit 0
EOF
chmod +x "$HOOK_PASS"
pass_hash="$(compute_file_sha256 "$HOOK_PASS")"

printf "on-freeze%s%s%ssha256:%s%s10%sgate\n" "$TAB" "$HOOK_PASS" "$TAB" "$pass_hash" "$TAB" "$TAB" > "$REG_FILE"

run_out=""
run_rc=0
run_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze P-99 2>&1)" || run_rc=$?

if [ "$run_rc" -eq 0 ] && echo "$run_out" | grep -q "PASS_HOOK: event=on-freeze mode=gate plan=P-99"; then
  got="PASS"
else
  got="FAIL"
fi
report "exit code 0 allows transition and exports Dual Delivery env vars" "PASS" "$got" "$run_out"

# ------------------------------------------------------------------------------
# Test 4: SHA256 hash mismatch triggers tamper-evident hard abort (mode=gate)
# ------------------------------------------------------------------------------
# Alter the script content without updating the hash in registry.tsv
echo 'echo "tampered"' >> "$HOOK_PASS"

tamper_out=""
tamper_rc=0
tamper_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || tamper_rc=$?

if [ "$tamper_rc" -ne 0 ] && echo "$tamper_out" | grep -q "SHA256 mismatch"; then
  got="PASS"
else
  got="FAIL"
fi
report "SHA256 mismatch halts transition with integrity violation" "PASS" "$got" "$tamper_out"

# Restore script to match hash
cat << 'EOF' > "$HOOK_PASS"
#!/bin/sh
exit 0
EOF
chmod +x "$HOOK_PASS"
pass_hash="$(compute_file_sha256 "$HOOK_PASS")"
printf "on-freeze%s%s%ssha256:%s%s10%sgate\n" "$TAB" "$HOOK_PASS" "$TAB" "$pass_hash" "$TAB" "$TAB" > "$REG_FILE"

# ------------------------------------------------------------------------------
# Test 5: Exit code 1 halts lifecycle transition for gate mode
# ------------------------------------------------------------------------------
HOOK_FAIL="$PROJ_DIR/hook_fail.sh"
cat << 'EOF' > "$HOOK_FAIL"
#!/bin/sh
echo "Quality gate rejected transition: unlisted fallback detected" >&2
exit 1
EOF
chmod +x "$HOOK_FAIL"
fail_hash="$(compute_file_sha256 "$HOOK_FAIL")"

printf "on-freeze%s%s%ssha256:%s%s10%sgate\n" "$TAB" "$HOOK_FAIL" "$TAB" "$fail_hash" "$TAB" "$TAB" > "$REG_FILE"

fail_out=""
fail_rc=0
fail_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || fail_rc=$?

if [ "$fail_rc" -ne 0 ] && echo "$fail_out" | grep -q "Quality gate rejected transition"; then
  got="PASS"
else
  got="FAIL"
fi
report "exit code 1 halts operation and streams stderr in gate mode" "PASS" "$got" "$fail_out"

# ------------------------------------------------------------------------------
# Test 6: Exit code 1 logs advisory warning and continues in notify mode
# ------------------------------------------------------------------------------
printf "on-freeze%s%s%ssha256:%s%s10%snotify\n" "$TAB" "$HOOK_FAIL" "$TAB" "$fail_hash" "$TAB" "$TAB" > "$REG_FILE"

notify_out=""
notify_rc=0
notify_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || notify_rc=$?

if [ "$notify_rc" -eq 0 ] && echo "$notify_out" | grep -q "Quality gate rejected transition"; then
  got="PASS"
else
  got="FAIL"
fi
report "exit code 1 warns and proceeds when mode=notify" "PASS" "$got" "$notify_out"

# ------------------------------------------------------------------------------
# Test 7: Exit code 2 logs warning and continues in gate mode
# ------------------------------------------------------------------------------
HOOK_WARN="$PROJ_DIR/hook_warn.sh"
cat << 'EOF' > "$HOOK_WARN"
#!/bin/sh
echo "Advisory warning from hook" >&2
exit 2
EOF
chmod +x "$HOOK_WARN"
warn_hash="$(compute_file_sha256 "$HOOK_WARN")"

printf "on-freeze%s%s%ssha256:%s%s10%sgate\n" "$TAB" "$HOOK_WARN" "$TAB" "$warn_hash" "$TAB" "$TAB" > "$REG_FILE"

warn_out=""
warn_rc=0
warn_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || warn_rc=$?

if [ "$warn_rc" -eq 0 ] && echo "$warn_out" | grep -q "Advisory warning from hook"; then
  got="PASS"
else
  got="FAIL"
fi
report "exit code 2 logs advisory warning and proceeds in gate mode" "PASS" "$got" "$warn_out"

# ------------------------------------------------------------------------------
# Test 8: Watchdog timeout halts in gate mode, warns in notify mode
# ------------------------------------------------------------------------------
HOOK_SLOW="$PROJ_DIR/hook_slow.sh"
cat << 'EOF' > "$HOOK_SLOW"
#!/bin/sh
sleep 5
exit 0
EOF
chmod +x "$HOOK_SLOW"
slow_hash="$(compute_file_sha256 "$HOOK_SLOW")"

# Timeout 1s with mode=gate
printf "on-freeze%s%s%ssha256:%s%s1%sgate\n" "$TAB" "$HOOK_SLOW" "$TAB" "$slow_hash" "$TAB" "$TAB" > "$REG_FILE"

slow_gate_out=""
slow_gate_rc=0
slow_gate_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || slow_gate_rc=$?

if [ "$slow_gate_rc" -ne 0 ] && echo "$slow_gate_out" | grep -q "exceeded timeout"; then
  got="PASS"
else
  got="FAIL"
fi
report "watchdog timeout halts transition in gate mode (fail-closed)" "PASS" "$got" "$slow_gate_out"

# Timeout 1s with mode=notify
printf "on-freeze%s%s%ssha256:%s%s1%snotify\n" "$TAB" "$HOOK_SLOW" "$TAB" "$slow_hash" "$TAB" "$TAB" > "$REG_FILE"

slow_not_out=""
slow_not_rc=0
slow_not_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || slow_not_rc=$?

if [ "$slow_not_rc" -eq 0 ] && echo "$slow_not_out" | grep -q "exceeded timeout"; then
  got="PASS"
else
  got="FAIL"
fi
report "watchdog timeout warns and proceeds in notify mode" "PASS" "$got" "$slow_not_out"

# ------------------------------------------------------------------------------
# Test 9: Malformed 6-column line detected and refused
# ------------------------------------------------------------------------------
printf "on-freeze%s%s%ssha256:%s%s10%sgate%sunexpected_6th_field\n" "$TAB" "$HOOK_WARN" "$TAB" "$warn_hash" "$TAB" "$TAB" "$TAB" > "$REG_FILE"

malform_out=""
malform_rc=0
malform_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-freeze 2>&1)" || malform_rc=$?

if [ "$malform_rc" -ne 0 ] && echo "$malform_out" | grep -q "unexpected 6th field"; then
  got="PASS"
else
  got="FAIL"
fi
report "strict 5-column parsing catches malformed 6th field" "PASS" "$got" "$malform_out"

# Clean registry file
echo "" > "$REG_FILE"

# ------------------------------------------------------------------------------
# Test 10: Local git config overrides run in notify mode and cannot gate
# ------------------------------------------------------------------------------
(
  cd "$PROJ_DIR" || exit 1
  git config --add aapp.hook.on-done "$HOOK_FAIL"
)

local_out=""
local_rc=0
local_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-done 2>&1)" || local_rc=$?

if [ "$local_rc" -eq 0 ] && echo "$local_out" | grep -q "Quality gate rejected transition"; then
  got="PASS"
else
  got="FAIL"
fi
report "local git config hooks execute in notify mode and cannot gate" "PASS" "$got" "$local_out"

# ------------------------------------------------------------------------------
# Test 11: aapp.allowLocalHooks false disables uncommitted hooks
# ------------------------------------------------------------------------------
(
  cd "$PROJ_DIR" || exit 1
  git config aapp.allowLocalHooks false
)

dis_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hook-test on-done 2>&1)"
if ! echo "$dis_out" | grep -q "Quality gate rejected transition"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp.allowLocalHooks false disables local git config hooks" "PASS" "$got" "$dis_out"

# Cleanup git config
(
  cd "$PROJ_DIR" || exit 1
  git config --unset-all aapp.hook.on-done || true
  git config --unset aapp.allowLocalHooks || true
)

# ------------------------------------------------------------------------------
# Test 12: aapp hooks inspector reports registered hooks and statuses
# ------------------------------------------------------------------------------
printf "on-freeze%s%s%ssha256:%s%s10%sgate\n" "$TAB" "$HOOK_PASS" "$TAB" "$pass_hash" "$TAB" "$TAB" > "$REG_FILE"

hooks_audit="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hooks 2>&1)"
if echo "$hooks_audit" | grep -q "on-freeze" && echo "$hooks_audit" | grep -q "VALID"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp hooks inspects registered hooks and audits SHA256 integrity" "PASS" "$got" "$hooks_audit"

# ------------------------------------------------------------------------------
# Test 13: Extension-Agnostic Plugin Discovery & aapp plugins inspector
# ------------------------------------------------------------------------------
# Create sample action plugins in .agents/skills/:
# 1. Extensionless canonical: .agents/skills/tool-bin/run
mkdir -p "$PROJ_DIR/.agents/skills/tool-bin"
cat << 'EOF' > "$PROJ_DIR/.agents/skills/tool-bin/run"
#!/bin/sh
echo "EXEC_TOOL_BIN: args=$*"
exit 0
EOF
chmod +x "$PROJ_DIR/.agents/skills/tool-bin/run"

# 2. Arbitrary extension (.py): .agents/skills/tool-py/scripts/tool-py.py
mkdir -p "$PROJ_DIR/.agents/skills/tool-py/scripts"
cat << 'EOF' > "$PROJ_DIR/.agents/skills/tool-py/scripts/tool-py.py"
#!/usr/bin/env python3
import sys
print(f"EXEC_TOOL_PY: args={' '.join(sys.argv[1:])}")
EOF
chmod +x "$PROJ_DIR/.agents/skills/tool-py/scripts/tool-py.py"

plugins_audit="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" plugins 2>&1)"
if echo "$plugins_audit" | grep -q "tool-bin" && echo "$plugins_audit" | grep -q "tool-py"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp plugins discovers extensionless and polyglot action plugins" "PASS" "$got" "$plugins_audit"

# ------------------------------------------------------------------------------
# Test 14: Transparent CLI fallthrough executes action plugins
# ------------------------------------------------------------------------------
# Execute extensionless plugin: aapp tool-bin foo bar
fallthrough_bin_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" tool-bin foo bar 2>&1)"
if echo "$fallthrough_bin_out" | grep -q "EXEC_TOOL_BIN: args=foo bar"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp <plugin> executes extensionless action plugin transparently" "PASS" "$got" "$fallthrough_bin_out"

# Execute arbitrary extension plugin: aapp tool-py alpha beta
fallthrough_py_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" tool-py alpha beta 2>&1)"
if echo "$fallthrough_py_out" | grep -q "EXEC_TOOL_PY: args=alpha beta"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp <plugin> executes arbitrary extension (.py) action plugin transparently" "PASS" "$got" "$fallthrough_py_out"

# ------------------------------------------------------------------------------
# Test 15: resolve_plugin_entrypoint ignores run.sample even if marked executable
# ------------------------------------------------------------------------------
mkdir -p "$PROJ_DIR/.agents/skills/sample-tool"
cat << 'EOF' > "$PROJ_DIR/.agents/skills/sample-tool/run.sample"
#!/bin/sh
echo "SAMPLE_TOOL_SHOULD_NOT_RUN"
EOF
chmod +x "$PROJ_DIR/.agents/skills/sample-tool/run.sample"

sample_entrypoint="$(resolve_plugin_entrypoint "$PROJ_DIR/.agents/skills/sample-tool" "sample-tool" 2>/dev/null || true)"
if [ -z "$sample_entrypoint" ]; then
  got="PASS"
else
  got="FAIL ($sample_entrypoint)"
fi
report "resolve_plugin_entrypoint ignores run.sample even if marked executable" "PASS" "$got"

# ------------------------------------------------------------------------------
# Test 16: aapp switchboard rejects execution of .sample plugins
# ------------------------------------------------------------------------------
sample_run_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" sample-tool 2>&1 || true)"
if ! echo "$sample_run_out" | grep -q "SAMPLE_TOOL_SHOULD_NOT_RUN" && echo "$sample_run_out" | grep -q "Unknown command"; then
  got="PASS"
else
  got="FAIL ($sample_run_out)"
fi
report "aapp switchboard rejects executing sample plugins directly" "PASS" "$got"

# ------------------------------------------------------------------------------
# Test 17: aapp hooks marks .sample registered handler as INERT SAMPLE
# ------------------------------------------------------------------------------
SAMPLE_HOOK_LINE="on-freeze${TAB}examples/hooks/fallback-ratchet.sh.sample${TAB}sha256:0000000000000000000000000000000000000000000000000000000000000000${TAB}10${TAB}gate"
echo "$SAMPLE_HOOK_LINE" >> "$REG_FILE"
hooks_sample_audit="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hooks 2>&1)"
if echo "$hooks_sample_audit" | grep -q "INERT SAMPLE"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp hooks reports INERT SAMPLE badge for registered .sample hook" "PASS" "$got"

# ------------------------------------------------------------------------------
# Test 18: aapp plugins & aapp hooks show available sample discovery
# ------------------------------------------------------------------------------
plugins_discovery="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" plugins 2>&1)"
hooks_discovery="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" hooks 2>&1)"
if echo "$plugins_discovery" | grep -q "Standard Extension Points:" && \
   echo "$plugins_discovery" | grep -q "aapp-planid" && \
   echo "$hooks_discovery" | grep -q "Reference Samples:"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp plugins & aapp hooks display standard extension points and sample discovery" "PASS" "$got"

echo "============================================================"
echo "📊 Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] || exit 1
