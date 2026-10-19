---
title: "GitHub Issues Tracker Provider Plugin"
description: "How to connect AAPP's issue lane to GitHub Issues using the issue tracker provider plugin protocol."
category: "plugins-and-hooks"
difficulty: "advanced"
tags: [plugins, issue-tracker, github, gh-cli, integration]
---

# 🍳 Recipe: GitHub Issues Tracker Provider Plugin

## 🎯 Goal
Connect AAPP's Issue Lane commands (`aapp issue log`, `aapp issue queue`, `aapp issue close`, `aapp issue list`) to GitHub Issues via the GitHub CLI (`gh`), creating and updating remote issues while maintaining local planning ledger synchronization.

## 📋 Prerequisites
- GitHub CLI (`gh`) installed and authenticated (`gh auth status`).
- A repository with AAPP initialized.
- A remote GitHub repository linked as `origin`.

## 🛠️ Step-by-Step Instructions

### 1. Scaffold the Provider Plugin Directory
The issue tracker provider uses a reserved canonical plugin location:
```bash
mkdir -p .agents/skills/aapp-issue-tracker
```

### 2. Author the Provider Handler (`run`)
Create `.agents/skills/aapp-issue-tracker/run`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Read event payload from STDIN
INPUT_PAYLOAD=$(cat)
EVENT=$(echo "$INPUT_PAYLOAD" | jq -r '.event // empty' 2>/dev/null || echo "")

case "$EVENT" in
  "issue.log")
    # Extract issue details
    SEV=$(echo "$INPUT_PAYLOAD" | jq -r '.data.severity // "normal"')
    TYPE=$(echo "$INPUT_PAYLOAD" | jq -r '.data.type // "BUG"')
    SYMPTOM=$(echo "$INPUT_PAYLOAD" | jq -r '.data.symptom // "Unspecified issue"')
    NOTE=$(echo "$INPUT_PAYLOAD" | jq -r '.data.note // ""')

    BODY="**Severity**: $SEV\n**Type**: $TYPE\n\n$NOTE"

    # Create issue via GitHub CLI
    GH_OUT=$(gh issue create --title "[$TYPE] $SYMPTOM" --body "$BODY" --label "aapp,sev:$SEV" 2>/dev/null)
    ISSUE_NUM=$(echo "$GH_OUT" | grep -o '[0-9]*$')
    ISSUE_URL="$GH_OUT"

    # Emit JSON response on STDOUT
    echo "{\"status\": \"ok\", \"id\": \"#$ISSUE_NUM\", \"url\": \"$ISSUE_URL\"}"
    ;;

  "issue.queue")
    ID=$(echo "$INPUT_PAYLOAD" | jq -r '.data.id // empty' | tr -d '#')
    PRIORITY=$(echo "$INPUT_PAYLOAD" | jq -r '.data.priority // "normal"')

    if [ -n "$ID" ]; then
      gh issue edit "$ID" --add-label "queued:$PRIORITY" >/dev/null 2>&1 || true
    fi
    echo '{"status": "ok"}'
    ;;

  "issue.close")
    ID=$(echo "$INPUT_PAYLOAD" | jq -r '.data.id // empty' | tr -d '#')
    REASON=$(echo "$INPUT_PAYLOAD" | jq -r '.data.reason // "completed"')

    if [ -n "$ID" ]; then
      gh issue close "$ID" --comment "Resolved via AAPP ($REASON)" >/dev/null 2>&1 || true
    fi
    echo '{"status": "ok"}'
    ;;

  "issue.list")
    # Return remote issues for synchronization
    ISSUES_JSON=$(gh issue list --json number,title,labels,state --limit 30 2>/dev/null || echo "[]")
    echo "{\"status\": \"ok\", \"issues\": $ISSUES_JSON}"
    ;;

  *)
    # Graceful decline: kit handles unhandled operations with local ledger
    echo '{"status": "declined"}'
    ;;
esac
```

Make the script executable:
```bash
chmod +x .agents/skills/aapp-issue-tracker/run
```

### 3. Test the Provider
Log an issue using the standard AAPP CLI:
```bash
aapp issue log normal BUG "Navbar collapses unexpectedly on mobile" note "Tested on Safari iOS 17"
```
AAPP dispatches `issue.log` to `.agents/skills/aapp-issue-tracker/run`, which creates the issue on GitHub and records `#<num>` in `.plans/ISSUES.md`.

## ⚠️ Critical Invariants & Gotchas
- **Zero Credentials on STDIN**: AAPP never transmits credentials, tokens, or private secrets in the JSON envelope. The provider plugin relies strictly on the ambient environment (`gh auth` or `$GITHUB_TOKEN`).
- **Standard JSON on STDOUT**: The provider must output clean, single-line or valid formatted JSON on STDOUT. Diagnostic logging must be redirected to `stderr` (`>&2`).
- **Decline Unhandled Events**: If the plugin does not implement an optional event, always return `{"status": "declined"}` so AAPP falls back to local ledger logic seamlessly.
- **Section 2 Self-Protection**: Files inside `.agents/skills/aapp-*` are protected against arbitrary modifications by AI agents.

## 🔗 Related References
- 📖 [Technical Manual: Issue Tracker Integration](../../../MANUAL.md#external-issue-tracker-provider-plugins)
- 🍳 [Recipe: Authoring Custom Action Plugins](04-authoring-custom-action-plugins.md)
- 🍳 [Recipe: Solo Developer Workflow](../getting-started/solo-developer-workflow.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
