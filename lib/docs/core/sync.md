# sync

## Tests
Run: `t/test-run sync`

- `t/core/sync.t::test_init_seeds_sync_defaults` -> `aapp init` sets `aapp.remote origin`, all three worktrees, `ff-only` pulls and the `builtin` strategy
- `t/core/sync.t::test_push_pull_sync_round_trip` -> `push` puts the kit branches on the remote with upstream tracking; `pull` fast-forwards; `sync` pulls then pushes; a dirty worktree stops `pull` and `sync`; `push <remote>` and `aapp.syncWorktrees` choose where and what
- `t/core/sync.t::test_hook_strategy_and_precedence` -> the `hook` strategy without a handler is refused; a registered on-sync handler gets the action in its environment and the envelope on stdin; git config overrides the registry and a CLI token overrides git config
