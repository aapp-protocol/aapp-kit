---
title: "Pairing AAPP with Lefthook"
description: "How to integrate AAPP blast radius and commit verification hooks into projects using Lefthook."
category: "integrations"
difficulty: "beginner"
tags: [lefthook, git-hooks, go, fast, polyglot]
---

# 🍳 Recipe: Pairing AAPP with Lefthook

## 🎯 Goal
Configure the fast polyglot hook manager Lefthook to execute AAPP's blast radius and commit verification engines alongside existing project linters and formatters.

## 📋 Prerequisites
- A repository using Lefthook (`lefthook.yml` present).
- AAPP initialized via `aapp init`.

## 🛠️ Step-by-Step Instructions

### 1. Update `lefthook.yml`
Open `lefthook.yml` and add the `aapp-blast-radius` command to your `pre-commit` pipeline:
```yaml
pre-commit:
  parallel: false
  commands:
    01-aapp-blast-radius:
      run: "$(git rev-parse --show-toplevel)/.githooks/aapp-pre-commit"
      fail_text: "AAPP Blast Radius or Changelog verification failed."

    02-lint:
      run: npm run lint
      glob: "*.{js,ts,jsx,tsx}"

commit-msg:
  commands:
    01-aapp-commit-msg:
      run: "$(git rev-parse --show-toplevel)/.githooks/aapp-commit-msg {1}"
```

### 2. Install / Refresh Lefthook Hooks
Run Lefthook's hook installer:
```bash
lefthook install
```

### 3. Test Hook Dispatch
Stage a test change and attempt a commit:
```bash
lefthook run pre-commit
```
Verify that `01-aapp-blast-radius` passes when changes are in-bounds or reports a clear failure when an out-of-bounds file is staged.

## ⚠️ Critical Invariants & Gotchas
- **Execution Order**: Set `parallel: false` or ensure `01-aapp-blast-radius` runs first so out-of-scope changes are aborted before expensive parallel lint suites execute.
- **Fail-Text Clarity**: Provide a descriptive `fail_text` to guide contributors toward inspecting `.plans/current/` when a commit is blocked.

## 🔗 Related References
- 📖 [Technical Manual: Pre-Commit Protection](../../../MANUAL.md#layer-2-authoritative-pre-commit-boundary)
- 🍳 [Recipe: Pairing AAPP with Husky](husky-git-hooks.md)
- 🍳 [Recipe: CI Blast Radius Gates with GitHub Actions](github-actions-ci.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
