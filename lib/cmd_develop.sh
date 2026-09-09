#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `develop`
#
# Links the active development repository directly into `$HOME/.local/bin/aapp`
# and `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit` via symbolic links.
#
# Allows live testing and editing across the entire system without re-copying files.
# ==============================================================================
set -e

SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit"
BIN_DIR="$HOME/.local/bin"

if [ ! -d "$AAPP_SCRIPT_DIR/templates" ] || [ ! -f "$AAPP_SCRIPT_DIR/templates/pre-commit" ] || [ ! -d "$AAPP_SCRIPT_DIR/lib" ]; then
    echo "❌ Error: AAPP development signatures (templates/ and lib/) not found in '$AAPP_SCRIPT_DIR'."
    echo "   Run 'aapp develop' from the root of an AAPP development repository (e.g., aapp-develop-kit)."
    exit 1
fi

echo "🛠️  Linking AAPP Development Environment (v$AAPP_VERSION)..."
echo "📍 Source Repository: $AAPP_SCRIPT_DIR"

BIN_CREATED=0
[ ! -d "$BIN_DIR" ] && BIN_CREATED=1

mkdir -p "$BIN_DIR" "$(dirname "$SHARE_DIR")"

echo "🔗 Symlinking shared data to $SHARE_DIR..."
rm -rf "$SHARE_DIR"
ln -sf "$AAPP_SCRIPT_DIR" "$SHARE_DIR"

echo "🔧 Symlinking global binary to $BIN_DIR/aapp..."
rm -f "$BIN_DIR/aapp"
ln -sf "$AAPP_SCRIPT_DIR/aapp" "$BIN_DIR/aapp"
chmod +x "$AAPP_SCRIPT_DIR/aapp"

# PATH Configuration & Shell Detection
PATH_OK=0
case ":$PATH:" in
    *":$BIN_DIR:"*) PATH_OK=1 ;;
esac

SHELL_NAME="$(basename "${SHELL:-bash}")"

if [ "$PATH_OK" -eq 1 ]; then
    echo "✅ '$BIN_DIR' is already in your PATH."
elif [ "$BIN_CREATED" -eq 1 ]; then
    echo "ℹ️  Created '$BIN_DIR'. On many systems (Debian/Ubuntu/macOS), logging out and"
    echo "   back in will automatically add it to your PATH."
else
    case "$SHELL_NAME" in
        zsh)  RC_FILE="$HOME/.zshrc" ;;
        fish) RC_FILE="$HOME/.config/fish/config.fish" ;;
        *)    RC_FILE="$HOME/.bashrc" ;;
    esac

    RC_ALREADY_CONFIGURED=0
    if [ -f "$RC_FILE" ] && grep -qs '\.local/bin' "$RC_FILE"; then
        RC_ALREADY_CONFIGURED=1
    elif [ -f "$HOME/.profile" ] && grep -qs '\.local/bin' "$HOME/.profile"; then
        RC_ALREADY_CONFIGURED=1
    fi

    if [ "$RC_ALREADY_CONFIGURED" -eq 1 ]; then
        echo "ℹ️  '$BIN_DIR' is configured in your shell rc ($RC_FILE). Restart your shell or run:"
        echo "     source \"$RC_FILE\""
    elif [ -t 0 ] && [ -f "$RC_FILE" ]; then
        echo ""
        echo "💡 '$BIN_DIR' is not yet in your PATH."
        read -r -p "   Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to $RC_FILE? [y/N] " ADD_PATH_CHOICE
        case "$ADD_PATH_CHOICE" in
            [yY]|[yY][eE][sS])
                echo "" >> "$RC_FILE"
                echo '# Added by AAPP CLI' >> "$RC_FILE"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
                echo "✅ Added '$BIN_DIR' to $RC_FILE."
                echo "   Run 'source $RC_FILE' or start a new terminal session to use 'aapp'."
                ;;
            *)
                echo "ℹ️  Skipped rc edit. You can add it manually:"
                echo '     export PATH="$HOME/.local/bin:$PATH"'
                ;;
        esac
    else
        echo "ℹ️  To use 'aapp' globally, ensure '$BIN_DIR' is in your PATH:"
        echo '     export PATH="$HOME/.local/bin:$PATH"'
    fi
fi

echo ""
echo "✨ AAPP Development Environment Successfully Linked!"
echo "➡️  Binary Symlink:  $BIN_DIR/aapp -> $AAPP_SCRIPT_DIR/aapp"
echo "➡️  Share Symlink:   $SHARE_DIR -> $AAPP_SCRIPT_DIR"
echo ""
echo "Live development mode active — all local edits are immediately testable globally."
