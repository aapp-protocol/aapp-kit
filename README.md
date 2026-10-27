# 🤖 Asymmetric Agent Planning Protocol (AAPP)

> A planning and guard kit for working with AI coding agents. It aims to keep an agent's changes inside the plan you agreed on, and to keep the planning itself out of your code history.

Plans, agent rules and Git hooks live in their own Git worktrees on orphan branches (`.plans/`, `.agents/`, `.githooks/`). Your code branches carry your code. A plan names the files it may change, its **Blast Radius**, and the kit checks edits and commits against that list.

```text
your-repo/ (main/dev branch)
├── .plans/    --> orphan branch 'plans'    (blueprints, issues, decisions)
├── .agents/   --> orphan branch 'agents'   (rules, codemap, skills)
└── .githooks/ --> orphan branch 'githooks' (blast-radius guard, pre-commit)
```

---

## 🎯 Why

Working with an agent through chat alone tends to drift:
* the agent touches files nobody asked about, or rewrites code that worked;
* plans and notes end up in chat logs or code commits, and are lost or in the way;
* a new session starts without knowing what was decided or what is half done.

AAPP keeps the plan in a file both of you can read, gives it a file list the tools can check, and gives every session the same briefing.

It works like a spec-first workflow and adds two things: checks that hold the agent to the plan's files, and a record of plans, issues and decisions kept beside the code, not in its history. Archived plans stay searchable, so you can look up later why something was built the way it was.

### When it fits

The kit trades some speed for predictability. That trade pays off for:
* solo developers and small teams who write the spec first and hand the work to agents;
* long-lived code where a stray change costs more than the time spent planning;
* work that spans many sessions, branches, or more than one agent.

It is not a good fit for weekend projects, quick prototypes or throwaway experiments: drafting, freezing and closing plans is overhead there that does not pay back.

---

## ⚡ What the Kit Does

* 🗺️ **Plans before code**: an idea becomes a blueprint in `.plans/current/`. You review and refine it, then freeze its design and file list before any code is written.
* 🛡️ **Blast Radius checks**: an agent's write tools are checked against the plan's `### 📂 Target Files`, and the pre-commit hook refuses staged files outside them. Drift can still happen; the checks are there to catch it early.
* 🐛 **Two lanes**: bugs go to an issue ledger (`ISSUES.md`), new work goes to plans. A small fix runs as a mini plan in its own worktree; a large one is promoted to a full plan.
* 🌳 **A worktree per plan**: with `aapp.planWorktrees = on`, each plan gets its own branch and checkout under `.workspace/`, and `aapp done` lands it as one commit.
* 🧩 **Plan groups**: a feature that needs several plans shares one goal and one feature branch; each member lands there, and the group lands on its parent branch.
* 🧭 **Session briefing**: `aapp status` shows what shipped, the issue queue, open plans and unworked ideas, so a new session or a returning developer can pick up where things stand.
* 📝 **Changelog with every change**: a plan declares its changelog line up front, and `aapp commit` writes it on the plan's first commit.
* 🔍 **Honest attribution**: optional emailless trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) or private Git notes record which agent helped. Off by default.

---

## 🔧 Git Plumbing You Get Along the Way

The kit is built on plain Git features, and they stay useful on their own:

* **Orphan branches as worktrees**: `plans`, `agents` and `githooks` share no history with your code. Switching, rebasing or merging code branches never touches your plans.
* **Versioned hooks**: `aapp init` sets `core.hooksPath` to `.githooks`, so the hooks are tracked and shared like any other branch.
* **Safe sync**: `aapp push`, `aapp pull` (`--ff-only` by default) and `aapp sync` move all three worktrees in one step.
* **Named stashes**: `aapp pause` sets in-flight work aside in every worktree as named stashes; `aapp resume` restores it.
* **Notes that survive rewrites**: `aapp note` sets `notes.rewriteRef` so notes in `refs/notes/commits` and `refs/notes/ai` follow amends and rebases.
* **Rebase, not merge**: plan branches take fixes with `git rebase --autostash <parent>`, which keeps their history linear.

---

## 🚀 Quick Start

### 1. Install (no root needed)
```bash
git clone https://github.com/aapp-protocol/aapp-kit.git
./aapp-kit/aapp install
```
`aapp` goes to `~/.local/bin`, its files to `~/.local/share/aapp-kit/`.

