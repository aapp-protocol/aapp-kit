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
    if [ -f "$BIN" ]; then
        rm -f "$BIN"
        echo "   • Removed $BIN"
        REMOVED_ANY=1
    fi
done

if [ -d "$SHARE_DIR" ]; then
    rm -rf "$SHARE_DIR"
    echo "   • Removed $SHARE_DIR"
    REMOVED_ANY=1
fi

if [ "$REMOVED_ANY" -eq 1 ]; then
    echo "✨ Uninstallation complete."
    echo "ℹ️  Note: Any PATH export lines added to your shell rc file were left untouched."
else
    echo "ℹ️  No AAPP installation found in $BIN_DIR or $SHARE_DIR."
fi
