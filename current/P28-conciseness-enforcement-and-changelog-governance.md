# 🗺️ Plan P-28: Conciseness Enforcement & Changelog Governance
* **Created:** 2026-09-21 | **Last Refined:** 2026-09-21
* **Target Issue / Milestone:** #76
* **Plan ID:** P-28
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

During recent development sessions, autonomous coding agents (notably Claude Code) developed a pattern of severe verbosity bloat across two primary surfaces:
1. **`CHANGELOG.md` Entries**: Single bullet points under `## [Unreleased]` ballooned into 1,000–2,000 character architectural dissertations detailing internal regexes, file paths, and AST nuances on a single line.
2. **Commit Message Bodies**: Full multi-page implementation walkthroughs and transcript duplicates were pasted into commit message bodies, degrading `git log` readability and duplicating what is already canonically recorded in `.plans/` blueprints.

Because `aapp status` reads `CHANGELOG.md` to construct Pillar 1 (`[1/4] SHIPPED (Recently Landed / Unreleased)`), these bloated entries cause the Context Recovery Briefing to explode across multiple terminal screens (>100 wrapped lines), obscuring active issues, active plans, and pickup ideas.

Attempting to filter or truncate these bloated entries at display time in `lib/cmd_status.sh` is an anti-pattern: arbitrary string slicing or truncation chops thoughts mid-sentence and loses the core semantic essence of what shipped.

The correct architectural remedy is **mechanical enforcement at the commit boundary**:
- Enforce changelog line/bullet length in Layer 2 `pre-commit` (`templates/aapp-pre-commit`).
- Enforce commit message body length in `commit-msg` (`templates/aapp-commit-msg`).
- Codify explicit conciseness invariants in `.agents/AGENTS.md` and `templates/AGENTS.md`.
- Remediate existing bloated entries in `CHANGELOG.md` into crisp 1–2 sentence Keep a Changelog entries.

---

## 2. Technical Blueprint

### §2.1 The Root Cause & Boundary Philosophy
- **Separation of Concerns**:
  - `CHANGELOG.md` serves human operators and end users. It answers: *What capability or fix landed?* in 1–2 concise sentences.
  - `.plans/current/<plan>.md` and `.plans/done/<plan>.md` are the canonical architectural records. They answer: *How was it designed, what were the tradeoffs, and what is the blast radius?*
  - `git commit` messages record the atomic changeset summary (*why* and *what*), referencing the blueprint for comprehensive architectural context.
- **Fail-Closed Mechanical Gate**: Autonomous agents do not reliably adhere to subjective prose guidelines ("be concise") without deterministic gates. Mechanical pre-commit and commit-msg gates provide inescapable boundary walls.

### §2.2 Pre-Commit Gate: Changelog Single-Line Bullet Conciseness Check
In `templates/aapp-pre-commit`:
1. When `CHANGELOG.md` or `.plans/CHANGELOG.md` is staged in the index:
   - Extract newly added lines via `git diff --cached -U0 "$CHANGELOG_FILE" | grep '^+[^+]'`.
   - Strip the leading diff `+` from each line (`line="${raw_line#+}"`).
2. Filter & Validate Line Invariants:
   - **Skip**: Empty/whitespace-only lines, Markdown headers (`^#+[[:space:]]`), and footer link references (`^\[[^]]+\]:[[:space:]]`).
   - **Rule 1 (Shape Invariant)**: Every content line added to a changelog section MUST start with a list marker (`^[[:space:]]*[-*][[:space:]]+`). Unbulleted or indented continuation lines are strictly refused to prevent multi-line essay wrapping.
   - **Rule 2 (Bullet Length Ceiling)**: Read `MAX_CHANGELOG_LEN="$(git config --int aapp.changelogMaxLen 2>/dev/null || echo "300")"`. If any added bullet line exceeds `MAX_CHANGELOG_LEN` characters:
     - Refuse commit with exit code 1.
     - Print clear advisory guidance:
       ```text
       ❌ [Pre-Commit Error] Changelog bullet exceeds maximum length ($LINE_LEN > $MAX_CHANGELOG_LEN chars)!
          Line: <line snippet...>
          👉 Keep a Changelog requires concise, single-line bullet points (<= $MAX_CHANGELOG_LEN chars).
          👉 Move technical blueprints, file lists, and internal implementation mechanics to .plans/ blueprints.
       ```

