# 🗺️ Plan: Distribution rework — `aapp-init` / `aapp-install`

* **Created:** 2026-09-07 | **Last Refined:** 2026-09-07
* **Target Issue / Milestone:** —
* **Status:** 🟢 Ready for Execution
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

---

## 1. Context & Architectural Goal

The kit currently ships one script, `init-agent-planning.sh`, which grew a self-removal
phase, two flags (`--keep-kit`, `--yes`) and a marker file (`.aapp-kit-source`) to work
out whether it was allowed to delete itself. All of that exists because the kit had no
install story — it had to guess its own role at runtime.

**Goal:** replace the guessing with two explicit entry points, and delete the machinery
that guessing required.

| Command | Meaning | Kit afterwards |
| :--- | :--- | :--- |
| `./aapp-kit/aapp-init` | Set up *this* project | Consumed — `aapp-kit/` removed |
| `./aapp-kit/aapp-install` | Install for reuse across projects | Kept; copied to `~/.local` |

The user drops one self-contained folder into a project (`git clone <url> aapp-kit`)
and nothing lands at the project root. Adoption stays reversible by `rm -rf aapp-kit`
right up until `aapp-init` runs.

**Net effect on size:** removes ~55 lines of detection/flag logic and one marker file;
adds `aapp-install`. The self-removal *behaviour* survives; the machinery deciding
whether it is allowed does not.

---

## 2. Technical Blueprint

### 📋 Implementation Checklist
- [x] **Phase 1: Entry Point Renaming & Refactoring (`aapp-init`)**
  - [x] Rename `init-agent-planning.sh` to `aapp-init` (`git mv`)
  - [x] Implement content-based template signature discovery (`has_kit_signature`)
  - [x] Implement target repository resolution (`IS_DROP_IN` parent check vs installed cwd)
  - [x] Implement non-destructive `core.hooksPath` wiring detection for Husky/Lefthook (Q8)
  - [x] Implement collision guard for pre-existing non-worktree directories in `mount_or_create_worktree`
  - [x] Implement multi-machine restore mode (mounting `origin/*` branches without false conflict warnings)
  - [x] Implement skipped files collection and pre-banner warning block
  - [x] Implement kit folder retention on conflict and `--cleanup` command (Q9)
  - [x] Remove legacy flags (`--keep-kit`, `--standalone`, `--yes`), marker file (`.aapp-kit-source`), and Phase 6 branching
- [x] **Phase 2: Global Installer (`aapp-install`)**
  - [x] Create `aapp-install` with directory creation for `$HOME/.local/bin` and share directory
  - [x] Copy `aapp-init` and `aapp-install` to `$HOME/.local/bin` (`chmod +x`)
  - [x] Copy `templates/` and `tests/` to `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/`
  - [x] Implement shell PATH detection (`zsh`, `bash`, `fish`) and non-interactive `[ ! -t 0 ]` handling
  - [x] Implement self-consumption of `aapp-kit/` upon completion
  - [x] Implement `--uninstall` removing binaries and share directory while preserving shared directories and rc PATH lines
- [x] **Phase 3: Test Verification Suite (`tests/install_test.sh`)**
  - [x] Create `tests/install_test.sh` covering 27 regression cases
  - [x] Verify drop-in root, nested, and subdirectory resolutions
  - [x] Verify conflicts, warnings, and `--cleanup` lifecycle
  - [x] Verify Husky / native hook wiring interoperability
  - [x] Verify global installer, PATH advice, and `--uninstall`
  - [x] Ensure `tests/pre-commit_test.sh` (12 tests) and `tests/write-guard_test.sh` (26 tests) pass green
- [x] **Phase 4: Documentation Overhaul (`README.md`)**
  - [x] Rewrite Quick Start for drop-in (`./aapp-kit/aapp-init`) and global (`./aapp-kit/aapp-install`) workflows
  - [x] Add Section §2.7: Git history evidence of unconstrained agent drift
  - [x] Add Section §2.8: Existing project conflicts, silent skipping, and hook manager wiring
  - [x] Document self-consumption, update via re-clone, and uninstall behavior
  - [x] Update test verification recipes with all 3 test suites (65 tests)
  - [x] Synchronize Table of Contents and relative anchors
