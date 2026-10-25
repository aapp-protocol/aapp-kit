#!/usr/bin/env bash
# ==============================================================================
# Blast Radius Guard - PreToolUse Hook Entrypoint
# ==============================================================================
AAPP_PERL_LIB="${AAPP_LIB:-}"
if [ -z "$AAPP_PERL_LIB" ] || [ ! -d "$AAPP_PERL_LIB" ]; then
    KD="$(git config --get aapp.kitDir 2>/dev/null || true)"
    [ -n "$KD" ] && [ -d "$KD/lib" ] && AAPP_PERL_LIB="$KD/lib"
fi
if [ -z "$AAPP_PERL_LIB" ] || [ ! -d "$AAPP_PERL_LIB" ]; then
    HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
    if [ -f "$HOOK_DIR/../lib/AAPP/JSON.pm" ]; then
        AAPP_PERL_LIB="$(cd "$HOOK_DIR/../lib" && pwd)"
    fi
fi
if [ -z "$AAPP_PERL_LIB" ] || [ ! -d "$AAPP_PERL_LIB" ]; then
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    [ -d "$DATA_HOME/aapp-kit/lib" ] && AAPP_PERL_LIB="$DATA_HOME/aapp-kit/lib"
fi

if ! command -v perl >/dev/null 2>&1 || [ ! -r "$AAPP_PERL_LIB/AAPP/JSON.pm" ]; then
    echo "❌ [Blast Radius Guard Violation] Perl core missing: perl and ${AAPP_PERL_LIB}/AAPP/JSON.pm are required. Install the kit: aapp install." >&2
    exit 2
fi

exec perl -CSA -Mutf8 -I"$AAPP_PERL_LIB" -MAAPP::Hooks::WriteGuard -e 'exit AAPP::Hooks::WriteGuard->run(@ARGV)' -- "$@"
