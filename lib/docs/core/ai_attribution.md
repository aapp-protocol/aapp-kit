# ai_attribution

## Tests
Run: `t/test-run ai_attribution`

- `t/core/ai_attribution.t::test_init_defaults_and_hooks` -> `aapp init` sets attribution `none`, credits `false`, and installs the commit-msg and post-commit hooks executable
- `t/core/ai_attribution.t::test_ai_notes_leaves_remote_refspecs` -> `aapp ai notes`, run twice, adds no push or fetch refspec to the remote
- `t/core/ai_attribution.t::test_commit_msg_conciseness` -> the commit-msg hook refuses a subject over 72 characters (or `aapp.subjectMaxLen`), a missing blank line 2, a body line over 100 characters unless it holds a URL, and a body over 20 lines; a revert is exempt
- `t/core/ai_attribution.t::test_coauthor_refused_in_every_mode` -> a co-author trailer is refused in every attribution mode
- `t/core/ai_attribution.t::test_attribution_modes` -> `none` refuses AI trailers; `lax` takes a human commit and checks trailers present; `strict` requires all three, naming `aapp ai lax`, and lets a revert through; the retired `commit` mode is refused by name
- `t/core/ai_attribution.t::test_staged_note_attaches_to_its_commit` -> no staged note, no note; a staged note waits in a buffer keyed by the message, attaches to the matching commit verbatim, is unlinked, and survives an amend
- `t/core/ai_attribution.t::test_staged_note_kept_when_attaching_fails` -> a note that cannot be attached keeps its buffer
- `t/core/ai_attribution.t::test_stale_note_buffer_reaped` -> a buffer older than the TTL is removed at the next commit
- `t/core/ai_attribution.t::test_credits_follow_mode_and_history` -> `aapp ai credits` writes nothing in `none` and `notes`, keeps a hand-written block there, and in a trailer mode lists the union of block and history in byte order, stable on regeneration
- `t/core/ai_attribution.t::test_credits_refuse_broken_block` -> a credits block without its end tag, or with the tags inverted, is refused
- `t/core/ai_attribution.t::test_credits_alias_map` -> `aapp.aiAlias` merges a renamed identity into one entry
- `t/core/ai_attribution.t::test_identity_precedence` -> `resolve_ai_identity` takes parameters over the environment over worktree config, and never the repository config
- `t/core/ai_attribution.t::test_coauthor_converted_with_warning` -> a co-author trailer in the message becomes the identity, with a warning
- `t/core/ai_attribution.t::test_strict_decorate_without_identity_refused` -> `attribution_decorate` in `strict` without an identity fails
- `t/core/ai_attribution.t::test_note_text_without_identity_refused` -> `attribution_note` with text but no identity fails and says why
- `t/core/ai_attribution.t::test_note_identity_only_passes` -> `attribution_note` with an identity and no text writes the note
