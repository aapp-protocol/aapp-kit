---
title: AI Attribution Suite & Multi-Vendor Switchboard
description: Multi-mode AI attribution, emailless semantic trailers, dual Git notes architecture, and credits generation in AAPP.
---

# 🤖 AI Attribution Suite & Multi-Vendor Switchboard

AAPP replaces legacy synthetic co-author email trailers (`Co-authored-by: Agent <agent@vendor.com>`) with an explicit, multi-mode AI attribution suite governed by repository configuration (`git config aapp.aiAttribution`).

---

## Attribution Models: Trailers vs. Notes Asymmetry

Public git servers (such as GitHub) scan commit trailers for `Co-authored-by:` email addresses. When synthetic addresses (such as `antigravity@google.com`) are present, GitHub matches unrelated accounts in its global registry that verified that email, permanently misattributing repository contributions. Furthermore, human email addresses force external account linkage.

AAPP introduces two distinct, purpose-driven attribution channels:

| Mode | Command | Target Ref / Layer | Visibility & Durability |
| :--- | :--- | :--- | :--- |
| `none` | `aapp ai none` | Working tree only | **Default. Pure human authoring until opted in.** Accidental AI trailers are blocked by `commit-msg`. |
| `lax` | `aapp ai lax` | Commit object trailers | **Recommended when opting in. Mixed human/AI work.** Validates emailless trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) when present; human commits pass freely without trailers. |
| `strict` | `aapp ai strict` | Commit object trailers | **Autonomous agent trace.** Every commit must carry valid emailless semantic trailers. Parallel notes attach when provided or when `aapp.aiNotes=true`. |
| `notes` | `aapp ai notes` | `refs/notes/ai` | **Private-first attribution.** Commit messages remain pristine and human-only. Metadata attaches via Git notes. |

---

## The Switchboard Command Family

The `aapp ai` command family manages configuration and credits without manual config editing:

- **`aapp ai status`**: Displays active attribution mode, `aapp.aiNotes` policy, `aapp.subjectMaxLen`, `aapp.aiCredits` toggle status, and scans for pending note buffers reporting count, message hash, and age.
- **`aapp ai lax`**: Enables lax attribution (validates trailers if present; human commits pass freely; parallel notes attach when provided).
- **`aapp ai strict`**: Enables strict attribution (requires valid trailers on every commit; parallel notes attach when provided).
- **`aapp ai notes [on|off]`**: Switches to private git notes mode, or toggles parallel AI Git Notes (`aapp.aiNotes = true|false`) so AI commits automatically record traces in `refs/notes/ai`.
- **`aapp ai none`**: Disables AI attribution (pure human authoring; does not erase existing `README.md` blocks).
- **`aapp ai credits`**: Generates or updates the `AI Contributors` block in `README.md`.

---

## Commit & Changelog Conciseness Invariants

Every commit message and staged changelog is evaluated mechanically by `.githooks/aapp-pre-commit` and `.githooks/aapp-commit-msg`:

1. **Changelog Single-Line Bullet Invariant**: Every bullet added to `CHANGELOG.md` (or `.plans/CHANGELOG.md`) must be a single line starting with `- ` (or `* `) and not exceed 300 characters (`git config aapp.changelogMaxLen`). Unbulleted continuation lines and multi-line indented paragraphs are strictly refused to prevent bloated essay wrapping.
2. **Numeric Commit Conciseness & Structure Invariants**:
   - **Subject Length**: Must not exceed 72 characters (`git config aapp.subjectMaxLen`) and be written in the imperative mood (`feat: ...`, `fix: ...`).
   - **Blank Separator Line**: Line 2 must be blank if a body is present. Text immediately following the subject line without an empty line breaks `git log --oneline` and is rejected.
   - **Line Width**: No individual line in the commit body may exceed 100 characters (`git config aapp.commitLineMaxLen`), except for lines containing unbroken URLs.
   - **Body Volume**: Total commit body volume must not exceed 1,200 characters (`git config aapp.bodyMaxLen`) and 20 lines (`git config aapp.maxBodyLines`), excluding trailing metadata/trailers.
