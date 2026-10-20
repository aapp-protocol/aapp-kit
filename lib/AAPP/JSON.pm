package AAPP::JSON;

use strict;
use warnings;
use utf8;
use 5.026;

use B ();
use POSIX ();
use Scalar::Util ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR);
use AAPP::Config ();
use AAPP::Logger ();
use AAPP::Paths ();

use constant FORMAT_VERSION => '1.0';

our %key_order;

package AAPP::JSON::Boolean {
    use overload
        'bool' => sub { ${ $_[0] } },
        '""'   => sub { ${ $_[0] } ? 'true' : 'false' },
        '0+'   => sub { ${ $_[0] } },
        '=='   => sub { ( ${ $_[0] } ? 1 : 0 ) == ( $_[1] ? 1 : 0 ) },
        '!'    => sub { !${ $_[0] } },
        fallback => 1;
}

our $true  = bless \( my $t = 1 ), 'AAPP::JSON::Boolean';
our $false = bless \( my $f = 0 ), 'AAPP::JSON::Boolean';

# Usage     : my $s = escape($text)
# Purpose   : Escapes a text for a JSON string: backslash, quote, and control characters.
# Returns   : The escaped text, without the surrounding quotes.
sub escape
{
    my ($text) = @_;
    $text =~ s/\\/\\\\/g;
    $text =~ s/"/\\"/g;
    $text =~ s/\n/\\n/g;
    $text =~ s/\r/\\r/g;
    $text =~ s/\t/\\t/g;
    $text =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord($1))/ge;
    return $text;
}

# Usage     : my $j = json_str($text)
# Purpose   : A JSON string.
# Returns   : The JSON text.
sub json_str
{
    my ($text) = @_;
    return '"' . escape( $text // '' ) . '"';
}

# Usage     : my $j = json_strn($text)
# Purpose   : A JSON string, or null for an undefined or empty text.
# Returns   : The JSON text.
sub json_strn
{
    my ($text) = @_;
    if ( !defined $text || $text eq '' ) {
        return 'null';
    }
    return json_str($text);
}

# Usage     : my $j = json_num($n)
# Purpose   : A JSON number, 0 for an undefined or empty value.
# Returns   : The JSON text.
sub json_num
{
    my ($n) = @_;
    if ( !defined $n || $n eq '' ) {
        return '0';
    }
    return "$n";
}

# Usage     : my $j = json_numn($n)
# Purpose   : A JSON number, or null for an undefined or empty value.
# Returns   : The JSON text.
sub json_numn
{
    my ($n) = @_;
    if ( !defined $n || $n eq '' ) {
        return 'null';
    }
    return "$n";
}

# Usage     : my $j = json_bool($value)
# Purpose   : true for 1, 'true' or a true AAPP::JSON boolean; false otherwise.
# Returns   : The JSON text.
sub json_bool
{
    my ($value) = @_;
    if ( ref($value) eq 'AAPP::JSON::Boolean' ) {
        return $value ? 'true' : 'false';
    }
    if ( defined $value && ( $value eq '1' || $value eq 'true' ) ) {
        return 'true';
    }
    return 'false';
}

# Usage     : my $j = json_list(json_str('a'), json_num(2))
# Purpose   : A JSON list of values that are already JSON.
# Returns   : The JSON text.
sub json_list
{
    my (@values) = @_;
    return '[' . join( ',', @values ) . ']';
}

# Usage     : my $j = json_strlist('a', 'b')
# Purpose   : A JSON list of strings; empty texts are left out.
# Returns   : The JSON text.
sub json_strlist
{
    my (@texts) = @_;
    return json_list( map { json_str($_) } grep { defined $_ && $_ ne '' } @texts );
}

# Usage     : my $j = json_obj(id => json_str('12'), open => json_bool(1))
# Purpose   : A JSON object from key/value pairs, in the order given; the values are already JSON.
# Returns   : The JSON text.
sub json_obj
{
    my (@pairs) = @_;
    my @members;
    while ( @pairs >= 2 ) {
        my $key   = shift @pairs;
        my $value = shift @pairs;
        push @members, json_str($key) . ':' . $value;
    }
    return '{' . join( ',', @members ) . '}';
}

# Usage     : my $text = pretty($compact)
# Purpose   : Prints one compact JSON document with a 2-space indent, a key and its value on one
#             line, empty [] and {} kept whole.
# Returns   : The document, ending with a newline.
sub pretty
{
    my ($json) = @_;
    my $out    = '';
    my $indent = 0;
    my $in_str = 0;
    my $esc    = 0;
    my $n      = length($json);
    for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $c = substr( $json, $i, 1 );
        if ($in_str) {
            $out .= $c;
            if ($esc) {
                $esc = 0;
            } elsif ( $c eq '\\' ) {
                $esc = 1;
            } elsif ( $c eq '"' ) {
                $in_str = 0;
            }
            next;
        }
        if ( $c eq '"' ) {
            $in_str = 1;
            $out .= $c;
            next;
        }
        if ( $c =~ /[ \n\t\r]/ ) {
            next;
        }
        if ( $c eq '{' || $c eq '[' ) {
            my $j = $i + 1;
            while ( $j < $n && substr( $json, $j, 1 ) =~ /[ \n\t\r]/ ) {
                $j++;
            }
            my $d = substr( $json, $j, 1 );
            if ( ( $c eq '{' && $d eq '}' ) || ( $c eq '[' && $d eq ']' ) ) {
                $out .= "$c$d";
                $i = $j;
                next;
            }
            $indent++;
            $out .= "$c\n" . ( '  ' x $indent );
            next;
        }
        if ( $c eq '}' || $c eq ']' ) {
            $indent--;
            $out .= "\n" . ( '  ' x $indent ) . $c;
            next;
        }
        if ( $c eq ',' ) {
            $out .= ",\n" . ( '  ' x $indent );
            next;
        }
        if ( $c eq ':' ) {
            $out .= ': ';
            next;
        }
        $out .= $c;
    }
    return "$out\n";
}

