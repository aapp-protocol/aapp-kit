---
title: "Failure-First TDD Workflows (`aapp tdd`)"
description: "How to declare failure-first assertions in your plan blueprint, verify red test execution, and implement clean green solutions."
category: "workflows"
difficulty: "intermediate"
tags: [tdd, testing, quality, test-driven-development, validation]
---

# 🍳 Recipe: Failure-First TDD Workflows (`aapp tdd`)

## 🎯 Goal
Execute a strict Test-Driven Development (TDD) cycle within AAPP: register failing test identifiers in Section 3 of your blueprint before freeze, verify that tests fail cleanly for the expected reason (Red phase), implement code changes within target files, and verify passing assertions (Green phase).

## 📋 Prerequisites
- A plan in `📝 Refining` status.
- A test suite or runner configured in your project (e.g. `npm test`, `pytest`, `cargo test`, or `./aapp test`).

## 🛠️ Step-by-Step Instructions

### 1. Declare Failing Tests in Blueprint
Before freezing your blueprint, declare your planned test identifiers and test files using the TDD helper:
```bash
aapp tdd P-1 "test_invalid_token_rejected" "test_expired_session_cleared" test tests/auth_test.ts
```
This updates Section 3 and Section 4 of `.plans/current/P1-*.md` with explicit failure-first criteria:
```markdown
### 🧪 Planned Test Identifiers (Failure-First)
- [ ] `test_invalid_token_rejected` (tests/auth_test.ts)
- [ ] `test_expired_session_cleared` (tests/auth_test.ts)
```

### 2. Freeze and Activate the Blueprint
Lock the blueprint and start implementation in its worktree:
```bash
aapp freeze P-1
aapp start P-1
cd .workspace/P1
```

### 3. Write the Failing Test Assertions (Red Phase)
Author the test cases in the declared test file (`tests/auth_test.ts`). Run your test runner:
```bash
npm test
```
Verify that the tests fail **strictly because the feature is not yet built**, and not due to syntax errors or compilation failures.

### 4. Implement Code Changes (Green Phase)
Implement the minimum code necessary in the files declared in `### 📂 Target Files`.
Run tests again:
```bash
npm test
```
Verify all assertions pass cleanly.

### 5. Commit and Record Progress
Check off the test items in Section 3 of the blueprint and commit:
```bash
aapp commit "feat(auth): implement token rejection and session cleanup"
```

## ⚠️ Critical Invariants & Gotchas
- **Target Files Coverage**: Test files modified during TDD *must* be declared in `### 📂 Target Files`. The write-guard will reject writes to undeclared test files.
- **Fail First**: Never write implementation code before observing your test fail. A test that passes without code changes validates nothing.
- **Design Lock**: You can check off `- [x]` test checkboxes in Section 3 of a frozen plan freely, but cannot add new test files to Section 4 without unfreezing.

## 🔗 Related References
- 📖 [Technical Manual: The TDD Skill (`aapp tdd`)](../../../MANUAL.md#tdd-failure-first-assertions-aapp-tdd)
- 🍳 [Recipe: Solo Developer Workflow](../getting-started/solo-developer-workflow.md)
- 🍳 [Recipe: Multi-Agent Worktrees](multi-agent-worktrees.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
