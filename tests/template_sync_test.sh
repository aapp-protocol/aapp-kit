#!/usr/bin/env bash
# Core suite for template sync and document governance (P-25, #73): tier 1
# templates, tier 2 hybrid documents, tier 3 project data, the
# aapp.templateSync switchboard, the drift line of `aapp status`, and the
# start skill.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

# project <name>: an initialized project; prints its path.
project() {
  local p="$R/$1"
  mkdir -p "$p" && git init -q "$p" && setup_test_git_identity "$p"
  echo "# Starter" > "$p/README.md"
  git -C "$p" add README.md && git -C "$p" commit -qm "initial commit"
  (cd "$p" && aapp init >/dev/null 2>&1)
  echo "$p"
}
init_in() { (cd "$1" && aapp init 2>&1); }

echo "== tier 1 templates =="
P="$(project t1)"
for f in .plans/plan-template.md .plans/release/release_checklist.md .plans/done/000-archive-ledger.md; do
  [ -f "$P/$f" ] || t_fail "missing $f"
done
t_done test_init_provisions_templates

P="$(project t1-delim)"
printf '\n## 7. Bespoke Project Architecture Matrix\n* custom section *\n' >> "$P/.plans/plan-template.md"
init_in "$P" >/dev/null
grep -q "Bespoke Project Architecture Matrix" "$P/.plans/plan-template.md" || t_fail "custom section lost"
grep -q "AAPP-PROTOCOL:START" "$P/.plans/plan-template.md" || t_fail "protocol block missing"
t_done test_block_update_keeps_custom_sections

P="$(project t1-safe)"
printf '# Legacy Plan Template\n* Custom field without delimiter comments *\n' > "$P/.plans/plan-template.md"
out="$(init_in "$P")"
[ -f "$P/.plans/plan-template.md.new" ] || t_fail "no .new buffer"
grep -q "Legacy Plan Template" "$P/.plans/plan-template.md" || t_fail "diverged template overwritten"
echo "$out" | grep -q "wrote updated template to .plans/plan-template.md.new" || t_fail "out=$out"
t_done test_safe_mode_writes_new_buffer

P="$(project t1-strict)"
printf '# Obsolete Plan Template\n* Diverged content *\n' > "$P/.plans/plan-template.md"
git -C "$P" config aapp.templateSync strict
out="$(init_in "$P")"
grep -q "<!-- AAPP-PROTOCOL:START" "$P/.plans/plan-template.md" || t_fail "template not restored"
grep -q "Obsolete Plan Template" "$P/.plans/plan-template.md" && t_fail "diverged text kept"
echo "$out" | grep -q "\[strict\] Overwrote diverged template" || t_fail "out=$out"
t_done test_strict_mode_overwrites

P="$(project t1-manual)"
echo "# Manual Mode Custom Template" > "$P/.plans/plan-template.md"
git -C "$P" config aapp.templateSync manual
init_in "$P" >/dev/null
grep -q "Manual Mode Custom Template" "$P/.plans/plan-template.md" || t_fail "template changed"
[ ! -f "$P/.plans/plan-template.md.new" ] || t_fail ".new buffer written"
t_done test_manual_mode_leaves_templates

P="$(project t1-prose)"
echo '- [ ] Checklist bullet mentioning `<!-- AAPP-PROTOCOL:START v1.0.0 -->` in prose' >> "$P/.plans/release/release_checklist.md"
out="$(init_in "$P")"
echo "$out" | grep -q "Found unclosed <!-- AAPP-PROTOCOL:START --> marker" && t_fail "false unclosed warning"
grep -q "Checklist bullet mentioning" "$P/.plans/release/release_checklist.md" || t_fail "bullet lost"
t_done test_inline_marker_mention_ignored

echo "== tier 2 documents =="
P="$(project t2-pickup)"
echo "- [ ] Revolutionary idea: quantum blast radius validation" >> "$P/.plans/pickup.md"
init_in "$P" >/dev/null
grep -q "Revolutionary idea" "$P/.plans/pickup.md" || t_fail "idea lost"
grep -q "<!-- AAPP-PROTOCOL:START" "$P/.plans/pickup.md" || t_fail "protocol block missing"
t_done test_pickup_sync_keeps_ideas

