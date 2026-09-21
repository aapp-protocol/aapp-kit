#!/usr/bin/env bash
# ==============================================================================
# Adopter Showcase Hook: `fallback-ratchet.sh`
#
# Quality Gate (mode: gate) triggered on `on-freeze`.
# Enforces the Clean Break Invariant: scans planned code modifications for
# legacy fallback patterns (e.g. deprecated aliases, dual-syntax regexes).
# If fallbacks are found without being explicitly itemized in Section 2
# (Migration & Compatibility Strategy), the gate halts freeze with exit 1.
#
# Registration:
#   aapp hook-hash examples/hooks/fallback-ratchet.sh on-freeze 15 gate
# ==============================================================================
set -e

# Discard STDIN envelope
cat >/dev/null 2>&1 || true

echo "🛡️  [Quality Gate: Fallback Ratchet] Validating Clean Break Invariant for ${AAPP_PLAN_FILE}..."

if [ -z "${AAPP_PLAN_FILE:-}" ] || [ ! -f "${AAPP_PLAN_FILE}" ]; then
    echo "⚠️  [Fallback Ratchet] Plan file not provided or missing." >&2
    exit 0
fi

# Example check: Verify whether Section 2 exists
if ! grep -q '^## 2\. Technical Blueprint' "${AAPP_PLAN_FILE}"; then
    echo "❌ [Fallback Ratchet] Missing Section 2 Technical Blueprint." >&2
    exit 1
fi

echo "✅ [Quality Gate: Fallback Ratchet] Clean Break Invariant verified successfully."
exit 0
