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

## 2. Layered Configuration Hierarchy & Precedence

AAPP enforces an **inverted authority hierarchy** across three tiers: administrative policies defined at higher tiers strictly bind lower tiers and cannot be overridden locally by autonomous agents or repository-level git configuration.

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. System Level (/etc/aapp/main.conf)                        │
│    - Matching [aapp "repo:$REPO_ROOT"] (Highest authority)  │
│    - Global [aapp]                                          │
├─────────────────────────────────────────────────────────────┤
│ 2. User Level (~/.config/aapp/main.conf)                    │
│    - Matching [aapp "repo:$REPO_ROOT"]                      │
│    - Global [aapp]                                          │
├─────────────────────────────────────────────────────────────┤
│ 3. Repository Level (.git/config)                           │
│    - Local git config (Lowest authority)                   │
└─────────────────────────────────────────────────────────────┘
```

### Precedence Rules
1. **Inverted Authority (`System > User > Repo`)**: The highest tier defining a setting wins.
2. **Repository Subsections**: Within a given tier's `main.conf`, a subsection matching the project's primary root (`[aapp "repo:/path/to/project"]`) overrides that file's global defaults (`[aapp]`). Linked plan/fix worktrees (`.workspace/*`) automatically match against the primary checkout root.
3. **Multi-Valued Keys (`aapp.allowPath`, `aapp.hook.*`)**: The highest tier that sets the key supplies the complete set. Lower tiers cannot append or widen administrative allowlists.
4. **Clean Fallthrough**: Keys absent from upper tiers cleanly fall through to standard Git configuration resolution (`.git/config`, `~/.gitconfig`).

### Upper-Level Policy Allowlist
To protect monotonic state progression (such as `aapp.planId`, `aapp.issueId`, and `aapp.lastRelease`), upper-level `main.conf` files permit only administrative policies and safety ceilings:
- **Governance**: `aapp.governance`, `aapp.governanceHandler`, `aapp.governanceTimeout`
- **Attribution & Identity**: `aapp.aiAttribution`, `aapp.aiNotes`
- **Limits & Ceilings**: `aapp.fixMaxLines`, `aapp.fixMaxFiles`, `aapp.maxEmergencyHotfixes`, `aapp.subjectMaxLen`, `aapp.commitLineMaxLen`, `aapp.bodyMaxLen`
- **Runtime Environment & Hooks**: `aapp.quarantineIgnored`, `aapp.perlLogFile`, `aapp.allowPath`, and `aapp.hook.*`

Any unlisted key present in `main.conf` fails closed with diagnostic error:
`❌ [Config Refusal] /etc/aapp/main.conf: line 6: 'aapp.planId' is not allowed in upper-level configuration.`

### Example `main.conf`
```ini
# /etc/aapp/main.conf or ~/.config/aapp/main.conf

# Global administrative defaults for this tier
[aapp]
governance = hitl
aiAttribution = strict
subjectMaxLen = 72

# Project-specific policy override
[aapp "repo:/path/to/project"]
governance = autonomous
governanceHandler = /usr/local/bin/automated-gate
hook.pre-freeze = /usr/local/bin/security-audit
allowPath = /tmp/build-artifacts
```

### Inspecting Configuration Values & Origins
```bash
# Query active configuration value
git config aapp.governance

# Programmatic origin query via AAPP::Config::source($key)
# returns: 'system:repo', 'system:global', 'user:repo', 'user:global', or 'repository'
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
