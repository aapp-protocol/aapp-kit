#!/usr/bin/env bash
# ==============================================================================
# AAPP Output Renderers (P-91, P-92)
#
# Shared rendering for commands that print records: the terminal width, and
# text wrapped or cut to it. Widths and limits count characters, not bytes:
# UTF-8 continuation bytes are not counted, whatever the locale.
# Sourced by lib/cmd_status.sh and lib/cmd_issue.sh; the hooks never load it.
# ==============================================================================

# out_width -> `aapp.statusOutputWidth` (default 85), the most characters on a
# line. Fails, naming the key, when it is not a whole number of at least 40.
out_width() {
    local v
    v="$(git config --get aapp.statusOutputWidth 2>/dev/null)" || v=85
    case "$v" in ''|*[!0-9]*) ;; *) [ "$v" -ge 40 ] && { echo "$v"; return 0; } ;; esac
    echo "❌ [Output] aapp.statusOutputWidth is '$v'; it must be a whole number of at least 40." >&2
    return 1
}

# out_wrap <first-indent> <hang-indent> [<width>]: stdin, one paragraph (line
# breaks read as spaces), wrapped at spaces: the first line indented by
# <first-indent> spaces, the others by <hang-indent>, none longer than the
# width (out_width when not given). Leading spaces are dropped; a run of
# spaces inside the text is kept as written. A word longer than the room left
# stands on a line of its own, whole. Prints nothing for empty input.
out_wrap() {
    local w="${3:-}"
    [ -n "$w" ] || w="$(out_width)" || return 1
    LC_ALL=C awk -v first="$1" -v hang="$2" -v width="$w" '
        function clen(s,   t) { t = s; gsub(cont, "", t); return length(t) }
        BEGIN { cont = "[\200-\277]"; para = "" }
        { gsub(/\t/, " "); para = para (para == "" ? "" : " ") $0 }
        END {
            sub(/^ +/, "", para); sub(/ +$/, "", para)
            # A run of spaces: one separator, the others kept as \001 tokens.
            while (index(para, "  ")) gsub(/  /, " \001", para)
            n = split(para, word, / /)
            line = ""; pad = sprintf("%" first "s", ""); used = 0
            for (i = 1; i <= n; i++) {
                if (word[i] == "") continue
                if (!used) { line = pad word[i]; used = 1; continue }
                if (clen(line) + 1 + clen(word[i]) <= width + 0) { line = line " " word[i]; continue }
                print line; line = sprintf("%" hang "s", "") word[i]
            }
            if (used) { print line }
        }' | LC_ALL=C tr '\001' ' '
}

# ------------------------------------------------------------------------------
# The JSON writer (P-94). A document is built compact from the pieces below,
# then printed by `out_json_pretty`. Strings go through `json_escape`
# (lib/hook_dispatcher.sh, loaded with lib/plan_resolver.sh). The contract:
# docs/reference/08-output-json.md.
# ------------------------------------------------------------------------------

# out_json_str <text> -> a JSON string; out_json_strn: `null` for an empty text.
out_json_str() { printf '"%s"' "$(json_escape "$1")"; }
out_json_strn() { if [ -n "$1" ]; then out_json_str "$1"; else printf 'null'; fi; }
# out_json_num <n> -> a number, 0 when empty; out_json_numn: `null` when empty.
out_json_num() { printf '%s' "${1:-0}"; }
out_json_numn() { if [ -n "$1" ]; then printf '%s' "$1"; else printf 'null'; fi; }
# out_json_bool <value> -> `true` for 1 or true, `false` otherwise.
out_json_bool() { case "$1" in 1|true) printf 'true' ;; *) printf 'false' ;; esac; }
# out_json_strlist <a,b,…> -> a list of strings; `[]` for an empty text.
out_json_strlist() {
    local IFS=',' item out=""
    for item in $1; do [ -n "$item" ] && out="${out:+$out,}$(out_json_str "$item")"; done
    printf '[%s]' "$out"
}
# out_json_list <json>… -> a list of the values given.
out_json_list() { local IFS=','; printf '[%s]' "$*"; }
# out_json_obj <key> <json> [<key> <json>]… -> an object, keys in the order given.
out_json_obj() {
    local out=""
    while [ $# -ge 2 ]; do out="${out:+$out,}\"$1\":$2"; shift 2; done
    printf '{%s}' "$out"
}

# out_json_local_path -> true unless `aapp.jsonLocalPath` is false; fails,
# naming the key, for any other value.
out_json_local_path() {
    local v
    v="$(git config --get aapp.jsonLocalPath 2>/dev/null)" || v=true
    case "$v" in true) return 0 ;; false) return 1 ;; esac
    echo "❌ [Output] aapp.jsonLocalPath is '$v'; it must be true or false." >&2
    return 2
}

