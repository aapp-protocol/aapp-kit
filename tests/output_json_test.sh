#!/usr/bin/env bash
# Suite: the JSON documents of `aapp status json` and `aapp issue list json`
# (P-94), checked against docs/reference/08-output-json.md.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

if ! command -v python3 >/dev/null 2>&1; then
  echo "  ℹ️  python3 not found: the JSON documents cannot be parsed here; suite skipped."
  print_test_summary "$PASS" "$FAIL"
  exit 0
fi

# jq_ <file> <python expression over `d`>: prints the expression's value, JSON-encoded.
jq_() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(eval(sys.argv[2]), ensure_ascii=False))' "$1" "$2"; }
# parses <file>: true when the file is exactly one JSON object.
parses() { python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(o, dict) else 1)' "$1" 2>/dev/null; }

SYM='Says "hi" with `code`, a \back\slash and … done.'
init_sandbox_project "$R/j"
cd "$R/j" || exit 1
git config aapp.issueFixWait 0; git config aapp.offlineEnabled false
git remote add origin "https://someone:s3cret@example.com/acme/app.git"
# Changelog: one entry tagged with a plan, committed.
sed -i 's/^### Fixed$/### Fixed\n- A tagged fix (P-7)/' CHANGELOG.md
git add CHANGELOG.md && git commit -qm "docs: a fix" --no-verify
# Issues: #1 queued urgently (tracker names, notes), #2 queued, #3 not queued.
{ printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
  printf '| #1 | `Medium` | `CLI` | 2026-10-01 | `src/a.sh` | %s |  | 🟡 `Incubated` |\n' "$SYM"
  printf '%s\n' '| #2 | `Low` | `CORE` | 2026-10-02 | `src/b.sh` | Second symptom. |  | 🟡 `Incubated` |'
  printf '%s\n' '| #3 | `High` | `HOOK` | 2026-10-03 | `src/c.sh` | Third symptom. |  | 🟡 `Incubated` |'
} > .plans/ISSUES.md
printf '%s\n' '# 🗺️ Issue Work Queue' '' '## 🧱 Plan Blockers' '' '## 📋 Queued' '' '### 🔺 Urgent' \
  '- [ ] #1 -> First. (queued 2026-10-04)' '' '### Normal' '- [ ] #2 -> Second symptom. (queued 2026-10-05)' '' '### Low' > .plans/issues_road_map.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture --no-verify >/dev/null 2>&1
git config aapp.issueId 10
printf '#1\tjira\thttps://t.example/1\t2.1\n' > "$(git rev-parse --git-common-dir)/aapp_issue_meta"
aapp refine issues "notes" note 1 "secret first note" note 1 "secret second note" >/dev/null 2>&1
# Plans: a group with a member, and a plan of its own.
gid="P-$(git config aapp.planId)"; aapp draft json-group group >/dev/null 2>&1
mid="P-$(git config aapp.planId)"; aapp draft json-member group "$gid" >/dev/null 2>&1
pid="P-$(git config aapp.planId)"; aapp draft json-plan >/dev/null 2>&1
# Pickup: an idea naming a file that exists and one that does not.
mkdir -p .plans/pickup && echo notes > .plans/pickup/kept.md
printf '%s\n' '- [ ] Linked Idea: see `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.' >> .plans/pickup.md

aapp status json > "$R/status.json" 2> "$R/status.err"; src=$?
aapp issue list json > "$R/list.json" 2> "$R/list.err"; lrc=$?
# A paused project, for the pause object: its buffer as `aapp pause` writes it.
buf="$(git rev-parse --git-common-dir)/aapp_paused"
printf '{"reason": "Away", "timestamp": "2026-10-16T10:00:00Z", "snapshot": {"stashes": [{"worktree": "%s", "branch": "develop"}]}}\n' "$(pwd)" > "$buf"
aapp status json > "$R/paused.json" 2>/dev/null
rm -f "$buf"

