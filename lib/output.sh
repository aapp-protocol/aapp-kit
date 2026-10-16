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