- [x] **Phase 5: Archival & Reference Example**
  - [x] Move frozen blueprint to `examples/example-plan-distribution-rework.md`
  - [x] Update status to `🟢 Ready for Execution` as canonical reference blueprint

---

### 2.1 Rename and layout

- `git mv init-agent-planning.sh aapp-init` — no extension, as a command should have.
  The extension leaks the implementation into the interface; dropping it means the
  script could stop being bash without breaking a caller.
- `aapp-init` and `aapp-install` both live **inside** the kit folder. Nothing is ever
  placed at the project root.
- Kit repo needs **no restructuring**: `git clone <url> aapp-kit` from the project root
  produces the required layout, because `aapp-kit` is just the clone directory name.

### 2.2 Base resolution (how the templates are found)

The discriminator is the **distinctive folder name**, never `templates/` — that name
collides with Flask, Django, Jinja, Hugo and Ansible projects, and a false positive
would delete a user's application code.

```
BASE = <dir containing this script>              if it is named aapp-kit / has templates+tests
     = ${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit   otherwise
```

The layout below `BASE` is identical in both cases (`$BASE/templates`, `$BASE/tests`),
so this is one code path with a variable base, not two lookup strategies.

- **Local wins over installed.** A dropped-in copy is a deliberate act and takes
  precedence, which also lets one project pin an older kit.
- If neither is found: fail loudly with install instructions (the existing
  missing-templates error, retargeted).

### 2.3 Target repository resolution — differs by mode

| Mode | Target repo | Why |
| :--- | :--- | :--- |
| Drop-in | `cd "$(dirname "$KIT_DIR")" && git rev-parse --show-toplevel` | A kit living in your project belongs to that project |
| Installed | `git rev-parse --show-toplevel` from **cwd** | An installed binary acts on wherever you are standing |

The parent rule is required, not cosmetic: after `git clone <url> aapp-kit` the kit
folder **is itself a git repository**, so resolving from cwd inside it returns the
kit's clone and the whole setup silently targets the wrong repo. Starting from the
parent steps outside the clone's `.git`; git then walks up, so `tools/aapp-kit`
resolves correctly too.

**Error case:** drop-in mode resolving to no git repository means the user cloned into
a bare directory intending to install. Message must say:

```
❌ No git repository here. Did you mean ./aapp-kit/aapp-install ?
```

### 2.4 `aapp-init` — deletions

On success in **drop-in mode**, `rm -rf "$KIT_DIR"` — one operation removing templates,
tests, the clone's `.git`, and both scripts. No separate self-delete, so the `rm "$0"`
while-running subtlety disappears. Installed mode deletes nothing, ever.

**Exception (Q9): if any file was skipped, the folder is kept.** The user needs the
templates to reconcile against. The rule in one line: *the kit folder is removed when its
job is done.* A skipped file means it is not.

`--cleanup` — the only flag on `aapp-init` besides `--help` — removes the kit folder and
does nothing else. It exists for the state above: reconcile by hand, then run it. It is
not a duplicate of a default; it completes a run that deliberately stopped short.

Removed entirely:
- `--keep-kit` and `--standalone` flags
- `KIT_IS_INSIDE` detection
- `.aapp-kit-source` marker file
- Phase 6's four-branch conditional

Retained: `--help` and `--cleanup` (Q9). **`--yes` is retired** — it existed to skip a confirmation
prompt, and Q5 removes the prompt from both commands, so it has nothing left to skip.
`aapp-init` therefore takes `--help` and `--cleanup`; `aapp-install` takes `--help` and
`--uninstall`.

### 2.5 `aapp-install` — new

0. **Create the target directories if missing.** `mkdir -p` both
   `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit` and `$HOME/.local/bin` — neither is
   guaranteed to exist on a fresh system, and `cp` into a missing directory fails. Report
   which ones were created, since that changes the PATH advice (see §2.6).