# Usage     : my $json = encode($data)
# Purpose   : Writes Perl data as compact JSON: hashes in the key order read by decode (keys added
#             later follow, sorted), AAPP::JSON booleans as true/false, undef as null.
# Returns   : The JSON text.
sub encode
{
    my ($data) = @_;
    if ( !defined $data ) {
        return 'null';
    }
    my $type = ref($data);
    if ( $type eq 'AAPP::JSON::Boolean' ) {
        return $data ? 'true' : 'false';
    }
    if ( $type eq 'HASH' ) {
        my @pairs;
        foreach my $key ( key_order($data) ) {
            push @pairs, $key, encode( $data->{$key} );
        }
        return json_obj(@pairs);
    }
    if ( $type eq 'ARRAY' ) {
        return json_list( map { encode($_) } @{$data} );
    }
    if ( _is_number($data) ) {
        return "$data";
    }
    return json_str($data);
}

# Usage     : my @keys = key_order($hash)
# Purpose   : The keys of a hash in the order decode read them; keys not read that way follow, sorted.
# Returns   : List of keys.
sub key_order
{
    my ($hash) = @_;
    my $known = $key_order{ Scalar::Util::refaddr($hash) } // [];
    my %seen;
    my @keys = grep { exists $hash->{$_} && !$seen{$_}++ } @{$known};
    push @keys, sort grep { !$seen{$_} } keys %{$hash};
    return @keys;
}

# Usage     : if ( _is_number($value) ) { ... }
# Purpose   : Tells a number from a string by how Perl holds the value, as JSON writers do.
# Returns   : 1 for a number, 0 for a string.
sub _is_number
{
    my ($value) = @_;
    my $flags = B::svref_2object( \$value )->FLAGS;
    if ( ( $flags & ( B::SVp_IOK() | B::SVp_NOK() ) ) && !( $flags & B::SVp_POK() ) ) {
        return 1;
    }
    return 0;
}

