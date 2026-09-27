#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `uninstall`
#
# Removes global AAPP binaries from `$HOME/.local/bin/` and share files from
# `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/`.
# ==============================================================================
set -e

SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit"
BIN_DIR="$HOME/.local/bin"

echo "🗑️  Uninstalling AAPP global tools..."
REMOVED_ANY=0
for BIN in "$BIN_DIR/aapp" "$BIN_DIR/aapp-init" "$BIN_DIR/aapp-install"; do
    if [ -e "$BIN" ] || [ -L "$BIN" ]; then
        rm -f "$BIN"
        echo "   • Removed $BIN"
        REMOVED_ANY=1
    fi
done

if [ -e "$SHARE_DIR" ] || [ -L "$SHARE_DIR" ]; then
    rm -rf "$SHARE_DIR"
    echo "   • Removed $SHARE_DIR"
    REMOVED_ANY=1
fi

# Develop-only pre-commit engine (P-34). The uninstaller is global and keeps
# no record of which repositories ran `aapp develop`, so it can only clean the
# repository it is invoked in. Outside a repository there is nothing to clean.
if UNINSTALL_COMMON="$(git rev-parse --git-common-dir 2>/dev/null)"; then
    UNINSTALL_ROOT="$(cd "$UNINSTALL_COMMON/.." && pwd)"
    DEV_HOOK="$UNINSTALL_ROOT/.githooks/aapp-pre-commit-develop"
    WRAPPER="$UNINSTALL_ROOT/.githooks/pre-commit"
    if [ -f "$DEV_HOOK" ]; then
        rm -f "$DEV_HOOK"
        echo "   • Removed $DEV_HOOK"
        REMOVED_ANY=1
    fi
    if [ -f "$WRAPPER" ] && grep -qF "# >>> aapp-pre-commit-develop (P-34) >>>" "$WRAPPER"; then
        sed '/^# >>> aapp-pre-commit-develop (P-34) >>>$/,/^# <<< aapp-pre-commit-develop (P-34) <<<$/d' "$WRAPPER" > "$WRAPPER.aapp-tmp"
        cat "$WRAPPER.aapp-tmp" > "$WRAPPER"
        rm -f "$WRAPPER.aapp-tmp"
        echo "   • Removed develop-only block from $WRAPPER"
        REMOVED_ANY=1
    fi
fi

if [ "$REMOVED_ANY" -eq 1 ]; then
    echo "✨ Uninstallation complete."
    echo "ℹ️  Note: Any PATH export lines added to your shell rc file were left untouched."
else
    echo "ℹ️  No AAPP installation found in $BIN_DIR or $SHARE_DIR."
fi
