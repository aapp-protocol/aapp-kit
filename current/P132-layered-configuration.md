# 🗺️ Plan P-132: Layered Configuration
* **Created:** 2026-10-23 | **Last Refined:** 2026-10-23
* **Target Issue / Milestone:** Group P-111 (Perl port)
* **Plan ID:** P-132
* **Changelog:** Added: settings can be set in system and user config files above the repository; a higher level always wins
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Every `aapp.*` setting lives in the repository's git config today. An agent working in the repository can change any of it (`git config aapp.<key> <value>`), so a setting meant to bind the agent (P-131's governance mode and handler, and later others) cannot live there alone.

Decided with the developer (2026-10-23):
- **Three levels, and a higher level always wins:** System, then User, then the repository's Git config. This reverses the usual program config order on purpose: the kit plans and enforces (gates, blast radius), so authority grows upward. It applies to every key; there is no list of special keys and no lock marker.
- **Most settings stay in the repository's git config.** The upper levels hold only what must be stricter; a key not set above keeps its repository value, so nothing changes for a project that never uses them.
- **Single Standard INI File Per Level (`main.conf`):** Instead of sprawling per-repository file directories (`repos/<key>.conf`), each upper level has a single standard INI file (`main.conf`). Global settings sit under `[aapp]`, while per-repository overrides sit in matching subsection blocks (e.g. `[aapp "repo:/path/to/project"]`).
- **One plan of its own**, so the decision is tracked apart from governance; P-131 reads its keys through this hierarchy.

---

## 2. Technical Blueprint

### 2.1 Places (in `AAPP::Constants`, per OS)
| Level | Linux, BSD | macOS | Windows | File |
| :--- | :--- | :--- | :--- | :--- |
| **System** | `/etc/aapp/` | `/Library/Application Support/aapp/` | `%ProgramData%\aapp\` | `main.conf` |
| **User** | `$XDG_CONFIG_HOME/aapp/` (default `~/.config/aapp/`) | as Linux | `%APPDATA%\aapp\` | `main.conf` |

There are no per-repository multi-files (`repos/<key>.conf`). All machine-wide and user-wide configurations reside cleanly within that level's `main.conf`.

### 2.2 Standard INI Format with Repository Subsections
```ini
# Example: /etc/aapp/main.conf or ~/.config/aapp/main.conf

# 1. Global defaults for this level
[aapp]
governance = hitl
governanceHandler = /usr/local/bin/review-gate

# 2. Per-repository override section within this level:
# Matches against repository root path (from git rev-parse --show-toplevel)
[aapp "repo:/home/lorand/projects/sandbox"]
governance = autonomous
```

- **Section Syntax**:
  - `[aapp]` declares global settings for that level. `governance = hitl` maps to key `aapp.governance`.
  - `[aapp "repo:<path>"]` declares overrides for a specific repository directory path.
  - Subsections for other keys follow Git config convention: `[aapp "hook"]` + `test = true` maps to `aapp.hook.test`.
- **Parsing Rules**:
  - `#` and `;` start comments; blank lines are ignored; values are trimmed.
  - No shell includes, no external dependencies, no complex interpolation.
  - A malformed line fails closed: emits an `[ ERROR ]` naming file and line number, and halts execution.

### 2.3 Evaluation Precedence
When resolving a configuration key for an active repository at path `$REPO_ROOT`:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. System Level (/etc/aapp/main.conf)                        │
│    - Matching [aapp "repo:$REPO_ROOT"] (Highest authority)  │
│    - Global [aapp]                                          │
├─────────────────────────────────────────────────────────────┤
│ 2. User Level (~/.config/aapp/main.conf)                    │
│    - Matching [aapp "repo:$REPO_ROOT"]                      │
│    - Global [aapp]                                          │
├─────────────────────────────────────────────────────────────┤
│ 3. Repository Level (.git/config)                           │
│    - Local git config (Lowest authority)                   │
└─────────────────────────────────────────────────────────────┘
```

- **Evaluation Order**: The highest level that defines the key wins.
- Within a single level's `main.conf`, a matching `[aapp "repo:..."]` block takes precedence over the global `[aapp]` block.
- **Diagnostics (`AAPP::Config::source($key)`)**: Returns the winning authority level and source (`system:global`, `system:repo`, `user:global`, `user:repo`, `repository`).
- **Mutation Guard**: `aapp config set` or `git config` modifies only the local repository `.git/config`. If a higher authority level currently sets that key, the CLI emits a notice explaining that the key is governed from above and names the governing file.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Repositories without upper-level `main.conf` files operate completely unchanged.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Constants and Parser Engine
- [ ] Task 1.1: Author per-OS `main.conf` paths in `lib/AAPP/Constants.pm`.
- [ ] Task 1.2: Implement native INI reader in `lib/AAPP/Config.pm` parsing `[section]`, `[section "subsection"]`, and `key = value` lines with line-numbered fail-closed diagnostics.
- [ ] Task 1.3: Implement repository root matcher for `[aapp "repo:<path>"]` blocks.

### Phase 2: Precedence & Integration
- [ ] Task 2.1: Extend `AAPP::Config::load` to evaluate System `main.conf`, User `main.conf`, and Local `.git/config` with inverted precedence (`System > User > Repo`).
- [ ] Task 2.2: Implement `AAPP::Config::source($key)` tracking the authoritative origin of each configuration key.
- [ ] Task 2.3: Update config setter diagnostics to warn when a set key is shadowed by an upper-level authority.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Author contract tests `t/core/config.t` validating:
  - System overrides User and Repo.
  - User overrides Repo.
  - Repo-specific block overrides global block within the same `main.conf`.
  - Absent keys cleanly fall through to local `.git/config`.
  - Malformed syntax fails closed with file and line diagnostics.
- [ ] Task 3.2: Author documentation contract in `lib/docs/core/config.md`.
- [ ] Task 3.3: Update `MANUAL.md` with configuration hierarchy guide and example `main.conf`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly confined to the files listed under `### 📂 Target Files`.
- [ ] `lib/AAPP/Config.pm` -> Multi-level INI load, repository subsection resolution, source origin tracking.
- [ ] `lib/AAPP/Constants.pm` -> Per-OS system and user `main.conf` directory locations.
- [ ] `NEW FILE` -> `t/core/config.t` -> Unit tests for layered configuration hierarchy.
- [ ] `NEW FILE` -> `lib/docs/core/config.md` -> Core contract for layered configuration.
- [ ] `MANUAL.md` -> User documentation for `main.conf` and inverted precedence.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/State.pm` -> Workspace state remains focused on repository git objects.
- [ ] `lib/AAPP/Util.pm` -> Unchanged; no extra project hash functions needed.
- [ ] `lib/*.sh` -> Legacy bash scripts continue reading local git config until ported.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** Multi-valued keys (`aapp.allowPath`, `aapp.aiAlias`, `aapp.hook.<event>`): Does a higher level completely replace the list, or append to it? *(Default proposal: Replace, keeping the authority model strictly deterministic).*
* [ ] **Question 2:** Git's own user and system config (`~/.gitconfig`, `/etc/gitconfig`): Should `git config --list -z` continue supplying base values for level 3, or should level 3 strictly inspect `--local`? *(Default proposal: `--list -z` as today, with AAPP upper files sitting above it).*

---

## 📦 6. Change Log & Refinement History
* **2026-10-23:** Plan drafted as dedicated Group P-111 member.
* **2026-10-23:** Refined to replace multi-file `repos/<key>.conf` with standard INI `[aapp "repo:<path>"]` subsection overrides inside `main.conf`.
