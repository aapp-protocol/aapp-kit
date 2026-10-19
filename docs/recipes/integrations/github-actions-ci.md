---
title: "CI Blast Radius Gates with GitHub Actions"
description: "How to enforce AAPP blast radius boundaries, planning health, and commit attribution in GitHub Actions CI."
category: "integrations"
difficulty: "intermediate"
tags: [ci, github-actions, continuous-integration, blast-radius]
---

# 🍳 Recipe: CI Blast Radius Gates with GitHub Actions

## 🎯 Goal
Implement a server-side CI workflow in GitHub Actions that automatically verifies planning health, prevents unreleased/out-of-bounds commits from merging, and rejects machine-specific paths (`"file:""///"`) in pull requests.

## 📋 Prerequisites
- A GitHub repository with AAPP initialized.
- GitHub Actions enabled on the repository.

## 🛠️ Step-by-Step Instructions

### 1. Create the Workflow File
Create `.github/workflows/aapp-verify.yml`:
```yaml
name: AAPP Protocol & Planning Health Gate

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  aapp-verification:
    name: Verify Planning Invariants
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Mount Isolated Worktrees (if applicable)
        run: |
          if git show-ref --quiet refs/heads/plans; then
            git worktree add .plans plans || true
          fi
          if git show-ref --quiet refs/heads/agents; then
            git worktree add .agents agents || true
          fi

      - name: Verify No Machine-Specific Paths or URIs
        run: |
          echo "Scanning for illegal "file:""///" URIs..."
          if grep -rn ""file:""///"" --exclude-dir=".git" --exclude-dir=".workspace" .; then
            echo "❌ ERROR: Detected machine-specific "file:""///" URIs in tracked files."
            exit 1
          fi

      - name: Run Planning Health Audit
        run: |
          chmod +x ./aapp
          ./aapp status
          ./aapp matrix --check

      - name: Run Shipped Test Suites
        run: |
          ./aapp test strict quiet
```

### 2. Configure PR Protection Rules
In GitHub repository settings under **Branches** -> **Branch protection rules**:
1. Require status check to pass before merging: check `Verify Planning Invariants`.
2. Require linear commit history (optional, recommended for clean atomic plans).

### 3. Verify in a Pull Request
Open a test pull request. Observe that GitHub Actions runs the verification suite, ensuring that the state matrix matches plan statuses and no out-of-bounds commits or machine-specific links exist.

## ⚠️ Critical Invariants & Gotchas
- **Full History Fetch**: `actions/checkout` must specify `fetch-depth: 0` so that `git merge-base` and tag reachability checks have access to full commit history.
- **Fail-Closed**: Always keep CI checks fail-closed. Never allow PRs with failing planning health to bypass branch protection.

## 🔗 Related References
- 📖 [Technical Manual: Planning Health Engine](../../../MANUAL.md#7-pair-planning-health-engine)
- 🍳 [Recipe: Pairing AAPP with Husky](husky-git-hooks.md)
- 🍳 [Recipe: Pairing AAPP with Lefthook](lefthook-git-hooks.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