# Usage     : my ($rc, $data, $why) = decode($text)
# Purpose   : Reads one JSON document into Perl data: objects as hashes (key order kept for encode),
#             lists as arrays, true/false as AAPP::JSON booleans, null as undef.
# Returns   : (RETURN_OK, $data), or (RETURN_FAIL, undef, $why) when the text is not valid JSON.
sub decode
{
    my ($text) = @_;
    if ( !defined $text ) {
        return ( RETURN_FAIL, undef, 'no JSON text' );
    }
    my $p    = { text => $text, pos => 0, err => undef };
    my $data = _parse_value($p);
    if ( defined $p->{err} ) {
        return ( RETURN_FAIL, undef, $p->{err} );
    }
    _skip_space($p);
    if ( $p->{pos} < length($text) ) {
        return ( RETURN_FAIL, undef, "unexpected text at offset $p->{pos}" );
    }
    return ( RETURN_OK, $data );
}

# Usage     : my ($rc, $data, $why) = decode_file($path)
# Purpose   : Reads a UTF-8 file and decodes it as one JSON document.
# Returns   : As decode; (RETURN_ERROR, undef, $why) when the file cannot be read.
sub decode_file
{
    my ($path) = @_;
    my $fh;
    if ( !open( $fh, '<:encoding(UTF-8)', $path ) ) {
        return ( RETURN_ERROR, undef, "cannot read $path: $!" );
    }
    my $text = do { local $/; <$fh> };
    close($fh);
    return decode($text);
}

# Usage     : my $value = json_field($json, 'status')
# Purpose   : A top-level string, number or boolean of a flat JSON object, as plugin answers carry them.
# Returns   : The value as text (booleans as 'true'/'false'), or undef when absent, nested or not JSON.
sub json_field
{
    my ( $json, $key ) = @_;
    my ( $rc, $data ) = decode($json);
    if ( $rc != RETURN_OK || ref($data) ne 'HASH' ) {
        return;
    }
    my $value = $data->{$key};
    if ( !defined $value ) {
        return;
    }
    my $type = ref($value);
    if ( $type eq 'AAPP::JSON::Boolean' ) {
        return "$value";
    }
    if ( $type ne '' ) {
        return;
    }
    return $value;
}

# Usage     : _skip_space($p)
# Purpose   : Moves the parser past JSON whitespace.
# Returns   : undef
sub _skip_space
{
    my ($p) = @_;
    pos( $p->{text} ) = $p->{pos};
    if ( $p->{text} =~ /\G[ \t\n\r]+/gc ) {
        $p->{pos} = pos( $p->{text} );
    }
    return;
}

# Usage     : my $value = _fail($p, $why)
# Purpose   : Records the first parse error; later steps see it and stop.
# Returns   : undef
sub _fail
{
    my ( $p, $why ) = @_;
    if ( !defined $p->{err} ) {
        $p->{err} = $why;
    }
    return;
}

# Usage     : my $value = _parse_value($p)
# Purpose   : Parses one JSON value at the parser's position.
# Returns   : The value; undef with $p->{err} set on bad input.
sub _parse_value
{
    my ($p) = @_;
    _skip_space($p);
    my $c = substr( $p->{text}, $p->{pos}, 1 );
    if ( $c eq '{' ) {
        return _parse_object($p);
    }
    if ( $c eq '[' ) {
        return _parse_array($p);
    }
    if ( $c eq '"' ) {
        return _parse_string($p);
    }
    pos( $p->{text} ) = $p->{pos};
    if ( $p->{text} =~ /\G(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?)/gc ) {
        $p->{pos} = pos( $p->{text} );
        return 0 + $1;
    }
    foreach my $word ( [ 'true', $true ], [ 'false', $false ], [ 'null', undef ] ) {
        if ( substr( $p->{text}, $p->{pos}, length( $word->[0] ) ) eq $word->[0] ) {
            $p->{pos} += length( $word->[0] );
            return $word->[1];
        }
    }
    return _fail( $p, "unexpected character at offset $p->{pos}" );
}

