#!/usr/bin/env bash
# ==============================================================================
# Sample AAPP Hook: `on-done`
#
# Triggered when an implementation plan is archived to done/.
# Demonstrates Dual Delivery: uses exported environment variables ($AAPP_PLAN_FILE)
# while optionally reading the complete JSON envelope from stdin.
# ==============================================================================
set -e

# Read JSON payload from STDIN (optional)
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD="$(cat)"
fi

echo "🎉 [Sample on-done Hook] Plan completion observed!"
echo "   Event     : ${AAPP_EVENT:-on-done}"
echo "   Plan ID   : ${AAPP_PLAN_ID:-unknown}"
echo "   Plan File : ${AAPP_PLAN_FILE:-unknown}"
echo "   Actor     : ${AAPP_ACTOR:-developer}"

# Example: Append completion event to an audit log
AUDIT_LOG="audit.log"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
echo "$TIMESTAMP | DONE | Plan: ${AAPP_PLAN_ID} | File: ${AAPP_PLAN_FILE}" >> "$AUDIT_LOG"

exit 0
