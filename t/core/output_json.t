package AAPP::T::Core::OutputJson;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use AAPP::Constants qw(RETURN_OK);
use AAPP::JSON ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/output_json.md. Run alone: prove -l t/core/output_json.t
# The JSON documents are read with AAPP::JSON, the one kit parser a test may use (P-126 §2.1.10).

our $SYM    = 'Says "hi" with `code`, a \back\slash and … done.';
our $REMOTE = 'https://someone:s3cret@example.com/acme/app.git';
our %TIMEOUT = ( test_error_codes => 120, test_sync_warning_in_notices => 120 );

# Usage     : fixture($self)
# Purpose   : A project with a changelog entry, three issues (two queued, one with tracker names and two
#             notes), a group with a member, a plan, and a pickup idea naming a kept and a gone file; then
#             the documents every test reads: status.json, list.json, list1.json, listall.json,
#             paused.json, error.json (with status.err), and ids.txt (the group, member and plan ids).
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    $self->ok_cmd( 'git', 'config', $_->[0], $_->[1] ) for [ 'aapp.issueFixWait', '0' ], [ 'aapp.offlineEnabled', 'false' ];
    $self->ok_cmd( 'git', 'remote', 'add', 'origin', $REMOTE );
    AAPP::Tests::write_text( 'CHANGELOG.md', AAPP::Tests::read_text('CHANGELOG.md') =~ s/^### Fixed$/### Fixed\n- A tagged fix (P-7)/mr );
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'docs: a fix', '--no-verify' );
    AAPP::Tests::write_text( '.plans/ISSUES.md', join( "\n", '# Issues', '',
        '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |', '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |',
        "| #1 | `Medium` | `CLI` | 2026-10-01 | `src/a.sh` | $SYM |  | 🟡 `Incubated` |",
        '| #2 | `Low` | `CORE` | 2026-10-02 | `src/b.sh` | Second symptom. |  | 🟡 `Incubated` |',
        '| #3 | `High` | `HOOK` | 2026-10-03 | `src/c.sh` | Third symptom. |  | 🟡 `Incubated` |' ) . "\n" );
    AAPP::Tests::write_text( '.plans/issues_road_map.md', join( "\n", '# 🗺️ Issue Work Queue', '', '## 🧱 Plan Blockers', '', '## 📋 Queued', '', '### 🔺 Urgent',
        '- [ ] #1 -> First. (queued 2026-10-04)', '', '### Normal', '- [ ] #2 -> Second symptom. (queued 2026-10-05)', '', '### Low' ) . "\n" );
    $self->ok_cmd( 'git', '-C', '.plans', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'fixture', '--no-verify' );
    $self->ok_cmd( 'git', 'config', 'aapp.issueId', '10' );
    my $common = $self->ok_cmd( 'git', 'rev-parse', '--git-common-dir' )->{out} =~ s/\s+$//r;
    AAPP::Tests::write_text( "$common/aapp_issue_meta", "#1\tjira\thttps://t.example/1\t2.1\n" );
    $self->ok_cmd( 'aapp', 'refine', 'issues', 'notes', 'note', '1', 'secret first note', 'note', '1', 'secret second note' );
    my %id;
    foreach my $draft ( [ 'gid', 'json-group', 'group' ], [ 'mid', 'json-member', 'group', 'GID' ], [ 'pid', 'json-plan' ] ) {
        my ( $key, $slug, @rest ) = @{$draft};
        $id{$key} = 'P-' . ( $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} =~ s/\s+$//r );
        $self->ok_cmd( 'aapp', 'draft', $slug, map { $_ eq 'GID' ? $id{gid} : $_ } @rest );
    }
    AAPP::Tests::write_text( 'ids.txt', "$id{gid} $id{mid} $id{pid}\n" );
    File::Path::make_path('.plans/pickup');
    AAPP::Tests::write_text( '.plans/pickup/kept.md', "notes\n" );
    AAPP::Tests::write_text( '.plans/pickup.md',
        AAPP::Tests::read_text('.plans/pickup.md') . "- [ ] Linked Idea: see `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.\n" );

    save( $self, 'status.json', 'status', 'json' );
    save( $self, 'list.json',   'issue', 'list', 'json' );
    save( $self, 'list1.json',  'issue', 'list', '1', 'json' );
    save( $self, 'listall.json', 'issue', 'list', 'all', 'json' );
    AAPP::Tests::write_text( "$common/aapp_paused",
        '{"reason": "Away", "timestamp": "2026-10-16T10:00:00Z", "snapshot": {"stashes": [{"worktree": "' . Cwd::getcwd() . '", "branch": "develop"}]}}' . "\n" );
    save( $self, 'paused.json', 'status', 'json' );
    unlink("$common/aapp_paused") or die "cannot remove the pause buffer: $!\n";
    $self->ok_cmd( 'git', 'config', 'aapp.statusItemsMax', 'none' );
    my $r = save( $self, 'error.json', 'status', 'json' );
    AAPP::Tests::write_text( 'status.err', $r->{err} );
    AAPP::Tests::write_text( 'error.exit', "$r->{exit}\n" );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.statusItemsMax' );
    return 1;
}

