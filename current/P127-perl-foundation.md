# 🗺️ Plan P-127: Perl Foundation
* **Created:** 2026-10-20 | **Last Refined:** 2026-10-20
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-127
* **Changelog:** Added: Perl 5.26+ foundation modules (`AAPP::Constants`, `AAPP::Paths`, `AAPP::Config`, `AAPP::Logger`, `AAPP::Runner`) with declared return numbers, signal and crash handling, and an optional log file (`aapp.perlLogFile`) (P-127)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `6cd81b1` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P127 (plan/P127-perl-foundation)
* **Group:** P-111
* **Commits:** `8e51e53` (plan/P127-perl-foundation)
<!-- AAPP-PROTOCOL:START v0.9.0 -->
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
The first member of the Perl port, before any test harness or verb: the core every later module and test stands on. Five modules under `lib/AAPP/`, modeled on `~/000/logsniffer/src/Logsniffer/` (`Runner.pm`, `Constants.pm`, `Logger.pm`), whose style is copied as-is: `use strict; use warnings; use 5.026;`, package variables for run state, one sub-header comment block per sub, brace on its own line for subs.

- **No sub dies on purpose.** Subs return declared numbers; the exit code is derived from them. `die` happens only on a crash, and the crash handler reports it.
- **Agents are never left in the dark.** Everything shown to an agent goes through one `printf` format; warnings and crashes print to STDERR when no log file is configured.
- **Logging is independent of hooks.** `AAPP::Logger` writes its own file (`aapp.perlLogFile`, optional); it never dispatches a hook. The key is `aapp.perlLogFile` while the port runs, apart from the event logger's `aapp.logFile`; P-122 renames it to `aapp.logFile` when the kit logs per event.
- **Config and paths are read once per process** and are used by the code and by the tests alike.

Nothing in the bash kit is switched here: the modules exist and are tested by the harness member (P-126); P-115 onward use them. Verbosity levels (a debug setting) are out of scope: `DEBUG_LEVEL` is a fixed constant for now.

---

## 2. Technical Blueprint

### 2.1 Comment rule (all Perl code of the port)
Every sub has this header and nothing else above it. `Purpose` is at most 3 lines. No history, no issue or bug descriptions, no commented-out code. Inside a sub, no comments unless a line cannot say what it does (one line, then).

```perl
# Usage     : exit_code()
# Purpose   : Maps $return status value to OS process exit code and terminates execution.
# Returns   : Does not return (calls exit).
sub exit_code
{
    ...
}
```

### 2.2 `lib/AAPP/Constants.pm`: names, defaults, return numbers
```perl
package AAPP::Constants;

use strict;
use warnings;
use 5.026;

use Exporter 'import';

use constant NAME => 'AAPP';

use constant {
    DEBUG_LEVEL      => 0,
    LOG_KEY          => 'aapp.perlLogFile',
    CONFIG_PREFIX    => 'aapp.',

    RETURN_OK        => 1,     # exit 0
    RETURN_FAIL      => 0,     # exit 1: refused, nothing changed
    RETURN_ERROR     => -1,    # exit 1: failed while working
    RETURN_DENY      => -2,    # exit 2: the write guard's deny
    RETURN_NOT_FOUND => -3,    # exit 3: named item does not exist
};

our %EXIT_FOR = (
    RETURN_OK()        => 0,
    RETURN_FAIL()      => 1,
    RETURN_ERROR()     => 1,
    RETURN_DENY()      => 2,
    RETURN_NOT_FOUND() => 3,
);

our @EXPORT_OK = qw(NAME DEBUG_LEVEL LOG_KEY CONFIG_PREFIX
    RETURN_OK RETURN_FAIL RETURN_ERROR RETURN_DENY RETURN_NOT_FOUND %EXIT_FOR);

1;
```
A new exit code the contracts promise is added here, as a `RETURN_*` constant and its `%EXIT_FOR` entry, and nowhere else. Subs that report an outcome return one of these; nothing else returns a status.

