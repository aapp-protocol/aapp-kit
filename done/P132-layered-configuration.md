# 🗺️ Plan P-132: Layered Configuration
* **Created:** 2026-10-23 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** Group P-111 (Perl port)
* **Plan ID:** P-132
* **Changelog:** Added: settings can be set in system and user config files above the repository; a higher level always wins
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
* **Status:** ✅ Done
* **Base:** `1fa37f3` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P132 (plan/P132-layered-configuration)
* **Group:** P-111
* **Commits:** `9ad7108` (plan/P132-layered-configuration)
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
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
- **Three levels, and a higher level always wins:** System, then User, then the repository's Git config. This reverses the usual program config order on purpose: the kit plans and enforces (gates, blast radius), so authority grows upward.
- **The upper levels take administrative keys only:** an allow-list (§2.3) names them (governance, attribution, limits, team or user preferences such as the commit message lengths); any other key in a `main.conf` is refused. Repository state (the id counters) and repository settings stay in the repository's git config.
- **The kit only reads the upper levels:** it never writes a `main.conf`; administering them belongs to a separate tool outside the kit.
- **Most settings stay in the repository's git config.** The upper levels hold only what must be stricter; a key not set above keeps its repository value, so nothing changes for a project that never uses them.
- **Single Standard INI File Per Level (`main.conf`):** Instead of sprawling per-repository file directories (`repos/<key>.conf`), each upper level has a single standard INI file (`main.conf`). Global settings sit under `[aapp]`, while per-repository overrides sit in matching subsection blocks (e.g. `[aapp "repo:/path/to/project"]`).
- **One plan of its own**, so the decision is tracked apart from governance; P-131 reads its keys through this hierarchy.

**Implementation References:**
- **RFC Parent:** `.plans/pickup/perl-port-test-salvage-rfc.md` (Group (a) Pure Unit Suites)
- **Specification Contract:** `lib/docs/core/config.md`

---

## 2. Technical Blueprint

### 2.1 Places (in `AAPP::Constants`, per OS)
| Level | Linux, BSD | macOS | Windows | File |
| :--- | :--- | :--- | :--- | :--- |
| **System** | `/etc/aapp/` | `/Library/Application Support/aapp/` | `%ProgramData%\aapp\` | `main.conf` |
| **User** | `$XDG_CONFIG_HOME/aapp/` (default `~/.config/aapp/`) | as Linux | `%APPDATA%\aapp\` | `main.conf` |

There are no per-repository multi-files (`repos/<key>.conf`). All machine-wide and user-wide configurations reside cleanly within that level's `main.conf`.

**Test & Sandbox Redirection**: For sandboxed unit tests (`t/core/config.t`) and non-root environments, directory paths can be redirected via environment variables `$ENV{AAPP_SYS_CONF_DIR}` (defaulting to the OS system directory above) and `$ENV{AAPP_USER_CONF_DIR}` (defaulting to the user config directory above). When set, `AAPP::Config` and `AAPP::Constants` read `main.conf` from these directories.

### 2.2 Standard INI Format with Repository Subsections
```ini
# Example: /etc/aapp/main.conf or ~/.config/aapp/main.conf

# 1. Global defaults for this level
[aapp]
governance = hitl
governanceHandler = /usr/local/bin/review-gate

# 2. Per-repository override section within this level:
# Matches against primary checkout root (AAPP::Paths::primary_root),
# covering the main repository and all active plan/fix worktrees (.workspace/*).
[aapp "repo:/path/to/project"]
governance = autonomous
hook.pre-freeze = /usr/local/bin/custom-freeze-gate
```

- **Section Syntax**:
  - `[aapp]` declares global settings for that level. `governance = hitl` maps to key `aapp.governance`.
  - `[aapp "repo:<path>"]` declares overrides for a specific repository. Path matching is evaluated against `AAPP::Paths::primary_root` so that linked worktrees (`.workspace/P123`, `.workspace/fix-<num>`) automatically inherit the project's repository rules.
  - Subsections for other keys follow Git config convention: `[aapp "hook"]` + `test = true` maps to `aapp.hook.test`.
  - Inside `[aapp "repo:<path>"]`, dotted keys (e.g. `hook.pre-freeze = ...`) map directly to the corresponding subsection key (`aapp.hook.pre-freeze`).
- **Parsing Rules**:
  - `#` and `;` start comments; blank lines are ignored; values are trimmed.
  - No shell includes, no external dependencies, no complex interpolation.
  - A malformed line fails closed: emits an `[ ERROR ]` naming file and line number, and halts execution.

### 2.3 Policy vs. Local-State Boundary (Upper-Level Allowlist)
Repository Git configuration holds two distinct kinds of data:
1. **Administrative Policies & Safety Limits**: Ceilings, gates, and attribution rules (`aapp.governance*`, `aapp.fixMaxLines`, `aapp.aiAttribution`).
2. **Local Monotonic State Counters**: Internal Git history progression counters (`aapp.planId`, `aapp.issueId`, `aapp.lastRelease`) mutated directly by verbs like `aapp draft` and `aapp issue log`.

Under inverted precedence (`System > User > Repo`), setting a monotonic state counter in `main.conf` would permanently freeze the counter for the local repository, causing subsequent plan and issue allocations to collide.

