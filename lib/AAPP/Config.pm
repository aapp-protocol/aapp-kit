package AAPP::Config;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR);
use AAPP::Logger ();

our %config;
our $loaded = 0;

our @PLAN_STATES;
our $states_loaded = 0;

my @DEFAULT_STATES = (
    [ 'under-review',   '🟣', 'Under Review',   '🧠 Human Thought & Refinement (The Incubator)',      10 ],
    [ 'refining',       '📝', 'Refining',       '🧠 Human Thought & Refinement (The Incubator)',      10 ],
    [ 'frozen',         '🔷', 'Frozen',         '🔷 Frozen & Ready for Coding (The Greenlight Zone)', 20 ],
    [ 'in-development', '⚡', 'In Development', '⚡ In Development (Active Implementation Context)',  30 ],
    [ 'blocked',        '🟥', 'BLOCKED',        '🟥 Blocked (Halted on an Issue)',                    40 ],
);

# Usage     : my $k = canonical_key('aapp.planState.Review')
# Purpose   : Writes a key as git does: section and name lowercased, a subsection kept as written.
# Returns   : The canonical key.
sub canonical_key
{
    my ($key) = @_;
    my $first = index( $key, '.' );
    my $last  = rindex( $key, '.' );
    if ( $first < 0 ) {
        return lc $key;
    }
    if ( $first == $last ) {
        return lc $key;
    }
    my $section    = substr( $key, 0, $first );
    my $subsection = substr( $key, $first + 1, $last - $first - 1 );
    my $name       = substr( $key, $last + 1 );
    return lc($section) . '.' . $subsection . '.' . lc($name);
}