### §2.3 Commit-Msg Gate: Body Length, Shape & Blank Line Invariants
In `templates/aapp-commit-msg`:
1. **Revert Exemption**: Evaluate revert commit patterns (`^Revert "` or `^This reverts commit`) first so automated reverts are exempt from body length and trailer rules.
2. **Check 1: Subject Length & Shape**: Enforce `aapp.subjectMaxLen` (default 72 chars).
3. **Check 1b: Blank Separator Line**: If a commit body exists, line 2 MUST be empty. Text on line 2 breaks standard `git log --oneline` parsing and is refused.
4. **Check 1c: Body Conciseness & Unwrapped Line Ceiling**:
   - Strip comments (`^[[:space:]]*#`), leading/trailing blank lines, and trailing trailer blocks (`^[A-Za-z0-9-]+:[[:space:]]`).
   - Read configuration thresholds:
     - `MAX_BODY_LEN="$(git config --int aapp.bodyMaxLen 2>/dev/null || echo "1200")"`
     - `MAX_BODY_LINES="$(git config --int aapp.maxBodyLines 2>/dev/null || echo "20")"`
     - `MAX_LINE_LEN="$(git config --int aapp.commitLineMaxLen 2>/dev/null || echo "100")"`
   - **Line Width Check**: If any body line exceeds `MAX_LINE_LEN` characters (and does not contain an unbroken URL `https?://`), refuse commit to prevent unwrapped horizontal scrolling in git logs.
   - **Total Volume Check**: If remaining body text exceeds `MAX_BODY_LEN` characters or `MAX_BODY_LINES` lines:
     - Refuse commit with exit code 1.
     - Print clear advisory guidance:
       ```text
       ❌ [Commit-Msg Violation] Commit message body exceeds conciseness limit ($BODY_LEN > $MAX_BODY_LEN chars / $LINE_COUNT > $MAX_BODY_LINES lines)!
          👉 Keep commit bodies focused on *why* and *what* concisely.
          👉 Detailed technical architecture belongs in canonical blueprints (.plans/current/<plan>.md).
       ```

### §2.4 Agent Rules Invariant Updates
In `templates/AGENTS.md` and `.agents/AGENTS.md`:
1. **Code Verification & Changelog Rule**:
   - Codify the **Changelog Single-Line Bullet Invariant**:
     - Every entry is a concise, single-line bullet starting with `- ` (strictly <= 300 characters).
     - Unbulleted continuation lines and multi-line indented paragraphs are strictly prohibited.
     - Prohibit listing extensive file lists or code signatures in changelog bullets.
2. **Numeric Commit Conciseness Invariant**:
   - Expand the rule to explicitly cover:
     - Subject: Imperative, <= 72 chars.
     - Separator: Empty line 2 before body.
     - Body: <= 1,200 chars, <= 20 lines, wrapped at <= 100 chars/line.
     - Reiterate that commit bodies must not reproduce implementation blueprints or redundant file summaries.

### §2.5 Remediation: Condense Existing `CHANGELOG.md`
- Condense the bloated single-bullet essays in `CHANGELOG.md` under `## [Unreleased]` (lines 13, 14, 15, 16, 28, 29, 31, 34) into standard 1–2 sentence Keep a Changelog entries.
- Verify that running `aapp status` produces a clean, high-density briefing where Pillar 1 takes fewer than 15 lines total.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Existing repos continue to function; setting `aapp.changelogMaxLen`, `aapp.bodyMaxLen`, or `aapp.commitLineMaxLen` allows projects to adjust limits if specifically desired.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pre-Commit & Commit-Msg Hook Gates
- [ ] Task 1.1: Update `templates/aapp-pre-commit` to inspect added changelog lines: verify leading `- ` shape and check length against `aapp.changelogMaxLen` (default 300 chars).
- [ ] Task 1.2: Update `templates/aapp-commit-msg` to check blank line 2, line width against `aapp.commitLineMaxLen` (default 100 chars), and body volume against `aapp.bodyMaxLen` (default 1200 chars) / `aapp.maxBodyLines` (default 20 lines), excluding semantic trailers and exempting reverts.
- [ ] Task 1.3: Synchronize `.githooks/aapp-pre-commit` and `.githooks/aapp-commit-msg` in the local development environment (via `aapp develop` / copy).

