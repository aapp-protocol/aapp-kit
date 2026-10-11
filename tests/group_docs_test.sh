#!/usr/bin/env bash
# Tests: a group plan's ARCHITECTURE/CODEMAP sections applied by heading (lib/group_docs.sh, P-64 §2.6)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# shellcheck source=/dev/null
. "$KIT/lib/group_docs.sh"

# fixture: a target file and a group plan with one replaced and one new section.
fixture() {
  cat > "$R/ARCH.md" <<'EOF'
# Arch
## Intro
intro
## Modules
old
### Old Sub
old sub
## Tail
tail
EOF
  cat > "$R/group.md" <<'EOF'
# 🧩 Group Plan P-9: Grp
## Architecture & Codemap
### ARCHITECTURE.md
````markdown
## Modules
new modules
### New Sub
new sub
````
````markdown
## Brand New
added
````
### .agents/CODEMAP.md
No changes.
## 5. Open Questions
EOF
}

echo "== base lines =="
fixture
group_docs_stamp "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" >/dev/null 2>&1; rc=$?
mods_sum="$(printf '## Modules\nold\n### Old Sub\nold sub\n' | group_docs_sum)"
first="$(grep -m1 'aapp-base:' "$R/group.md")"; second="$(grep 'aapp-base:' "$R/group.md" | sed -n 2p)"
cp "$R/group.md" "$R/stamped.md"
group_docs_stamp "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" >/dev/null 2>&1
if [ "$rc" -eq 0 ] && [ "$first" = "<!-- aapp-base: $mods_sum -->" ] && [ "$second" = "<!-- aapp-base: new -->" ] && \
   cmp -s "$R/group.md" "$R/stamped.md"; then
  ok "test_base_lines_recorded_for_new_sections"
else
  bad "test_base_lines_recorded_for_new_sections" "rc=$rc first=[$first] second=[$second] sum=$mods_sum"
fi

echo "== apply =="
out="$(group_docs_apply "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" 2>&1)"; rc=$?
want="$(printf '# Arch\n## Intro\nintro\n## Modules\nnew modules\n### New Sub\nnew sub\n## Tail\ntail\n## Brand New\nadded\n')"
if [ "$rc" -eq 0 ] && [ "$(cat "$R/ARCH.md")" = "$want" ]; then
  ok "test_existing_heading_replaces_whole_section"
else
  bad "test_existing_heading_replaces_whole_section" "rc=$rc got=$(cat "$R/ARCH.md" | tr '\n' '|')"
fi
if tail -2 "$R/ARCH.md" | head -1 | grep -qx '## Brand New'; then
  ok "test_new_heading_is_added_at_the_end"
else
  bad "test_new_heading_is_added_at_the_end" "tail=$(tail -2 "$R/ARCH.md" | tr '\n' '|')"
fi
if echo "$out" | grep -qx 'replaced: ## Modules' && echo "$out" | grep -qx 'added: ## Brand New'; then
  ok "test_report_names_replaced_and_added"
else
  bad "test_report_names_replaced_and_added" "out=$out"
fi

out="$(group_docs_apply "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$R/ARCH.md")" = "$want" ] && echo "$out" | grep -qx 'unchanged: ## Modules' && \
   echo "$out" | grep -qx 'unchanged: ## Brand New'; then
  ok "test_reapply_reports_unchanged"
else
  bad "test_reapply_reports_unchanged" "rc=$rc out=$out"
fi

echo "== no changes =="
printf '# Map\n## A\na\n' > "$R/MAP.md"; cp "$R/MAP.md" "$R/MAP.orig"
out="$(group_docs_apply "$R/group.md" .agents/CODEMAP.md "$R/MAP.md" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$R/MAP.md" "$R/MAP.orig" && [ -z "$out" ]; then
  ok "test_no_changes_leaves_files_untouched"
else
  bad "test_no_changes_leaves_files_untouched" "rc=$rc out=$out"
fi

echo "== overwrite guard =="
fixture
group_docs_stamp "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" >/dev/null 2>&1
sed -i 's/^old$/old, edited meanwhile/' "$R/ARCH.md"; cp "$R/ARCH.md" "$R/ARCH.before"
out1="$(group_docs_apply "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" 2>&1)"; r1=$?
same1=0; cmp -s "$R/ARCH.md" "$R/ARCH.before" && same1=1
fixture
group_docs_stamp "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" >/dev/null 2>&1
printf '## Brand New\nsomeone else\n' >> "$R/ARCH.md"; cp "$R/ARCH.md" "$R/ARCH.before"
out2="$(group_docs_apply "$R/group.md" ARCHITECTURE.md "$R/ARCH.md" 2>&1)"; r2=$?
same2=0; cmp -s "$R/ARCH.md" "$R/ARCH.before" && same2=1
if [ "$r1" -ne 0 ] && [ "$same1" -eq 1 ] && echo "$out1" | grep -qF '## Modules' && \
   [ "$r2" -ne 0 ] && [ "$same2" -eq 1 ] && echo "$out2" | grep -qF '## Brand New'; then
  ok "test_changed_section_refuses"
else
  bad "test_changed_section_refuses" "r=$r1/$r2 same=$same1/$same2 out=$out1 | $out2"
fi

print_test_summary "$PASS" "$FAIL"