3. **Attribution Policy & Revert Safety**:
   - In `lax` mode, trailers are optional; when present, all three emailless fields (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) are validated.
   - In `strict` mode, all three emailless trailers are mandatory on every commit.
   - In `none` and `notes` modes, AI trailers in the commit message are prohibited.
   - In all modes, synthetic vendor email addresses (`Co-authored-by:`) are strictly prohibited.
   - Revert commits (`Revert "..."` or containing `This reverts commit <sha>`) are automatically exempted from conciseness and attribution gates.

---

## Option C Staged Note Protocol & Amend Durability

In `notes` mode, notes are staged prior to committing to prevent concurrent staging collisions or stale misattribution:

1. **Buffer Staging**: The note is saved to `$(git rev-parse --git-path aapp_pending_note).<msg-sha256>`.
2. **Byte-Faithful Hashing Invariant**: Message hashes are computed from the exact commit object bytes:
   ```bash
   git cat-file commit HEAD | sed '1,/^$/d' | sha256sum | awk '{print $1}'
   ```
3. **Atomic Attachment & Failure Safety**: `post-commit` attaches the note via `git notes add -f -F` and unlinks the buffer **only on success (`&&`)**. On failure, the buffer is preserved on disk.
4. **TTL Sweep**: `post-commit` reaps orphaned notes older than `aapp.noteTTL` (default 1440m / 24h) via `find ... -mmin +TTL -exec rm -f {} +`.
5. **Amend Durability**: `notes.rewriteRef` (containing both `refs/notes/commits` and `refs/notes/ai`) ensures git copies notes to the new SHA during `git commit --amend` and `git rebase`.

---

## General-Purpose Git Notes Subsystem (`aapp note`)

AAPP provides a general-purpose Git Notes infrastructure decoupled from AI attribution modes, supporting both developer/review notes and immutable AI audit traces:

### Two Fixed Notes Namespaces
1. **`refs/notes/commits` (Developer Notes)**:
   - General developer notes, code review annotations, benchmark logs, and descriptions.
   - Visible by default in standard `git log`.
2. **`refs/notes/ai` (AI Audit Traces)**:
   - Private agent identity headers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) and autonomous traces.
   - Configured once during setup via `notes.displayRef = refs/notes/ai` so standard `git log` displays both namespaces without special flags.
   - Isolated: A human editing or removing a note in `refs/notes/commits` cannot delete or tamper with the AI audit trail in `refs/notes/ai`.

### Note CLI Commands (`aapp note`)
- **`aapp note status`**: Inspects configured notes remote, active merge strategies, rewrite settings, audit guard status, and pending note buffers.
- **`aapp note stage "<text>" [msg "<commit-msg>"] [agent <A> vendor <V> model <M>]`**: Pre-stages a hash-keyed note buffer. Identity tokens route the note to `refs/notes/ai`; omitting identity routes to `refs/notes/commits`.
- **`aapp note push [remote]`**: Pushes local notes refs (`refs/notes/commits`, `refs/notes/ai`) to target remote without force.
- **`aapp note pull [remote]`**: Fetches remote notes into tracking namespace and merges into local refs (defaulting to `union` merge).

---

## The AI Contributors Roster (`README.md`)

When `aapp ai credits` runs under `lax` or `strict` mode:
- **Union, never subtraction**: `new roster = existing block ∪ git history trailers`. Names are never removed.
- **Deterministic ordering**: Sorted with `LC_ALL=C sort -u`.
- **Byte-identical when unchanged**: Contains no timestamps, durations, or commit counts that dirty git status.
- **Alias map normalization**: Renames or merges duplicate identities via `git config --add aapp.aiAlias "Claude Code=Claude"`.

> [!IMPORTANT]
> In `notes` mode, `aapp ai credits` exits with an explanatory notice without modifying `README.md`. Choosing private notes keeps AI involvement internal; publishing a distilled roster would defeat that privacy choice.

**Settings on this page:** [Attribution & Notes](03-configuration-matrix.md#attribution--notes) · [Commits & Changelog](03-configuration-matrix.md#commits--changelog)

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