1. Copy `$KIT_DIR/{templates,tests}` → `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/`
2. Copy `$KIT_DIR/aapp-init` → `${HOME}/.local/bin/aapp-init`, `chmod +x`
3. **Copy, never symlink.** A symlink into the clone makes the clone look like a
   drop-in kit, so the first run in any project would delete it. Copying costs a
   re-run to update and removes that entire class of failure.
4. **Removes `aapp-kit/` afterwards** (Q4). Both entry points consume the folder — one
   folder in, one action, folder gone. `aapp-init` is on `PATH` after installing, so
   setting up the current project is still a single command.
5. Prints exactly what was removed (Q5), naming the clone and its `.git`. No prompt.
6. **Advises before, not after** (Q6): `--help` and the README both state that the folder
   is consumed and that you should copy it first if you want to keep the source. No
   detection of development checkouts — installing means the clone has served its purpose.
7. `--uninstall` removes both installed paths, prints exactly what it removed, and
   **leaves the `~/.bashrc` PATH line alone** (Q7) — noting that it did so, and that the
   line can be deleted by hand.

**Consequence — updating.** With the clone consumed there is no local copy to
`git pull`. Updating is: re-clone into `aapp-kit/`, run `aapp-install` again. Acceptable
because the kit is built to be stable with few updates (Q4); an autoupdate mechanism is
deferred until adoption shows it is needed. The README must state this plainly, or users
will assume the clone is still there.

**Consequence — copy-not-symlink is now forced.** Symlinking into a clone that is about
to be deleted would break immediately. The earlier reasoning still holds; the constraint
is now simply unavoidable.

### 2.5b Skipped-file warning (in `aapp-init`)

**Required.** Every `[ ! -f ]` guard that declines to copy must be **reported**. Keeping
the user's file is correct; doing it silently is not — the run currently ends in
`✨ Setup Complete!` while part of the agent contract was never installed.

- Collect every skipped path during the run; print **one block immediately before** the
  success banner, so it is the last thing on screen rather than lost in the scroll.
- It is a **warning, not an error**: setup continues and exits 0.
- Covers all guarded copies — `.plans/*`, `.agents/AGENTS.md`, `.agents/PROJECT.MD`,
  `.githooks/*`, the four root anchors, and `.claude/settings.json`.
- State the consequence in concrete terms, not "may differ". For example: *your
  `CODEMAP.md` was kept, so it does not carry the "scan this before creating any new
  file" rule the agents are told to obey.*
- Close with the §2.8 advice: reconcile by hand, or hand the merge to your AI assistant.

**The folder is kept whenever anything was skipped (Q9)**, so each warned file can name
its counterpart directly — `aapp-kit/templates/AGENTS.md` — and the block closes with the
command that finishes the job:

```
⚠️  These files already existed and were kept as-is:
      • AGENTS.md    → kit version: aapp-kit/templates/AGENTS.md
      • CODEMAP.md   → kit version: aapp-kit/templates/codemap.md

    Your CODEMAP.md does not carry the "scan this before creating any new file"
    rule the agents are told to obey. Reconcile these by hand, or hand the merge
    to your AI assistant.

    The kit folder was KEPT so you can compare.
    When you are done:  ./aapp-kit/aapp-init --cleanup
```

### 2.5c Wiring into an existing hook manager (Q8)

When `core.hooksPath` points elsewhere, the hooks are installed but not active. The
printed instructions must give the user a line to paste into their existing
`pre-commit` (husky, lefthook, or a native `.git/hooks/pre-commit`):

```sh
"$(git rev-parse --show-toplevel)/.githooks/pre-commit" || exit 1
```

**Do not recommend `source`.** Our hook ends in a bare `exit 0` on success. Sourced, that
`exit` terminates the *calling* hook as well, so any of the user's own checks placed after
the line would be silently skipped — a hook that looks wired in and quietly stops running
half of itself. Executing it as a subprocess keeps the exit code ours to return and lets
`|| exit 1` propagate a failure.

Environment still reaches it: `SKIP_BLAST_RADIUS=1 git commit` is inherited by the child
process, so the escape hatch works unchanged.

If the user genuinely wants `source` semantics (shared shell state), it must be the **last
line** of their hook. Worth one sentence; the subprocess form should be the default shown.

