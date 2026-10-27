---
title: Configuration Hierarchy Reference
description: Where aapp settings come from, how system and user main.conf files are layered over the repository's git config, and which keys those files may set.
---

# 🗂️ Configuration Hierarchy Reference

Every setting is an `aapp.*` key; what each key does and accepts is [03. Configuration Reference](03-configuration-matrix.md). This page covers where a value comes from.

---

## 1. Git Configuration

In a repository, settings are ordinary Git configuration:

```bash
git config aapp.commitMode                 # read one setting
git config aapp.commitMode microcommits    # set it for this repository
git config --global aapp.aiAttribution lax # set a default for all your repositories
git config --get-regexp '^aapp\.'          # list every aapp setting in effect
git config --unset aapp.commitMode         # back to the default
```

Git's own order applies: the repository's `.git/config` (and worktree config) over your `~/.gitconfig` over the system's `/etc/gitconfig`. A key set nowhere takes the default listed in 03.

A few keys are per worktree and read only with `git config --worktree` (`aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`), so each plan worktree can carry its own agent identity.

---

## 2. System and User Policy Files (`main.conf`)

Above Git configuration, an administrator (system file) or a person (user file) can set policy that a repository, and an agent working in it, cannot override:

| Level | File (Linux, BSD) | macOS | Windows |
| :--- | :--- | :--- | :--- |
| System (highest) | `/etc/aapp/main.conf` | `/Library/Application Support/aapp/main.conf` | `%ProgramData%\aapp\main.conf` |
| User | `$XDG_CONFIG_HOME/aapp/main.conf` (`~/.config/aapp/main.conf`) | as Linux | `%APPDATA%\aapp\main.conf` |
| Repository (lowest) | Git configuration (§1) | | |

`AAPP_SYS_CONF_DIR` and `AAPP_USER_CONF_DIR` point the kit at other folders (used by the kit's tests).

**Today these files are read by the kit's Perl core only.** The bash verbs read Git configuration directly, so a `main.conf` value reaches only the parts already ported to Perl (for example `aapp.jsonLocalPath` in JSON output, `aapp.perlLogFile`). When the Perl port replaces the bash verbs, the hierarchy applies to every setting.

### Precedence
1. **Higher level wins:** system over user over repository. The highest level that sets a key decides its value.
2. **Repository sections:** inside one `main.conf`, a section for this repository, `[aapp "repo:<path>"]`, wins over that file's plain `[aapp]` section. `<path>` is the primary checkout; plan and fix worktrees under `.workspace/` match it too. Sections for other repositories are skipped.
3. **Multi-valued keys** (`aapp.allowPath`, `aapp.hook.<event>`): the highest level that sets the key supplies the whole list; lower levels cannot add to it.
4. **Fall-through:** a key no `main.conf` sets is read from Git configuration (§1).

### Keys a `main.conf` may set
Only policy and safety limits; counters and repository state (`aapp.planId`, `aapp.issueId`, …) stay with the repository:

- **Attribution:** `aapp.aiAttribution`, `aapp.aiNotes`
- **Limits:** `aapp.fixMaxFiles`, `aapp.fixMaxLines`, `aapp.maxEmergencyHotfixes`, `aapp.subjectMaxLen`, `aapp.commitLineMaxLen`, `aapp.bodyMaxLen`
- **Runtime:** `aapp.quarantineIgnored`, `aapp.perlLogFile`, `aapp.allowPath`, `aapp.hook.<event>`
- **Reserved:** `aapp.governance`, `aapp.governanceHandler`, `aapp.governanceTimeout` are accepted for the lifecycle governance being built in the Perl port; they have no effect yet.

Any other key in a `main.conf` stops the kit with the file, line and key:
`❌ [Config Refusal] /etc/aapp/main.conf: line 6: 'aapp.planId' is not allowed in upper-level configuration.`
A malformed line stops it the same way, with the file and line.

### Example
```ini
# ~/.config/aapp/main.conf

# Defaults for every repository
[aapp]
aiAttribution = strict
subjectMaxLen = 72

# One repository
[aapp "repo:/srv/projects/shop"]
hook.pre-freeze = /usr/local/bin/security-audit
allowPath = /tmp/build-artifacts
```

### Where a value came from
The Perl core records the level each value came from: `system:repo`, `system:global`, `user:repo`, `user:global` or `repository` (`AAPP::Config::source($key)`).

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Reference](03-configuration-matrix.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