P="$(project t2-agents)"
printf '\n## 🔒 Bespoke Security Guard\n- Custom policy.\n' >> "$P/.agents/AGENTS.md"
init_in "$P" >/dev/null
grep -q "Bespoke Security Guard" "$P/.agents/AGENTS.md" || t_fail "custom rule lost"
grep -q "<!-- AAPP-PROTOCOL:START" "$P/.agents/AGENTS.md" || t_fail "protocol block missing"
t_done test_agents_sync_keeps_project_rules

P="$(project t2-unclosed)"
printf '%s\n' '<!-- AAPP-PROTOCOL:START v1.0.0 -->' 'Broken unclosed instruction block' '- [ ] Precious unbacked idea that must survive' > "$P/.plans/pickup.md"
out="$(init_in "$P")"; rc=$?
t_expect "rc" 0 "$rc"
echo "$out" | grep -q "Found unclosed <!-- AAPP-PROTOCOL:START --> marker" || t_fail "out=$out"
grep -q "Precious unbacked idea" "$P/.plans/pickup.md" || t_fail "content lost"
t_done test_unclosed_marker_fails_safe

echo "== tier 3 project data =="
P="$(project t3)"
echo "| #999 | P1 | CORE | 2026-09-21 | lib/a.sh | Active custom bug | Fix | 🟠 Incubated |" >> "$P/.plans/ISSUES.md"
echo "# Project Specific Architecture Map" > "$P/.agents/CODEMAP.md"
echo "# Project Specific Profile" > "$P/.agents/PROJECT.MD"
init_in "$P" >/dev/null
grep -q "#999" "$P/.plans/ISSUES.md" || t_fail "ISSUES.md overwritten"
grep -q "Project Specific Architecture Map" "$P/.agents/CODEMAP.md" || t_fail "CODEMAP.md overwritten"
grep -q "Project Specific Profile" "$P/.agents/PROJECT.MD" || t_fail "PROJECT.MD overwritten"
t_done test_project_data_never_overwritten

echo "== status drift line =="
P="$(project st-synced)"
out="$(cd "$P" && aapp status 2>&1)"
echo "$out" | grep -q "📑 Templates:  All worktree templates synced" || t_fail "out=$out"
t_done test_status_reports_synced

P="$(project st-drift)"
printf '# Stale Plan Template\n<!-- Status must be exactly ONE of: Draft | In Progress -->\n' > "$P/.plans/plan-template.md"
out="$(cd "$P" && aapp status 2>&1)"
echo "$out" | grep -q "📑 Templates:  1 template drifted.*-> run 'aapp init'" || t_fail "out=$out"
t_done test_status_reports_drift

echo "== start skill (P-87) =="
SKILL="$KIT/templates/skills/aapp/SKILL.md"
grep -qx 'name: aapp' "$SKILL" && grep -qF '.agents/AGENTS.md' "$SKILL" && grep -qF 'aapp status' "$SKILL" && \
  grep -qF 'aapp help' "$SKILL" || t_fail "start skill lacks its name, the rules file, status or help"
grep -qE '(^|[^.A-Za-z])/(home|Users)/|view_file|run_command|CommandLine' "$SKILL" && t_fail "start skill names a machine path or a tool"
t_done test_start_skill_text

P="$(project skill)"
[ -f "$P/.agents/skills/aapp/SKILL.md" ] || t_fail "no .agents/skills/aapp/SKILL.md"
[ -e "$P/.claude/skills/aapp/SKILL.md" ] || t_fail "no .claude/skills/aapp/SKILL.md"
item="$(grep -F 'Onboarding:' "$P/.plans/pickup.md")"
for want in '.agents/CODEMAP.md' 'ARCHITECTURE.md' '.agents/PROJECT.MD' 'placeholder' 'entry point'; do
  printf '%s\n' "$item" | grep -qiF -- "$want" || t_fail "onboarding item lacks [$want]: $item"
done
t_done test_init_installs_start_skill_and_onboarding

print_test_summary "$PASS" "$FAIL"
