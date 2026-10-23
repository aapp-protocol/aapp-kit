# write-guard

## Tests
Run: `t/test-run write-guard`

- `t/core/write-guard.t::test_targets_and_shared_docs_decide` -> declared targets, `.plans/`, `.agents/` rules, invariant anchors and shared docs are allowed; Out of Bounds, prose-only and undeclared files are denied, by command line and by JSON payload alike
- `t/core/write-guard.t::test_self_protection` -> the hook settings, the kit's governance skills, the hooks, `.git/hooks` and other agents' rule files are denied; a user's own skill is allowed
- `t/core/write-guard.t::test_active_buffer_picks_the_plan` -> the bound plan's targets and Out of Bounds apply, not another plan's; two plans in development with no binding deny
- `t/core/write-guard.t::test_blocked_plan_grants_nothing` -> a blocked plan's own targets are denied
- `t/core/write-guard.t::test_guard_follows_adopter_statuses` -> adopter statuses from `aapp.planState.*` block or grant as the kit's do
- `t/core/write-guard.t::test_fails_open_on_bad_input` -> with no plans, garbage, empty or non-file payloads, and `SKIP_BLAST_RADIUS=1`, the guard allows; self-protection still holds
- `t/core/write-guard.t::test_deny_payload_schema` -> a denial prints the decision with `hookSpecificOutput` for PreToolUse and names the violation on stderr
- `t/core/write-guard.t::test_large_payload_denied` -> a payload over 300 KB is still denied with exit 2
- `t/core/write-guard.t::test_external_paths_and_precedence` -> agent memory, scratch and `aapp.allowPath` paths are allowed; other external paths are denied; self-protection and the hard-deny list win over the allowlist; traversal is closed; MultiEdit is enforced
- `t/core/write-guard.t::test_glob_targets` -> `*`, `**`, `?`, bracket classes and directory prefixes match as globs, in targets and Out of Bounds
- `t/core/write-guard.t::test_parser_boundaries` -> quoted and foreign-section paths are denied; Required Test Files are allowed
- `t/core/write-guard.t::test_only_in_development_plans_grant` -> a frozen plan restricts nothing on its own and grants nothing beside a plan in development; a retired status grants nothing
- `t/core/write-guard.t::test_active_verb_switches_plan` -> `aapp active <id>`, `swap` and `clear` move the guard from plan to plan
- `t/core/write-guard.t::test_freeze_start_grants_at_once` -> after `freeze-start` the plan's targets are allowed and other files denied
- `t/core/write-guard.t::test_linked_worktree_and_held_plans` -> a linked worktree reads the primary's plans; an unbound checkout neither writes nor adopts a plan held elsewhere
- `t/core/write-guard.t::test_workspace_worktree_reads_its_buffer` -> a `.workspace` worktree and the primary each follow their own binding, for files in subdirectories too
- `t/core/write-guard.t::test_plans_as_linked_worktree` -> with `.plans` a linked worktree, planning writes inside it are allowed and code outside the plan still denied
- `t/core/write-guard.t::test_pause_blocks_code_writes` -> while paused only pickup, issues and `current/` plans (and external scratch) are writable; after resume the targets are allowed again
