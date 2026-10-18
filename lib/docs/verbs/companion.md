# companion [add <name> <path> [worktree] | add <name> <url> | status [name] | push <name> | remove <name> [force] | list]

## Ingress
- positional forms:
    - `add <name> <path> [worktree]`: registers an existing local checkout where it is, or creates a worktree under `.workspace/companion/<name>` for a non-AAPP repo
    - `add <name> <url>`: clones a remote repository URL into `.workspace/companion/<name>`
    - `status [name]`: offline status metrics (branch, dirty count, ahead/behind, last fetch)
    - `push <name>`: delegates push to configured upstream branch in companion repo
    - `remove <name> [force]`: unlinks checkout without deleting directory; removes worktree or clone (guarded against unpushed/uncommitted unless `force`)
    - `list`: lists all registered companions with topology mode and active branch
- reads config: `aapp.companion.<name>.path`, `aapp.companion.<name>.mode`, `aapp.allowPath`
- reads: companion git directory, refs, and working trees

## Preconditions
- Inside a Git repository
- `add`: name must be lowercase alphanumeric, dash, or underscore (`^[a-z0-9_-]+$`); name must not already exist
- `add <path>`: path must be a valid Git repository
- `add <path> worktree`: path must not be an AAPP repository (G2 refusal rule)
- `push <name>`: companion must be clean (`dirty == 0`) and have an upstream tracking branch configured

## Failure modes
- invalid companion name -> exit 1, diagnostic on stderr
- duplicate companion name -> exit 1, diagnostic naming existing path
- non-git path -> exit 1, diagnostic on stderr
- worktree mode on AAPP repository -> exit 1, G2 refusal naming `aapp start` and checkout mode
- push while dirty or without upstream branch -> exit 1, diagnostic on stderr
- remove worktree/clone with uncommitted or unpushed commits without force -> exit 1, diagnostic on stderr

## Effects (happy path)
- `add` checkout: records path and mode in `.git/config`, adds path to `aapp.allowPath`
- `add` worktree: creates `.workspace/companion/<name>` via `git worktree add`, records path/mode, adds to `aapp.allowPath`
- `add` clone: clones into `.workspace/companion/<name>`, records path/mode, adds to `aapp.allowPath`
- `status`: reports metrics without network access
- `push`: executes `git -C <path> push` to upstream
- `remove` checkout: unlinks git config and allowlist; preserves directory contents
- `remove` worktree/clone: prunes worktree or deletes clone directory, unlinks config and allowlist

## Exit
- 0 on success
- non-zero on validation error, refusal, or git failure

## Tests
Run: `aapp test verb companion`

- `tests/verbs/companion.sh::test_companion_add_checkout_validates_repo` -> registers existing repo and adds to allowlist
- `tests/verbs/companion.sh::test_companion_add_worktree_non_aapp` -> worktree mode creates worktree for non-AAPP repo
- `tests/verbs/companion.sh::test_companion_add_worktree_refuses_aapp_repo` -> worktree mode refuses AAPP repos per G2 with helpful guidance
- `tests/verbs/companion.sh::test_companion_status_offline_metrics` -> status reports dirty count, ahead/behind without network access
- `tests/verbs/companion.sh::test_companion_push_bounded` -> push delegates to git -C push, refusing dirty copy or unconfigured upstream
- `tests/verbs/companion.sh::test_companion_remove_checkout_unlinks_only` -> remove on checkout preserves directory and unregisters config
- `tests/verbs/companion.sh::test_companion_remove_worktree_guards_unpushed` -> remove on worktree refuses unpushed commits unless force specified
- `tests/verbs/companion.sh::test_companion_guard_delegation_aapp` -> blast-radius-guard delegates check to companion AAPP guard per G1
