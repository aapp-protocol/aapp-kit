# Project Rules: [Project Name]

How we build here. Agents read this before writing code; humans keep it true.
`CODEMAP.md` says **what exists** and how it is called; this file says **how to build**.
Try to keep each rule in one place only. The sections below are a starting point — adapt them to
your needs and your project's particulars.

---

## 🧭 1. Project Summary
- **What it does:** [one or two sentences]
- **Stack:** [languages, runtime versions, frameworks]
- **Build & run:** [the commands]

## ✍️ 2. Code Style & Conventions
- **Formatting / linting:** [tool and config, e.g. `prettier`, `perltidy -pbp`, `shellcheck`]
- **Naming:** [files, functions, variables, constants]
- **Structure:** [where new modules go; one concern per file; …]
- **Comments:** [when and how much]

## 📦 3. Libraries & Dependencies
- **Use:** [approved libraries for common needs — HTTP, JSON, dates, logging, …]
- **Avoid:** [libraries or patterns not wanted here, and why]
- **Adding a dependency:** [who approves; pinning policy]

## 🚨 4. Error Handling
- **Policy:** [exceptions / Result types / exit codes; fail closed or fail open, and when]
- **Messages:** [where diagnostics go — stderr, logs; format]
- **Never:** [e.g. silent fallbacks, empty catch blocks]

Per-module error contracts (which errors or exit codes a module produces) live in `CODEMAP.md`.

## 🧪 5. Testing
- **Framework & location:** [e.g. `tests/`, `pytest`, `prove -r t/`]
- **Run:** [the exact command]
- **Expectations:** [failure-first tests for new behaviour (`aapp tdd`); what must be covered]

## 📚 6. Documentation — Where & When
- **User & operator docs:** [e.g. `README.md`, `MANUAL.md`, `docs/`]
- **Developer reference:** [e.g. `docs/api/`, docstrings, POD]
- **Update when:** a change alters user-facing behaviour, commands or options, configuration, or
  workflows.