# out_json_repository -> the `repository` object: the remote (credentials
# removed, `_envelope_remote_json`), the branch, and the checkout's path unless
# `aapp.jsonLocalPath` is false.
out_json_repository() {
    local root rc=0 branch
    out_json_local_path || rc=$?
    case "$rc" in 0) root="$(out_json_str "$REPO_ROOT")" ;; 1) root=null ;; *) return 1 ;; esac
    branch="$(git -C "$REPO_ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)"
    out_json_obj remote "$(_envelope_remote_json | tr -d '\n')" branch "$(out_json_strn "$branch")" root "$root"
}

# out_json_envelope <command> <notices json> -> the envelope's pairs, as
# `out_json_obj` arguments would give them, without the braces.
out_json_envelope() {
    local repo
    repo="$(out_json_repository)" || return 1
    printf '"version":"1.0","command":%s,"generated_at":%s,"repository":%s,"notices":%s' \
        "$(out_json_str "$1")" "$(out_json_str "$(date -u +%Y-%m-%dT%H:%M:%SZ)")" "$repo" "$2"
}

# out_json_notices -> `level\tsection\ttext` lines on stdin as the `notices`
# list; the text without the emoji the terminal gives it.
out_json_notices() {
    local level sec text out=""
    while IFS=$'\t' read -r level sec text; do
        [ -n "$level" ] || continue
        text="$(printf '%s' "$text" | LC_ALL=C sed -E 's/^[^][A-Za-z0-9(#`]+//')"
        out="${out:+$out,}$(out_json_obj level "$(out_json_str "$level")" section "$(out_json_str "$sec")" text "$(out_json_str "$text")")"
    done
    printf '[%s]' "$out"
}

# out_json_pretty: one compact JSON document on stdin, printed with a 2-space
# indent, a key and its value on one line, `[]` and `{}` kept whole.
out_json_pretty() {
    LC_ALL=C awk 'BEGIN { RS = "\001" }
        function pad(n,   s) { s = ""; while (n-- > 0) s = s "  "; return s }
        {
            s = $0; n = length(s); ind = 0; str = 0; esc = 0
            for (i = 1; i <= n; i++) {
                c = substr(s, i, 1)
                if (str) { printf "%s", c; if (esc) esc = 0; else if (c == "\\") esc = 1; else if (c == "\"") str = 0; continue }
                if (c == "\"") { str = 1; printf "%s", c; continue }
                if (c == " " || c == "\n" || c == "\t" || c == "\r") continue
                if (c == "{" || c == "[") {
                    for (j = i + 1; j <= n && substr(s, j, 1) ~ /[ \n\t\r]/; j++) ;
                    d = substr(s, j, 1)
                    if ((c == "{" && d == "}") || (c == "[" && d == "]")) { printf "%s%s", c, d; i = j; continue }
                    ind++; printf "%s\n%s", c, pad(ind); continue
                }
                if (c == "}" || c == "]") { ind--; printf "\n%s%s", pad(ind), c; continue }
                if (c == ",") { printf ",\n%s", pad(ind); continue }
                if (c == ":") { printf ": "; continue }
                printf "%s", c
            }
            printf "\n"
        }'
}

# out_cut <limit>: stdin, one paragraph, cut at the last space before <limit>
# characters and ended with `…`, the whole within <limit>; shorter text is
# unchanged. A first word longer than the limit is cut inside it.
out_cut() {
    LC_ALL=C awk -v limit="$1" '
        function clen(s,   t) { t = s; gsub(cont, "", t); return length(t) }
        BEGIN { cont = "[\200-\277]"; para = "" }
        { para = para (para == "" ? "" : " ") $0 }
        END {
            if (clen(para) <= limit + 0) { print para; exit }
            n = split(para, word, / /); out = ""
            for (i = 1; i <= n; i++) {
                try = (out == "" ? word[i] : out " " word[i])
                if (clen(try) > limit - 1) break
                out = try
            }
            if (out == "") {
                # One word longer than the limit: its first limit-1 characters.
                k = 0
                for (j = 1; j <= length(para) && k < limit - 1; j++) {
                    c = substr(para, j, 1); if (c !~ cont) k++
                    out = out c
                }
                while (j <= length(para) && substr(para, j, 1) ~ cont) { out = out substr(para, j, 1); j++ }
            }
            print out "…"
        }'
}
