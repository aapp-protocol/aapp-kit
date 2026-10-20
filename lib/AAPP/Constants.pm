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
