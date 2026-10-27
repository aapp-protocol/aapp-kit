---
title: Plan ID Allocation Reference
description: How aapp draft takes a Plan ID, the local counter aapp.planId, the aapp-planid provider a team needs, its contract, and what happens when it fails.
---

# 🔢 Plan ID Allocation Reference

Every plan gets a Plan ID (`P-42`) when `aapp draft` creates it. IDs are **stored, not derived**: the kit hands out the next one from a counter or from a provider, never by scanning file names. Always draft with `aapp draft`; a plan file created by hand does not move the counter, and the next draft can reuse its number.

---

## 1. The Local Counter

`aapp.planId` ([settings](03-configuration-matrix.md#plans--worktrees)) holds the **next** id as a bare number; `P-` is added on output, to tell a plan (`P-22`) from an issue (`#22`).

```bash
git config --get aapp.planId     # the next id
```

- `aapp init` seeds it once, from the highest id in `.plans/current/`, `.plans/done/`, `.plans/aborted/` and the archive ledger (`1` in a new project). A number already there is left alone: running `init` again, or the `init` after `aapp upgrade`, never moves it.
- A value that is not a number is refused, never restarted at `P-1` (which would collide with existing plans). Run `aapp init` to seed it again.

---

## 2. Solo or Team

| Setup | What you need |
| :--- | :--- |
| **One person** | Nothing: the local counter is enough, as you are the only one handing out ids. |
| **More than one contributor** | An `aapp-planid` provider backed by one shared authority. Git configuration is never pushed, so two clones would otherwise hand out the same id. |

---

## 3. Installing a Provider

The provider is an action plugin you supply; it does not ship with `aapp init`. Its folder is `.agents/skills/aapp-planid/`, and the kit runs the first executable it finds there: `run`, `aapp-planid`, `scripts/run`, `scripts/aapp-planid`, or one of those with any extension (`.sample` files are skipped).

A reference is shipped in `examples/plugins/aapp-planid/`:

```bash
cp -r "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/examples/plugins/aapp-planid" .agents/skills/
mv .agents/skills/aapp-planid/run.sample .agents/skills/aapp-planid/run
chmod +x .agents/skills/aapp-planid/run
```

The folder name starts with `aapp-`, so it is a protected path: agents cannot rewrite your id authority ([13. Planning Health](13-planning-health-engine.md#3-protected-paths-pair-5)).

### Contract

| | |
| :--- | :--- |
| **stdin** | The plugin envelope with `"event": "plan.allocate"` ([06. Action Plugin Protocol](06-plugin-protocol.md)) |
| **stdout** | One JSON object: `{"id": "P-42"}` or `{"id": 42}`; anything else is refused |
| **exit 0** | The id is issued |
| **exit non-zero** | Refused; an optional `{"error": "<text>"}` is shown |

After each issued id, the local counter is moved past it, so the counter never falls behind the provider.

---

## 4. When the Provider Fails

Only a missing provider means the local counter is used. A provider that is installed and fails never falls back to the local counter, because that would bring back the collisions it exists to prevent. Instead:

- **Offline staging on** (`aapp.offlineEnabled`, the default): the draft takes a temporary id and is written to `.offline/current/`; `aapp offline sync` publishes it with a real id once the provider answers. A draft for an issue (`issue <num>`), a group, or a member of a group is refused offline, as it could not be linked yet.
- **Offline staging off:** the draft is refused.
- **Offline-only** (`aapp offline on`): the provider is not asked; every draft is staged.

Settings: [Offline](03-configuration-matrix.md#offline).

---

## 5. Security: Your Provider, Your Responsibility

The kit defines the contract above and nothing more. It does not inspect what a provider contains, and cannot: a provider may be any program.

- Anything committed to the repository is cloned and may be public. A credential placed in a provider stays in history.
- Keep the provider a one-line hand-over to a program outside the repository, as the shipped sample does:

  ```sh
  #!/bin/sh
  exec "${AAPP_PLANID_CMD:-$HOME/.local/bin/aapp-planid-provider}" "$@"
  ```

  `~/.local/bin/` is outside the folders agents may write to. Do not put the program in `~/.config` or `~/.local/share`: agents may write there.
- This is a documented responsibility, not something the kit can enforce.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🔌 [Action Plugin Protocol](06-plugin-protocol.md)
- ⚙️ [Configuration Reference](03-configuration-matrix.md#plans--worktrees)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