echo "== the documents =="
if [ "$src" -eq 0 ] && parses "$R/status.json" && [ "$(jq_ "$R/status.json" 'd["command"]')" = '"status"' ] && \
   ! grep -q 'Context Recovery Briefing' "$R/status.json"; then
  ok "test_status_json_parses"
else
  bad "test_status_json_parses" "rc=$src head=$(head -c 300 "$R/status.json") err=$(head -c 200 "$R/status.err")"
fi

aapp issue list 1 json > "$R/list1.json" 2>/dev/null; r1=$?
aapp issue list all json > "$R/listall.json" 2>/dev/null; ra=$?
if [ "$lrc" -eq 0 ] && [ "$r1" -eq 0 ] && [ "$ra" -eq 0 ] && parses "$R/list.json" && \
   [ "$(jq_ "$R/list.json" '[d["shown"], d["total"], len(d["issues"])]')" = "[3, 3, 3]" ] && \
   [ "$(jq_ "$R/list1.json" '[d["shown"], d["total"], len(d["issues"])]')" = "[1, 3, 1]" ] && \
   [ "$(jq_ "$R/listall.json" 'd["shown"]')" = "3" ]; then
  ok "test_issue_list_json_parses"
else
  bad "test_issue_list_json_parses" "rc=$lrc/$r1/$ra list=$(head -c 300 "$R/list.json") err=$(head -c 200 "$R/list.err")"
fi

echo "== the reference =="
cat > "$R/check.py" <<'PY'
import json, re, sys
doc, status_f, list_f = sys.argv[1:4]
tables, name = {}, None
for line in open(doc, encoding="utf-8"):
    m = re.match(r"^### `([^`]+)`", line)
    if m: name = m.group(1); tables[name] = []; continue
    if line.startswith("## "): name = None; continue
    m = re.match(r"^\| `([a-z_]+)` \|", line)
    if name and m: tables[name].append(m.group(1))
st, ls = json.load(open(status_f, encoding="utf-8")), json.load(open(list_f, encoding="utf-8"))
errors, seen = [], set()
def check(table, obj, where):
    if obj is None: return
    seen.add(table)
    if list(obj.keys()) != tables.get(table):
        errors.append(f"{where}: keys {list(obj.keys())} != `{table}` {tables.get(table)}")
env = tables["envelope"]
for d, t, w in ((st, "status", "status"), (ls, "issue list", "issue list")):
    keys = list(d.keys())
    if keys[:len(env)] != env: errors.append(f"{w}: envelope {keys[:len(env)]} != {env}")
    if keys[len(env):] != tables[t]: errors.append(f"{w}: {keys[len(env):]} != `{t}` {tables[t]}")
    seen.update(("envelope", t))
    check("repository", d["repository"], w + ".repository")
    check("repository.remote", d["repository"]["remote"], w + ".repository.remote")
    for n in d["notices"]: check("notices[]", n, w + ".notices[]")
def issue(i, w):
    check("issue", i, w); check("issue.queue", i["queue"], w + ".queue"); check("issue.tracker", i["tracker"], w + ".tracker")
for i in ls["issues"]: issue(i, "issue list.issues[]")
for i in st["issues"]["queue"]: issue(i, "status.issues.queue[]")
for k in ("overview", "templates", "pause", "shipped", "issues", "plans", "pickup", "adoption", "offline", "next_action"):
    check("status." + k, st[k], "status." + k)
for x in st["templates"]["drifted"]: check("status.templates.drifted[]", x, "drifted[]")
if st["pause"]:
    for x in st["pause"]["stashes"]: check("status.pause.stashes[]", x, "stashes[]")
for x in st["shipped"]["entries"]: check("status.shipped.entries[]", x, "entries[]")
def plan(p, w):
    check("plan", p, w)
    for m in p["members"]: plan(m, w + ".members[]")
