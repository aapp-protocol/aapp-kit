package AAPP::T::Core::AappLib;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/aapp_lib.md. Run alone: prove -l t/core/aapp_lib.t

# Usage     : my $file = plan4($name, $body)
# Purpose   : A plan whose §4 holds $body, between a §3 and a §5 heading.
# Returns   : The file name.
sub plan4
{
    my ( $name, $body ) = @_;
    AAPP::Tests::write_text( $name, "## 🔨 3. Implementation Steps\n## 💥 4. Blast Radius & System Boundaries\n$body## ❓ 5. Open Questions\n" );
    return $name;
}

# Usage     : my $text = paths($self, $function, $file)
# Purpose   : The paths an AAPP::State reader gives for a plan, one per line.
# Returns   : The text.
sub paths
{
    my ( $self, $function, $file ) = @_;
    return join( "\n", @{ $self->lib_call( 'state', $function, $file )->{ret} } );
}

sub test_blockquote_not_parsed
{
    my ($self) = @_;
    my $f = plan4( 'blockquote.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
> **Authoring rule:** the first `backticked path` on a line is the target.
>   - `src/quoted.py` indented quote
- [ ] `src/a.py` -> real target
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), 'src/a.py', 'targets' );
    return 1;
}

sub test_foreign_subsection_ends_region
{
    my ($self) = @_;
    my $f = plan4( 'foreign.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 📝 Implementation Notes
- `src/notes.py` -> not a target
#### 🔎 Deeper Note
- `src/deeper.py` -> not a target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), 'src/a.py', 'targets' );
    return 1;
}

sub test_foreign_heading_after_oob
{
    my ($self) = @_;
    my $f = plan4( 'heading_after_oob.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> vetoed
### 📝 Notes
- [ ] `src/notes.py` -> neither
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), 'src/a.py',      'targets' );
    $self->eq_or_die( paths( $self, 'plan_oob_paths', $f ),    'src/secret.py', 'out of bounds' );
    return 1;
}

sub test_required_test_files_is_parsed
{
    my ($self) = @_;
    my $f = plan4( 'required_files.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🧪 Required Test Files
> Test files that must prove this plan's failure cases.
- `tests/a_test.sh`
- [x] `tests/b_test.sh`
### 🛑 Out of Bounds (Do Not Touch)
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), "src/a.py\ntests/a_test.sh\ntests/b_test.sh", 'targets' );
    return 1;
}

