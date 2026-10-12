#!/usr/bin/env bash
# Unit suite for the issue ledger section of lib/aapp-lib.sh (P-73): the one
# accessor of ISSUES.md, done/000-issues-archive.md and issues_road_map.md.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
LIB="$KIT/lib/aapp-lib.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

# shellcheck source=/dev/null
. "$LIB"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }
have() { declare -f "$1" >/dev/null; }

# Fixture: a plans directory with the three ledgers.
fixture() {
  PLANS_DIR="$R/$1"; export PLANS_DIR
  mkdir -p "$PLANS_DIR/done"
  cat > "$PLANS_DIR/ISSUES.md" <<'EOF'
# 🐛 Issues: Active Technical Backlog

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #12 | `Low` | `CLI` | 2026-10-01 | `lib/a.sh` | Lists `🟠\|🔵` rows only; skips `NEW\|OLD`. |  | 🟡 `Incubated` |
| #11 | `High` | `CORE` | 2026-09-30 | `lib/b.sh` | Second problem. | [P-7](current/P7-fix-it.md) | 🔵 `Planned` |
| #10 | `Medium` | `DOCS` | 2026-09-29 | `MANUAL.md` | Third problem. | blocks [P-8](current/P8-other.md) | 🟡 `Incubated` |
EOF
  cat > "$PLANS_DIR/done/000-issues-archive.md" <<'EOF'
# Issues Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #9 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
EOF
  cat > "$PLANS_DIR/issues_road_map.md" <<'EOF'
# Issues Road Map

## 🧱 Plan Blockers
- [ ] #10 -> Third problem. (blocks P-8)

## 🔴 High Priority
- [ ] #11 -> Second problem. See [P-7](current/P7-fix-it.md).
- [x] #8 -> Old one. ✅ Resolved
- [ ] #12 -> First problem.
EOF
}

echo "== rows =="
fixture rows
if have ledger_rows; then
  line="$(ledger_rows | awk -F'\t' '$1 == "#12"')"
  cells="$(printf '%s\n' "$line" | awk -F'\t' '{ print NF }')"
  symptom="$(printf '%s\n' "$line" | cut -f6)"
  planned="$(ledger_rows Planned | cut -f1 | tr '\n' ' ')"
  if [ "$cells" = "9" ] && [ "$symptom" = 'Lists `🟠\|🔵` rows only; skips `NEW\|OLD`.' ] && \
     [ "$(printf '%s\n' "$line" | cut -f8)" = '🟡 `Incubated`' ] && [ "$(printf '%s\n' "$line" | cut -f9)" = "local" ] && \
     [ "$planned" = "#11 " ]; then
    ok "test_rows_keep_escaped_pipes"
  else
    bad "test_rows_keep_escaped_pipes" "cells=$cells symptom=[$symptom] planned=[$planned]"
  fi
else
  bad "test_rows_keep_escaped_pipes" "ledger_rows not implemented"
fi

echo "== locate =="
if have ledger_locate; then
  a="$(ledger_locate 11)"; b="$(ledger_locate 9)"; c="$(ledger_locate 99)"; d="$(ledger_locate 1)"
  if [ "$a" = "active" ] && [ "$b" = "archive" ] && [ -z "$c" ] && [ -z "$d" ]; then
    ok "test_locate_active_archive_unknown"
  else
    bad "test_locate_active_archive_unknown" "11=[$a] 9=[$b] 99=[$c] 1=[$d]"
  fi
else
  bad "test_locate_active_archive_unknown" "ledger_locate not implemented"
fi

echo "== set cell =="
fixture setcell
if have ledger_set_cell; then
  before="$(grep -v '^| #12 ' "$PLANS_DIR/ISSUES.md")"
  ledger_set_cell 12 link '[P-9](current/P9-new.md)'; r1=$?
  ledger_set_cell 12 status '🔵 `Planned`'; r2=$?
  row="$(grep '^| #12 ' "$PLANS_DIR/ISSUES.md")"
  snap="$(cat "$PLANS_DIR/ISSUES.md")"
  ledger_set_cell 12 symptom "changed" 2>/dev/null; r3=$?
  ledger_set_cell 99 status "x" 2>/dev/null; r4=$?
  want='| #12 | `Low` | `CLI` | 2026-10-01 | `lib/a.sh` | Lists `🟠\|🔵` rows only; skips `NEW\|OLD`. | [P-9](current/P9-new.md) | 🔵 `Planned` |'
  if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$row" = "$want" ] && [ "$r3" -ne 0 ] && [ "$r4" -ne 0 ] && \
     [ "$(cat "$PLANS_DIR/ISSUES.md")" = "$snap" ] && [ "$(grep -v '^| #12 ' "$PLANS_DIR/ISSUES.md")" = "$before" ]; then
    ok "test_set_cell_changes_lifecycle_only"
  else
    bad "test_set_cell_changes_lifecycle_only" "rc=$r1/$r2/$r3/$r4 row=[$row]"
  fi
