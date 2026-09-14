# 🐛 Issues: Active Technical Backlog

> **Active Backlog Only:** Every row below is an unresolved defect or gap. When resolved, issues are relocated to `.plans/done/000-issues-archive.md` and pruned from `issues_road_map.md`.

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Medium` | `CORE` | YYYY-MM-DD | `src/core.py:42` | Example issue description stating exact symptom. | Fix in place — no plan needed. | 🟡 `Incubated` |
| #2 | `High` | `CLI` | YYYY-MM-DD | `src/cli.py:110` | Example issue whose fix spans multiple modules. | Promoted: [`current/cli-refactor.md`](current/cli-refactor.md) | 🔵 `Planned` |

---

### 📋 Schema & Metadata Specification

* **`#`**: Numeric identifier prefixed with `#` (e.g. `#1`, `#49`). Use unpadded positive integers.
* **`Sev` (Severity)**: Technical impact:
  - `Critical`: Breaks core runtime, causes data corruption, or bypasses security/write-guards.
  - `High`: Major functionality failure or unexpected crash.
  - `Medium`: Isolated feature failure, CLI ergonomics, portability issue.
  - `Low`: Formatting, cosmetic, or documentation drift.
* **`Type` (Extensible Domain Taxonomy)**: Uppercase token conforming to `^[A-Z0-9_-]+$`.
  - **Recommended Core Vocabulary**:
    - `CORE`: Core execution engine, runtime algorithms, language internals.
    - `CLI`: Command-line interface, argument parsing, terminal output, prompts.
    - `UI`: User interface, web views, components, layout, styling, UX.
    - `DB`: Database, ORM, schemas, migrations, persistent storage.
    - `NET`: Networking, API endpoints, HTTP/gRPC, socket protocols, remote sync.
    - `SEC`: Security, authentication, authorization, write guards, sandboxing.
    - `HOOK`: Git hooks, tool use interceptors, lifecycle plugins.
    - `DOCS`: Documentation, README, user manuals, starter templates.
    - `TEST`: Test suites, regression harnesses, CI/CD pipelines, assertions.
    - `PERF`: Performance, memory leaks, latency, caching, stream buffering.
  - **Extensibility Rule**: Projects may declare custom domain tags (e.g., `ML`, `AUDIO`, `3D`). Linters warn on unknown tokens, never block.
* **`Date`**: Date discovered (`YYYY-MM-DD`).
* **`Location`**: File path and line reference (`path/to/file.ext:123`).
* **`Symptom / Problem`**: Exact defect description (2–3 concise sentences maximum).
* **`Target Plan / Fix`**: Direction of fix, or link to promoted blueprint (`current/plan-<name>.md`).
* **`Status`**: `🟡 Incubated` (recorded, unscheduled) · `🔵 Planned` (promoted to a blueprint) · `🟠 In Progress` (active execution).
  *(Note: `✅ Resolved` does NOT exist in this table; resolved items are relocated to `.plans/done/000-issues-archive.md`).*
