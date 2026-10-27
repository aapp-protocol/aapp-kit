# 🤝 Contributing to AAPP

The kit is developed with its own protocol: every change is a plan or a logged issue, made inside a locked Blast Radius and committed with `aapp commit`. This page gets you from a clone to a reviewed change.

---

## 1. Set Up a Development Clone

Requirements: Git, Bash, Perl 5.26 or later.

```bash
git clone https://github.com/aapp-protocol/aapp-kit.git aapp-develop-kit
cd aapp-develop-kit
./aapp develop
```

`aapp develop` makes your clone the installed kit: it links `~/.local/bin/aapp` and `${XDG_DATA_HOME:-~/.local/share}/aapp-kit` to the clone, so every edit to `lib/`, `templates/` and the hooks is live at once in every repository on your machine. It offers to add `~/.local/bin` to your `PATH` when it is missing.

Keep the clone's folder name `aapp-develop-kit` (or `agent-planning-kit`). `aapp install` treats the folder it runs from as a temporary download and deletes it afterwards, except a folder with one of these names, a linked worktree, or a folder holding files beyond the kit's own.

To go back to a normal install, run `./aapp install` from a fresh clone, which replaces the links with copies; `aapp uninstall` removes the kit.

The clone itself uses the kit: run `aapp init` once in it, then `/aapp` (or `aapp status`) at the start of each session.

---

## 2. Run the Tests

Two suites run before every commit, and both must be green:

| Command | Runs |
| :--- | :--- |
| `t/test-run` | The Perl test files: `t/core/*.t` (core modules) and `t/verb/*.t` (verbs). `t/test-run help` lists selectors and modifiers; one file alone: `prove -l t/core/output.t`. |
| `./aapp test` | The bash verb suites in `tests/verbs/`, until the Perl port replaces them. `aapp help test` lists modifiers. |

Add `strict` to either for fail-closed sandbox containment, and `quiet` for one line per file. Every test is named by a contract: core modules in `lib/docs/core/<name>.md`, verbs in `lib/docs/verbs/<verb>.md`. A behaviour change updates the contract and its test together.

**Tests never touch your repository.** Each run builds a sandbox under the system's temporary folder: a disposable home with the kit installed as an install would ship it, and fixture repositories copied per test. `HOME` and the XDG folders point into it and the system Git config is ignored; your Git name and email are copied in, with commit and tag signing off, so tests run headless on any machine. A test process that hangs is stopped with its whole process group. With `strict`, a test whose working repository is not inside the sandbox fails at once.

---

## 3. How a Change Is Made

- **A new capability or a refactor** is a plan: `aapp draft <slug>` (or `/aapp-plan`), refined until it has no open questions, then `aapp freeze-start <id>`. Work happens in the plan's worktree, inside its Target Files; commit with `aapp commit "<msg>"`; archive with `aapp done <id>`. Lifecycle: [01. Lifecycle State Machine](docs/reference/01-lifecycle-state-machine.md).
- **A bug** is an issue first: `aapp issue log <sev> <type> "<symptom>" file <path>`. A small fix is made through `aapp issue fix <num>` once a maintainer queues it; a larger one is promoted to a plan. Lanes: [03. Two-Lane Governance](docs/concepts/03-two-lane-governance.md).
- **Several plans for one feature** form a group with an amendments member: [Planning a Plan Group](docs/recipes/workflows/planning-a-plan-group.md), [16. Group Amendments](docs/reference/16-group-amendments.md).

Every code commit is covered by `CHANGELOG.md` (one entry per plan, declared in its header), and agent commits carry the attribution the repository asks for ([05. AI Attribution](docs/reference/05-ai-attribution-and-notes.md)).

---

## 4. Where the Conventions Are

| File | What it holds |
| :--- | :--- |
| `.agents/PROJECT.MD` | Code style, dependencies, error handling, testing and documentation rules for this repository |
| `.agents/AGENTS.md` | The protocol rules every session (person or agent) follows |
| `.agents/CODEMAP.md` | Which module owns which concern |
| `ARCHITECTURE.md` | How the parts fit together |
| `lib/docs/verbs/`, `lib/docs/core/` | The contract of each verb and core module |

User-facing changes update the docs listed in `.agents/PROJECT.MD` §6 in the same plan.

---

## 5. Reporting

- **A bug:** open a GitHub issue with the command, its full output, `aapp version` and your platform.
- **A platform result**, pass or fail: see [19. Platform Verification](docs/reference/19-platform-verification.md#3-how-to-report). A "works on my machine" report is as useful as a failure.

---

## 🧭 Continuous Navigation
- 🏠 [Repository Overview](README.md)
- 📖 [Technical Manual](MANUAL.md)
- 💻 [CLI Verb Reference](docs/reference/02-cli-commands-and-verbs.md)
