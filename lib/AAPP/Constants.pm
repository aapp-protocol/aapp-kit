package AAPP::Constants;

use strict;
use warnings;
use utf8;
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

use constant {
    DEFAULT_OUTPUT_WIDTH     => 85,
    MIN_OUTPUT_WIDTH         => 40,
    DEFAULT_PICKUP_TITLE_MAX => 72,
    MIN_PICKUP_TITLE_MAX     => 10,
    DEFAULT_SUBJECT_MAX_LEN  => 72,
    MIN_SUBJECT_MAX_LEN      => 1,

    DEFAULT_LOCK_WAIT        => 15,
    LOCK_STALE_SECONDS       => 5,
    LOCK_FIRST_STEP          => 2,
    PLANS_COMMIT_ATTEMPTS    => 5,
    PLANS_COMMIT_RETRY_DELAY => 0.5,

    DEFAULT_REMOTE           => 'origin',
    DEFAULT_DEV_BRANCHES     => 'develop dev development',
    DEFAULT_COMMIT_MODE      => 'atomic',
    DEFAULT_CHANGELOG_MODE   => 'plan',
    DEFAULT_INTEGRATE_TARGET => 'parent',

    KIT_DIR_NAME             => 'aapp-kit',
    DATA_HOME_DEFAULT        => '.local/share',
    STATE_HOME_DEFAULT       => '.local/state',

    JSON_FORMAT_VERSION      => '1.0',
    DEFAULT_VERB             => 'help',

    TEST_WATCHDOG_SECONDS    => 60,
    TEST_STOP_GRACE_SECONDS  => 2,
    TEST_JOBS_STEP           => 4,
    TEST_SANDBOX_PREFIX      => 'aapp-test',
    TEST_GIT_NAME            => 'AAPP Test Runner',
    TEST_GIT_EMAIL           => 'test-runner@aapp.internal',
    TEST_DEFAULT_BRANCH      => 'main',
    TEST_RECAP_LINES         => 20,
};

our %EXIT_FOR = (
    RETURN_OK()        => 0,
    RETURN_FAIL()      => 1,
    RETURN_ERROR()     => 1,
    RETURN_DENY()      => 2,
    RETURN_NOT_FOUND() => 3,
);

our @DEFAULTS = qw(DEFAULT_OUTPUT_WIDTH MIN_OUTPUT_WIDTH DEFAULT_PICKUP_TITLE_MAX MIN_PICKUP_TITLE_MAX
    DEFAULT_SUBJECT_MAX_LEN MIN_SUBJECT_MAX_LEN DEFAULT_LOCK_WAIT LOCK_STALE_SECONDS LOCK_FIRST_STEP
    PLANS_COMMIT_ATTEMPTS PLANS_COMMIT_RETRY_DELAY DEFAULT_REMOTE DEFAULT_DEV_BRANCHES DEFAULT_COMMIT_MODE
    DEFAULT_CHANGELOG_MODE DEFAULT_INTEGRATE_TARGET KIT_DIR_NAME DATA_HOME_DEFAULT STATE_HOME_DEFAULT
    JSON_FORMAT_VERSION DEFAULT_VERB TEST_WATCHDOG_SECONDS TEST_STOP_GRACE_SECONDS TEST_JOBS_STEP
    TEST_SANDBOX_PREFIX TEST_GIT_NAME TEST_GIT_EMAIL TEST_DEFAULT_BRANCH TEST_RECAP_LINES);

our @EXPORT_OK = ( qw(NAME DEBUG_LEVEL LOG_KEY CONFIG_PREFIX
        RETURN_OK RETURN_FAIL RETURN_ERROR RETURN_DENY RETURN_NOT_FOUND %EXIT_FOR), @DEFAULTS );

our %EXPORT_TAGS = ( defaults => \@DEFAULTS );

1;