### Phase 2: Agent Rules & Documentation
- [ ] Task 2.1: Update `templates/AGENTS.md` and `.agents/AGENTS.md` with the Changelog Single-Line Bullet Invariant and expanded Numeric Commit Conciseness Invariant.
- [ ] Task 2.2: Document `aapp.changelogMaxLen`, `aapp.bodyMaxLen`, `aapp.maxBodyLines`, and `aapp.commitLineMaxLen` in `MANUAL.md`.

### Phase 3: Historical Remediation & Verification
- [ ] Task 3.1: Condense bloated unreleased entries in `CHANGELOG.md` to crisp Keep a Changelog bullets.
- [ ] Task 3.2: Add automated tests in `tests/pre-commit_test.sh` for changelog length gate (rejection on overly long bullets and unbulleted continuation lines, acceptance on valid bullets).
- [ ] Task 3.3: Add automated tests in `tests/ai_attribution_test.sh` for commit message blank line 2, line width, and body length gates.
- [ ] Task 3.4: Verify `aapp status` renders a concise, 1-screen briefing across all 4 pillars.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/aapp-pre-commit` -> Add changelog bullet length ceiling check (`aapp.changelogMaxLen`).
- [ ] `templates/aapp-commit-msg` -> Add commit message body length ceiling check (`aapp.bodyMaxLen`).
- [ ] `templates/AGENTS.md` -> Codify Changelog Conciseness Invariant and expand Commit Conciseness Invariant.
- [ ] `.agents/AGENTS.md` -> Codify Changelog Conciseness Invariant and expand Commit Conciseness Invariant.
- [ ] `CHANGELOG.md` -> Condense verbose unreleased bullet essays into concise 1-2 sentence Keep a Changelog entries.
- [ ] `MANUAL.md` -> Document `aapp.changelogMaxLen`, `aapp.bodyMaxLen`, and `aapp.maxBodyLines` configuration parameters.
- [ ] `tests/pre-commit_test.sh` -> Add automated test cases verifying changelog length rejection and pass behavior.
- [ ] `tests/ai_attribution_test.sh` -> Add automated test cases verifying commit body length rejection and pass behavior.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_status.sh` -> Display logic remains clean and unmodified; conciseness is enforced at the source.
- [ ] `lib/plan_resolver.sh` -> Plan resolution engine is unaffected.

---

## ❓ 5. Open Questions & Design Decisions

1. **Default Threshold for Changelog Bullet Length & Single-Line Shape**:
   - *Decision*: `300` characters (configurable via `git config aapp.changelogMaxLen`). Every entry must start with `- ` on a single line; unbulleted continuation lines are prohibited to prevent wrapping 1,000+ char paragraphs.
   - *Rationale*: A typical concise sentence is 80–120 characters. 300 characters easily accommodates a title, target reference, and a thorough 2-sentence summary while strictly blocking multi-line essay paragraphs.

2. **Default Threshold for Commit Body Length & Line Wrapping**:
   - *Decision*: `1,200` characters / `20` lines (configurable via `git config aapp.bodyMaxLen` and `aapp.maxBodyLines`), with individual line width capped at `100` characters (configurable via `git config aapp.commitLineMaxLen`, URLs exempt).
   - *Rationale*: Generous enough for multi-paragraph explanations of *why* and *what*, but firmly blocks agents from dumping multi-page file-by-file walkthroughs into commit messages or writing unwrapped single-line blocks.

3. **Revert Exemption & Line 2 Blank Invariant**:
   - *Decision*: Commits matching standard git revert patterns are exempt from body length gates. If a body exists, Line 2 must be empty to conform to standard git oneline parsing.

---

## 📦 6. Change Log & Refinement History

- **2026-09-21**: Initial draft of Plan P-28 created to address Issue #76, establishing mechanical conciseness gates in `pre-commit` and `commit-msg`, agent invariants in `AGENTS.md`, and remediation of `CHANGELOG.md`.
- **2026-09-29**: Refined §2.2 with Single-Line Bullet Invariant (blocking unbulleted continuation lines), refined §2.3 with commit line width ceilings (`aapp.commitLineMaxLen`), line 2 blank invariant, and revert exemption ordering.