# Usage     : AAPP::Config::load()
# Purpose   : Reads every git config value once (git config --list -z) into %config, decoded as UTF-8.
#             A key written without a value is stored as undef, which git reads as true.
# Returns   : RETURN_OK, or RETURN_ERROR after an [ ERROR ] line when git config cannot be read.
sub load
{
    if ( $loaded == 1 ) {
        return RETURN_OK;
    }
    if ( $loaded == -1 ) {
        return RETURN_ERROR;
    }
    my $fh;
    if ( !open( $fh, '-|:encoding(UTF-8)', 'git', 'config', '--list', '-z' ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot run git config: $!" );
        $loaded = -1;
        return RETURN_ERROR;
    }
    local $/ = "\0";
    while ( my $entry = <$fh> ) {
        chomp($entry);
        my ( $key, $value ) = split( /\n/, $entry, 2 );
        push @{ $config{ canonical_key($key) } }, $value;
    }
    if ( !close($fh) ) {
        AAPP::Logger::print_msg( 'ERROR', 'git config --list failed; settings cannot be read.' );
        $loaded = -1;
        return RETURN_ERROR;
    }
    $loaded = 1;
    return RETURN_OK;
}

# Usage     : my $v = AAPP::Config::get('aapp.perlLogFile')
# Purpose   : Returns the last value of a key, as git does for single-valued keys.
# Returns   : The value ('' for a key without a value), or undef when unset.
sub get
{
    my ($key) = @_;
    load();
    my $all = $config{ canonical_key($key) };
    if ( !defined $all ) {
        return;
    }
    return $all->[-1] // '';
}

# Usage     : my @v = AAPP::Config::get_all('aapp.allowPath')
# Purpose   : Returns every value of a multi-valued key, in config order.
# Returns   : List of values; empty when unset.
sub get_all
{
    my ($key) = @_;
    load();
    my $all = $config{ canonical_key($key) };
    if ( !defined $all ) {
        return ();
    }
    return map { $_ // '' } @{$all};
}

# Usage     : my ($rc, $n) = AAPP::Config::get_int('aapp.statusOutputWidth', 85, 40)
# Purpose   : Returns a whole-number setting, its default when unset; a value below $min or not a number is an error.
# Returns   : (RETURN_OK, $value), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub get_int
{
    my ( $key, $default, $min ) = @_;
    my $v = get($key);
    if ( !defined $v ) {
        return ( RETURN_OK, $default );
    }
    if ( $v !~ /^\d+$/ || ( defined $min && $v < $min ) ) {
        my $limit = defined $min ? " of at least $min" : '';
        AAPP::Logger::print_msg( 'ERROR', "$key is '$v'; it must be a whole number$limit." );
        return ( RETURN_ERROR, undef );
    }
    return ( RETURN_OK, $v );
}

# Usage     : my ($rc, $on) = AAPP::Config::get_bool('aapp.docs', 1)
# Purpose   : Returns a boolean setting as git reads it (true/yes/on/non-zero, false/no/off/0/empty),
#             its default when unset; any other value is an error.
# Returns   : (RETURN_OK, 1 or 0), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub get_bool
{
    my ( $key, $default ) = @_;
    load();
    my $all = $config{ canonical_key($key) };
    if ( !defined $all ) {
        return ( RETURN_OK, $default );
    }
    my $v = $all->[-1];
    if ( !defined $v ) {
        return ( RETURN_OK, 1 );
    }
    my $word = lc $v;
    if ( $word eq 'true' || $word eq 'yes' || $word eq 'on' ) {
        return ( RETURN_OK, 1 );
    }
    if ( $word eq 'false' || $word eq 'no' || $word eq 'off' || $word eq '' ) {
        return ( RETURN_OK, 0 );
    }
    if ( $word =~ /^-?\d+$/ ) {
        return ( RETURN_OK, $word != 0 ? 1 : 0 );
    }
    AAPP::Logger::print_msg( 'ERROR', "$key is '$v'; it must be true or false." );
    return ( RETURN_ERROR, undef );
}

# Usage     : my @keys = AAPP::Config::keys_with_prefix('aapp.planState.')
# Purpose   : Lists the keys that start with a prefix, for registries such as aapp.planState.*.
# Returns   : Sorted list of canonical keys.
sub keys_with_prefix
{
    my ($prefix) = @_;
    load();
    my $want = canonical_key( $prefix . 'x' );
    $want = substr( $want, 0, length($want) - 1 );
    my @keys = sort grep { index( $_, $want ) == 0 } keys %config;
    return @keys;
}

# Usage     : plan_states_load()
# Purpose   : Builds the plan status registry once: the kit's five states, then aapp.planState.<slug>
#             tuples (<emoji>|<name>|<heading>|<rank>); a known slug is replaced in place, a new one appended.
# Returns   : RETURN_OK
sub plan_states_load
{
    if ($states_loaded) {
        return RETURN_OK;
    }
    @PLAN_STATES = ();
    foreach my $d (@DEFAULT_STATES) {
        push @PLAN_STATES, { slug => $d->[0], emoji => $d->[1], name => $d->[2], heading => $d->[3], rank => $d->[4] };
    }
    foreach my $key ( keys_with_prefix('aapp.planState.') ) {
        my $slug = substr( $key, rindex( $key, '.' ) + 1 );
        foreach my $tuple ( get_all($key) ) {
            my $state = _plan_state_from_tuple( $key, $slug, $tuple );
            if ( !defined $state ) {
                next;
            }
            my ($known) = grep { $_->{slug} eq $slug } @PLAN_STATES;
            if ( defined $known ) {
                %{$known} = %{$state};
            } else {
                push @PLAN_STATES, $state;
            }
        }
    }
    $states_loaded = 1;
    return RETURN_OK;
}

# Usage     : my $state = _plan_state_from_tuple($key, $slug, $tuple)
# Purpose   : Checks one adopter tuple; a malformed one is skipped with a [ WARN ] line, never fatal.
# Returns   : Hash ref {slug, emoji, name, heading, rank}, or undef when malformed.
sub _plan_state_from_tuple
{
    my ( $key, $slug, $tuple ) = @_;
    my @fields = split( /\|/, $tuple, -1 );
    if ( @fields != 4 ) {
        AAPP::Logger::print_msg( 'WARN', "Plan state '$key' skipped: expected 4 fields (<emoji>|<name>|<heading>|<rank>), got " . scalar(@fields) . '.' );
        return;
    }
    my ( $emoji, $name, $heading, $rank ) = @fields;
    if ( $emoji eq '' || $name eq '' || $heading eq '' ) {
        AAPP::Logger::print_msg( 'WARN', "Plan state '$key' skipped: emoji, name and heading must all be non-empty." );
        return;
    }
    if ( $rank !~ /^\d+$/ ) {
        AAPP::Logger::print_msg( 'WARN', "Plan state '$key' skipped: rank '$rank' is not a whole number." );
        return;
    }
    return { slug => $slug, emoji => $emoji, name => $name, heading => $heading, rank => $rank };
}

# Usage     : my $value = plan_state_field('frozen', 'emoji')
# Purpose   : Reads one field (emoji, name, heading, rank) of a registered status.
# Returns   : The value, or undef for an unknown slug or field.
sub plan_state_field
{
    my ( $slug, $field ) = @_;
    plan_states_load();
    my ($state) = grep { $_->{slug} eq $slug } @PLAN_STATES;
    if ( !defined $state ) {
        return;
    }
    return $state->{$field};
}

# Usage     : my $slug = plan_state_for_status_line($line)
# Purpose   : Resolves a Status line to a slug by the status NAME, never the emoji; tolerates a
#             leading * or -, bold markers, spacing and trailing text.
# Returns   : The slug, or undef when the line has no known status.
sub plan_state_for_status_line
{
    my ($line) = @_;
    plan_states_load();
    my $at = index( $line, '**Status:**' );
    if ( $at < 0 ) {
        return;
    }
    my $rest = substr( $line, $at + length('**Status:**') );
    foreach my $state (@PLAN_STATES) {
        if ( $rest =~ /\Q$state->{name}\E(?:\s|\z)/ ) {
            return $state->{slug};
        }
    }
    return;
}

# Usage     : my $line = status_line_of_lines(@lines)
# Purpose   : Finds the header's Status line: the first **Status:** line outside fenced blocks,
#             before the first '## ' heading.
# Returns   : The line without its newline, or undef when there is none.
sub status_line_of_lines
{
    my (@lines) = @_;
    my $fenced = 0;
    foreach my $line (@lines) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ($fenced) {
            next;
        }
        if ( $line =~ /^##\s/ ) {
            return;
        }
        if ( $line =~ /^\s*[*-]?\s*\*\*Status:\*\*/ ) {
            my $found = $line;
            chomp($found);
            return $found;
        }
    }
    return;
}

# Usage     : my @lines = _read_lines($file)
# Purpose   : Reads a text file as UTF-8 ('-' reads STDIN).
# Returns   : (RETURN_OK, @lines), or (RETURN_ERROR) after an [ ERROR ] line when the file cannot be read.
sub _read_lines
{
    my ($file) = @_;
    if ( $file eq '-' ) {
        my @lines = <STDIN>;
        return ( RETURN_OK, @lines );
    }
    my $fh;
    if ( !open( $fh, '<:encoding(UTF-8)', $file ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot read $file: $!" );
        return (RETURN_ERROR);
    }
    my @lines = <$fh>;
    close($fh);
    return ( RETURN_OK, @lines );
}

# Usage     : my $line = plan_status_line($file)
# Purpose   : The one reader of a plan's Status line ('-' reads STDIN).
# Returns   : The line, or undef when the file has none or cannot be read.
sub plan_status_line
{
    my ($file) = @_;
    my ( $rc, @lines ) = _read_lines($file);
    if ( $rc != RETURN_OK ) {
        return;
    }
    return status_line_of_lines(@lines);
}

# Usage     : my $text = plan_status_text($file)
# Purpose   : The status as written after **Status:**, for messages.
# Returns   : The text, or '' when there is no Status line.
sub plan_status_text
{
    my ($file) = @_;
    my $line = plan_status_line($file);
    if ( !defined $line ) {
        return '';
    }
    my $text = substr( $line, index( $line, '**Status:**' ) + length('**Status:**') );
    $text =~ s/^\s+//;
    return $text;
}

# Usage     : my $slug = plan_status_slug($file)
# Purpose   : The registry slug of a plan's status.
# Returns   : The slug, or undef when the line is missing or names no known status.
sub plan_status_slug
{
    my ($file) = @_;
    my $line = plan_status_line($file);
    if ( !defined $line ) {
        return;
    }
    return plan_state_for_status_line($line);
}

# Usage     : if ( plan_status_is($file, 'frozen', 'in-development') ) { ... }
# Purpose   : Tells whether a plan's status is one of the given slugs.
# Returns   : 1 when it is, 0 otherwise.
sub plan_status_is
{
    my ( $file, @wanted ) = @_;
    my $slug = plan_status_slug($file);
    if ( !defined $slug ) {
        return 0;
    }
    foreach my $want (@wanted) {
        if ( $slug eq $want ) {
            return 1;
        }
    }
    return 0;
}

# Usage     : my $text = plan_status_render('frozen')
# Purpose   : '<emoji> <name>', as a Status line and messages show a status.
# Returns   : The text, or undef for an unknown slug.
sub plan_status_render
{
    my ($slug) = @_;
    my $emoji = plan_state_field( $slug, 'emoji' );
    my $name  = plan_state_field( $slug, 'name' );
    if ( !defined $emoji || !defined $name ) {
        return;
    }
    return "$emoji $name";
}

# Usage     : my $rc = plan_set_status($file, 'in-development')
# Purpose   : The one writer of a plan's Status line, from the registry. An unknown slug or a plan
#             without a Status line is refused and nothing is written.
# Returns   : RETURN_OK; RETURN_FAIL when refused; RETURN_ERROR when the file cannot be read or written.
sub plan_set_status
{
    my ( $file, $slug ) = @_;
    my $text = plan_status_render($slug);
    if ( !defined $text ) {
        AAPP::Logger::print_msg( 'ERROR', "Unknown status '$slug'." );
        return RETURN_FAIL;
    }
    my ( $rc, @lines ) = _read_lines($file);
    if ( $rc != RETURN_OK ) {
        return RETURN_ERROR;
    }
    if ( !defined status_line_of_lines(@lines) ) {
        my $name = $file =~ s{.*/}{}r;
        AAPP::Logger::print_msg( 'ERROR', "$name has no Status line." );
        return RETURN_FAIL;
    }
    my ( $fenced, $done, $past ) = ( 0, 0, 0 );
    foreach my $line (@lines) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ( $fenced || $done || $past ) {
            next;
        }
        if ( $line =~ /^##\s/ ) {
            $past = 1;
            next;
        }
        if ( $line =~ /^\s*[*-]?\s*\*\*Status:\*\*/ ) {
            $line = "* **Status:** $text\n";
            $done = 1;
        }
    }
    my $tmp = "$file.aapp-status.$$";
    my $out;
    if ( !open( $out, '>:encoding(UTF-8)', $tmp ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot write $tmp: $!" );
        return RETURN_ERROR;
    }
    print {$out} @lines;
    if ( !close($out) || !rename( $tmp, $file ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot write $file: $!" );
        unlink($tmp);
        return RETURN_ERROR;
    }
    return RETURN_OK;
}

# Usage     : my @headings = plan_state_sections()
# Purpose   : The matrix section headings, unique, by rank; ties keep registry order.
# Returns   : List of headings.
sub plan_state_sections
{
    plan_states_load();
    my @order = sort { $PLAN_STATES[$a]{rank} <=> $PLAN_STATES[$b]{rank} || $a <=> $b } 0 .. $#PLAN_STATES;
    my %seen;
    my @headings;
    foreach my $i (@order) {
        my $heading = $PLAN_STATES[$i]{heading};
        if ( !$seen{$heading}++ ) {
            push @headings, $heading;
        }
    }
    return @headings;
}

1;
