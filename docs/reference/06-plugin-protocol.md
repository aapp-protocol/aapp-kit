---
title: Plugin Protocol
description: The exchange between the kit and a supported plugin: what the kit sends, what the plugin answers, and what the kit does next.
category: reference
---

# Plugin Protocol

A supported plugin is one the kit calls by a reserved name (`aapp plugins` lists them). The kit and such a plugin talk in one way, described here. Each subject has its own page with its events, fields and commands: [issues](07-issue-protocol.md).

Plans are not covered yet: `aapp-planid` and its `plan.allocate` event keep the contract described in the [manual](../../MANUAL.md).

## The exchange

A step is a short exchange.

1. **The kit asks.** It runs the plugin and writes a JSON envelope to its standard input.
2. **The plugin does its work**, network included, and answers with one JSON object on standard output.
3. **The kit finishes** the local part: everything the plugin did not take care of, then the commands the plugin asked for.

## What the kit sends

```json
{
  "version": "1.0",
  "event": "issue.close",
  "timestamp": "2026-10-12T09:14:03Z",
  "actor": "lorand",
  "repository": {
    "root": "/path/to/project",
    "branch": "develop",
    "remote": { "name": "origin", "url": "git@github.com:acme/app.git" }
  },
  "data": { "id": "#79", "commit": "e07811f", "summary": "…", "plan": "P-32" },
  "extra": {}
}
```

| Field | Holds |
| :--- | :--- |
| `version` | The protocol version the kit speaks (`1.0`) |
| `event` | The step; each subject's page lists its events |
| `timestamp`, `actor` | When, and who ran the command |
| `repository.root`, `repository.branch` | The checkout that is calling |
| `repository.remote` | The project's remote (`aapp.remote`, default `origin`), with any credentials removed from the URL; `null` without a remote |
| `data` | The subject of the step; each subject's page lists its fields |
| `extra` | Reserved; always `{}`; the kit never reads it |

The plugin's environment also carries:

| Variable | Holds |
| :--- | :--- |
| `AAPP_ACTION` | The step's short name (`close`, `allocate`, …) |
| `AAPP_REPO_ROOT` | The repository root |
| `AAPP_PLUGIN_STEP` | The event; set for as long as the step runs |
| `AAPP_PLUGIN_LIST` | A file for answers with many items (see below) |
| `AAPP_PLUGIN_DO` | A file for the commands the plugin wants run (see below) |

## What the plugin answers

One flat JSON object. The exit code decides success: zero for an answer, non-zero for a failure.

```json
{ "status": "ok", "message": "Closed PROJ-101 on the tracker", "handled": "note", "id": "PROJ-101", "tracker": "jira" }
```

| Field | Values | Meaning |
| :--- | :--- | :--- |
| `status` | `ok`, `declined`, `failed` | `ok`: the plugin did its part. `declined`: not the plugin's; the kit does everything. `failed`: the same as a non-zero exit. Absent on a zero exit means `ok`. Any other word is read as `ok` and shown as given |
| `message` | one sentence | Shown to the user |
| `handled` | names separated by commas | What the plugin took care of. Whatever it does not name, the kit does; each subject's page lists the names per event |
| `id` | an id | What the plugin produced, where the event asks for one |
| `tracker`, `url` | text | The tracker's name and the subject's address there. Informational: shown, never interpreted |
| `version` | `1.0` | The protocol version the plugin speaks. An answer from a version newer than the kit's is refused |
| `error` | text | With a non-zero exit: why; shown to the user |

Anything else in the object is ignored. Output that is not a JSON object is rejected.

## Longer answers

Two files, both optional, named in the plugin's environment. Every line stands alone, so `cat` shows them.

**`AAPP_PLUGIN_LIST`**: one flat JSON object per line, in the shape of `data`. For a step that returns many items.

**`AAPP_PLUGIN_DO`**: the `do` list: aapp commands exactly as a person types them, one per line.

```
issue close 12 summary "closed on the tracker"
issue abort 14 reason "won't fix: superseded"
```

The kit runs them after the plugin has exited and the step is over and has released its lock:

- in order, through the same code the command line runs, each command taking the lock it needs;
- only the commands listed for the subject (its page has the list); any other line is refused and reported;
- a line that is refused is reported, and the rest still run;
- a command run this way does not call the plugin that asked for it.

## Rules

- **During a step, a plugin does not change the project through `aapp`.** A verb that writes, run from inside a step, is refused and names the `do` list. Verbs that only read work: `status`, `plan-status`, `plugins`, `hooks`, `help`, `version`, `issue list`, `issue next`, `note show`, `matrix check`.
- **Time.** A plugin has `aapp.pluginTimeout` seconds to answer (default 10). One that takes longer is ended and counts as failed.
- **No plugin installed.** The kit does everything.
- **A plugin that fails.** Each event says what follows: the kit carries on with a warning, or the command refuses.
- **Credentials are the plugin's.** The envelope carries none and the kit stores none. The plugin runs with the caller's environment and obtains its credentials as its deployment provides them. A missing or rejected credential is an ordinary failure with a clear `error`.
- **Behind its entry point a plugin is its own business.** The file in `.agents/skills/<name>/` is typically a thin caller of a service that lives elsewhere, where the credentials are. Keeping its own state, recognising a step it has already seen, and avoiding a second record when a step is sent again are the plugin's to do, for example by keeping its own hashes of the payloads it has handled. A tracker may create a record even when the kit saw a timeout; the kit does not try to prevent or detect that.
- **Ad hoc plugins and scripts** are outside this protocol. To the kit they are command-line users like any other, and the command line's own locks and checks are the only safeguard.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