### 2.6 PATH handling (in `aapp-install`)

Runs **after** the directories are created (§2.5 step 0), because creating
`~/.local/bin` is itself often the fix.

Ordered, and the common case changes nothing:

0. **We just created `~/.local/bin`** → on Debian/Ubuntu the stock `~/.profile` adds it
   to `PATH` *only if it existed at login*. So on a fresh system the correct advice is
   **"log out and back in"** — no file is edited, and the directory now exists so the
   next login picks it up. This is the most common first-install case and it needs no
   configuration at all.
1. **Already on PATH** → done.
   `case ":$PATH:" in *":$HOME/.local/bin:"*)` — colon-wrapped so `/opt/local/bin`
   cannot false-match.
2. **Not on PATH, but an rc/profile already references it** → print "restart your
   shell" and **edit nothing**. Debian/Ubuntu's stock `~/.profile` already adds
   `~/.local/bin` guarded on the directory existing *at login*; appending our own line
   would duplicate it permanently.
3. **Genuinely absent** → print the exact line and **ask before writing**. Never edit a
   shell rc unprompted; it persists after the tool is gone. This is the one prompt in
   the kit, and it stays: Q5 removes prompts for *our own* files, not for someone's
   shell configuration.
   **Target file for bash: `~/.bashrc`** (Q1) — it affects the terminal the user is
   standing in.

**Never remove what we added** (Q7). `~/.local/bin` is shared: by uninstall time the user
may be relying on it for unrelated tools, so deleting the PATH entry could break things we
know nothing about. Uninstall reports the line and leaves it.

The same rule covers the directories: `--uninstall` removes **our files** and the
`aapp-kit` share directory, but never `~/.local/bin` or `~/.local/share` themselves, even
if we created them. They are shared locations and may be holding someone else's tools by
then.

Shell detection from `$SHELL` basename. fish needs different syntax entirely
(`fish_add_path ~/.local/bin`, not an export).

### 2.7 Docs: this repo's own git log as evidence

**Required.** The README must state that this repository stands as a testament to the
problem the kit exists to solve — and point at its own history as the proof, not as an
assertion.

The claim: **working through a flat chat, with no frozen plan and no blast radius, an
agent implements what it judges best rather than what the developer envisioned.** Not
through malice or incompetence — each addition is locally reasonable. That is exactly
why it accumulates unnoticed.

Cite the checkable instances from `git log`:

| Commit | What happened |
| :--- | :--- |
| `0f9fd43` → `80e597f` | Developer asked *what happens to the templates after init?* The agent answered by **building a `--standalone` flag**. The correct answer was to invert the default. Corrected one commit later. |
| `0f9fd43` | Introduced `.aapp-kit-source`, a marker file invented to solve a problem the agent's own design had created. |
| `7fc4119` | Documented `~/tools/` as an install location — a convention that does not exist. Corrected in `80e597f` to `~/.local/share`. |
| `f52823e` | The documented install had been silently broken: it produced empty worktrees, no hooks, and still printed *Setup Complete*. Found only because the developer asked an unrelated question. |

The point to draw: none of these were caught by the agent. Every one surfaced because
the developer pushed back. A frozen plan with a declared Blast Radius is what converts
that from *luck* into *structure* — the agent executes the developer's shape, and
anything outside it is refused rather than debated.

Placement: near the top of the README, in the motivation section — it is evidence for
the thesis, not an appendix to it. Keep it short and factual; the commits carry the
argument, so it does not need rhetoric.

### 2.8 Docs: conflicts with an existing setup

**Required.** The README must tell the user what happens when the kit meets a project
that already has some of these files. The honest picture is the opposite of what people
assume, so it needs stating plainly rather than a generic "may overwrite" warning.