else
  bad "test_set_cell_changes_lifecycle_only" "ledger_set_cell not implemented"
fi

echo "== archive =="
fixture archive
if have ledger_archive_row; then
  ledger_archive_row 12 def5678 "Offers by \`a|b\` name"; rc=$?
  top="$(awk '/^\|[[:space:]]*:---/ { getline; print; exit }' "$PLANS_DIR/done/000-issues-archive.md")"
  today="$(date +%Y-%m-%d)"
  want="| #12 | \`Low\` | \`CLI\` | 2026-10-01 | $today | \`def5678\` | Offers by \`a\\|b\` name |"
  ledger_archive_row 99 def5678 "x" 2>/dev/null; rmiss=$?
  if [ "$rc" -eq 0 ] && [ "$top" = "$want" ] && ! grep -q '^| #12 ' "$PLANS_DIR/ISSUES.md" && \
     ! grep -q '#12 ' "$PLANS_DIR/issues_road_map.md" && grep -q '#11 ' "$PLANS_DIR/issues_road_map.md" && [ "$rmiss" -ne 0 ]; then
    ok "test_archive_row_moves_and_prunes"
  else
    bad "test_archive_row_moves_and_prunes" "rc=$rc rmiss=$rmiss top=[$top]"
  fi
  ledger_archive_row 10 aborted "Aborted: not a bug"; rc=$?
  top="$(awk '/^\|[[:space:]]*:---/ { getline; print; exit }' "$PLANS_DIR/done/000-issues-archive.md")"
  want="| #10 | \`Medium\` | \`DOCS\` | 2026-09-29 | $today | \`aborted\` | Aborted: not a bug |"
  if [ "$rc" -eq 0 ] && [ "$top" = "$want" ] && ! grep -q '#10 ' "$PLANS_DIR/issues_road_map.md"; then
    ok "test_archive_row_aborted"
  else
    bad "test_archive_row_aborted" "rc=$rc top=[$top]"
  fi
else
  bad "test_archive_row_moves_and_prunes" "ledger_archive_row not implemented"
  bad "test_archive_row_aborted" "ledger_archive_row not implemented"
fi

echo "== relink =="
fixture relink
if have ledger_relink; then
  n="$(ledger_relink "current/P7-fix-it.md" "done/P7-fix-it.md")"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$n" = "2" ] && grep -qF '| [P-7](done/P7-fix-it.md) |' "$PLANS_DIR/ISSUES.md" && \
     grep -qF 'See [P-7](done/P7-fix-it.md).' "$PLANS_DIR/issues_road_map.md" && \
     grep -qF 'blocks [P-8](current/P8-other.md)' "$PLANS_DIR/ISSUES.md"; then
    ok "test_relink_ledger_and_roadmap"
  else
    bad "test_relink_ledger_and_roadmap" "rc=$rc n=[$n]"
  fi
else
  bad "test_relink_ledger_and_roadmap" "ledger_relink not implemented"
fi

echo "== path =="
if have ledger_path; then
  unset PLANS_DIR REPO_ROOT
  main="$R/main"; mkdir -p "$main/.plans/done" "$main/sub"; git init -q "$main"
  : > "$main/.plans/ISSUES.md"; : > "$main/.plans/done/000-issues-archive.md"; : > "$main/.plans/issues_road_map.md"
  wt="$R/planswt"; mkdir -p "$wt/done"; git init -q "$wt"; : > "$wt/ISSUES.md"; : > "$wt/done/000-issues-archive.md"
  rootonly="$R/rootonly"; mkdir -p "$rootonly"; git init -q "$rootonly"; : > "$rootonly/ISSUES.md"
  p1="$(cd "$main/sub" && ledger_path issues)"; p2="$(cd "$main" && ledger_path archive)"; p3="$(cd "$main" && ledger_path roadmap)"
  p4="$(cd "$wt" && ledger_path issues)"; p5="$(cd "$wt" && ledger_path archive)"
  p6="$(cd "$rootonly" && ledger_path issues)"
  p7="$(cd "$rootonly" && ledger_path roadmap)"; r7=1; [ -n "$p7" ] && [ ! -f "$p7" ] && r7=0
  p8="$(PLANS_DIR="$main/.plans" ledger_path issues)"
  if [ "$p1" = "$main/.plans/ISSUES.md" ] && [ "$p2" = "$main/.plans/done/000-issues-archive.md" ] && \
     [ "$p3" = "$main/.plans/issues_road_map.md" ] && [ "$p4" = "$wt/ISSUES.md" ] && \
     [ "$p5" = "$wt/done/000-issues-archive.md" ] && [ "$p6" = "$rootonly/ISSUES.md" ] && [ "$r7" -eq 0 ] && \
     [ "$p8" = "$main/.plans/ISSUES.md" ]; then
    ok "test_path_resolves_in_each_place"
  else
    bad "test_path_resolves_in_each_place" "p1=$p1 p4=$p4 p6=$p6 r7=$r7 p8=$p8"
  fi