### 2. Enable in a repository
```bash
cd your-project
aapp init
```

### 3. First session
In your agent's chat (Claude Code, Antigravity):
```text
/aapp
/aapp-digest Onboarding
```
`/aapp` loads the rules and prints the briefing. The Onboarding plan maps your project into `.agents/CODEMAP.md` and `ARCHITECTURE.md`; its Blast Radius covers only those files.

The whole path, for an existing repository, a clone of a repository that already uses AAPP, existing hook managers and upgrades: [Adopting an Existing Repository](docs/recipes/getting-started/adopt-existing-repo.md). Every setting: [Configuration Reference](docs/reference/03-configuration-matrix.md).

---

## 🔄 The Plan Lifecycle

```bash
aapp draft auth-rate-limit       # 1. Scaffold a blueprint in .plans/current/
aapp tdd 12                      # 2. (Optional) Declare failure-first tests
aapp freeze 12                   # 3. Lock the design and the Blast Radius
aapp start 12                    # 4. Begin work (in its own worktree, when enabled)
aapp commit "feat: add limit"    # 5. Commit code; record the SHA in the plan
aapp done 12                     # 6. Archive the plan, land it, close its issue
```
`aapp freeze-start 12` does steps 3 and 4 at once. Every verb prints its arguments with `aapp help <verb>`.

---

## 🛡️ Two Checkpoints

| Checkpoint | When | What it checks |
| :--- | :--- | :--- |
| **Write-time guard** | An agent's `Write` / `Edit` tool call | Refuses edits outside the Target Files, and edits to the hooks and agent settings. Shell writes are not seen here. |
| **Pre-commit hook** | `git commit` | Refuses staged files outside the plan, a missing changelog entry, declared test files that do not exist, and work on a blocked plan. |

Both can be bypassed on purpose (`SKIP_BLAST_RADIUS=1`, `git commit --no-verify`). They guard against mistakes, not against someone set on getting around them. Running tests before `done` is an opt-in `pre-done` hook (`examples/hooks/test-gate.sh.sample`).

---

## 👥 Cloning a Project That Uses AAPP

Run `aapp init` in a fresh clone: it automatically finds the remote `plans`, `agents` and `githooks` branches and mounts them as local worktrees. If `aapp` is not installed yet on your machine, install it first via [Quick Start](#1-install-no-root-needed); otherwise commits are refused unless bypassed manually (`git commit --no-verify` or `SKIP_BLAST_RADIUS=1`).

---

## 🧪 Platform Support (Help Wanted)

The kit is developed and tested on **Linux** with Claude Code and Antigravity. macOS, Windows (Git Bash), WSL, the BSDs and other agents are untested. A test run report, pass or fail, helps: see [Platform Verification](docs/reference/19-platform-verification.md).

Known risk on Windows: the kit passes Git Bash paths (`/c/Users/…`) to Perl. Git for Windows' own Perl reads them; a native Perl first on `PATH` (Strawberry, ActiveState) does not, and the write guard then refuses every write ("Perl core missing").

---

## 🛠️ Developing the Kit

The kit is built with its own protocol. To set up a development clone (`./aapp develop`), run the test suites and make a change through a plan or an issue, read [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📚 Documentation

* ⚡ **[CHEATSHEET.md](CHEATSHEET.md)**: daily commands, who may write what, sync, and common traps.
* 🍳 **[COOKBOOK.md](COOKBOOK.md)**: step-by-step recipes (hook managers, CI, multi-agent setups).
* 📖 **[MANUAL.md](MANUAL.md)**: core axioms, architecture, and master Diátaxis specification map.
* 🏛️ **[ARCHITECTURE.md](ARCHITECTURE.md)**: the kit's design decisions.
* 🧭 **[Documentation Hub](docs/)**: [Concepts](docs/concepts/), [Reference Manuals](docs/reference/), and [Guides](docs/guides/).
* 🤝 **[CONTRIBUTING.md](CONTRIBUTING.md)**: developing the kit itself.

---

## 📄 License

Released under the [BSD 3-Clause License](LICENSE).

<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- Antigravity (Google)
- Claude (Anthropic)

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->
