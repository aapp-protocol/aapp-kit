# help [<verb> [full]]

## Ingress
- no argument: the catalog of verbs, grouped by tier, from `lib/verbs.tsv`
- `<verb>` (positional): a verb of the catalog; prints its synopsis and its arguments, from its contract in `lib/docs/verbs/`
- `full` (bare token, after a verb): prints the verb's whole contract (refusals, effects, exit codes, tests)
- `aapp <verb> help` is the same command as `aapp help <verb>`: the dispatcher answers it before the verb runs
- reads: `lib/verbs.tsv` and the contracts of the installed kit
- reads config: none
- reads env: none

## Preconditions
- None: runs outside a Git repository too

## Failure modes
- `<verb>` is not in the catalog -> exit 1, stderr names `aapp help`
- `lib/verbs.tsv` is not found -> exit 1, stderr names `aapp install`
- the verb's contract file is missing -> exit 1, stderr names the file

## Effects (happy path)
- `aapp help <verb>`: first line `aapp <verb> <arguments>` (the contract's first line), then the contract's `## Ingress` lines, then a last line naming `aapp help <verb> full`
- a verb without a contract: one line, `aapp <verb> — <description>`
- `aapp <verb> help`: the verb does not run; nothing is written, drafted or committed
- writes nothing

## Exit
- 0 on success
- 1 on an unknown verb or a missing catalog or contract

## Tests
Run: `aapp test verb help`

- `tests/verbs/help.sh::test_help_verb_is_short` -> `aapp help commit` prints the synopsis and the Ingress lines, and no `## Failure modes` or `## Tests`
- `tests/verbs/help.sh::test_help_names_full` -> the short form's last line names `aapp help commit full`
- `tests/verbs/help.sh::test_help_verb_full` -> `aapp help commit full` prints the whole contract
- `tests/verbs/help.sh::test_help_after_verb` -> `aapp tdd help`, `aapp draft help` and `aapp issue help` print the verb's help, exit 0, and leave `.plans` without a new plan or commit
- `tests/verbs/help.sh::test_help_after_verb_without_contract` -> `aapp pause help` prints the verb's description and does not pause
- `tests/verbs/help.sh::test_help_unknown_verb` -> `aapp help nosuch` exits 1 naming `aapp help`