To guarantee local repository state integrity, an **Upper-Level Policy Allowlist** sits at the top of `lib/AAPP/Config.pm` (allow-lists live at the top of their module). Only administrative policy settings may be specified in `main.conf`:
- **Governance**: `aapp.governance`, `aapp.governanceHandler`, `aapp.governanceTimeout`
- **Attribution & Identity**: `aapp.aiAttribution`, `aapp.aiNotes`
- **Blast Radius & Limits**: `aapp.fixMaxLines`, `aapp.fixMaxFiles`, `aapp.maxEmergencyHotfixes`, `aapp.subjectMaxLen`, `aapp.commitLineMaxLen`, `aapp.bodyMaxLen`
- **Runtime Environment & Hooks**: `aapp.quarantineIgnored`, `aapp.perlLogFile`, `aapp.allowPath`, and `aapp.hook.*`

**Fail-Closed Allowlist Guard**: A key not on the allow-list in a system or user `main.conf` makes the parser **fail closed**, naming the file, the line and the key:
```text
❌ [Config Refusal] /etc/aapp/main.conf: line 6: 'aapp.planId' is not allowed in upper-level configuration.
```

### 2.4 Evaluation Precedence
When resolving a configuration key for an active repository at `primary_root` (`$REPO_ROOT`):

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
- **Multi-valued keys** (`aapp.allowPath`, `aapp.hook.<event>`): the highest level that sets the key gives the whole list; lower levels add nothing to it, so a repository can never widen what an administrator set.
- **The repository level is git config as git resolves it today** (`git config --list -z`: the repository's own config over git's user and system files), so a project that uses no `main.conf` reads exactly as before.
- **Diagnostics (`AAPP::Config::source($key)`)**: Returns the winning authority level and source (`system:global`, `system:repo`, `user:global`, `user:repo`, `repository`).
- **No setter**: `AAPP::Config` has no general setter. The only write is the id counter (`set_id`/`get_id`, repository level only, P-117 Task 0.1 as an amendment for P-115), and counters are never on the allow-list, so nothing the kit writes can be shadowed from above. Verbs may use `source($key)` to say which level a value came from.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Repositories without upper-level `main.conf` files operate completely unchanged.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Constants and Parser Engine
- [x] Task 1.1: Author per-OS `main.conf` paths in `lib/AAPP/Constants.pm`, and the upper-level allow-list at the top of `lib/AAPP/Config.pm`.
- [x] Task 1.2: Implement native INI reader in `lib/AAPP/Config.pm` parsing `[section]`, `[section "subsection"]`, and `key = value` lines with line-numbered fail-closed diagnostics.
- [x] Task 1.3: Implement repository root matcher for `[aapp "repo:<path>"]` blocks against `primary_root`.
- [x] Task 1.4: Implement fail-closed allow-list validation in `lib/AAPP/Config.pm`: a key not on the list in an upper `main.conf` is refused, naming file, line and key.

### Phase 2: Precedence & Integration
- [x] Task 2.1: Extend `AAPP::Config::load` to evaluate System `main.conf`, User `main.conf`, and Local `.git/config` with inverted precedence (`System > User > Repo`).
- [x] Task 2.2: Implement `AAPP::Config::source($key)` tracking the authoritative origin of each configuration key.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Author contract tests `t/core/config.t` validating:
  - System overrides User and Repo.
  - User overrides Repo.
  - Repo-specific block overrides global block within the same `main.conf`.
  - Absent keys cleanly fall through to local `.git/config`.
  - Malformed syntax fails closed with file and line diagnostics.
- [x] Task 3.2: Author documentation contract in `lib/docs/core/config.md`.
- [x] Task 3.3: Update `MANUAL.md` with configuration hierarchy guide and example `main.conf`.

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
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-25:** Plan implementation completed and archived to done/.
* **2026-10-25:** Plan activated into ⚡ In Development via start.
* **2026-10-25:** Plan activated into ⚡ In Development via start.
* **2026-10-25:** Plan activated into ⚡ In Development via start.
* **2026-10-25:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-24:** Refined technical blueprint, D7 references, and checklist with single-repo schema and test matrix references.
* **2026-10-23:** Drafted as a member of group P-111 at the developer's request, from the P-131 review: settings that bind the agent need a place the agent cannot change.
* **2026-10-23:** One `main.conf` per level with `[aapp "repo:<path>"]` blocks matched on the primary checkout root; dotted keys inside a repository block.
* **2026-10-23:** Upper levels take allow-listed administrative keys only (commit message lengths included, as team or user preferences); the kit reads them and never writes them, no setter; the allow-list sits at the top of `AAPP::Config`.
* **2026-10-24:** Open questions closed by the decisions taken: multi-valued keys come whole from the highest level (follows from "a higher level always wins"); the repository level stays git config as git resolves it (follows from "nothing changes without a `main.conf`"); placed 6th in P-111 §3, after P-123 and before P-131.
* **2026-10-23:** Plan drafted as dedicated Group P-111 member.
* **2026-10-23:** Refined to replace multi-file `repos/<key>.conf` with standard INI `[aapp "repo:<path>"]` subsection overrides inside `main.conf`.
* **2026-10-23:** Refined to use `AAPP::Paths::primary_root` for worktree path coverage, support dotted subsection keys, remove machine paths, and clarify setter diagnostics.
* **2026-10-23:** Added Upper-Level Policy Allowlist refusing local state counters (planId, issueId) in main.conf.