else
  bad "test_path_resolves_in_each_place" "ledger_path not implemented"
fi

echo "== road map =="
fixture roadmap
if have roadmap_entries && have roadmap_blockers; then
  open="$(roadmap_entries | grep -oE '#[0-9]+' | tr '\n' ' ')"
  capped="$(roadmap_entries 1 | wc -l | tr -d ' ')"
  blockers="$(roadmap_blockers | tr '\n' ' ')"
  if [ "$open" = "#10 #11 #12 " ] && [ "$capped" = "1" ] && [ "$blockers" = "10 " ]; then
    ok "test_roadmap_entries_and_blockers"
  else
    bad "test_roadmap_entries_and_blockers" "open=[$open] capped=$capped blockers=[$blockers]"
  fi
else
  bad "test_roadmap_entries_and_blockers" "roadmap_entries / roadmap_blockers not implemented"
fi
if have roadmap_prune; then
  roadmap_prune 11; r1=$?
  one="$(grep -c '#11 ' "$PLANS_DIR/issues_road_map.md")"
  roadmap_prune resolved; r2=$?
  if [ "$r1" -eq 0 ] && [ "$one" = "0" ] && [ "$r2" -eq 0 ] && ! grep -q '#8 ' "$PLANS_DIR/issues_road_map.md" && \
     grep -q '#12 ' "$PLANS_DIR/issues_road_map.md" && grep -q '#10 ' "$PLANS_DIR/issues_road_map.md"; then
    ok "test_roadmap_prune"
  else
    bad "test_roadmap_prune" "rc=$r1/$r2 one=$one"
  fi
else
  bad "test_roadmap_prune" "roadmap_prune not implemented"
fi

echo "== one accessor =="
# No code outside the ledger section of lib/aapp-lib.sh reads or writes a ledger.
# Not access, and left out: comments, messages (echo/printf), the permission
# lists of the hooks, and the files that only seed or name the ledgers.
names='ISSUES\.md|000-issues-archive\.md|issues_road_map\.md'
section="$(awk '/^# ---- Issue ledgers \(P-73\)/ { s = 1 } /^# ---- end issue ledgers/ { s = 0 } s' "$LIB" | wc -l | tr -d ' ')"
outside=""
for f in "$KIT"/lib/*.sh "$KIT/templates/aapp-pre-commit" "$KIT/aapp"; do
  # cmd_init.sh seeds the ledgers; adoption.sh asks only whether a seeded
  # ledger is still the template; cmd_matrix.sh's road map is the matrix's.
  case "${f##*/}" in cmd_init.sh|adoption.sh|cmd_matrix.sh) continue ;; esac
  hits="$(awk -v names="$names" -v lib="$LIB" -v f="$f" '
      f == lib && /^# ---- Issue ledgers \(P-73\)/ { s = 1 }
      f == lib && /^# ---- end issue ledgers/ { s = 0; next }
      s { next }
      /^[[:space:]]*#/ { next }
      $0 !~ names { next }
      /^[[:space:]]*(echo|printf)[[:space:]]/ { next }
      /(echo|printf)[[:space:]]+"[^"]*(ISSUES\.md|000-issues-archive\.md|issues_road_map\.md)/ { next }
      /^[[:space:]]*[^ ]*(pickup\*|ISSUES\.md)[^ ]*\)[[:space:]]*$/ { next }
      { print FILENAME ":" FNR ": " $0 }' "$f")"
  [ -n "$hits" ] && outside="$outside
$hits"
done
if [ "$section" -gt 0 ] && [ -z "$outside" ]; then
  ok "test_no_direct_ledger_access"
else
  bad "test_no_direct_ledger_access" "section lines=$section$(printf '%s\n' "$outside" | head -40 | cut -c1-160)"
fi

print_test_summary "$PASS" "$FAIL"
