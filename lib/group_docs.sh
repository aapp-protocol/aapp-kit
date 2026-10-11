#!/usr/bin/env bash
# lib/group_docs.sh (P-64 §2.6): a group plan's `## Architecture & Codemap` holds
# whole sections of ARCHITECTURE.md and .agents/CODEMAP.md, one ```` fence each,
# under `### <file>`. At the group's `done` each section replaces the file's
# section with the same heading (up to the next heading of the same or a higher
# level), or is added at the end. A base line above each fence,
# `<!-- aapp-base: <sha256> | new -->`, records the file's section when the plan
# took it over; `group_docs_apply` refuses a section the file changed since.

# group_docs_sum: sha256 of stdin, hex only.
group_docs_sum() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{ print $1 }'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{ print $1 }'
    else echo "❌ [Group Docs] No sha256sum or shasum found." >&2; return 1
    fi
}

# _gd_split <plan> <file-key> <dir>: writes <dir>/N.body, <dir>/N.base for each
# fenced section under `### <file-key>`; prints the count.
_gd_split() {
    AAPP_KEY="$2" awk -v dir="$3" '
        BEGIN { n = 0 }
        infence && /^````/ { infence = 0; next }
        infence { if (mine) print > (dir "/" n ".body"); next }
        /^## Architecture & Codemap/ { inarch = 1; next }
        /^## / { inarch = 0; key = ""; next }
        !inarch { next }
        /^### / { key = substr($0, 5); pending = ""; next }
        /^<!-- aapp-base: .* -->[[:space:]]*$/ { pending = $0; sub(/^<!-- aapp-base: /, "", pending); sub(/ -->[[:space:]]*$/, "", pending); next }
        /^````/ { infence = 1; mine = (key == ENVIRON["AAPP_KEY"])
                  if (mine) { n++; printf "%s", pending > (dir "/" n ".base"); close(dir "/" n ".base"); printf "" > (dir "/" n ".body") }
                  pending = ""; next }
        END { print n }
    ' "$1"
}

# _gd_section <doc> <heading-line>: prints the doc's section under that exact
# heading (outside ``` fences), up to the next heading of the same or a higher
# level; fails when the heading is absent.
_gd_section() {
    AAPP_H="$2" awk '
        BEGIN { h = ENVIRON["AAPP_H"]; match(h, /^#+/); lvl = RLENGTH }
        /^[[:space:]]*```/ { fence = !fence }
        !fence && /^#+ / { match($0, /^#+/)
                           if (on && RLENGTH <= lvl) exit
                           if ($0 == h) { on = 1; found = 1 } }
        on { print }
        END { exit found ? 0 : 1 }
    ' "$1"
}

# _gd_replace <doc> <heading-line> <body-file>: the doc with that section replaced.
_gd_replace() {
    AAPP_H="$2" awk -v body="$3" '
        BEGIN { h = ENVIRON["AAPP_H"]; match(h, /^#+/); lvl = RLENGTH }
        /^[[:space:]]*```/ && !on { fence = !fence }
        !fence && /^#+ / { match($0, /^#+/)
                           if (on && RLENGTH <= lvl) on = 0
                           else if (!done && $0 == h) { while ((getline l < body) > 0) print l; on = 1; done = 1; next } }
        !on { print }
    ' "$1"
}

# group_docs_stamp <plan> <file-key> <doc>: gives each section without a base
# line one, from <doc> as it is now. Existing base lines are kept.
group_docs_stamp() {
    local plan="$1" key="$2" doc="$3" dir n i h base tmp
    dir="$(mktemp -d)" || return 1
    n="$(_gd_split "$plan" "$key" "$dir")" || { rm -rf "$dir"; return 1; }
    tmp="$plan.aapp-gd.$$"
    cp "$plan" "$tmp" || { rm -rf "$dir"; return 1; }
    for ((i = n; i >= 1; i--)); do
        [ -s "$dir/$i.base" ] && continue
        h="$(head -n 1 "$dir/$i.body")"
        if base="$(_gd_section "$doc" "$h")"; then
            base="$(printf '%s\n' "$base" | group_docs_sum)" || { rm -rf "$dir" "$tmp"; return 1; }
        else
            base="new"
        fi
        # Insert above the i-th fence under `### <key>`.
        AAPP_KEY="$key" awk -v want="$i" -v line="<!-- aapp-base: $base -->" '
            infence && /^````/ { infence = 0; print; next }
            infence { print; next }
            /^## Architecture & Codemap/ { inarch = 1; print; next }
            /^## / { inarch = 0; key = "" }
            inarch && /^### / { key = substr($0, 5) }
            inarch && /^````/ { infence = 1; if (key == ENVIRON["AAPP_KEY"] && ++seen == want) print line }
            { print }
        ' "$tmp" > "$tmp.n" && mv "$tmp.n" "$tmp" || { rm -rf "$dir" "$tmp" "$tmp.n"; return 1; }
    done
    mv "$tmp" "$plan"
    rm -rf "$dir"
}

# group_docs_apply <plan> <file-key> <doc>: checks every section against its
# base line, then applies them all; prints `replaced: <heading>` / `added: <heading>`.
# Any mismatch refuses with <doc> unchanged.
group_docs_apply() {
    local plan="$1" key="$2" doc="$3" dir n i h base cur bad=0 tmp
    dir="$(mktemp -d)" || return 1
    n="$(_gd_split "$plan" "$key" "$dir")" || { rm -rf "$dir"; return 1; }
    for ((i = 1; i <= n; i++)); do
        h="$(head -n 1 "$dir/$i.body")"; base="$(cat "$dir/$i.base")"
        if cur="$(_gd_section "$doc" "$h")"; then
            if [ "$base" = "new" ]; then
                echo "❌ [Group Docs] $key: '$h' is new in the plan but now exists in the file; merge it into the plan's section and clear its base line." >&2; bad=1
            elif [ "$(printf '%s\n' "$cur" | group_docs_sum)" != "$base" ]; then
                echo "❌ [Group Docs] $key: '$h' changed in the file since the plan took it over; update the plan's section and clear its base line." >&2; bad=1
            fi
        elif [ "$base" != "new" ]; then
            echo "❌ [Group Docs] $key: '$h' is no longer in the file; update the plan's section and clear its base line." >&2; bad=1
        fi
        if [ -z "$base" ]; then
            echo "❌ [Group Docs] $key: '$h' has no base line; run 'aapp refine' on the group first." >&2; bad=1
        fi
    done
    if [ "$bad" -ne 0 ]; then rm -rf "$dir"; return 1; fi
    tmp="$doc.aapp-gd.$$"
    cp "$doc" "$tmp" || { rm -rf "$dir"; return 1; }
    for ((i = 1; i <= n; i++)); do
        h="$(head -n 1 "$dir/$i.body")"
        if _gd_section "$tmp" "$h" >/dev/null; then
            _gd_replace "$tmp" "$h" "$dir/$i.body" > "$tmp.n" && mv "$tmp.n" "$tmp" || { rm -rf "$dir" "$tmp" "$tmp.n"; return 1; }
            echo "replaced: $h"
        else
            cat "$dir/$i.body" >> "$tmp" || { rm -rf "$dir" "$tmp"; return 1; }
            echo "added: $h"
        fi
    done
    mv "$tmp" "$doc"
    rm -rf "$dir"
}