for p in st["plans"]["items"]: plan(p, "plans.items[]")
for x in st["pickup"]["items"]: check("status.pickup.items[]", x, "pickup.items[]")
unseen = set(tables) - seen - {"status.offline", "status.templates.drifted[]"}
if unseen: errors.append(f"tables with no object in the fixture: {sorted(unseen)}")
print("\n".join(errors)); sys.exit(1 if errors else 0)
PY
cout="$(python3 "$R/check.py" "$KIT/docs/reference/08-output-json.md" "$R/paused.json" "$R/list.json" 2>&1)"; crc=$?
if [ "$crc" -eq 0 ]; then ok "test_fields_match_reference"; else bad "test_fields_match_reference" "$cout"; fi

echo "== the values =="
i3="$(jq_ "$R/list.json" '[i for i in d["issues"] if i["id"] == "#3"][0]')"
if [ "$(printf '%s' "$i3" | python3 -c 'import json,sys; i=json.load(sys.stdin); print([i["plan"], i["blocks"], i["queue"], i["branch"], i["tracker"], i["offline"]])')" = "[None, None, None, None, None, False]" ] && \
   [ "$(jq_ "$R/status.json" 'd["plans"]["items"][[p["id"] for p in d["plans"]["items"]].index("'"$pid"'")]["members"]')" = "[]" ] && \
   [ "$(jq_ "$R/status.json" 'd["templates"]["drifted"]')" = "[]" ]; then
  ok "test_absent_values_are_null"
else
  bad "test_absent_values_are_null" "#3=$i3"
fi