sub test_required_tests_checklist_not_parsed
{
    my ($self) = @_;
    my $f = plan4( 'required_tests.md', <<'EOF' );
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.sh::test_x` -> asserts x
### 🧪 Required Test Filesxyz
- `tests/near_miss.sh`
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), 'src/a.py', 'targets' );
    return 1;
}

sub test_new_file_marker_skipped
{
    my ($self) = @_;
    my $f = plan4( 'markers.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `src/new.py` -> created
- [x] `MODIFY` -> `src/mod.py` -> ticked and modified
- [ ] `DELETE` -> `src/gone.py` -> removed
- [ ] `ADD` -> `src/add.py` -> added
- [ ] `REPLACE` -> `src/rep.py` -> replaced
- [X] `src/plain.py` -> ticked plain target
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), "src/new.py\nsrc/mod.py\nsrc/gone.py\nsrc/add.py\nsrc/rep.py\nsrc/plain.py", 'targets' );
    return 1;
}

sub test_fenced_example_not_parsed
{
    my ($self) = @_;
    my $f = plan4( 'fenced.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 📝 Example For Authors
```markdown
### 🧪 Required Test Files
- `src/test/kotlin/AuthTest.kt`
```
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', $f ), 'src/a.py', 'targets' );
    return 1;
}

sub test_heading_outside_section4_not_parsed
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'outside4.md', <<'EOF' );
## 2. Technical Blueprint
### 🧪 Required Test Files
- `tests/example_in_s2.sh`
### 📂 Target Files (Modifications & Additions)
- [ ] `src/example_in_s2.py`
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
## ❓ 5. Open Questions
### 📂 Target Files (Modifications & Additions)
- [ ] `src/after_s4.py`
EOF
    $self->eq_or_die( paths( $self, 'plan_target_paths', 'outside4.md' ), 'src/a.py', 'targets' );
    return 1;
}

sub test_oob_paths_parsed
{
    my ($self) = @_;
    my $f = plan4( 'oob.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> real target
### 🛑 Out of Bounds (Do Not Touch)
> Quoted `src/quoted_oob.py` is prose.
- [ ] `src/secret.py` -> vetoed
- [ ] `.githooks/*` -> vetoed glob
### 📝 Later Notes
- `src/not_oob.py`
EOF
    $self->eq_or_die( paths( $self, 'plan_oob_paths', $f ), "src/secret.py\n.githooks/*", 'out of bounds' );
    return 1;
}

sub test_parse_required_test_files
{
    my ($self) = @_;
    my $f = plan4( 'req_tests.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🧪 Required Test Files
> Test files that prove this plan's failure cases.
- `tests/a_test.py`
- `tests/b_test.py`
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/secret_test.py`
EOF
    $self->eq_or_die( paths( $self, 'plan_required_test_files', $f ), "tests/a_test.py\ntests/b_test.py", 'required test files' );
    return 1;
}

sub test_parse_required_tests
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'plan_tests.md', <<'EOF' );
## 🔨 3. Implementation Steps & Execution Checklist
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.py::test_fail_early` -> asserts exit 1
- [x] `tests/b_test.py::test_boundary` -> asserts clean boundary
- [ ] tests/c_test.py::test_unbackticked -> asserts clean error
### Phase 1: Implementation
- [ ] Task 1.1: Do something
## 💥 4. Blast Radius & System Boundaries
EOF
    $self->eq_or_die( paths( $self, 'plan_required_tests', 'plan_tests.md' ), "tests/a_test.py\ntests/b_test.py\ntests/c_test.py", 'required tests' );
    return 1;
}

sub test_validate_tdd_correspondence_matches
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'tdd_valid.md', <<'EOF' );
## 🔨 3. Implementation Steps & Execution Checklist
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/a_test.py::test_fail_early` -> asserts exit 1
- [x] `tests/b_test.py::test_boundary` -> asserts clean boundary
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🧪 Required Test Files
- `tests/a_test.py`
- `tests/b_test.py`
EOF
    $self->eq_or_die( $self->lib_call( 'state', 'plan_tdd_correspondence', 'tdd_valid.md', 'Test' )->{ret}[0], RETURN_OK, 'matching §3/§4 pass' );
    $self->eq_or_die( $self->lib_call( 'state', 'plan_has_required_test_files', 'tdd_valid.md' )->{ret}[0], 1, 'the plan declares test files' );
    return 1;
}

sub test_validate_tdd_correspondence_opted_out
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'tdd_opt_out.md', <<'EOF' );
## 🔨 3. Implementation Steps & Execution Checklist
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
EOF
    $self->eq_or_die( $self->lib_call( 'state', 'plan_tdd_correspondence', 'tdd_opt_out.md', 'Test' )->{ret}[0], RETURN_OK, 'an opted-out plan passes' );
    $self->eq_or_die( $self->lib_call( 'state', 'plan_has_required_test_files', 'tdd_opt_out.md' )->{ret}[0], 0, 'it declares no test files' );
    return 1;
}

sub test_extract_plan_section
{
    my ($self) = @_;
    AAPP::Tests::write_text( 's.md', join( "\n", '## 🔨 3. Steps', '- s3', '## 💥 4. Blast Radius', '### 📂 Target Files', '- [ ] `src/a.py`', '## ❓ 5. Questions', '- s5' ) . "\n" );
    $self->eq_or_die( join( "\n", @{ $self->lib_call( 'state', 'plan_section', 's.md', 4 )->{ret} } ),
        join( "\n", '## 💥 4. Blast Radius', '### 📂 Target Files', '- [ ] `src/a.py`' ), 'section 4' );
    AAPP::Tests::write_text( 'f.md', join( "\n", '## 2. Decisions', '- d', '## 4. Docs', '```markdown', '## ⚙️ 2. Codemap', '- c', '```', '## 5. Q' ) . "\n" );
    $self->eq_or_die( join( "\n", @{ $self->lib_call( 'state', 'plan_section', 'f.md', 2 )->{ret} } ), join( "\n", '## 2. Decisions', '- d' ),
        'a fenced heading is not section 2' );
    $self->eq_or_die( join( "\n", @{ $self->lib_call( 'state', 'plan_section', 'f.md', 4 )->{ret} } ),
        join( "\n", '## 4. Docs', '```markdown', '## ⚙️ 2. Codemap', '- c', '```' ), 'a fenced heading does not end section 4' );
    return 1;
}

sub test_aapp_os_branches
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'proc_linux', "Linux version 6.8.0 (gcc) #1 SMP\n" );
    AAPP::Tests::write_text( 'proc_wsl',   "Linux version 5.15.153.1-microsoft-standard-WSL2\n" );
    foreach my $case ( [ 'Linux', 'proc_linux', 'linux' ], [ 'Linux', 'proc_wsl', 'wsl' ], [ 'Linux', 'no_such_file', 'linux' ], [ 'Darwin', 'proc_linux', 'darwin' ],
        [ 'MINGW64_NT-10.0-19045', 'proc_linux', 'windows' ], [ 'MSYS_NT-10.0', 'proc_linux', 'windows' ], [ 'CYGWIN_NT-10.0', 'proc_linux', 'windows' ],
        [ 'FreeBSD', 'proc_linux', 'bsd' ], [ 'OpenBSD', 'proc_linux', 'bsd' ], [ 'NetBSD', 'proc_linux', 'bsd' ], [ 'SunOS', 'proc_linux', 'unknown' ] )
    {
        $self->eq_or_die( $self->lib_call( 'paths', 'aapp_os', $case->[0], $case->[1] )->{ret}[0], $case->[2], "aapp_os $case->[0]" );
    }
    $self->match_or_die( $self->lib_call( 'paths', 'aapp_os' )->{ret}[0], qr/^(?:linux|darwin|windows|wsl|bsd|unknown)$/, 'the live system' );
    return 1;
}

sub test_parse_plan_commits
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'c.md', "# Plan P-99: Test\n* **Status:** ⚡ In Development\n* **Commits:** `bca7d9a` (develop), `8c0c103` (feat/parser), `1a2b3c4` (detached)\n" );
    $self->eq_or_die( paths( $self, 'plan_commits', 'c.md' ), "bca7d9a\n8c0c103\n1a2b3c4", 'three commits, their branches ignored' );
    AAPP::Tests::write_text( 'c.md', "* **Commits:** none\n" );
    $self->eq_or_die( paths( $self, 'plan_commits', 'c.md' ), '', 'none' );
    AAPP::Tests::write_text( 'c.md', "* **Commits:** bca7d9a (develop), `8c0c103`, just prose\n" );
    $self->eq_or_die( paths( $self, 'plan_commits', 'c.md' ), '8c0c103', 'a backticked hash counts without a branch; an unbackticked one and prose give nothing' );
    return 1;
}

sub test_pickup_entry_split
{
    my ($self) = @_;
    my $split = sub { join( "\t", @{ $self->lib_call( 'text', 'pickup_entry_split', $_[0] )->{ret} } ) };
    $self->eq_or_die( $split->('- [ ] Verbosity Budget: keep agents to the essence: always.'), "Verbosity Budget\tkeep agents to the essence: always.", 'title and text' );
    $self->eq_or_die( $split->('- [ ] Configuration Manager CLI (`aapp config: set`): add a manifest'),
        "Configuration Manager CLI (`aapp config: set`)\tadd a manifest", 'a colon inside backticks' );
    $self->eq_or_die( $split->('- [ ] an idea with no title at all'),   "\tan idea with no title at all",   'no title' );
    $self->eq_or_die( $split->('Plain Title: text without the marker'), "Plain Title\ttext without the marker", 'no marker' );
    return 1;
}

sub test_subject_max_len
{
    my ($self) = @_;
    $self->init_repo();
    $self->eq_or_die( $self->lib_call( 'state', 'subject_max_len' )->{ret}[1], 72, 'the default' );
    $self->ok_cmd( 'git', 'config', 'aapp.subjectMaxLen', '50' );
    $self->eq_or_die( $self->lib_call( 'state', 'subject_max_len' )->{ret}[1], 50, 'a set limit' );
    $self->ok_cmd( 'git', 'config', 'aapp.subjectMaxLen', 'not-a-number' );
    my $r = $self->lib_call( 'state', 'subject_max_len' );
    $self->true_or_die( $r->{ret}[0] != RETURN_OK, 'a value that is not a number is refused' );
    $self->match_or_die( $r->{err}, qr/aapp\.subjectMaxLen/, 'the refusal names the setting' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