**Nothing is overwritten.** Every copy is guarded by `[ ! -f ]`. An existing
`AGENTS.md`, `PROJECT.MD`, `CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `ISSUES.md`
or `.claude/settings.json` is kept exactly as it is.

**The real risk is the opposite: silent skipping.** Because your file is kept, the kit's
version is never installed — and nothing says so. You keep your `CODEMAP.md`, but it
lacks the *"scan this before creating any new file"* rule the agents are told to obey;
you keep your `AGENTS.md`, but it has none of the workflow commands or the Blast Radius
contract. The setup looks complete and half the agent-facing contract is missing.

So the README must say: **if you already have any of these files, reconcile them by hand
afterwards** — the kit will not do it for you and will not warn you.

**One thing genuinely is overwritten:** `git config core.hooksPath .githooks` is
unconditional. If the project uses husky (`.husky`), lefthook, or the pre-commit
framework, this silently repoints git and their hooks stop running. Setting `hooksPath`
also makes git ignore `.git/hooks/` entirely, so native hooks stop firing too. This must
be called out explicitly — it is the only destructive change the installer makes.

**Advice to include:** if you already work with an AI assistant, run the setup through it
rather than by hand. Reconciling an existing `AGENTS.md` with the template, merging a
`CODEMAP.md`, or chaining an existing hook manager is exactly the kind of merge an agent
does well — and it is work the installer deliberately does not attempt.

### 2.9 Tests

New `tests/install_test.sh` covering the silent-failure modes, which is where every
bug found today has lived:

- [x] drop-in: `./aapp-kit/aapp-init` from project root targets the **project**
- [x] drop-in: `cd aapp-kit && ./aapp-init` targets the project, **not the clone**
- [x] drop-in: nested at `tools/aapp-kit` still resolves to the project root
- [x] drop-in, no conflicts: `aapp-kit/` is gone afterwards; workflow still enforces
- [x] drop-in, a file skipped: `aapp-kit/` is **kept** and the warning names the template path
- [x] `--cleanup` removes the folder and touches nothing else
- [x] `--cleanup` on an already-clean project is a harmless no-op
- [x] existing `AGENTS.md` / `CODEMAP.md` present → kept, and the skip is **warned about**
- [x] the warning block appears before the success banner and exit code stays 0
- [x] a clean project skips nothing and prints no warning block
- [x] `core.hooksPath` unset → set to `.githooks`, no warning
- [x] `core.hooksPath` already `.githooks` → unchanged, no warning (idempotent re-run)
- [x] `core.hooksPath=.husky` → hooks installed, **config untouched**, wiring printed
- [x] executable `.git/hooks/pre-commit` present → config untouched, wiring printed
- [x] the wiring line actually works: pasted into a husky hook, a blast radius violation is still refused
- [x] drop-in with no parent repo → the "did you mean aapp-install?" message
- [x] a project containing its own `templates/` (Flask-style) is **never** mistaken
      for the kit and never has it deleted
- [x] installed mode: targets cwd's repo, deletes nothing
- [x] `aapp-install` removes `aapp-kit/` and the installed copy still works
- [x] `aapp-install` then `--uninstall` leaves no trace
- [x] `tests/` reachable from the installed share dir after the clone is gone
- [x] `--uninstall` leaves the `~/.bashrc` PATH line untouched and says so
- [x] PATH: already-present → no edit; referenced-in-rc → no edit; absent → prompts
- [x] install succeeds when `~/.local/bin` and `~/.local/share` do not exist at all
- [x] freshly-created `~/.local/bin` → advises re-login, edits nothing
- [x] `--uninstall` removes our files but leaves `~/.local/bin` and `~/.local/share`

Existing `tests/pre-commit_test.sh` (12) and `tests/write-guard_test.sh` (26) must stay
green; they are unaffected by this change.

---

## 💥 3. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files
> outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target;
> everything after it is prose.

- [x] `init-agent-planning.sh` -> renamed to `aapp-init` via `git mv`; flags, marker check and Phase 6 branching removed; base + target resolution reworked
- [x] `NEW FILE` -> `aapp-install` -> installer, PATH check, `--uninstall`
- [x] `NEW FILE` -> `tests/install_test.sh` -> resolution and cleanup coverage
- [x] `README.md` -> rewrite install/quick-start; drop `~/tools/`, `--keep-kit`, `.aapp-kit-source`; remove the stale duplicate block; add the git-log-as-testament section (§2.7); add the existing-setup conflict section (§2.8); state that both commands consume `aapp-kit/` and to copy it first if keeping the source (Q6); state that updating means re-clone (Q4); state that uninstall leaves the PATH line (Q7)
- [x] `.aapp-kit-source` -> DELETE

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/pre-commit` -> enforcement logic is settled and tested; this change is distribution only
- [ ] `templates/blast-radius-guard.sh` -> as above
- [ ] `tests/pre-commit_test.sh` -> must keep passing unchanged
- [ ] `tests/write-guard_test.sh` -> must keep passing unchanged
- [ ] `templates/*.md` -> workflow docs unaffected by how the kit is installed

