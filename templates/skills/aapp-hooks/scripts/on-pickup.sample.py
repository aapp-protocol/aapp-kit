#!/usr/bin/env python3
"""Sample AAPP Hook: `on-pickup` (Python)

Triggered when a new idea is added to .plans/pickup.md or via /pickup.
Demonstrates parsing the structured JSON envelope from STDIN.
"""
import json
import sys

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            print("ℹ️  [on-pickup] Empty payload received.", file=sys.stderr)
            return 0

        payload = json.loads(raw_input)
        event = payload.get("event", "on-pickup")
        data = payload.get("data", {})
        idea_text = data.get("raw_text", "unspecified idea")
        actor = payload.get("actor", "developer")

        print(f"💡 [Sample on-pickup Hook] New intake captured by {actor}: '{idea_text}'")
        # Here an adopter could send a message to Slack, Discord, or Jira.
        return 0
    except Exception as e:
        print(f"⚠️  [on-pickup Error] {e}", file=sys.stderr)
        # Return 0 or 2 so notification failure never blocks the developer
        return 0

if __name__ == "__main__":
    sys.exit(main())
