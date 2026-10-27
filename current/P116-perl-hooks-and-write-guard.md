# 🗺️ Plan P-116: Perl Hooks And Write Guard
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-116
* **Changelog:** Changed: port `aapp-pre-commit`, `aapp-commit-msg`, `aapp-post-commit`, `aapp-post-rewrite`, `blast-radius-guard` and `AAPP::HookDispatcher` to Perl 5.26+ over `AAPP::State` with structured log event telemetry
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `9ad7108` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P116 (plan/P116-perl-hooks-and-write-guard)
* **Group:** P-111
* **Commits:** `300f58f` (plan/P116-perl-hooks-and-write-guard), `850223a` (plan/P116-perl-hooks-and-write-guard), `d020abf` (plan/P116-perl-hooks-and-write-guard), `5b605a4` (plan/P116-perl-hooks-and-write-guard), `7378bae` (plan/P116-perl-hooks-and-write-guard), `316d312` (plan/P116-perl-hooks-and-write-guard), `759889a` (plan/P116-perl-hooks-and-write-guard), `c9edad4` (plan/P116-perl-hooks-and-write-guard)
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
`pre-commit` alone accounts for ~25% of all process spawns (~130 processes per commit), reading the active-plan buffer 4×, looping `.plans/current/*.md` 4×, and spawning multiple `awk`/`sed`/`grep` pipelines per plan and ledger. Porting the Git hooks (`templates/aapp-pre-commit`, `templates/aapp-pre-commit-develop`, `templates/aapp-commit-msg`, `templates/aapp-post-commit`, `templates/aapp-post-rewrite`), `templates/blast-radius-guard.sh`, `lib/AAPP/HookDispatcher.pm` (`lib/hook_dispatcher.sh`, 509 lines), and `lib/AAPP/Attribution.pm` (`lib/attribution.sh`, 271 lines) to Perl 5.26+ as thin layers over `AAPP::State` (`P-115`) collapses ~130 process spawns per commit to 2–3 `git` queries.

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§2–§4):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (§4 Core Suites, Groups (b) & (c)):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (§4 D6 Group (b) Suites & Epoch E1):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 Hook Modules & Templates
1. **`lib/AAPP/HookDispatcher.pm` & `lib/AAPP/Attribution.pm`:**
   - `AAPP::HookDispatcher` ports `lib/hook_dispatcher.sh` (509 lines) to Perl using `Digest::SHA::sha256_hex` (in-process SHA-256 verification of `.agents/skills/aapp-hooks/registry.tsv`), process-group watchdog timeout (`aapp.hookTimeout` / `aapp.pluginTimeout`, exit 124 on timeout), and `AAPP::JSON` envelope/response handling (`build_event_envelope`, `run_action_plugin`, `AAPP_PLUGIN_LIST`, `AAPP_PLUGIN_DO` execution from `lib/plugin_do.tsv`).
   - `AAPP::Attribution` ports `lib/attribution.sh` (271 lines): `resolve_ai_identity`, `attribution_decorate`, `attribution_note`, `apply_agent_aliases`, `normalize_agent_identity`.
2. **`templates/aapp-pre-commit` & `templates/aapp-pre-commit-develop` (`lib/AAPP/Hooks/PreCommit.pm`, `PreCommitDevelop.pm`):**
   - `PreCommit` loads `AAPP::State` once and evaluates circuit breaker (`aapp_paused` / `PAUSED.md`), runtime reachability, parent integration lock check (`integrate/<parent>`), changelog rule (`plan` and `commit` modes), blocked/held/active plan resolution, TDD correspondence & test file existence, Target Files / Out of Bounds blast radius, frozen §2/§4/group-section design lock, portability (`file://` / home path) check, changelog bullet length check, group member `ARCHITECTURE.md` rule, roadmap auto-prune, active `ISSUES.md` resolved-row check, and atomic commit mode check in memory.
   - Missing Perl core: once its checks run in Perl, the pre-commit hook refuses the commit (exit 1, "Perl core missing … install the kit") when `perl` or `AAPP/JSON.pm` cannot be found in the kit's `lib/`, as the write guard refuses writes (exit 2). Until this plan, the bash hook uses Perl only for the pause reason and lets a commit through without the modules; the refusal belongs here, with the checks that need them (decided 2026-10-21 in P-115).
   - `PreCommitDevelop` ports `templates/aapp-pre-commit-develop` (seeded by `aapp develop` to run bidirectional contract correspondence when commits touch `lib/verbs.tsv`, `lib/docs/{verbs,core}/*.md`, or `t/{Verb,Core}/*.pm`).
