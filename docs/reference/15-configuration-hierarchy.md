---
title: Configuration Hierarchy & Resolution Reference
description: Specification of Git configuration keys, resolution hierarchy, default values, and environment variables in AAPP.
---

# ⚙️ Configuration Hierarchy & Resolution Reference

AAPP relies on Git's native configuration database (`git config`) as its authoritative configuration store. This guarantees zero custom config files, seamless multi-worktree inheritance, and full compatibility with standard Git workflows.

---

## 1. Complete Git Config Key Catalog

All AAPP configuration settings reside under the `aapp.*` namespace:

| Config Key | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `aapp.aiAttribution` | `enum` | `none` | Attribution policy: `none` (human-only), `lax` (optional trailers), `strict` (mandatory trailers), `notes` (private notes). |
| `aapp.aiNotes` | `boolean` | `false` | When true, parallel AI audit traces are automatically staged to `refs/notes/ai`. |
| `aapp.allowPath` | `path` | `""` | Multi-value list of additional paths permitted outside plan target files (e.g. scratch directories). |
| `aapp.allowVendor` | `string` | `""` | Comma-separated list of approved AI vendors (e.g., `Anthropic,Google,OpenAI`). |
| `aapp.bodyMaxLen` | `integer` | `1200` | Maximum allowed character count for git commit bodies. |
| `aapp.branchParity` | `boolean` | `true` | When true, `aapp release` and verification tools enforce `main` and active branch parity. |
| `aapp.changelogFile` | `path` | `CHANGELOG.md` | Canonical path to the project changelog file. |
| `aapp.changelogMaxLen` | `integer` | `300` | Maximum character length for an individual changelog bullet line. |
| `aapp.changelogMode` | `enum` | `plan` | Changelog management strategy: `plan` (one bullet per plan) or `commit` (bullet per commit). |
| `aapp.commitLineMaxLen` | `integer` | `100` | Maximum character length for lines within a commit body. |
| `aapp.commitMode` | `enum` | `atomic` | Plan commit policy: `atomic` (single folded commit) or `microcommits` (incremental commits). |
| `aapp.copilotReview` | `boolean` | `false` | When true, triggers automated GitHub Copilot code review integration upon commit. |
| `aapp.issueArchiveMax` | `integer` | `100` | Maximum number of closed issue rows stored per archive file before rolling over to numbered ledgers. |
| `aapp.issueFixWait` | `integer` | `5` | Minutes `aapp issue fix` will wait to acquire worktree lock if another fix is active. |
| `aapp.maxBodyLines` | `integer` | `20` | Maximum number of lines permitted in a git commit body. |
| `aapp.notesScope` | `string` | `ai,commits` | Target Git notes namespaces used for attribution and review traces. |
| `aapp.pickupTitleMax` | `integer` | `72` | Maximum character length for ideation task titles in `pickup.md`. |
| `aapp.plansDir` | `path` | `.plans` | Canonical root directory containing plans, issues, and matrices. |
| `aapp.preReleaseGate` | `string` | `""` | Shell test command executed during `aapp release` preflight (e.g. `./aapp test strict quiet`). |
| `aapp.releaseBundling` | `boolean` | `true` | When true, bundles implemented plans and issue ledgers into `.plans/release/<tag>/` upon release. |
| `aapp.subjectMaxLen` | `integer` | `72` | Maximum character length for git commit subject lines. |
| `aapp.tagLedgerMax` | `integer` | `50` | Maximum number of releases cataloged per tag ledger file. |
| `aapp.worktreeRoot` | `path` | `.workspace` | Directory path where plan and fix worktrees are mounted. |

*Note: For the exhaustive tabular dictionary of all settings, flags, and defaults, see the [Configuration Matrix](03-configuration-matrix.md).*

---

## 2. Configuration Resolution Hierarchy

AAPP queries Git configuration following standard Git precedence order:

```text
Highest Priority:   1. Local Repository Config     (.git/config or worktree config)
                    2. Global User Config          (~/.gitconfig)
                    3. System Config               (/etc/gitconfig)
Lowest Priority:    4. Built-in Protocol Defaults  (hardcoded in lib/aapp-lib.sh)
```

### Inspecting & Setting Configuration Values

```bash
# Read a configuration setting
git config aapp.commitMode

# Set repository-local setting
git config aapp.commitMode microcommits

# Set global user default across all AAPP repos
git config --global aapp.aiAttribution lax

# List all active AAPP configuration keys
git config --get-regexp '^aapp\.'
```

---

## 3. Environment Variable Overrides

In automated environments (CI/CD pipelines, headless testing), specific environment variables take precedence over `git config`:

| Environment Variable | Description |
| :--- | :--- |
| `AAPP_TEST_ROOT` | Overrides the root directory for test fixtures and temporary execution. |
| `AAPP_TEST_FAIL_AT` | Injects synthetic failure traps during test execution to verify rollback logic. |
| `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` | Standard Git identity variables for commit creation. |

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Matrix](03-configuration-matrix.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
