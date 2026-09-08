#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `install`
#
# Installs `aapp` binary to `$HOME/.local/bin/` and copies `lib/`, `templates/`,
# and `tests/` to `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/`.
# ==============================================================================
set -e

SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit"
BIN_DIR="$HOME/.local/bin"

if [ ! -d "$AAPP_SCRIPT_DIR/templates" ] || [ ! -f "$AAPP_SCRIPT_DIR/templates/pre-commit" ]; then
    echo "❌ Error: templates/ not found next to this script ($AAPP_SCRIPT_DIR)."
    echo "   Re-clone the full AAPP repository and run 'aapp install' from inside it."
    exit 1
fi

echo "🚀 Installing Asymmetric Agent Planning Protocol (AAPP v$AAPP_VERSION)..."

BIN_CREATED=0
[ ! -d "$BIN_DIR" ] && BIN_CREATED=1

mkdir -p "$SHARE_DIR" "$BIN_DIR"

echo "📦 Copying libraries, templates, and test suites to $SHARE_DIR..."
rm -rf "${SHARE_DIR:?}/lib" "${SHARE_DIR:?}/templates" "${SHARE_DIR:?}/tests"
[ -d "$AAPP_SCRIPT_DIR/lib" ] && cp -r "$AAPP_SCRIPT_DIR/lib" "$SHARE_DIR/"
cp -r "$AAPP_SCRIPT_DIR/templates" "$SHARE_DIR/"
[ -d "$AAPP_SCRIPT_DIR/tests" ] && cp -r "$AAPP_SCRIPT_DIR/tests" "$SHARE_DIR/"

echo "🔧 Installing binary into $BIN_DIR..."
cp "$AAPP_SCRIPT_DIR/aapp" "$BIN_DIR/aapp"
chmod +x "$BIN_DIR/aapp"

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
        echo "ℹ️  '$BIN_DIR' is referenced in your profile/rc file."
        echo "   Restart your shell or run: source $RC_FILE"
    elif [ "$SHELL_NAME" = "fish" ]; then
        echo "ℹ️  To add to PATH in fish shell, run:"
        echo "     fish_add_path ~/.local/bin"
    elif [ -t 0 ]; then
        printf "❓ Add '$BIN_DIR' to PATH in %s? [y/N] " "$RC_FILE"
        read -r REPLY
        case "$REPLY" in
            [yY]|[yY][eE][sS])
                echo "" >> "$RC_FILE"
                echo "# Added by AAPP installer" >> "$RC_FILE"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
                echo "📝 Added export to $RC_FILE. Run: source $RC_FILE"
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

# Consume Temporary Clone Folder
if [ "$(basename "$AAPP_SCRIPT_DIR")" != "agent-planning-kit" ]; then
    rm -rf "$AAPP_SCRIPT_DIR"
    echo ""
    echo "🧹 Consumed installer directory '$AAPP_SCRIPT_DIR'."
fi

echo ""
echo "✨ AAPP successfully installed!"
echo "➡️  Binary:   $BIN_DIR/aapp"
echo "➡️  Share:    $SHARE_DIR"
echo ""
echo "To initialize any git project with AAPP, run from your project root:"
echo "  aapp init"