### 2.3 `lib/AAPP/Paths.pm`: one `git rev-parse` per process
```perl
package AAPP::Paths;

use strict;
use warnings;
use 5.026;

our %paths;

# Usage     : my $p = AAPP::Paths::resolve()
# Purpose   : Reads the repository root, git dir and common dir with one git rev-parse, once per process.
# Returns   : Hash ref {root, git_dir, common_dir}; empty hash ref outside a repository.
sub resolve
{
    return \%paths if %paths;
    open( my $fh, '-|', 'git', 'rev-parse', '--show-toplevel', '--absolute-git-dir', '--git-common-dir' ) or return {};
    chomp( my @lines = <$fh> );
    close($fh) or return {};
    return {} if @lines != 3;
    my $common = $lines[2];
    $common = "$lines[0]/$common" if $common !~ m{^/};
    %paths = ( root => $lines[0], git_dir => $lines[1], common_dir => $common );
    return \%paths;
}

1;
```

### 2.4 `lib/AAPP/Config.pm`: one `git config --list -z` per process
```perl
package AAPP::Config;

use strict;
use warnings;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_ERROR);

our %config;
our $loaded = 0;

# Usage     : AAPP::Config::load()
# Purpose   : Reads every git config value of the repository once (git config --list -z) into %config.
# Returns   : RETURN_OK, or RETURN_ERROR when git config cannot be read.
sub load
{
    return RETURN_OK if $loaded;
    open( my $fh, '-|', 'git', 'config', '--list', '-z' ) or return RETURN_ERROR;
    local $/ = "\0";
    while ( my $entry = <$fh> ) {
        chomp($entry);
        my ( $key, $value ) = split( /\n/, $entry, 2 );
        push @{ $config{ lc $key } }, $value // '';
    }
    close($fh) or return RETURN_ERROR;
    $loaded = 1;
    return RETURN_OK;
}

# Usage     : my $v = AAPP::Config::get('aapp.perlLogFile')
# Purpose   : Returns the last value of a key, as git does for single-valued keys.
# Returns   : The value, or undef when unset.
sub get
{
    my ($key) = @_;
    load();
    my $all = $config{ lc $key } or return;
    return $all->[-1];
}

# Usage     : my @v = AAPP::Config::get_all('aapp.allowPath')
# Purpose   : Returns every value of a multi-valued key, in config order.
# Returns   : List of values; empty when unset.
sub get_all
{
    my ($key) = @_;
    load();
    return @{ $config{ lc $key } // [] };
}

# Usage     : my ($rc, $n) = AAPP::Config::get_int('aapp.statusOutputWidth', 85, 40)
# Purpose   : Returns a whole-number setting, its default when unset; a value below $min or not a number is an error.
# Returns   : (RETURN_OK, $value), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub get_int
{
    my ( $key, $default, $min ) = @_;
    my $v = get($key);
    return ( RETURN_OK, $default ) if !defined $v;
    if ( $v !~ /^\d+$/ || ( defined $min && $v < $min ) ) {
        AAPP::Logger::say( 'ERROR', sprintf( "%s is '%s'; it must be a whole number%s.", $key, $v, defined $min ? " of at least $min" : '' ) );
        return ( RETURN_ERROR, undef );
    }
    return ( RETURN_OK, $v );
}

# Usage     : my @keys = AAPP::Config::keys_with_prefix('aapp.planState.')
# Purpose   : Lists the keys that start with a prefix, for registries such as aapp.planState.*.
# Returns   : Sorted list of keys.
sub keys_with_prefix
{
    my ($prefix) = @_;
    load();
    return sort grep { index( $_, lc $prefix ) == 0 } keys %config;
}

1;
```
Git config keys are case-insensitive in their section and name parts, hence `lc`. The plan status registry (`aapp.planState.*`) is read through `keys_with_prefix` and `get`; its parsing stays in P-115.