# Usage     : my $r = save($self, $file, @aapp_args)
# Purpose   : Runs aapp and keeps its stdout in $file (and its exit in $file.exit).
# Returns   : { exit, out, err }.
sub save
{
    my ( $self, $file, @args ) = @_;
    my $r = $self->run_aapp(@args);
    AAPP::Tests::write_text( $file,        $r->{out} );
    AAPP::Tests::write_text( "$file.exit", "$r->{exit}\n" );
    return $r;
}

# Usage     : my $data = doc($self, $file_or_text)
# Purpose   : One JSON document, read with AAPP::JSON; dies naming the test line when it is not one object.
# Returns   : The data (objects as hashes, their key order from AAPP::JSON::key_order).
sub doc
{
    my ( $self, $file ) = @_;
    my ( $rc, $data, $why ) = AAPP::JSON::decode_file($file);
    $self->true_or_die( $rc == RETURN_OK && ref($data) eq 'HASH', "$file is one JSON object", $why // substr( AAPP::Tests::read_text($file), 0, 300 ) );
    return $data;
}

# Usage     : my $n = exit_of($file)
# Purpose   : The exit code save() kept for a document.
# Returns   : The number.
sub exit_of { my ($file) = @_; return 0 + AAPP::Tests::read_text("$file.exit"); }

# Usage     : my ($issue) = by_id($list, '#1')
# Purpose   : The record with that id.
# Returns   : The record, or nothing.
sub by_id { my ( $list, $id ) = @_; return grep { $_->{id} eq $id } @{$list}; }

sub test_status_json_parses
{
    my ($self) = @_;
    $self->eq_or_die( exit_of('status.json'), 0, 'status json exits 0' );
    $self->eq_or_die( doc( $self, 'status.json' )->{command}, 'status', 'the command' );
    $self->true_or_die( index( AAPP::Tests::read_text('status.json'), 'Context Recovery Briefing' ) < 0, 'no terminal briefing' );
    return 1;
}

sub test_issue_list_json_parses
{
    my ($self) = @_;
    foreach my $case ( [ 'list.json', 3, 3, 3 ], [ 'list1.json', 1, 3, 1 ], [ 'listall.json', 3, 3, 3 ] ) {
        my ( $file, @want ) = @{$case};
        my $d = doc( $self, $file );
        $self->eq_or_die( exit_of($file), 0, "$file exits 0" );
        $self->eq_or_die( join( ',', $d->{shown}, $d->{total}, scalar( @{ $d->{issues} } ) ), join( ',', @want ), "$file: shown, total, issues" );
    }
    return 1;
}

# Usage     : my %tables = reference_tables($self)
# Purpose   : The tables of docs/reference/08-output-json.md: '### `<name>`' to its '| `key` |' rows, in order.
# Returns   : name => [keys].
sub reference_tables
{
    my ($self) = @_;
    my ( %tables, $name );
    foreach my $line ( split( /\n/, AAPP::Tests::read_text("$self->{kit}/docs/reference/08-output-json.md") ) ) {
        if ( $line =~ /^### `([^`]+)`/ ) {
            $name = $1;
            $tables{$name} = [];
            next;
        }
        if ( $line =~ /^###? / ) {
            undef $name;
            next;
        }
        push @{ $tables{$name} }, $1 if defined $name && $line =~ /^\| `([a-z_]+)` \|/;
    }
    return %tables;
}

sub test_fields_match_reference
{
    my ($self) = @_;
    my %tables = reference_tables($self);
    my ( @errors, %seen );
    my $check = sub {
        my ( $table, $obj, $where ) = @_;
        return if !defined $obj;
        $seen{$table} = 1;
        my $got  = join( ',', AAPP::JSON::key_order($obj) );
        my $want = join( ',', @{ $tables{$table} // [] } );
        push @errors, "$where: keys [$got] != `$table` [$want]" if $got ne $want;
    };
    my ( $st, $ls ) = ( doc( $self, 'paused.json' ), doc( $self, 'list.json' ) );
    my @env = @{ $tables{envelope} };
    foreach my $pair ( [ $st, 'status' ], [ $ls, 'issue list' ] ) {
        my ( $d, $t ) = @{$pair};
        my @keys = AAPP::JSON::key_order($d);
        push @errors, "$t: envelope [@keys[0 .. $#env]] != [@env]" if join( ',', @keys[ 0 .. $#env ] ) ne join( ',', @env );
        push @errors, "$t: [@keys[ @env .. $#keys ]] != `$t`" if join( ',', @keys[ @env .. $#keys ] ) ne join( ',', @{ $tables{$t} } );
        @seen{ 'envelope', $t } = ( 1, 1 );
        $check->( 'repository',        $d->{repository},           "$t.repository" );
        $check->( 'repository.remote', $d->{repository}{remote},   "$t.repository.remote" );
        $check->( 'notices',           $d->{notices},              "$t.notices" );
        foreach my $level (qw(warning info)) {
            $check->( 'notices.*[]', $_, "$t.notices.$level\[]" ) for @{ $d->{notices}{$level} };
        }
    }
    my $issue = sub {
        my ( $i, $where ) = @_;
        $check->( 'issue', $i, $where );
        $check->( 'issue.queue',   $i->{queue},   "$where.queue" );
        $check->( 'issue.tracker', $i->{tracker}, "$where.tracker" );
    };
    $issue->( $_, 'issue list.issues[]' )    for @{ $ls->{issues} };
    $issue->( $_, 'status.issues.queue[]' )  for @{ $st->{issues}{queue} };
    $check->( "status.$_", $st->{$_}, "status.$_" ) for qw(overview templates pause shipped issues plans pickup adoption offline next_action);
    $check->( 'status.templates.drifted[]', $_, 'drifted[]' ) for @{ $st->{templates}{drifted} };
    if ( $st->{pause} ) {
        $check->( 'status.pause.stashes[]', $_, 'stashes[]' ) for @{ $st->{pause}{stashes} };
    }
    $check->( 'status.shipped.entries[]', $_, 'entries[]' ) for @{ $st->{shipped}{entries} };
    my $plan;
    $plan = sub {
        my ( $p, $where ) = @_;
        $check->( 'plan', $p, $where );
        $check->( 'plan.requests', $p->{requests}, "$where.requests" );
        $plan->( $_, "$where.members[]" ) for @{ $p->{members} };
    };
    $plan->( $_, 'plans.items[]' ) for @{ $st->{plans}{items} };
    $check->( 'status.pickup.items[]', $_, 'pickup.items[]' ) for @{ $st->{pickup}{items} };
    my $e    = doc( $self, 'error.json' );
    my @keys = AAPP::JSON::key_order($e);
    push @errors, 'error document: envelope differs' if join( ',', @keys[ 0 .. $#env ] ) ne join( ',', @env );
    push @errors, "error document: [@keys[ @env .. $#keys ]] differs" if join( ',', @keys[ @env .. $#keys ] ) ne join( ',', @{ $tables{'error document'} // [] } );
    $seen{'error document'} = 1;
    $check->( 'error',   $e->{error},   'error' );
    $check->( 'notices', $e->{notices}, 'error.notices' );
    my @unseen = grep { !$seen{$_} && $_ ne 'status.offline' && $_ ne 'status.templates.drifted[]' } sort keys %tables;
    push @errors, "tables with no object in the fixture: @unseen" if @unseen;
    $self->true_or_die( !@errors, 'every object matches its reference table', join( "\n", @errors ) );
    return 1;
}

sub test_absent_values_are_null
{
    my ($self) = @_;
    my ( undef, undef, $pid ) = split( ' ', AAPP::Tests::read_text('ids.txt') );
    my ($i3) = by_id( doc( $self, 'list.json' )->{issues}, '#3' );
    $self->true_or_die( !defined $i3->{$_}, "#3's $_ is null" ) for qw(plan blocks queue branch tracker);
    $self->true_or_die( exists $i3->{plan} && exists $i3->{tracker}, 'absent values are present as null' );
    $self->eq_or_die( "$i3->{offline}", 'false', "#3's offline is false" );
    my $st = doc( $self, 'status.json' );
    my ($plan) = grep { $_->{id} eq $pid } @{ $st->{plans}{items} };
    $self->eq_or_die( scalar( @{ $plan->{members} } ), 0, 'a plan without members has an empty list' );
    $self->eq_or_die( scalar( @{ $st->{templates}{drifted} } ), 0, 'no drifted templates: an empty list' );
    return 1;
}

sub test_text_verbatim
{
    my ($self) = @_;
    my ($i1)  = by_id( doc( $self, 'list.json' )->{issues}, '#1' );
    my ($q1)  = by_id( doc( $self, 'status.json' )->{issues}{queue}, '#1' );
    $self->eq_or_die( $i1->{symptom}, $SYM, 'the symptom in issue list' );
    $self->eq_or_die( $q1->{symptom}, $SYM, 'the symptom in status' );
    return 1;
}

sub test_issue_notes_count
{
    my ($self) = @_;
    my $issues = doc( $self, 'list.json' )->{issues};
    $self->eq_or_die( ( by_id( $issues, '#1' ) )[0]{notes}, 2, '#1 has two notes' );
    $self->eq_or_die( ( by_id( $issues, '#2' ) )[0]{notes}, 0, '#2 has none' );
    $self->true_or_die( AAPP::Tests::read_text('list.json') . AAPP::Tests::read_text('status.json') !~ /secret/, 'no note text in the documents' );
    return 1;
}

sub test_repository_remote
{
    my ($self) = @_;
    my $want = 'https://example.com/acme/app.git';
    $self->eq_or_die( doc( $self, 'status.json' )->{repository}{remote}{url}, $want, 'status: the URL without credentials' );
    my $remote = doc( $self, 'list.json' )->{repository}{remote};
    $self->eq_or_die( "$remote->{name} $remote->{url}", "origin $want", 'issue list: name and URL' );
    $self->true_or_die( AAPP::Tests::read_text('status.json') . AAPP::Tests::read_text('list.json') !~ /s3cret/, 'no credentials anywhere' );
    $self->ok_cmd( 'git', 'remote', 'remove', 'origin' );
    save( $self, 'nore.json',  'issue', 'list', 'json' );
    save( $self, 'nores.json', 'status', 'json' );
    $self->true_or_die( !defined doc( $self, 'nore.json' )->{repository}{remote},  'issue list without a remote: null' );
    $self->true_or_die( !defined doc( $self, 'nores.json' )->{repository}{remote}, 'status without a remote: null' );
    return 1;
}

sub test_local_path_setting
{
    my ($self) = @_;
    my $root = Cwd::getcwd();
    save( $self, 'here.json', 'issue', 'list', 'json' );
    $self->eq_or_die( doc( $self, 'here.json' )->{repository}{root}, $root, 'the root by default' );
    $self->ok_cmd( 'git', 'config', 'aapp.jsonLocalPath', 'false' );
    save( $self, 'nopath.json',  'issue', 'list', 'json' );
    save( $self, 'nopaths.json', 'status', 'json' );
    $self->true_or_die( !defined doc( $self, 'nopath.json' )->{repository}{root},  'issue list: root is null' );
    $self->true_or_die( !defined doc( $self, 'nopaths.json' )->{repository}{root}, 'status: root is null' );
    $self->true_or_die( index( AAPP::Tests::read_text('nopath.json') . AAPP::Tests::read_text('nopaths.json'), $root ) < 0, 'no local path anywhere' );
    return 1;
}

sub test_group_nests_members
{
    my ($self) = @_;
    my ( $gid, $mid ) = split( ' ', AAPP::Tests::read_text('ids.txt') );
    my $aid   = 'P-' . ( ( $gid =~ s/^P-//r ) + 1 );
    my $items = doc( $self, 'status.json' )->{plans}{items};
    my ($g)   = grep { $_->{id} eq $gid } @{$items};
    $self->eq_or_die( $g->{kind}, 'group', 'the group' );
    $self->eq_or_die( join( ',', map { $_->{id} } @{ $g->{members} } ), "$mid,$aid", 'its members, the amendments member last' );
    $self->eq_or_die( $g->{members}[0]{group}, $gid,         'a member names its group' );
    $self->eq_or_die( $g->{members}[1]{kind},  'amendments', 'the amendments member' );
    $self->true_or_die( !grep( { $_->{id} eq $mid } @{$items} ), 'members are not listed again at the top' );
    return 1;
}

sub test_pickup_objects
{
    my ($self) = @_;
    my $st = doc( $self, 'status.json' );
    my ($p) = grep { ( $_->{title} // '' ) eq 'Linked Idea' } @{ $st->{pickup}{items} };
    $self->eq_or_die( join( '|', AAPP::JSON::key_order($p) ), 'title|text|files', 'the item keys' );
    $self->eq_or_die( $p->{text}, 'see `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.', 'its text' );
    $self->eq_or_die( join( ',', @{ $p->{files} } ), '.plans/pickup/kept.md', 'existing files only' );
    my @notices = map { $_->{text} } @{ $st->{notices}{warning} }, @{ $st->{notices}{info} };
    $self->true_or_die( grep( { index( $_, '.plans/pickup/gone.md' ) >= 0 } @notices ), 'the missing file is a notice' );
    return 1;
}

sub test_same_items_as_terminal
{
    my ($self) = @_;
    my $term = $self->run_aapp('status')->{out};
    my ( $issues ) = $term =~ /ISSUES(.*?)PLANS/s;
    my ( $plans )  = $term =~ /PLANS(.*?)PICKUP/s;
    my ( $pickup ) = $term =~ /PICKUP(.*?)\n\n/s;
    my $tq = join( ',', $issues =~ /^  (#[0-9]+)/mg );
    my $tp = join( ',', $plans =~ /^  • (P-[0-9]+)/mg );
    my $ti = join( '|', $pickup =~ /^  - \[ \] (.*)$/mg );
    my $st = doc( $self, 'status.json' );
    $self->true_or_die( $tq ne '', 'the terminal briefing lists queued issues' );
    $self->eq_or_die( join( ',', map { $_->{id} } @{ $st->{issues}{queue} } ), $tq, 'the queue' );
    $self->eq_or_die( join( ',', map { $_->{id} } @{ $st->{plans}{items} } ),  $tp, 'the plans' );
    $self->eq_or_die( join( '|', map { $_->{title} || $_->{text} } @{ $st->{pickup}{items} } ), $ti, 'the pickup items' );
    return 1;
}

sub test_failure_is_error_document
{
    my ($self) = @_;
    my $e = doc( $self, 'error.json' );
    $self->true_or_die( exit_of('error.json') != 0, 'a failing run exits non-zero' );
    $self->eq_or_die( $e->{command}, 'status', 'the command' );
    $self->true_or_die( exists $e->{error} && !exists $e->{overview}, 'the error document, not the status document' );
    $self->match_or_die( AAPP::Tests::read_text('status.err'), qr/aapp\.statusItemsMax/, 'the message also on stderr' );
    return 1;
}

sub test_notices_grouped_by_level
{
    my ($self) = @_;
    my $st = doc( $self, 'status.json' );
    $self->eq_or_die( join( ',', AAPP::JSON::key_order( $st->{notices} ) ), 'warning,info', 'warning then info' );
    my $ln = doc( $self, 'list.json' )->{notices};
    $self->eq_or_die( scalar( @{ $ln->{warning} } ) + scalar( @{ $ln->{info} } ), 0, 'issue list: both empty' );
    my @all = ( @{ $st->{notices}{warning} }, @{ $st->{notices}{info} } );
    $self->true_or_die( scalar(@all), 'status has notices' );
    foreach my $n (@all) {
        $self->eq_or_die( join( ',', AAPP::JSON::key_order($n) ), 'section,text', 'a notice is {section, text}' );
        $self->match_or_die( $n->{text}, qr/^[\[A-Za-z0-9(#`.]/, 'a notice starts with its text, no emoji' );
    }
    return 1;
}

# Usage     : my $dir = tracker_project($self)
# Purpose   : A second project with one issue and an aapp-issue-tracker provider that lists issues
#             (<dir>.t/list) or fails on a step (<dir>.t/fail.<step>); the test is moved into it.
# Returns   : The provider's control folder.
sub tracker_project
{
    my ($self) = @_;
    my $tr = "$self->{dir}.tr";
    my $t  = "$self->{dir}.t";
    File::Path::make_path( $tr, $t );
    chdir($tr) or die "cannot enter $tr: $!\n";
    $self->init_project();
    $self->ok_cmd( 'git', 'config', $_->[0], $_->[1] ) for [ 'aapp.offlineEnabled', 'false' ], [ 'aapp.pluginTimeout', '5' ];
    AAPP::Tests::write_text( '.plans/ISSUES.md', join( "\n", '# Issues', '',
        '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |', '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |',
        '| #1 | `Low` | `CLI` | 2026-10-01 | `src/a.sh` | Defect one. |  | 🟡 `Incubated` |' ) . "\n" );
    AAPP::Tests::write_text( '.plans/issues_road_map.md', "# 🗺️ Issue Work Queue\n\n## 🧱 Plan Blockers\n\n## 📋 Queued\n" );
    $self->ok_cmd( 'git', '-C', '.plans', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'fixture', '--no-verify' );
    File::Path::make_path('.agents/skills/aapp-issue-tracker');
    AAPP::Tests::write_text( '.agents/skills/aapp-issue-tracker/run', <<"EOF" );
#!/bin/sh
cat > /dev/null
step="\${AAPP_PLUGIN_STEP#issue.}"
[ -f "$t/fail.\$step" ] && exit 3
if [ "\$step" = "list" ]; then [ -f "$t/list" ] && cat "$t/list" > "\$AAPP_PLUGIN_LIST"; echo '{"status": "ok", "handled": "list"}'
else echo '{"status": "ok"}'; fi
EOF
    chmod( 0755, '.agents/skills/aapp-issue-tracker/run' ) or die "cannot chmod the provider: $!\n";
    return $t;
}

sub test_sync_warning_in_notices
{
    my ($self) = @_;
    my $t = tracker_project($self);
    AAPP::Tests::write_text( "$t/fail.list", '' );
    my $r = save( $self, 'sync.json', 'issue', 'list', 'json' );
    $self->eq_or_die( $r->{exit}, 0,  'a failing tracker listing does not fail the run' );
    $self->eq_or_die( $r->{err},  '', 'nothing on stderr' );
    my @w = @{ doc( $self, 'sync.json' )->{notices}{warning} };
    $self->true_or_die( grep( { $_->{section} eq 'issues' && index( $_->{text}, 'aapp-issue-tracker' ) >= 0 } @w ), 'a warning in notices', AAPP::Tests::read_text('sync.json') );
    return 1;
}

sub test_error_codes
{
    my ($self) = @_;
    my $code = sub {
        my $e = doc( $self, $_[0] )->{error};
        return join( ',', $e->{code}, $e->{aapp_config} // 'null' );
    };
    my $u1 = save( $self, 'e-usage.json',  'issue', 'list', 'sideways', 'json' );
    my $u2 = save( $self, 'e-usage2.json', 'status', 'short', 'json' );
    $self->true_or_die( $u1->{exit} != 0 && $u2->{exit} != 0, 'usage errors exit non-zero' );
    $self->eq_or_die( $code->('e-usage.json'),  'usage,null', 'issue list sideways' );
    $self->eq_or_die( $code->('e-usage2.json'), 'usage,null', 'status short json' );
    $self->eq_or_die( $code->('error.json'),    'invalid-setting,aapp.statusItemsMax', 'a bad setting names it' );
    my $plain = "$self->{dir}.plain";
    File::Path::make_path($plain);
    $self->ok_cmd( 'git', 'init', '-q', $plain );
    my $f = $self->run_cmd( 'sh', '-c', 'cd "$1" && aapp issue list json', 'sh', $plain );
    AAPP::Tests::write_text( 'e-failed.json', $f->{out} );
    $self->true_or_die( $f->{exit} != 0, 'a repository without the kit fails' );
    $self->eq_or_die( $code->('e-failed.json'), 'failed,null', 'a failure' );
    my $t = tracker_project($self);
    AAPP::Tests::write_text( "$t/list",
        '{"id": "#1", "sev": "Low", "type": "CLI", "date": "2026-10-01", "location": "`src/a.sh`", "symptom": "Defect one.", "status": "open"}' . "\n" );
    my $c = save( $self, 'e-confirm.json', 'issue', 'list', 'json' );
    $self->true_or_die( $c->{exit} != 0, 'a needed answer fails a JSON run' );
    $self->eq_or_die( $code->('e-confirm.json'), 'confirm-needed,null', 'it never waits for an answer' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