# Usage     : my $hash = _parse_object($p)
# Purpose   : Parses a JSON object and records its key order.
# Returns   : Hash ref; undef with $p->{err} set on bad input.
sub _parse_object
{
    my ($p) = @_;
    my %hash;
    my @order;
    $p->{pos}++;
    _skip_space($p);
    if ( substr( $p->{text}, $p->{pos}, 1 ) eq '}' ) {
        $p->{pos}++;
        return \%hash;
    }
    while (1) {
        _skip_space($p);
        if ( substr( $p->{text}, $p->{pos}, 1 ) ne '"' ) {
            return _fail( $p, "expected a key at offset $p->{pos}" );
        }
        my $key = _parse_string($p);
        if ( defined $p->{err} ) {
            return;
        }
        _skip_space($p);
        if ( substr( $p->{text}, $p->{pos}, 1 ) ne ':' ) {
            return _fail( $p, "expected ':' at offset $p->{pos}" );
        }
        $p->{pos}++;
        my $value = _parse_value($p);
        if ( defined $p->{err} ) {
            return;
        }
        if ( !exists $hash{$key} ) {
            push @order, $key;
        }
        $hash{$key} = $value;
        _skip_space($p);
        my $c = substr( $p->{text}, $p->{pos}, 1 );
        if ( $c eq '}' ) {
            $p->{pos}++;
            last;
        }
        if ( $c ne ',' ) {
            return _fail( $p, "expected ',' or '}' at offset $p->{pos}" );
        }
        $p->{pos}++;
    }
    my $ref = \%hash;
    $key_order{ Scalar::Util::refaddr($ref) } = \@order;
    return $ref;
}

# Usage     : my $array = _parse_array($p)
# Purpose   : Parses a JSON list.
# Returns   : Array ref; undef with $p->{err} set on bad input.
sub _parse_array
{
    my ($p) = @_;
    my @list;
    $p->{pos}++;
    _skip_space($p);
    if ( substr( $p->{text}, $p->{pos}, 1 ) eq ']' ) {
        $p->{pos}++;
        return \@list;
    }
    while (1) {
        my $value = _parse_value($p);
        if ( defined $p->{err} ) {
            return;
        }
        push @list, $value;
        _skip_space($p);
        my $c = substr( $p->{text}, $p->{pos}, 1 );
        if ( $c eq ']' ) {
            $p->{pos}++;
            last;
        }
        if ( $c ne ',' ) {
            return _fail( $p, "expected ',' or ']' at offset $p->{pos}" );
        }
        $p->{pos}++;
    }
    return \@list;
}

my %UNESCAPE = ( '"' => '"', '\\' => '\\', '/' => '/', b => "\b", f => "\f", n => "\n", r => "\r", t => "\t" );

