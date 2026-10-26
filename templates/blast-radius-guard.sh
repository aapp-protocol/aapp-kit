#!/usr/bin/env bash
# ==============================================================================
# Blast Radius Guard - PreToolUse Hook Entrypoint
# ==============================================================================
# §2.1 item 5: Load AAPP::* from the installed kit ($AAPP_LIB, else kit_dir)
AAPP_PERL_LIB="${AAPP_LIB:-}"
if [ -z "$AAPP_PERL_LIB" ]; then
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    AAPP_PERL_LIB="$DATA_HOME/aapp-kit/lib"
fi

if ! command -v perl >/dev/null 2>&1 || [ ! -r "$AAPP_PERL_LIB/AAPP/JSON.pm" ]; then
    echo "❌ [Blast Radius Guard Violation] Perl core missing: perl and ${AAPP_PERL_LIB}/AAPP/JSON.pm are required. Install the kit: aapp install." >&2
    exit 2
fi

exec perl -CSA -Mutf8 -I"$AAPP_PERL_LIB" -MAAPP::Hooks::WriteGuard -e 'exit AAPP::Hooks::WriteGuard->run(@ARGV)' -- "$@"