### 2.5 `lib/AAPP/Logger.pm`: one output format, optional log file, no hooks
```perl
package AAPP::Logger;

use strict;
use warnings;
use 5.026;

use POSIX ();
use AAPP::Constants qw(DEBUG_LEVEL LOG_KEY);
use AAPP::Config ();
use AAPP::Paths ();

our $quiet = 0;

# Usage     : AAPP::Logger::say('NOTICE', $message)
# Purpose   : Prints one line for the agent in the standard format, and logs it.
#             NOTICE and INFO go to STDOUT (not with $quiet); WARN, ERROR and FATAL to STDERR.
# Returns   : 1
sub say
{
    my ( $tag, $message ) = @_;
    my $to_err = $tag =~ /^(?:WARN|ERROR|FATAL)$/;
    if ($to_err) {
        printf STDERR "[ %-6s ] %s\n", $tag, $message;
    } elsif ( !$quiet ) {
        printf STDOUT "[ %-6s ] %s\n", $tag, $message;
    }
    log_output( 0, $tag, $message );
    return 1;
}

# Usage     : AAPP::Logger::log_output($min_debug, $tag, $message)
# Purpose   : Appends a timestamped line to the log file when aapp.perlLogFile is set and DEBUG_LEVEL >= $min_debug.
# Returns   : 1, or 0 when the log file cannot be written.
sub log_output
{
    my ( $min_debug, $tag, $message ) = @_;
    return 1 if DEBUG_LEVEL < $min_debug;
    my $file = log_file() // return 1;
    open( my $fh, '>>', $file ) or return 0;
    printf {$fh} "%s [%s] %s\n", POSIX::strftime( '%Y-%m-%d %H:%M:%S', localtime ), $tag, $message;
    close($fh) or return 0;
    return 1;
}

# Usage     : my $file = AAPP::Logger::log_file()
# Purpose   : Resolves aapp.perlLogFile; a relative path is taken from the repository's common git dir.
# Returns   : Absolute path, or undef when no log file is configured.
sub log_file
{
    my $file = AAPP::Config::get(LOG_KEY);
    return if !defined $file || $file eq '';
    return $file if $file =~ m{^/};
    my $common = AAPP::Paths::resolve()->{common_dir} // return;
    return "$common/$file";
}

1;
```
Tags: `NOTICE`, `INFO`, `WARN`, `ERROR`, `FATAL`. Sample lines: `[ NOTICE ] Plan 'P-12' archived.`, `[ ERROR  ] aapp.statusOutputWidth is 'abc'; it must be a whole number of at least 40.`

### 2.6 `lib/AAPP/Runner.pm`: entry, signals, crash handling, exit codes
Logsniffer's `Runner.pm` (`init_signals`, `exit_code`, `return_on_error`, `cleanup`, `no_log_file`, `unopened_log_file`, `print_error_msg`, `logger`, `run`), adapted:

