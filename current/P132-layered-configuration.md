# 🗺️ Plan P-132: Layered Configuration
* **Created:** 2026-10-23 | **Last Refined:** 2026-10-23
* **Target Issue / Milestone:** Group P-111 (Perl port)
* **Plan ID:** P-132
* **Changelog:** Added: settings can be set in system and user config files above the repository; a higher level always wins
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

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
- **Three levels, and a higher level always wins:** system, then user, then the repository's git config. This reverses the usual program config order on purpose: the kit plans and also enforces (gates, blast radius), so authority grows upward. It applies to every key; there is no list of special keys and no lock marker.
- **Most settings stay in the repository's git config.** The upper levels hold only what must be stricter; a key not set above keeps its repository value, so nothing changes for a project that never uses them.
- **The upper levels are INI files:** at each level one central `main.conf` (every repository) and one file per repository. A `main.conf` may hold one or two lines (for example the governance mode).
- **One plan of its own**, so the decision is tracked apart from governance; P-131 reads its keys through this hierarchy.

---

## 2. Technical Blueprint

### 2.1 Places (in `AAPP::Constants`, per OS)
| Level | Linux, BSD | macOS | Windows |
| :--- | :--- | :--- | :--- |
| System | `/etc/aapp/` | `/Library/Application Support/aapp/` | `%ProgramData%\aapp\` |
| User | `$XDG_CONFIG_HOME/aapp/` (default `~/.config/aapp/`) | as Linux | `%APPDATA%\aapp\` |

At each level: `main.conf`, and `repos/<key>.conf` for one repository. `<key>` is the project key the issue text store already uses (the remote URL without scheme and credentials, else the checkout's folder name, made filesystem-safe); it moves out of `AAPP::State::issue_text_file` into one function both use.

### 2.2 File format
```ini
# /etc/aapp/main.conf
[aapp]
governance = strict
governanceHandler = /usr/local/bin/review-gate
```
- Section and key spell the git key: `[aapp]` + `governance` is `aapp.governance`; a git subsection is written `[aapp "hook"]`, as in git config files. One name per setting at every level.
- `#` and `;` start comments; blank lines are ignored; values are trimmed; no includes, no interpolation.
- A malformed line fails closed: an `[ ERROR ]` naming the file and line number, and the verb stops.

### 2.3 Reading (`AAPP::Config`)
- `load` reads the repository's git config (as today), then the user files, then the system files; each key keeps the value of the highest level that sets it, and remembers that level.
- `get`, `get_all`, `get_int`, `get_bool` keep their signatures; callers do not change.
- New `source($key)`: the level (`system`, `user`, `repository`) and file that gave the value, for diagnostics.
- `set` still writes only the repository's git config. When a higher level overrides the key, it says so once, naming the level and file; the kit never writes the upper files.
- Bash readers (`git config --get` in `lib/*.sh`) see only the repository level until their member ports them; the hierarchy applies wherever `AAPP::Config` reads.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A repository without upper files reads exactly as before.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Places and Format
- [ ] Task 1.1: The per-OS places and file names in `AAPP::Constants`.
- [ ] Task 1.2: The project key as one function, used by the issue text store and by the per-repository file name.
- [ ] Task 1.3: The INI reader with fail-closed errors naming file and line.

### Phase 2: Precedence
- [ ] Task 2.1: `AAPP::Config::load` merges the three levels, the highest level winning per key; `source($key)` names it.
- [ ] Task 2.2: `set` reports an override from a higher level.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `t/core/config.t` with its contract `lib/docs/core/config.md`: each level alone, a higher level overriding a lower one, per-repository and `main.conf` files, multi-valued keys, a malformed line, `source`, and a repository with no upper files unchanged.
- [ ] Task 3.2: `MANUAL.md`: the three levels, the reversed precedence and why, the file format, an example `main.conf`.
- [ ] Task 3.3: Both runners green.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/AAPP/Config.pm` -> Three-level load, highest level wins; `source`; `set` reports an override.
- [ ] `lib/AAPP/Constants.pm` -> Per-OS places and file names of the upper levels.
- [ ] `lib/AAPP/Util.pm` -> The project key, one function.
- [ ] `lib/AAPP/State.pm` -> The issue text store uses the shared project key.
- [ ] `NEW FILE` -> `t/core/config.t` -> Tests of the hierarchy.
- [ ] `NEW FILE` -> `lib/docs/core/config.md` -> Its contract.
- [ ] `MANUAL.md` -> The levels, the precedence and the file format.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/*.sh` -> Bash readers keep reading git config until their members port them.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** Within one level, does the per-repository file win over `main.conf` (the specific over the general), or `main.conf` (the central one)?
* [ ] **Question 2:** A multi-valued key (`aapp.allowPath`, `aapp.aiAlias`, `aapp.hook.<event>`) set at more than one level: does the higher level replace the lower list, or add to it?
* [ ] **Question 3:** Git's own user and system config (`~/.gitconfig`, `/etc/gitconfig`) are merged into the repository level today, the local value winning. Do `aapp.*` keys there keep counting as part of the repository level, or does the repository level read only the repository's own config (`git config --local`, with `--worktree`)?
* [ ] **Question 4:** Where in the group order: P-132 needs only `AAPP::Config` (P-115, done), and must come before P-131.

---

## 📦 6. Change Log & Refinement History
* **2026-10-23:** Drafted as a member of group P-111 at the developer's request, from the P-131 review: settings that bind the agent need a place the agent cannot change.
