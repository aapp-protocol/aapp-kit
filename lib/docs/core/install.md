# install

## Tests
Run: `t/test-run install`

- `t/core/install.t::test_version_and_help` -> `aapp version`, `-v` and `--version` print the kit's version; `aapp help` prints the catalog
- `t/core/install.t::test_init_confinement` -> an uninstalled kit clone initializes itself, refuses another project, and `init` outside a repository fails at the front door
- `t/core/install.t::test_agents_protocol_block_adopt_upgrade_migrate` -> `init` appends the protocol block to an unmanaged `AGENTS.md`, upgrades an old block in place keeping the rules around it, moves a root `AGENTS.md` into `.agents/`, and keeps root anchors
- `t/core/install.t::test_init_installs_hook_engines` -> `init` installs the kit's hooks beside a custom `pre-commit`, wiring it in; the shared library is installed as a real file, and a kit without it fails loudly naming the OS
- `t/core/install.t::test_claude_settings_merged` -> `init` writes the guard into `.claude/settings.json`, merging into existing settings without duplicates
- `t/core/install.t::test_hooks_path_interop` -> an unset or kit `core.hooksPath` is set quietly; a foreign hooks path or an executable `.git/hooks/pre-commit` is left alone with the wiring line printed; a custom hook with that line enforces the blast radius
- `t/core/install.t::test_init_collisions_and_restore` -> a project's own `templates/` is kept, a plain `.plans/` folder is refused, and a clone with remote kit branches mounts them
- `t/core/install.t::test_install_creates_and_consumes` -> `aapp install` creates `~/.local/bin` and the share directory, keeps the template library link, and removes the installer clone
- `t/core/install.t::test_install_keeps_folders_it_must_not_consume` -> `install` refuses `--keep` and keeps an installer folder holding extra files, uncommitted changes or a linked worktree
- `t/core/install.t::test_installed_kit_runs_from_path` -> the installed kit holds `lib/` and `tests/`, `aapp init` runs from the path, and a bin directory already on the path is reported, not edited
- `t/core/install.t::test_install_fresh_bin_advises_relogin` -> a freshly created bin directory gets advice to log in again, and no rc file is edited
- `t/core/install.t::test_uninstall_leaves_no_trace` -> `aapp uninstall` removes the binary and the share directory, keeping the shared directories and rc files
- `t/core/install.t::test_status_prints_four_pillars` -> `aapp status` prints the four pillars
- `t/core/install.t::test_install_keeps_develop_kit_folder` -> `install` never consumes an `aapp-develop-kit` folder
- `t/core/install.t::test_unclosed_protocol_marker_preserves_file` -> an unclosed protocol block in `AGENTS.md` is reported and the file left intact
- `t/core/install.t::test_develop_links_live_clone` -> `aapp develop` links the clone into the path and share directory, so edits are live and nothing is copied or consumed
- `t/core/install.t::test_develop_hook_seeding` -> the develop-only pre-commit engine is absent after `init`, seeded once by `develop` and removed with its wrapper block by `uninstall`
- `t/core/install.t::test_install_after_develop` -> `install` after `develop` replaces the links with copies and deletes no source
- `t/core/install.t::test_uninstall_cleans_dangling_links` -> `uninstall` removes links left dangling by a deleted clone
- `t/core/install.t::test_claude_settings_decoupled` -> `.claude/settings.json` links to `.agents/claude/settings.json`, and `.claude/` is ignored on the code branch
- `t/core/install.t::test_skills_installed_and_bridged` -> the kit's skills are installed in `.agents/skills/` and linked from `.claude/skills/`; a user's own skills and local settings are kept; stale files go on resync
- `t/core/install.t::test_skill_frontmatter` -> every kit skill has its name, description and invocation flag; retired skills are gone; fork and inline contexts are as specified; `aapp-fix` names its verbs
- `t/core/install.t::test_init_issue_ledgers` -> `init` provides the issue archive and keeps a custom `ISSUES.md` with a notice
- `t/core/install.t::test_template_shapes` -> the issue table has its eight columns and no subheadings; the plan template, archive ledger and pickup template carry their seeded fields
- `t/core/install.t::test_init_banner` -> `init` prints the first-loop guidance
- `t/core/install.t::test_skill_sync_and_pruning` -> `init` installs `aapp-pause`, whose skill has its frontmatter, and removes retired skills and their links while keeping `registry.tsv`
- `t/core/install.t::test_manifest_and_help_tiers` -> `lib/verbs.tsv` holds the five tiers, `aapp help` groups by them, and never shows the contract column
- `t/core/install.t::test_hooks_events_catalog` -> `aapp hooks events` prints the pre/on/post event catalog
- `t/core/install.t::test_cheatsheet_lists_every_verb` -> every verb in `lib/verbs.tsv` appears in `CHEATSHEET.md`
- `t/core/install.t::test_install_copies_examples_and_docs` -> `install` copies `examples/`, `docs/`, `COOKBOOK.md` and `MANUAL.md`, and drops stale examples
- `t/core/install.t::test_init_installs_no_samples` -> `init` puts no sample plugin into `.agents/skills/`
- `t/core/install.t::test_test_verb_runs_a_named_suite` -> `aapp test quiet <suite>` runs that suite alone and reports its summary
- `t/core/install.t::test_front_door_repository_check` -> operational verbs outside a repository exit 1 with the diagnostic; `version`, `help` and `install` work there
- `t/core/install.t::test_init_seeds_settings_only_when_absent` -> `init` seeds attribution, changelog mode, the union merge line, fix limits, commit mode and the plan worktree keys only when absent; `aapp.planSession` never
- `t/core/install.t::test_init_installs_and_wires_post_rewrite` -> `init` installs the post-rewrite engine and wires an existing post-rewrite hook without overwriting it
- `t/core/install.t::test_init_seeds_plan_counter_past_release_bundles` -> with no counter, `init` seeds the plan id past the plans in release bundles
- `t/core/install.t::test_skills_drive_the_verbs` -> the done, freeze, start, status and digest skills call their verbs and edit no state by hand