```perl
package AAPP::Runner;

use strict;
use warnings;
use 5.026;

use AAPP::Constants qw(DEBUG_LEVEL RETURN_OK RETURN_ERROR RETURN_FAIL %EXIT_FOR);
use AAPP::Logger ();

our $return = RETURN_OK;
our @args;
our $global_json  = 0;
our $global_quiet = 0;
our @cleanups;

# Usage     : init_signals()
# Purpose   : Registers signal handlers (HUP, TERM, INT) and error hooks (__WARN__, __DIE__).
# Returns   : undef
sub init_signals
{
    $SIG{HUP} = $SIG{TERM} = $SIG{INT} = \&cleanup;

    $SIG{__WARN__} = sub
    {
        my $msg = shift;
        chomp($msg);
        AAPP::Logger::log_output( 0, 'WARN', "[Perl::Warning] " . $msg );
        printf STDERR "[ %-6s ] %s\n", 'WARN', $msg;
    };

    $SIG{__DIE__} = sub
    {
        my $msg = shift;
        return if $^S;

        $msg =~ s/ at .*? line \d+\.?\n?$//s;
        $msg =~ s/\n$//;
        chomp($msg);

        $msg = "[FATAL ERROR]:[Perl] " . $msg if ( $msg !~ /^(?:AAPP|System)/ );
        $msg =~ s/^AAPP[:]?/[FATAL ERROR]:[AAPP]/;
        $msg =~ s/^System[:]?/[FATAL ERROR]:[System]/;

        my ( undef, $filename, $line ) = caller(0);

        my $stack = '';
        if ( DEBUG_LEVEL >= 1 ) {
            $stack = "    Full stack:\n";
            my $i = 0;
            while ( my @info = caller( $i++ ) ) {
                $stack .= "    Called from $info[1] at line $info[2] in subroutine $info[3]\n";
            }
        }

        logger( $msg, $filename, $line, $stack );
    };
    return;
}

# Usage     : exit_code()
# Purpose   : Maps $return status value to OS process exit code and terminates execution.
#             A value not declared in AAPP::Constants is itself a crash.
# Returns   : Does not return (calls exit).
sub exit_code
{
    die("AAPP: undeclared return value '" . ( $return // 'undef' ) . "'") if !defined $return || !exists $EXIT_FOR{$return};
    exit $EXIT_FOR{$return};
}

# Usage     : return_on_error()
# Purpose   : Sets return status to RETURN_ERROR and exits with failure.
# Returns   : Does not return.
sub return_on_error
{
    $return = RETURN_ERROR;
    exit_code();
    return;
}

# Usage     : cleanup()
# Purpose   : Runs the registered cleanups (temporary files, child process groups) on termination signals.
# Returns   : Does not return (exits with failure).
sub cleanup
{
    $_->() for reverse @cleanups;
    @cleanups = ();
    return_on_error();
    return;
}

# Usage     : no_log_file($msg, $file, $line, $stack, $syserr)
# Purpose   : Prints a fatal error to STDERR when no log file is configured.
# Returns   : Does not return.
sub no_log_file
{
    my ( $msg, $file, $line, $stack, $syserr ) = @_;
    my $text = sprintf( "%s (file: %s line: %s)%s", $msg, $file, $line, $syserr ? " ($syserr)" : '' );
    printf STDERR "[ %-6s ] %s\n%s", 'FATAL', $text, $stack;
    return_on_error();
    return;
}

# Usage     : unopened_log_file($syserr)
# Purpose   : Prints a warning when the log file cannot be written, then exits with failure.
# Returns   : Does not return.
sub unopened_log_file
{
    my ($syserr) = @_;
    printf STDERR "[ %-6s ] Could not write to log file %s%s\n", 'WARN', AAPP::Logger::log_file() // '', $syserr ? ": $syserr" : '';
    return_on_error();
    return;
}

# Usage     : print_error_msg($message, $file, $line, $stack)
# Purpose   : Appends the fatal error to the log file and prints it to STDERR, so the agent sees it.
# Returns   : Does not return.
sub print_error_msg
{
    my ( $message, $file, $line, $stack ) = @_;
    my $text = sprintf( "%s (file: %s line: %s)", $message, $file, $line );
    printf STDERR "[ %-6s ] %s\n%s", 'FATAL', $text, $stack;
    unopened_log_file($!) if !AAPP::Logger::log_output( 0, 'FATAL', $text . ( $stack ? "\n$stack" : '' ) );
    return_on_error();
    return;
}

# Usage     : logger($message, $file, $line, $stack)
# Purpose   : Routes an uncaught fatal error to the configured log file, or to STDERR alone.
# Returns   : undef
sub logger
{
    my ( $message, $file, $line, $stack ) = @_;
    local $! = 0;
    if ( defined AAPP::Logger::log_file() ) {
        print_error_msg( $message, $file, $line, $stack );
    } else {
        no_log_file( $message, $file, $line, $stack, $! );
    }
    return;
}

# Usage     : AAPP::Runner::run(@run_args)
# Purpose   : CLI entry point. Takes the global tokens (json, quiet), installs the handlers,
#             dispatches the verb to AAPP::Cmd::<Verb>->run(@args), and exits with its return number.
# Returns   : Does not return.
sub run
{
    my (@run_args) = @_;
    @args = ();
    foreach my $arg (@run_args) {
        if    ( $arg eq 'json' )  { $global_json  = 1; }
        elsif ( $arg eq 'quiet' ) { $global_quiet = 1; }
        else                      { push @args, $arg; }
    }
    $AAPP::Logger::quiet = $global_quiet;

    init_signals();

    my $verb = shift(@args) // 'help';
    ( my $module = join( '', map { ucfirst } split( /-/, $verb ) ) ) =~ s/[^A-Za-z]//g;
    my $class = "AAPP::Cmd::$module";
    if ( eval "require $class; 1" ) {
        $return = $class->run(@args);
    } else {
        AAPP::Logger::say( 'ERROR', "Unknown verb '$verb'. Run 'aapp help'." );
        $return = RETURN_FAIL;
    }
    exit_code();
    return;
}

1;
```
Notes:
- `@cleanups` is how later modules (the test harness, worktree verbs) register what a signal must undo, e.g. `push @AAPP::Runner::cleanups, sub { kill 'TERM', -$pgid };`.
- Hybrid routing in the `aapp` entry (which verbs go to Perl) is P-115's; here `run` dispatches only to `AAPP::Cmd::*`, none of which exist yet.
- `[ %-6s ]` is the one line format for agents; P-115's `AAPP::Output` renders the larger records (briefings, JSON) on top of it.

