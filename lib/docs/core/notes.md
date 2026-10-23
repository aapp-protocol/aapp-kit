# notes

## Tests
Run: `t/test-run notes`

- `t/core/notes.t::test_notes_land_in_their_own_ref` -> a staged developer note attaches to `refs/notes/commits` only, a staged AI note to `refs/notes/ai` only; removing one leaves the other
- `t/core/notes.t::test_note_appends_and_survives_amend` -> `attribution_note` appends to an existing AI note, and the note follows the commit through `git commit --amend`
- `t/core/notes.t::test_note_push_pull_union_merge` -> `aapp note push` puts the notes on the remote, `aapp note pull` brings them into another clone, and diverging AI notes merge by union
- `t/core/notes.t::test_note_pull_manual_conflict_fails_closed` -> a conflicting pull under the `manual` strategy exits non-zero and names how to resolve it
- `t/core/notes.t::test_note_audit_guard` -> `aapp.aiNotesGuard warn` warns about a lossy strategy, `enforce` refuses it, and lossless settings pass