---

## ❓ 4. Open Questions & Decision Matrix

### ✅ Answered 2026-09-07

* [x] **Q1 — bash PATH file.** → **`~/.bashrc`.** It affects the terminal the user is
  standing in. Still only written after an explicit prompt.

* [x] **Q2 — clean break on the old name?** → **Drop `init-agent-planning.sh`.** No shim.

* [x] **Q3 — install `tests/` to share?** → **Yes.** Now load-bearing rather than
  convenient: with the clone consumed (Q4), the share dir is the *only* surviving copy
  of the suites.

* [x] **Q4 — should `aapp-install` consume the kit folder?** → **Yes, both executables
  remove `aapp-kit/`.** After installing, `aapp-init` is on `PATH`, so running it in the
  project costs the same typing either way. One folder in, one action, folder gone.

  *Rationale on the update cost:* the kit is meant to be **stable over the long run**,
  with few updates — so "re-clone to update" is a rare action, not a recurring tax. If
  adoption grows and it becomes a real friction point, revisit with an autoupdate /
  autoclone mechanism rather than by keeping the folder around. Explicitly deferred, not
  overlooked.

* [x] **Q5 — confirmation before `rm -rf aapp-kit/`?** → **No prompt; print exactly what
  was removed.** Standard behaviour for this class of action.
  *Follows:* `--yes` is retired — with no prompt in either command it has nothing to
  skip. Both binaries end up flagless apart from `--help` and `--uninstall`.

* [x] **Q7 — should `--uninstall` remove the PATH line it added?** → **No. Never remove
  it; print a note instead.**

  `~/.local/bin` is a **shared** location. Between our install and our uninstall the user
  may well have started putting other things there — quite likely a novice following
  another program's setup instructions. Deleting the entry because *we* added it would
  silently break every other tool living in that directory.

  Recording that we added the line would let us remove it, but the shared-usage risk
  applies regardless of who added it, so the record does not make deletion safe. Precedent
  is mixed anyway: many installers only print instructions, some do nothing at all.

  **Rule: we add only with permission, and we never remove.** `--uninstall` prints exactly
  what it removed, then notes that the `~/.bashrc` PATH line was left in place and can be
  deleted by hand if the user wants it gone.

* [x] **Q6 — how should `aapp-install` behave in the kit's own development checkout?**
  → **Option 1: accept it. No special case, no marker, no dirty-tree check.**

  Once installed, the clone is dead weight — it serves nothing. The only reason to keep
  it is to develop or redistribute the kit, and anyone doing that knows to keep their own
  copy and push their work; that is manual work they are already signed up for.

  So: no detection machinery of any kind. Instead, **advise up front** — `aapp-install
  --help` and the README both state that the folder is consumed, and that you should copy
  it first if you want to keep the source. The removal printout (Q5) names the clone and
  its `.git` explicitly, so what happened is never a mystery after the fact.

  This closes the last blocker without reintroducing `.aapp-kit-source` or any substitute
  for it.

---

* [x] **Q9 — where should the skipped-file warning point for comparison?** → **Nowhere
  else: keep the kit folder when there was a conflict.**

  Removal is not unconditional, it is *conditional on the folder having finished its job*.
  A skipped file means the user still needs the templates to reconcile against, so the
  folder stays and the warning points at `aapp-kit/templates/<file>` — the diff target is
  right there, no URL, no scattered `.aapp-new` copies.

  A `--cleanup` flag removes the folder once reconciliation is done.

  *This overrides my proposal.* I argued a conditional rule repeats the `--standalone`
  mistake; it does not. `--standalone` was a flag duplicating a default. This is a
  condition tied to real unfinished business, and the rule states in one line: **the kit
  folder is removed when its job is done.**

