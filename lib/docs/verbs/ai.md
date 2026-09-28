# ai [status | none | lax | strict | notes [on|off] | credits]

## Ingress
- positional forms:
    - `status` (default when no subcommands given): displays current attribution mode, enforcement policy, AI notes policy, and pending note buffers
    - `none`: switches attribution policy to pure human authoring (`aapp.aiAttribution = none`)
    - `lax`: switches attribution policy to mixed human/AI mode (`aapp.aiAttribution = lax`)
    - `strict`: switches attribution policy to mandatory trailers mode (`aapp.aiAttribution = strict`)
    - `notes [on|off]`: switches attribution policy to private git notes mode (`aapp.aiAttribution = notes`), or toggles parallel AI Git Notes (`aapp.aiNotes = true|false`)
    - `credits`: generates or updates the alphabetical AI Contributors block in README.md
- configuration keys read:
    - `aapp.aiAttribution`: current attribution policy mode (`none`, `lax`, `strict`, `notes`)
    - `aapp.aiNotes`: toggle for parallel AI Git Notes recording (`true`, `false`)
    - `aapp.aiCredits`: toggle for contributors block generation
    - `aapp.subjectMaxLen`: commit subject line conciseness limit
    - `aapp.aiAlias`: alias mapping for contributors reconciliation
- configuration keys written:
    - `aapp.aiAttribution`: set to the selected mode (`none`, `lax`, `strict`, `notes`)
    - `aapp.aiNotes`: set to `true` or `false` via `aapp ai notes [on|off]`

## Preconditions
- Inside a Git worktree of a Git repository

## Failure modes
- unknown subcommand or invalid mode -> exit 1, stderr `Unknown AI mode or command: '<input>'. Valid: status, none, lax, strict, notes, credits.`
- `credits` with corrupted or inverted markers in README.md -> exit 1, stderr naming corrupted block

## Effects (happy path)
- `status`:
    - prints human-readable summary of active attribution mode, AI notes policy, description, and pending note buffers
- `none`:
    - sets `aapp.aiAttribution = none` in git config
    - prints confirmation of disabled AI attribution
- `lax`:
    - sets `aapp.aiAttribution = lax` in git config
    - prints confirmation of mixed human/AI attribution mode
- `strict`:
    - sets `aapp.aiAttribution = strict` in git config
    - prints confirmation of strict AI attribution mode
- `notes`:
    - bare `notes`: sets `aapp.aiAttribution = notes` and `aapp.aiNotes = true`
    - `notes on`: sets `aapp.aiNotes = true` (enables parallel AI Git Notes)
    - `notes off`: sets `aapp.aiNotes = false` (disables parallel AI Git Notes)
- `credits`:
    - parses git log for attribution trailers, matches alias mappings, and updates `README.md`

## Exit
- 0 on success
- non-zero on unknown subcommand or corrupted markdown in credits

## Tests
Run: `aapp test verb ai`

- `tests/verbs/ai.sh::test_ai_status_default` -> `aapp ai` or `aapp ai status` prints status block and exits 0
- `tests/verbs/ai.sh::test_ai_mode_transitions` -> `aapp ai none/lax/strict/notes` sets git config and exits 0
- `tests/verbs/ai.sh::test_ai_refuses_invalid_subcommand` -> unknown subcommand exits 1 with diagnostic
- `tests/verbs/ai.sh::test_ai_refuses_legacy_off_alias` -> `aapp ai off` exits 1 per clean break
- `tests/verbs/ai.sh::test_ai_credits_runs_cleanly` -> `aapp ai credits` updates README.md or reports no-op
- `tests/verbs/ai.sh::test_ai_notes_preserves_notes_config` -> `aapp ai notes` preserves pre-existing rewriteRef and mergeStrategy