# Usage     : my $s = _parse_string($p)
# Purpose   : Parses a JSON string, with \uXXXX escapes and surrogate pairs.
# Returns   : The string; undef with $p->{err} set on bad input.
sub _parse_string
{
    my ($p) = @_;
    my $start = $p->{pos};
    $p->{pos}++;
    my $out = '';
    while (1) {
        pos( $p->{text} ) = $p->{pos};
        if ( $p->{text} =~ /\G([^"\\\x00-\x1f]+)/gc ) {
            $out .= $1;
            $p->{pos} = pos( $p->{text} );
        }
        my $c = substr( $p->{text}, $p->{pos}, 1 );
        if ( $c eq '"' ) {
            $p->{pos}++;
            return $out;
        }
        if ( $c ne '\\' ) {
            return _fail( $p, "unterminated string starting at offset $start" );
        }
        my $e = substr( $p->{text}, $p->{pos} + 1, 1 );
        if ( exists $UNESCAPE{$e} ) {
            $out .= $UNESCAPE{$e};
            $p->{pos} += 2;
            next;
        }
        if ( $e ne 'u' ) {
            return _fail( $p, "bad escape at offset $p->{pos}" );
        }
        my $hex = substr( $p->{text}, $p->{pos} + 2, 4 );
        if ( $hex !~ /^[0-9A-Fa-f]{4}$/ ) {
            return _fail( $p, "bad \\u escape at offset $p->{pos}" );
        }
        my $code = hex($hex);
        $p->{pos} += 6;
        if ( $code >= 0xD800 && $code <= 0xDBFF && substr( $p->{text}, $p->{pos}, 2 ) eq '\\u' ) {
            my $low = hex( substr( $p->{text}, $p->{pos} + 2, 4 ) );
            if ( $low >= 0xDC00 && $low <= 0xDFFF ) {
                $code = 0x10000 + ( ( $code - 0xD800 ) << 10 ) + ( $low - 0xDC00 );
                $p->{pos} += 6;
            }
        }
        $out .= chr($code);
    }
}

# Usage     : my $text = plain($text)
# Purpose   : A text without the emoji and spaces the terminal puts before it.
# Returns   : The text.
sub plain
{
    my ($text) = @_;
    $text =~ s/^[^\]\[A-Za-z0-9(#`.]+//;
    return $text;
}

# Usage     : my ($rc, $on) = json_local_path()
# Purpose   : Whether JSON output names the checkout's path: aapp.jsonLocalPath, true unless false.
# Returns   : (RETURN_OK, 1 or 0), or (RETURN_ERROR, undef) after an [ ERROR ] line for any other value.
sub json_local_path
{
    my $v = AAPP::Config::get('aapp.jsonLocalPath');
    if ( !defined $v || $v eq 'true' ) {
        return ( RETURN_OK, 1 );
    }
    if ( $v eq 'false' ) {
        return ( RETURN_OK, 0 );
    }
    AAPP::Logger::print_msg( 'ERROR', "aapp.jsonLocalPath is '$v'; it must be true or false." );
    return ( RETURN_ERROR, undef );
}

# Usage     : my $j = remote_json()
# Purpose   : The remote of the envelope (aapp.remote, default origin), credentials removed from its URL.
# Returns   : The JSON object, or null when the remote does not exist.
sub remote_json
{
    my $name = AAPP::Config::get('aapp.remote') // 'origin';
    my $root = AAPP::Paths::resolve()->{root};
    my @at   = defined $root ? ( '-C', $root ) : ();
    my ( $ok, $url ) = AAPP::Paths::git_capture( @at, 'remote', 'get-url', $name );
    if ( !$ok || $url eq '' ) {
        return 'null';
    }
    chomp($url);
    if ( $url =~ m{^https?://[^/]*\@} ) {
        $url =~ s{^(https?://)[^/@]*\@}{$1};
    } elsif ( $url =~ m{://[^/]*:[^/]*\@} ) {
        $url =~ s{^([a-z+]+://[^/:@]*):[^/@]*\@}{$1\@};
    }
    return json_obj( name => json_str($name), url => json_str($url) );
}

# Usage     : my ($rc, $j) = repository_json()
# Purpose   : The envelope's repository object: remote, branch, and the checkout's path unless aapp.jsonLocalPath is false.
# Returns   : (RETURN_OK, $json), or (RETURN_ERROR, undef) when aapp.jsonLocalPath is invalid.
sub repository_json
{
    my ( $rc, $local ) = json_local_path();
    if ( $rc != RETURN_OK ) {
        return ( RETURN_ERROR, undef );
    }
    my $root   = AAPP::Paths::resolve()->{root};
    my $branch = '';
    if ( defined $root ) {
        my ( $ok, $out ) = AAPP::Paths::git_capture( '-C', $root, 'symbolic-ref', '--short', '-q', 'HEAD' );
        if ($ok) {
            $branch = $out;
            chomp($branch);
        }
    }
    my $root_json = $local ? json_strn($root) : 'null';
    return ( RETURN_OK, json_obj( remote => remote_json(), branch => json_strn($branch), root => $root_json ) );
}

# Usage     : my $stamp = utc_now()
# Purpose   : The current time as the envelope writes it (UTC, ISO 8601, seconds).
# Returns   : The time text.
sub utc_now
{
    return POSIX::strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime() );
}

# Usage     : my ($rc, @pairs) = envelope_pairs('status', $notices_json)
# Purpose   : The envelope's members (version, command, generated_at, repository, notices), as json_obj pairs.
# Returns   : (RETURN_OK, @pairs), or (RETURN_ERROR) when the repository object cannot be built.
sub envelope_pairs
{
    my ( $command, $notices ) = @_;
    my ( $rc, $repo ) = repository_json();
    if ( $rc != RETURN_OK ) {
        return (RETURN_ERROR);
    }
    return (
        RETURN_OK,
        version      => json_str(FORMAT_VERSION),
        command      => json_str($command),
        generated_at => json_str( utc_now() ),
        repository   => $repo,
        notices      => $notices,
    );
}

# Usage     : my $j = notices_json([ 'warning', 'Plans', 'text' ], ...)
# Purpose   : The notices object: { warning: [...], info: [...] }, each item { section, text }, the text plain.
# Returns   : The JSON text.
sub notices_json
{
    my (@items) = @_;
    my @warning;
    my @info;
    foreach my $item (@items) {
        my ( $level, $section, $text ) = @{$item};
        my $obj = json_obj( section => json_str($section), text => json_str( plain($text) ) );
        if ( $level eq 'warning' ) {
            push @warning, $obj;
        } else {
            push @info, $obj;
        }
    }
    return json_obj( warning => json_list(@warning), info => json_list(@info) );
}

# Usage     : my @items = remarks('Plans', $printed)
# Purpose   : Turns what a command printed into notice items: a line marked ⚠ or ❌ (or tagged WARN,
#             ERROR, FATAL) is a warning, any other info; an indented line continues the one before.
# Returns   : List of [level, section, text].
sub remarks
{
    my ( $section, $printed ) = @_;
    my @items;
    foreach my $line ( split( /\n/, $printed ) ) {
        if ( $line =~ /^\s*$/ ) {
            next;
        }
        if ( $line =~ /^\s/ && @items ) {
            my $more = $line =~ s/^\s+//r;
            $items[-1][2] .= " $more";
            next;
        }
        my $text  = $line =~ s/^\s+//r;
        my $level = $text =~ /^(?:⚠|❌|\[ (?:WARN|ERROR|FATAL)\s*\])/ ? 'warning' : 'info';
        push @items, [ $level, $section, $text ];
    }
    return @items;
}

# Usage     : my $doc = error_document('status', $message)
# Purpose   : The error document of a failed JSON run; error.code from the message: usage,
#             confirm-needed, sync-failed, invalid-setting (with aapp_config), or failed.
# Returns   : The pretty-printed document.
sub error_document
{
    my ( $command, $message ) = @_;
    if ( !defined $message || $message eq '' ) {
        $message = 'The command failed.';
    }
    my @parts;
    foreach my $line ( split( /\n/, $message ) ) {
        if ( $line =~ /^\s*$/ ) {
            next;
        }
        push @parts, plain( $line =~ s/^\s+//r );
    }
    my $text = join( ' ', @parts );
    my $code = 'failed';
    my $key;
    if ( $message =~ /[Uu]sage:/ ) {
        $code = 'usage';
    } elsif ( $message =~ /needs a confirmation|issue list confirm/ ) {
        $code = 'confirm-needed';
    } elsif ( $message =~ /does not know these open ones/ ) {
        $code = 'sync-failed';
    } elsif ( $message =~ /(aapp\.[A-Za-z0-9]+) is '/ ) {
        $code = 'invalid-setting';
        $key  = $1;
    }
    my $empty = json_obj( warning => '[]', info => '[]' );
    my ( $rc, @envelope ) = envelope_pairs( $command, $empty );
    if ( $rc != RETURN_OK ) {
        @envelope = (
            version      => json_str(FORMAT_VERSION),
            command      => json_str($command),
            generated_at => json_str( utc_now() ),
            repository   => 'null',
            notices      => $empty,
        );
    }
    my $error = json_obj( code => json_str($code), message => json_str($text), aapp_config => json_strn($key) );
    return pretty( json_obj( @envelope, error => $error ) );
}

1;
