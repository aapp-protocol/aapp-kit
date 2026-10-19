#!/usr/bin/env bash
# ==============================================================================
# AAPP Kit on-release Action Delegate Hook (P-59)
#
# Synchronizes AAPP_VERSION in the CLI executable (`aapp`) and advances protocol
# delimiter blocks (`<!-- AAPP-PROTOCOL:START v<version> -->`) across managed
# templates in `templates/` during `aapp release`.
#
# Receives Dual Delivery payload:
#   - POSIX Environment Variables:
#       AAPP_RELEASE_VERSION   (e.g. "v1.2.0")
#       AAPP_RAW_VERSION       (e.g. "1.2.0")
#       AAPP_PREVIOUS_VERSION  (e.g. "1.1.0")
#       AAPP_VERSION_BUMP      (e.g. "minor", "patch", "major", "explicit")
#   - STDIN JSON:
#       {"event":"on-release","tag":"...","rawVersion":"...","version":"...","previousVersion":"...","bump":"..."}
#
# Return code protocol:
#   - 0: Success. Mutations accepted; release continues.
#   - non-zero: Refusal/Failure. Triggers transactional rollback.
# ==============================================================================
set -euo pipefail

# 1. Dual Delivery extraction
STDIN_DATA=""
if [ ! -t 0 ]; then
    STDIN_DATA="$(cat)"
fi

# Dry-run test mode (e.g. `aapp hook-test on-release`)
if printf '%s' "$STDIN_DATA" | grep -q '"test"[[:space:]]*:[[:space:]]*true'; then
    echo "🧪 [kit-on-release] Dry-run mock test detected (test: true). Validating hook syntax and paths."
    exit 0
fi

RAW_VERSION="${AAPP_RAW_VERSION:-}"
if [ -z "$RAW_VERSION" ] && [ -n "$STDIN_DATA" ]; then
    # 1. Try explicit rawVersion (e.g. "rawVersion": "1.2.0")
    RAW_VERSION="$(printf '%s' "$STDIN_DATA" | grep -oE '"rawVersion"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*"rawVersion"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    # 2. Try tag (e.g. "tag": "v1.2.0")
    if [ -z "$RAW_VERSION" ]; then
        local_tag="$(printf '%s' "$STDIN_DATA" | grep -oE '"tag"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*"tag"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
        [ -n "$local_tag" ] && RAW_VERSION="${local_tag#v}"
    fi
    # 3. Try version in data payload
    if [ -z "$RAW_VERSION" ]; then
        data_ver="$(printf '%s' "$STDIN_DATA" | sed -E 's/.*"data"[[:space:]]*:[[:space:]]*\{[^}]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
        if [ -n "$data_ver" ] && [ "$data_ver" != "$STDIN_DATA" ]; then
            RAW_VERSION="${data_ver#v}"
        fi
    fi
fi

if [ -z "$RAW_VERSION" ]; then
    echo "❌ [kit-on-release] Error: Missing AAPP_RAW_VERSION environment variable and stdin JSON payload." >&2
    exit 1
fi

# Sanitize version string (ensure valid version format)
if ! printf '%s' "$RAW_VERSION" | grep -qE '^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$'; then
    echo "❌ [kit-on-release] Error: Invalid version format '$RAW_VERSION'." >&2
    exit 1
fi
RAW_VERSION="${RAW_VERSION#v}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 2. Update CLI Executable (`aapp`)
CLI_FILE="$REPO_ROOT/aapp"
if [ -f "$CLI_FILE" ]; then
    sed -i -E "s/^AAPP_VERSION=\".*\"/AAPP_VERSION=\"$RAW_VERSION\"/" "$CLI_FILE"
    if ! grep -q "^AAPP_VERSION=\"$RAW_VERSION\"" "$CLI_FILE"; then
        echo "❌ [kit-on-release] Failed to update AAPP_VERSION in $CLI_FILE" >&2
        exit 1
    fi
    echo "✔ [kit-on-release] Updated AAPP_VERSION to $RAW_VERSION in $CLI_FILE"
fi

# 3. Update managed templates
TEMPLATES_DIR="$REPO_ROOT/templates"
if [ -d "$TEMPLATES_DIR" ]; then
    UPDATED_COUNT=0
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        sed -i -E "s/<!-- AAPP-PROTOCOL:START v[0-9]+\.[0-9]+(\.[0-9]+)?.* -->/<!-- AAPP-PROTOCOL:START v$RAW_VERSION -->/" "$f"
        if ! grep -q "<!-- AAPP-PROTOCOL:START v$RAW_VERSION -->" "$f"; then
            echo "❌ [kit-on-release] Failed to verify protocol version update in $f" >&2
            exit 1
        fi
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    done < <(grep -l "<!-- AAPP-PROTOCOL:START" "$TEMPLATES_DIR"/* 2>/dev/null || true)
    echo "✔ [kit-on-release] Updated protocol version to v$RAW_VERSION in $UPDATED_COUNT template(s)"
fi

exit 0
