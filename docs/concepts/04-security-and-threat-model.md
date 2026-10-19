---
title: Security, Threat Model & Trust Boundaries
description: Collaborative pair-programming trust model, defense-in-depth architecture, shell boundary containment, and structural gates in AAPP.
---

# 🔒 Security, Threat Model & Trust Boundaries

Understanding AAPP's threat model and security boundaries is essential for properly deploying AI coding agents in professional engineering environments.

---

## The Pair-Programming Trust Model

AAPP is designed for **collaborative pair programming** between human developers and frontier AI agents. 
- **The Core Assumption:** The AI agent is aligned and attempting to follow repository guidelines defined in `.agents/AGENTS.md`.
- **The Primary Failure Mode:** Frontier models do not fail out of malicious intent; they fail due to **cognitive drift, context window compaction, overeagerness, and hallucinated scope**. When an agent sees an opportunity to "fix" an adjacent module or add an unrequested helper, it drifts from the human's plan.
- **The Role of Constraints:** AAPP's constraints provide **tactile mechanical friction**. When an agent attempts an unauthorized write, the guard immediately refuses the tool call with deterministic error feedback, stopping silent scope creep and prompting the agent to negotiate with the developer.

---

## Defense-in-Depth Architecture

AAPP implements four concentric layers of governance:

| Layer | Surface | Enforcement Mechanism | Purpose |
| :--- | :--- | :--- | :--- |
| **Layer 0** | **Host / OS Boundary** | Docker, Dev Containers, gVisor, bubblewrap, file permissions | **Adversarial Containment.** Isolates credentials, prevents host escapes, restricts network access. *(Host/container responsibility)* |
| **Layer 1** | **Semantic / Prompt Gate** | `.agents/AGENTS.md`, system rules, Universal Skills | **Instruction Alignment.** Instructs the model on protocol rules, lane separation, and lifecycle gates before any code is generated. |
| **Layer 2** | **Tool Interception** | `.githooks/blast-radius-guard` (`PreToolUse`) | **Pre-Disk Interception.** Intercepts structured tool-writing calls (`Write`, `Edit`, `MultiEdit`) to block file modifications outside `### 📂 Target Files` before touching disk. |
| **Layer 3** | **Commit-Time Boundary** | `.githooks/aapp-pre-commit` | **Immutable Gate.** Authoritative git commit inspection that halts any commit staging undeclared files, locked blueprint sections, or dirty changelogs. |

> [!NOTE]
> **Adopter Responsibility (Layer 0 vs. AAPP Protocol Scope):**
> AAPP provides and automates **Layers 1 through 3** natively within the Git repository. 
> **Layer 0 (Host / OS Boundary)** is external infrastructure that the adopter or organization provisions according to their own threat model (e.g., using Docker, Dev Containers, or sandbox runners). AAPP assumes it is running within an execution environment the adopter has deemed appropriate for agent operation.

---

## Why Shell Access Dictates the Containment Boundary

AI agents require shell execution (`Bash`, `run_command`) to run compilers, linters, and test suites. Because shell commands execute with the developer's process privileges:
- A shell command can execute arbitrary binaries, redirect output (`cat << 'EOF' > ...`), or invoke `git commit --no-verify`.
- Tool-call interception (`PreToolUse`) cannot reliably parse arbitrary bash heredocs or dynamic scripting without becoming a full shell emulator.
- Therefore, **Layer 3 (`pre-commit`) serves as the strict, inescapable boundary for committed history**, while **Layer 0 (Host OS / Container)** remains the only valid boundary for true adversarial process containment.

Attempting to treat Git hooks as a sandboxing hypervisor for untrusted or malicious models is a category error. If you are executing untrusted agent models or running autonomous loops without human oversight, you **must** wrap the agent in a containerized sandbox.

---

## Structural Gates vs. Brittle Client Flags

A critical architectural lesson in AAPP's design is the distinction between **structural verification gates** and **client-specific configuration flags**:
- Relying on client UI flags (such as `disable-model-invocation: true`) to prevent agent overreach often introduces cross-platform fragility (e.g., hiding slash commands in IDE autocompletion) without providing real security.
- True governance comes from **structural protocol gates**: requiring explicit plan arguments, checking task checkboxes, validating the Disjointness Activation Gate, verifying test suite execution, and enforcing pre-commit verification.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
