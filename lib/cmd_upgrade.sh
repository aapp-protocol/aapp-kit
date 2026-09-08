#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `upgrade`
#
# Upgrades global AAPP binaries & templates by fetching the latest release
# from upstream Git repository into ~/.local/share/aapp-kit and ~/.local/bin/aapp.
# ==============================================================================
set -e

UPSTREAM_URL="${AAPP_UPSTREAM_URL:-https://github.com/aapp-protocol/aapp-kit.git}"
TMP_DIR="$(mktemp -d -t aapp-upgrade-XXXXXX)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "🌐 Fetching latest AAPP release from $UPSTREAM_URL..."
if ! git clone --depth 1 "$UPSTREAM_URL" "$TMP_DIR" --quiet 2>/dev/null; then
    echo "❌ Error: Failed to clone upstream repository ($UPSTREAM_URL)."
    echo "   Check your network connection and try again."
    exit 1
fi

if [ ! -f "$TMP_DIR/aapp" ] || [ ! -d "$TMP_DIR/templates" ]; then
    echo "❌ Error: Upstream repository does not contain valid AAPP files."
    exit 1
fi

echo "🔄 Applying upgrade..."
(
    cd "$TMP_DIR"
    AAPP_SCRIPT_DIR="$TMP_DIR"
    # Run the installer from the temporary clone
    AAPP_IS_DROP_IN=1
    AAPP_VERSION="$(grep -m 1 'AAPP_VERSION=' "$TMP_DIR/aapp" | cut -d'"' -f2)"
    source "$TMP_DIR/lib/cmd_install.sh"
)

NEW_VERSION="$("$HOME/.local/bin/aapp" version 2>/dev/null || echo "v$AAPP_VERSION")"
echo ""
echo "✨ AAPP global tools successfully upgraded ($NEW_VERSION)!"
echo "➡️  Run 'aapp init' inside any project to sync it to the latest protocol."