3. **`templates/aapp-commit-msg`, `templates/aapp-post-commit`, `templates/aapp-post-rewrite` (`lib/AAPP/Hooks/CommitMsg.pm`, `PostCommit.pm`, `PostRewrite.pm`):**
   - Subject/line/body limits, `AI-*` trailer validation (`none`, `lax`, `strict`, `notes`, refusing retired `commit`), staged note attachment (`aapp_pending_note.<sha256>`), and post-rewrite `* **Commits:**` SHA mapping + `AAPP::CommitEngine::plans_commit`.
4. **`templates/blast-radius-guard.sh` (`lib/AAPP/Hooks/WriteGuard.pm`):**
   - Parses `PreToolUse` JSON stdin via `AAPP::JSON`, checks Section 1–5 (canonicalization, self-protection, external hard-deny/allowlist, G1 companion delegation, pause circuit breaker, always-allowed paths, and active/blocked/held plan Target Files) via `AAPP::State`.
5. **Modules from the installed kit:** Hook entrypoints load `AAPP::*` from the kit's `lib/`: `$AAPP_LIB` when an `aapp` verb runs the hook, else `${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib`. Nothing is copied into `.githooks/`. A guard that finds no `AAPP/JSON.pm` there refuses (exit 2). Once the hooks are Perl, they ask `AAPP::Paths::kit_dir()` (the one answer, OS-aware) instead of repeating the rule the bash templates spell out. (Decided in P-115, 2026-10-21.)
6. **Amendments (P-129):** the guard and the pre-commit hook port P-129's bash behaviour: the file of an approved amendment request naming the bound plan as requester is a target of that plan until its commit; the design lock accepts an owner's amendment lines (its Target Files line and its `### Amendments` line), in an archived owner too.