got="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print([i for i in d["issues"] if i["id"] == "#1"][0]["symptom"], end="")' "$R/list.json")"
if [ "$got" = "$SYM" ] && [ "$(jq_ "$R/status.json" '[i for i in d["issues"]["queue"] if i["id"] == "#1"][0]["symptom"]')" = "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$SYM")" ]; then
  ok "test_text_verbatim"
else
  bad "test_text_verbatim" "got=[$got]"
fi

if [ "$(jq_ "$R/list.json" '[i for i in d["issues"] if i["id"] == "#1"][0]["notes"]')" = "2" ] && \
   [ "$(jq_ "$R/list.json" '[i for i in d["issues"] if i["id"] == "#2"][0]["notes"]')" = "0" ] && \
   ! grep -q 'secret' "$R/list.json" "$R/status.json"; then
  ok "test_issue_notes_count"
else
  bad "test_issue_notes_count" "$(jq_ "$R/list.json" '[(i["id"], i["notes"]) for i in d["issues"]]')"
fi

want_url='"https://example.com/acme/app.git"'
if [ "$(jq_ "$R/status.json" 'd["repository"]["remote"]["url"]')" = "$want_url" ] && \
   [ "$(jq_ "$R/list.json" 'd["repository"]["remote"]')" = '{"name": "origin", "url": "https://example.com/acme/app.git"}' ] && \
   ! grep -q 's3cret' "$R/status.json" "$R/list.json"; then
  git remote remove origin
  aapp issue list json > "$R/nore.json" 2>/dev/null; aapp status json > "$R/nores.json" 2>/dev/null
  if [ "$(jq_ "$R/nore.json" 'd["repository"]["remote"]')" = "null" ] && [ "$(jq_ "$R/nores.json" 'd["repository"]["remote"]')" = "null" ]; then
    ok "test_repository_remote"
  else
    bad "test_repository_remote" "without a remote: $(jq_ "$R/nore.json" 'd["repository"]')"
  fi
  git remote add origin "https://someone:s3cret@example.com/acme/app.git"
else
  bad "test_repository_remote" "$(jq_ "$R/status.json" 'd["repository"]')"
fi

root="$(pwd)"
git config aapp.jsonLocalPath false
aapp issue list json > "$R/nopath.json" 2>/dev/null; aapp status json > "$R/nopaths.json" 2>/dev/null
git config --unset aapp.jsonLocalPath
if [ "$(jq_ "$R/list.json" 'd["repository"]["root"]')" = "\"$root\"" ] && [ "$(jq_ "$R/nopath.json" 'd["repository"]["root"]')" = "null" ] && \
   [ "$(jq_ "$R/nopaths.json" 'd["repository"]["root"]')" = "null" ] && ! grep -qF "$root" "$R/nopath.json" "$R/nopaths.json"; then
  ok "test_local_path_setting"
else
  bad "test_local_path_setting" "root=$(jq_ "$R/nopaths.json" 'd["repository"]') hits=$(grep -cF "$root" "$R/nopaths.json")"
fi

g="$(jq_ "$R/status.json" '[p for p in d["plans"]["items"] if p["id"] == "'"$gid"'"][0]')"
top="$(jq_ "$R/status.json" '[p["id"] for p in d["plans"]["items"]]')"
if printf '%s' "$g" | python3 -c 'import json,sys; g=json.load(sys.stdin); sys.exit(0 if g["kind"] == "group" and [m["id"] for m in g["members"]] == [sys.argv[1]] and g["members"][0]["group"] == sys.argv[2] else 1)' "$mid" "$gid" && \
   ! printf '%s' "$top" | grep -qF "\"$mid\""; then
  ok "test_group_nests_members"
else
  bad "test_group_nests_members" "group=$g top=$top"
fi

p="$(jq_ "$R/status.json" '[x for x in d["pickup"]["items"] if x["title"] == "Linked Idea"][0]')"
if [ "$p" = '{"title": "Linked Idea", "text": "see `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.", "files": [".plans/pickup/kept.md"]}' ] && \
   jq_ "$R/status.json" 'd["notices"]' | grep -qF '.plans/pickup/gone.md'; then
  ok "test_pickup_objects"
else
  bad "test_pickup_objects" "item=$p notices=$(jq_ "$R/status.json" 'd["notices"]')"
fi

# The same items as the terminal briefing lists, in its order.
term="$(aapp status 2>/dev/null)"
tq="$(printf '%s\n' "$term" | sed -n '/ISSUES/,/PLANS/p' | grep -oE '^  #[0-9]+' | tr -d ' ' | paste -sd, -)"
tp="$(printf '%s\n' "$term" | sed -n '/PLANS/,/PICKUP/p' | grep -oE '^  • P-[0-9]+' | sed 's/^  • //' | paste -sd, -)"
ti="$(printf '%s\n' "$term" | sed -n '/PICKUP/,/^$/p' | grep -E '^  - \[ \] ' | sed -E 's/^  - \[ \] //' | paste -sd'|' -)"
jqq="$(jq_ "$R/status.json" '",".join(i["id"] for i in d["issues"]["queue"])' | tr -d '"')"
jqp="$(jq_ "$R/status.json" '",".join(p["id"] for p in d["plans"]["items"])' | tr -d '"')"
jqi="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("|".join(x["title"] or x["text"] for x in d["pickup"]["items"]))' "$R/status.json")"
if [ -n "$tq" ] && [ "$tq" = "$jqq" ] && [ "$tp" = "$jqp" ] && [ "$ti" = "$jqi" ]; then
  ok "test_same_items_as_terminal"
else
  bad "test_same_items_as_terminal" "queue=[$tq|$jqq] plans=[$tp|$jqp] pickup=[$ti|$jqi]"
fi

# A run that fails prints nothing on stdout.
git config aapp.statusItemsMax none
out="$(aapp status json 2>/dev/null)"; frc=$?
git config --unset aapp.statusItemsMax
out2="$(aapp issue list sideways json 2>/dev/null)"; frc2=$?
if [ "$frc" -ne 0 ] && [ -z "$out" ] && [ "$frc2" -ne 0 ] && [ -z "$out2" ]; then
  ok "test_failure_prints_nothing"
else
  bad "test_failure_prints_nothing" "status=$frc [$out] list=$frc2 [$out2]"
fi

print_test_summary "$PASS" "$FAIL"
