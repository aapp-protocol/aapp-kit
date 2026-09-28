# note [status | stage "<text>" [agent <A> vendor <V> model <M>] [msg "<msg>"] | push [remote] | pull [remote]]

## Ingress
- positional forms:
    - `status` (default when no subcommands given): inspects notes remote, active merge strategies, rewrite settings, audit guard status, and pending note buffers
    - `stage "<text>" [options]`: pre-stages a note buffer in `.git/aapp_pending_note.<sha256>` keyed by planned commit message
    - `push [remote]`: pushes local notes refs (`refs/notes/commits`, `refs/notes/ai`) to target remote without force
    - `pull [remote]`: fetches remote notes into isolated tracking refs and merges into local notes refs (union default)
- stage options / tokens:
    - `msg "<commit-msg>"` or `--msg "<commit-msg>"`: planned commit message to compute key hash (required)
    - `agent <Agent>`: AI agent name (routes note to `refs/notes/ai`)
    - `vendor <Vendor>`: AI vendor name
    - `model <Model>`: AI model identifier
- configuration keys read:
    - `aapp.notesRemote`: target git remote for push/pull (unset = local-first)
    - `aapp.aiNotesGuard`: guard enforcement mode (`warn` or `enforce`)
    - `notes.mergeStrategy`, `notes.ai.mergeStrategy`, `notes.commits.mergeStrategy`: merge strategies
    - `notes.rewriteRef`, `notes.rewriteMode`: rewrite handling on amend/rebase

## Preconditions
- Inside a Git worktree of a Git repository
- For `stage`: planned commit message must be supplied (via `msg "<msg>"` or `--msg`)
- For `push` and `pull`: target remote must be provided as argument or configured via `aapp.notesRemote`

## Failure modes
- `stage` without planned commit message -> exit 1, stderr `A planned commit message is required to key the staged note buffer`
- `stage` with empty content/body -> exit 1, stderr `Note body content is empty`
- `push` with no remote configured or provided -> exit 1, stderr `No notes remote configured`
- `pull` with no remote configured or provided -> exit 1, stderr `No notes remote configured`
- `pull` encountering merge conflict under `manual` strategy -> exit 1, stderr `Merge conflict in <ref>`, naming `git notes merge --commit` / `--abort`
- `status` with lossy settings under `aapp.aiNotesGuard=enforce` -> exit 1, stderr `Audit Guard: ENFORCE Violation`

## Effects (happy path)
- safe setup initialization:
    - ensures `notes.rewriteRef` contains `refs/notes/commits` and `refs/notes/ai`
    - ensures `notes.displayRef` contains `refs/notes/ai`
    - configures `notes.ai.mergeStrategy` to `union` when unset
- `status`:
    - prints human-readable summary of notes configuration, guard state, and pending buffers
- `stage`:
    - creates `.git/aapp_pending_note.<hash>` with formatted note content
    - if identity tokens provided, prepends semantic `AI-Agent:` headers
- `push`:
    - executes non-forced git push for existing local notes refs to target remote
- `pull`:
    - fetches into `refs/notes/remote/<remote>/*` and merges into local notes refs without data loss

## Exit
- 0 on success
- non-zero on invalid arguments, missing remote, merge conflicts, or guard enforce violations

## Tests
Run: `aapp test verb note`

- `tests/verbs/note.sh::test_note_status_runs_cleanly` -> note status exits 0 and prints status block
- `tests/verbs/note.sh::test_note_stage_requires_message` -> staging without planned commit message exits 1 with diagnostic
- `tests/verbs/note.sh::test_note_stage_creates_buffer` -> staging with message creates hash-keyed buffer file
- `tests/verbs/note.sh::test_note_stage_ai_routes_to_ai_ref` -> staging with agent token formats AI headers
- `tests/verbs/note.sh::test_note_push_refuses_without_remote` -> push without remote exits 1
- `tests/verbs/note.sh::test_note_pull_refuses_without_remote` -> pull without remote exits 1
