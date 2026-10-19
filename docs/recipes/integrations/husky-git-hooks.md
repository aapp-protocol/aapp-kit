---
title: "Pairing AAPP with Husky"
description: "How to integrate AAPP blast radius and commit verification hooks into projects using Husky."
category: "integrations"
difficulty: "beginner"
tags: [husky, git-hooks, npm, javascript, typescript]
---

# 🍳 Recipe: Pairing AAPP with Husky

## 🎯 Goal
Chain AAPP's authoritative pre-commit and commit-msg verification engines into an existing or new Husky setup without breaking existing JavaScript/TypeScript linting or testing hooks.

## 📋 Prerequisites
- A Node.js repository with Husky installed (`husky` in `devDependencies`).
- AAPP initialized via `aapp init`.
- Existing hooks configured under `.husky/`.

## 🛠️ Step-by-Step Instructions

### 1. Chain the Blast Radius Gate in `pre-commit`
Open `.husky/pre-commit` (or create it with `npx husky add .husky/pre-commit`):
```sh
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# 1. Run AAPP Blast Radius Engine
"$(git rev-parse --show-toplevel)/.githooks/aapp-pre-commit" || exit 1

# 2. Run existing project linters / tests
npx lint-staged
```

### 2. (Optional) Chain Attribution & Conciseness in `commit-msg`
If your project enforces AI attribution trailers or commit message width limits, chain `aapp-commit-msg` in `.husky/commit-msg`:
```sh
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run AAPP Commit Message & AI Attribution Engine
"$(git rev-parse --show-toplevel)/.githooks/aapp-commit-msg" "$1" || exit 1
```

### 3. Verify Hook Execution
Make a test change outside your active plan's declared target files:
```bash
git add package.json
git commit -m "chore: test husky chain"
```
Husky should invoke `.githooks/aapp-pre-commit`, which halts the commit with a Blast Radius Refusal before `lint-staged` runs.

## ⚠️ Critical Invariants & Gotchas
- **Hook Ordering**: Always place the AAPP hook call *before* heavy linters or test runners. AAPP checks are instantaneous (~50ms) and will fail fast before CPU-intensive linters run.
- **Fail-Closed**: Do not append `|| true` to the AAPP invocation. Doing so disables blast-radius safety.
- **Path Resolution**: Use `$(git rev-parse --show-toplevel)/.githooks/...` rather than hardcoding relative paths so commits from subdirectories resolve reliably.

## 🔗 Related References
- 📖 [Technical Manual: Pre-Commit Protection](../../../MANUAL.md#layer-2-authoritative-pre-commit-boundary)
- 🍳 [Recipe: Pairing AAPP with Lefthook](lefthook-git-hooks.md)
- 🍳 [Recipe: CI Blast Radius Gates with GitHub Actions](github-actions-ci.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
