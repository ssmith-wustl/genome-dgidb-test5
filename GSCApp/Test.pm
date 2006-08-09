package GSCApp::Test;

use GSCApp;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = (@Test::More::EXPORT, 'flush_errors','flush_warnings');

use Test::More;
use Test::Builder;

my $Test = Test::Builder->new;

sub long_test_check {
    if (! $ENV{GSCAPP_RUN_LONG_TESTS}) {
        $Test->plan(
            skip_all => 'long_test and GSCAPP_RUN_LONG_TESTS not set'
        );
    }
}

sub splice_long_test {
    my @arg = @_;

    for my $i (0 .. $#arg) {
        if ($arg[$i] eq 'long_test') {
            my @long = splice @arg, $i, 2;
            long_test_check() if $long[1];
            last;
        }
    }

    return @arg;
}

sub import {
    my $class = shift;

    my @arg = splice_long_test(@_);

    my $caller = caller;
    __PACKAGE__->export($caller);
    Test::More::plan(@arg);
}

no warnings;
sub plan {
    my @arg = splice_long_test(@_);
    Test::More::plan(@arg);
}
use warnings;

# Gather status and warning messages,
# and check for unprocessed warnings and errors at the end.

our (@unchecked_warning_messages, @unchecked_error_messages);


App::MsgLogger->message_callback('status', sub { return 1; });

App::MsgLogger->message_callback(
    'warning', 
    sub 
    { 
        my $msg = $_[0]->text; 
        chomp $msg; 
        my $txt = App::Name->pkg_name . ": WARNING: " . join(': ', (caller(3))[0, 2]) . ": $msg\n"; 
        print STDERR $txt unless ($ENV{GSCAPP_TEST_QUIET});
        push @unchecked_warning_messages, $txt;
        return 1
    }
);

App::MsgLogger->message_callback(
    'error',   
    sub 
    {
        my $msg = $_[0]->text; 
        chomp $msg; 
        my $txt = App::Name->pkg_name . ": ERROR: " . join(': ', (caller(3))[0, 2]) . ": $msg\n"; 
        print STDERR $txt unless ($ENV{GSCAPP_TEST_QUIET});
        push @unchecked_error_messages, $txt;
        return 0
    }
);

sub flush_warnings {
    my @w = @unchecked_warning_messages;
    @unchecked_warning_messages = ();
    return @w;
}

sub flush_errors {
    my @e = @unchecked_error_messages;
    @unchecked_error_messages = ();
    return @e;
}

=pod

=head1 NAME

GSCApp::Test - Extension to Test::More with extra goodies for GSCApp.

=head1 SYNOPSIS

    use GSCApp::Test;
    plan('no_plan', long_test => 1);

      -or-

    use GSCApp::Test;
    plan(long_test => 1, tests => 5);

=head1 DESCRIPTION

This is a drop in replacement for Test::More.  You should not
need to use Test::More in your test scripts if you use GSCApp::Test.
However, you will have all the functions from Test::More available
to you.

If long_test is specified and the environment variable
GSCAPP_RUN_LONG_TESTS evaluates to false, then a skip_all
will be done.

If the GSCAPP_TEST_QUIET flag is set (as is done by "runtests"),
error and warning messages will not be dumped to STDERR as is the
default.

To test for expected warnings and errors:

use GSCApp::Test qw/flush_warnings flush_errors/;

ok(! $o->this_call_expected_to_fail, "Failed as expected");
ok(flush_errors() == 2, "Found two new error messages");
ok(flush_warnings() == 3, "Found three new warning messages");


=cut


1;

# $Header$

