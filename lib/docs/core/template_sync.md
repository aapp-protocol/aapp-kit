# template_sync

## Tests
Run: `t/test-run template_sync`

- `t/core/template_sync.t::test_init_provisions_templates` -> `aapp init` installs the plan template, the release checklist and the archive ledger
- `t/core/template_sync.t::test_block_update_keeps_custom_sections` -> a rerun updates a template's protocol block in place and keeps sections outside it
- `t/core/template_sync.t::test_safe_mode_writes_new_buffer` -> a template diverged without markers is kept, and the kit's version is written beside it as `.new`
- `t/core/template_sync.t::test_strict_mode_overwrites` -> `aapp.templateSync strict` overwrites a diverged template and says so
- `t/core/template_sync.t::test_manual_mode_leaves_templates` -> `aapp.templateSync manual` leaves templates as they are, writing no `.new`
- `t/core/template_sync.t::test_inline_marker_mention_ignored` -> a marker named inside backticks is not taken for an unclosed block
- `t/core/template_sync.t::test_pickup_sync_keeps_ideas` -> syncing `pickup.md` keeps the user's ideas
- `t/core/template_sync.t::test_agents_sync_keeps_project_rules` -> syncing `.agents/AGENTS.md` keeps the project's own rules
- `t/core/template_sync.t::test_unclosed_marker_fails_safe` -> an unclosed protocol block is reported and the file left intact
- `t/core/template_sync.t::test_project_data_never_overwritten` -> `ISSUES.md`, `.agents/CODEMAP.md` and `.agents/PROJECT.MD` are never overwritten
- `t/core/template_sync.t::test_status_reports_synced` -> `aapp status` reports all templates synced
- `t/core/template_sync.t::test_status_reports_drift` -> `aapp status` counts drifted templates and points to `aapp init`
- `t/core/template_sync.t::test_start_skill_text` -> the start skill names itself, the rules file, `aapp status` and `aapp help`, and no machine path or tool
- `t/core/template_sync.t::test_init_installs_start_skill_and_onboarding` -> `aapp init` installs the start skill for every agent and seeds the onboarding pickup item with its instruction