* [x] **Q8 — should the installer guard `core.hooksPath`?** → **Yes: detect, install
  anyway, never touch the config, and hand the user the wiring line.**

  Better than the three options I offered. Refusing (my proposal) would have left the user
  with no hooks installed at all; chaining would have meant guessing how someone else's
  hook manager works. This does the work and leaves only the decision.

  Detection, three states:

  | `core.hooksPath` | Action |
  | :--- | :--- |
  | unset | Set it to `.githooks` as now. Conventional case, no warning. |
  | already `.githooks` | Nothing to do. Idempotent re-run, no warning. |
  | anything else (`.husky`, `.lefthook`, …) | **Install hooks, leave the config untouched, print the wiring instructions.** |

  **Also covered:** `core.hooksPath` unset *but* an executable `.git/hooks/pre-commit`
  present (a real native hook, not a `.sample`). Setting `hooksPath` makes git ignore
  `.git/hooks/` entirely, so that hook would stop firing silently. Same treatment — install,
  do not set the config, print the wiring.

  See §2.5c for the wiring text, which must **not** recommend a bare `source`.

---

**All questions resolved (Q1–Q9).** Blast Radius is declared and no decisions remain
outstanding — the plan is eligible for `freeze`. Holding at 🔴 pending the developer's
instruction.

---

## 📦 5. Change Log & Refinement History

* **2026-09-07:** Drafted from the distribution discussion. Not yet executed; awaiting
  answers to Q1–Q5 and approval of the Blast Radius.
* **2026-09-07:** Added §2.7 at the developer's request — the README must record that
  this repo's own git log evidences unconstrained agent drift.
* **2026-09-07:** Q1–Q5 answered by the developer and folded into §2.4–§2.8. Q4 reversed
  my proposal: `aapp-install` now consumes the kit folder as well. Q5 retires `--yes`.
  Q4 raised a new blocker, Q6 (installer run inside the kit's own checkout), which is
  left open with no proposal.
* **2026-09-07:** Q4 rationale recorded (kit is stable long-run, so re-clone-to-update is
  rare; autoupdate deferred). Q7 answered: never remove the PATH line on uninstall, print
  a note instead — `~/.local/bin` is shared and may be carrying other tools by then.
  Still blocked on Q6.
* **2026-09-07:** Q6 answered — accept deletion of a development checkout, no detection
  machinery; advise in `--help` and the README to copy the folder first if the source is
  wanted.
* **2026-09-07:** Added §2.8 at the developer's request — docs must cover conflicts with
  an existing setup. Verified against the script: nothing is overwritten (all copies are
  `[ ! -f ]` guarded), so the real risk is *silent skipping* leaving half the agent
  contract uninstalled. Found one genuine unconditional overwrite, `core.hooksPath`,
  which disables an existing husky/lefthook setup without warning — raised as Q8.
  **Plan 🔴 — blocked on Q8.**
* **2026-09-07:** Developer instruction — the installer must create
  `~/.local/bin` and the share directory when absent. Recorded as §2.5 step 0. Noted the
  interaction: on Debian/Ubuntu a freshly created `~/.local/bin` is picked up by the
  stock `~/.profile` at next login, so the first-install case resolves by re-login with
  no file edited. Uninstall never removes the shared directories (Q7 rule extended).
* **2026-09-07:** Added 5 architectural refinements:
  1. `aapp-install` copies both `aapp-init` and `aapp-install` to `~/.local/bin` so `--uninstall` remains callable after `aapp-kit/` removal.
  2. Extended shell detection to support `zsh` (`~/.zshrc`) alongside `bash` (`~/.bashrc`) and `fish`.
  3. Added collision guard for pre-existing non-worktree directories in `mount_or_create_worktree`.
  4. Clarified multi-machine restore behavior (mounting existing `origin/*` branches does not trigger false conflict warnings).
  5. Added non-interactive/CI shell handling (`[ ! -t 0 ]`) for automated environments.
