#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `install`
#
# Installs `aapp` binary to `$HOME/.local/bin/` and copies `lib/`, `templates/`,
# and `tests/` to `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/`.
# ==============================================================================
set -e

KEEP_KIT="${AAPP_KEEP_KIT:-0}"
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: aapp install [--keep|-k]"
            echo ""
            echo "Installs AAPP globally into ~/.local/bin and ~/.local/share/aapp-kit."
            echo ""
            echo "Options:"
            echo "  --keep, -k    Preserve installer directory without self-consuming"
            echo "  --help, -h    Show this help message"
            return 0 2>/dev/null || exit 0
            ;;
        --keep|-k)
            KEEP_KIT=1
            ;;
    esac
done

SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit"
BIN_DIR="$HOME/.local/bin"

if ! declare -f is_safe_to_consume_kit_dir >/dev/null 2>&1; then
    is_safe_to_consume_kit_dir() {
        local dir="$1"
        local keep="${2:-0}"
        [ "$keep" -eq 1 ] && return 1
        [ ! -d "$dir" ] && return 1
        case "$(basename "$dir")" in
            aapp-develop-kit|agent-planning-kit) return 1 ;;
        esac
        if ! declare -f has_kit_signature >/dev/null 2>&1; then
            has_kit_signature() {
                local d="$1"
                [ -d "$d/templates" ] && [ -f "$d/templates/pre-commit" ] && \
                [ -f "$d/templates/AGENTS.md" ] && [ -d "$d/lib" ] && [ -f "$d/lib/cmd_init.sh" ]
            }
        fi
        ! has_kit_signature "$dir" && return 1
        local item base
        for item in "$dir"/* "$dir"/.*; do
            [ ! -e "$item" ] && [ ! -L "$item" ] && continue
            base="$(basename "$item")"
            case "$base" in
                .|..) continue ;;
                aapp|lib|templates|tests|examples|scripts) continue ;;
                README*|MANUAL*|CHEATSHEET*|CHANGELOG*|LICENSE*|COPYING*|CODEMAP*|ARCHITECTURE*) continue ;;
                .git*|.agents|.plans|.githooks|.claude|.cursor|.gemini|.github) continue ;;
                *) return 1 ;;
            esac
        done
        if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local git_status
            git_status="$(git -C "$dir" status --porcelain 2>/dev/null || true)"
            [ -n "$git_status" ] && return 1
        fi
        return 0
    }
fi

if [ ! -d "$AAPP_SCRIPT_DIR/templates" ] || [ ! -f "$AAPP_SCRIPT_DIR/templates/pre-commit" ]; then
    echo "❌ Error: templates/ not found next to this script ($AAPP_SCRIPT_DIR)."
    echo "   Re-clone the full AAPP repository and run 'aapp install' from inside it."
    exit 1
fi

echo "🚀 Installing Asymmetric Agent Planning Protocol (AAPP v$AAPP_VERSION)..."

BIN_CREATED=0
[ ! -d "$BIN_DIR" ] && BIN_CREATED=1

# If previously linked via 'aapp develop', unlink symlinks first to prevent traversing into source repo
[ -L "$SHARE_DIR" ] && rm -f "$SHARE_DIR"
[ -L "$BIN_DIR/aapp" ] && rm -f "$BIN_DIR/aapp"

mkdir -p "$SHARE_DIR" "$BIN_DIR"

echo "📦 Copying libraries, templates, and test suites to $SHARE_DIR..."
rm -rf "${SHARE_DIR:?}/lib" "${SHARE_DIR:?}/templates" "${SHARE_DIR:?}/tests"
[ -d "$AAPP_SCRIPT_DIR/lib" ] && cp -r "$AAPP_SCRIPT_DIR/lib" "$SHARE_DIR/"
cp -r "$AAPP_SCRIPT_DIR/templates" "$SHARE_DIR/"
[ -d "$AAPP_SCRIPT_DIR/tests" ] && cp -r "$AAPP_SCRIPT_DIR/tests" "$SHARE_DIR/"
chmod +x "$SHARE_DIR"/templates/* "$SHARE_DIR"/lib/*.sh 2>/dev/null || true

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
if [ "${AAPP_IS_UPGRADE:-0}" -ne 1 ]; then
    if [ "$KEEP_KIT" -eq 1 ]; then
        echo ""
        echo "ℹ️  Preserved installer directory '$AAPP_SCRIPT_DIR' (--keep)."
    elif is_safe_to_consume_kit_dir "$AAPP_SCRIPT_DIR" 0; then
        rm -rf "$AAPP_SCRIPT_DIR"
        echo ""
        echo "🧹 Consumed installer directory '$AAPP_SCRIPT_DIR'."
    else
        case "$(basename "$AAPP_SCRIPT_DIR")" in
            aapp-develop-kit|agent-planning-kit)
                # Development workspace: do not self-consume
                ;;
            *)
                echo ""
                echo "ℹ️  Preserved installer directory '$AAPP_SCRIPT_DIR' (contains files or modifications beyond kit signature)."
                ;;
        esac
    fi
fi

echo ""
echo "✨ AAPP successfully installed!"
echo "➡️  Binary:   $BIN_DIR/aapp"
echo "➡️  Share:    $SHARE_DIR"
echo ""
echo "To initialize any git project with AAPP, run from your project root:"
echo "  aapp init"