### 2.2 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §2–§4, all ported hook modules emit structured telemetry into `.git/aapp.log`:
1. `AAPP::HookDispatcher`: emits `hook.dispatch` (`kind => 'hook'|'plugin'`, `name => $name`, `step => $step`, `called => 1|0`, `skip_reason => $skip`, `status => 'ok'|'veto'|'timeout'|'failed'`, `payload_keys => \@keys`, `response => \%resp`).
2. `AAPP::Attribution`: emits `commits.decorate` (`mode => $mode`, `agent => $agent`, `vendor => $vendor`, `model => $model`, `trailers_added => 0|1`, `status => 'passed'|'refused'`) and `notes.attach` (`sha => $sha`, `ref => 'refs/notes/commits'|'refs/notes/ai'`, `action => 'add'|'rewrite'`, `text => $text`).
3. `AAPP::Hooks::WriteGuard`: emits `guard.check` (`decision => 'allow'|'deny'`, `path => $path`, `active_plan => $id`, `reason => $reason`).
4. `AAPP::Hooks::PreCommit`: emits `health.veto` (`pair => $pair`, `file => $file`, `reason => $reason`) and `guard.check` (`decision => 'deny'`, `path => $file`, `reason => 'self_protection'`).
*(Note: `commits.plans` is emitted by `AAPP::CommitEngine::plans_commit` in `P-115`/`P-133`; `post-commit` is emitted by `AAPP::Cmd::Commit->run` in `P-120`).*

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible` (Transitional bash/Perl coexistence within group `P-111` until `P-122`)
- **Fallback Inventory**:
  - `lib/hook_dispatcher.sh` and `lib/attribution.sh` are retained unchanged for unported bash verbs (`P-117`–`P-121`) and deleted in `P-122`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Hook Modules (`lib/AAPP/HookDispatcher.pm`, `lib/AAPP/Attribution.pm`, `lib/AAPP/Hooks/*.pm`)
- [x] Task 1.1: Implement `lib/AAPP/HookDispatcher.pm` and `lib/AAPP/Attribution.pm` (trailer validation, identity resolution, note staging, and `hook.dispatch` / `commits.decorate` / `notes.attach` event telemetry).
- [x] Task 1.2: Implement `lib/AAPP/Hooks/PreCommit.pm`, `lib/AAPP/Hooks/PreCommitDevelop.pm`, `lib/AAPP/Hooks/CommitMsg.pm`, `lib/AAPP/Hooks/PostCommit.pm`, `lib/AAPP/Hooks/PostRewrite.pm`, and `lib/AAPP/Hooks/WriteGuard.pm` over `AAPP::State` with `health.veto`, `guard.check`, and `notes.attach` telemetry.

### Phase 2: Hook Entrypoint Templates & Core Wrapper Tests
- [x] Task 2.1: Update `templates/aapp-pre-commit`, `templates/aapp-pre-commit-develop`, `templates/aapp-commit-msg`, `templates/aapp-post-commit`, `templates/aapp-post-rewrite`, `templates/blast-radius-guard.sh`, `templates/pre-commit`, `templates/commit-msg`, `templates/post-commit`, and `templates/post-rewrite` to invoke Perl, loading `AAPP::*` from the installed kit (item 5); `lib/cmd_init.sh` copies no Perl modules.
- [x] Task 2.2: Switch direct core wrapper calls in `t/core/hooks.t`, `t/core/write-guard.t`, and `t/core/pre-commit.t` to `AAPP::HookDispatcher`, `AAPP::Attribution`, `AAPP::Hooks::WriteGuard`, and `AAPP::Hooks::PreCommit`.
- [x] Task 2.3: Once the Perl core asks the `aapp-planid` provider, turn on `t/core/plan_resolver.t::test_plan_id_provider`: remove its skip and write its checks from its contract line (P-123 left it skipped, R28 in P-112).

### Phase 3: Verification
- [x] Task 3.1: Run `./aapp test strict quiet` and verify all hook, pre-commit, write-guard, attribution, and note tests pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/AAPP/HookDispatcher.pm` -> Lifecycle hook & plugin dispatcher in Perl (`Digest::SHA`, watchdog, `AAPP::JSON`).
- [ ] `NEW FILE` -> `lib/AAPP/Attribution.pm` -> AI attribution identity resolution, trailer validation, and staged note helpers in Perl.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/PreCommit.pm` -> Single-pass pre-commit enforcement over `AAPP::State`.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/PreCommitDevelop.pm` -> Develop-only contract correspondence pre-commit gate in Perl.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/CommitMsg.pm` -> Commit message conciseness and attribution gate in Perl.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/PostCommit.pm` -> Post-commit note attachment and event telemetry in Perl.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/PostRewrite.pm` -> Post-rewrite plan `Commits:` SHA mapping and `plans_commit` in Perl.
- [ ] `NEW FILE` -> `lib/AAPP/Hooks/WriteGuard.pm` -> Write-time `PreToolUse` blast-radius guard over `AAPP::State` and `AAPP::JSON`.
- [ ] `templates/aapp-pre-commit` -> Thin Perl entrypoint invoking `AAPP::Hooks::PreCommit`.
- [ ] `templates/aapp-pre-commit-develop` -> Thin Perl entrypoint invoking `AAPP::Hooks::PreCommitDevelop`.
- [ ] `templates/aapp-commit-msg` -> Thin Perl entrypoint invoking `AAPP::Hooks::CommitMsg`.
- [ ] `templates/aapp-post-commit` -> Thin Perl entrypoint invoking `AAPP::Hooks::PostCommit`.
- [ ] `templates/aapp-post-rewrite` -> Thin Perl entrypoint invoking `AAPP::Hooks::PostRewrite`.
- [ ] `templates/blast-radius-guard.sh` -> Thin Perl entrypoint invoking `AAPP::Hooks::WriteGuard`.
- [ ] `templates/pre-commit` -> Execute `aapp-pre-commit` directly.
- [ ] `templates/commit-msg` -> Execute `aapp-commit-msg` directly.
- [ ] `templates/post-commit` -> Execute `aapp-post-commit` directly.
- [ ] `templates/post-rewrite` -> Execute `aapp-post-rewrite` directly.
- [ ] `t/core/plan_resolver.t` -> Unskip `test_plan_id_provider` once Perl core asks provider (R28).
- [ ] `t/core/hooks.t` -> Switch core wrapper calls to `AAPP::HookDispatcher`.
- [ ] `t/core/write-guard.t` -> Switch core wrapper calls to `AAPP::Hooks::WriteGuard`.
- [ ] `t/core/pre-commit.t` -> Switch core wrapper calls to `AAPP::Hooks::PreCommit`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness runner is untouched.
- [ ] `tests/verbs/` -> The bash verb suites are untouched: they are the check during the ports (their Perl files come after, P-134, P-125).

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-26:** Verification sweeps completed; all core test suites passing (331/331 in t/test-run, 538/538 in ./aapp test); addressed review findings in HookDispatcher, WriteGuard, and PreCommit.
* **2026-10-25:** Plan activated into ⚡ In Development via start.
* **2026-10-25:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`hook.dispatch`, `commits.decorate`, `notes.attach`, `guard.check`, `health.veto`, `commits.plans`, `post-commit`), and target files with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan drafted as member 4 of group P-111 from settled RFC (`.plans/pickup/perl-port-rfc.md`).
* **2026-10-19:** Added `templates/aapp-pre-commit-develop` (`AAPP::Hooks::PreCommitDevelop`), registered `hook_dispatcher.sh`/`attribution.sh` coexistence in §2, and updated test paths to `t/*` per RFC §5.1.3 & §5.1.5.