### 2.7 Where the code lives
`lib/AAPP/` is the only authored copy; `aapp init` copies it into `.githooks/AAPP/` (P-111 §2, wired in P-121). `.agents/PROJECT.MD` gets the comment rule of §2.1 so every later member follows it.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Modules
- [ ] Task 1.1: `lib/AAPP/Constants.pm` per §2.2.
- [ ] Task 1.2: `lib/AAPP/Paths.pm` and `lib/AAPP/Config.pm` per §2.3–2.4.
- [ ] Task 1.3: `lib/AAPP/Logger.pm` per §2.5.
- [ ] Task 1.4: `lib/AAPP/Runner.pm` per §2.6.

### Phase 2: Rules
- [ ] Task 2.1: Add the comment rule (§2.1) to `.agents/PROJECT.MD`.

### Phase 3: Verification
- [ ] Task 3.1: `perl -c` every module; a scratch script calling `AAPP::Runner::run` shows: an unknown verb (exit 1, `[ ERROR  ]` line), a crash without a log file (exit 1, `[ FATAL  ]` on STDERR), a crash with `aapp.perlLogFile` set (logged and printed), an undeclared return number (crash), TERM running a registered cleanup. Automated tests come with the harness (P-126).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/AAPP/Constants.pm` -> Names, defaults, return numbers.
- [ ] `NEW FILE` -> `lib/AAPP/Paths.pm` -> One `git rev-parse` per process.
- [ ] `NEW FILE` -> `lib/AAPP/Config.pm` -> One `git config --list -z` per process; typed getters.
- [ ] `NEW FILE` -> `lib/AAPP/Logger.pm` -> Standard output line and optional log file.
- [ ] `NEW FILE` -> `lib/AAPP/Runner.pm` -> Entry, signals, crash handling, exit codes.
- [ ] `.agents/PROJECT.MD` -> The comment rule.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `aapp` -> Routing to Perl is P-115's.
- [ ] `lib/*.sh` -> The bash kit stays as it is.
- [ ] `templates/*` -> Hooks stay bash until P-116.
- [ ] `tests/*` -> Tests change in the harness and test members only.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1:** `aapp.logFile` is already read by `examples/hooks/event-logger.sample` (P-104). **Answer (user, 2026-10-20):** the Perl logger uses `aapp.perlLogFile` while the port runs; the clean-break member (P-122) swaps it to `aapp.logFile`, when the kit logs per event and both keys mean the same.

---

## 📦 6. Change Log & Refinement History
* **2026-10-20:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-20:** Drafted as the first member of the port: Constants, Paths, Config, Logger, Runner and the comment rule, in logsniffer's style.
