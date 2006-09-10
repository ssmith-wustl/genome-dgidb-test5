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

# handle timing and logging coverage 

use Cwd;
sub _deconvolve_path {
    # there must be a built-in which does this...?
    # replace me
    my $path = shift;
    my $cwd = Cwd::cwd();
    
    my @parts;
    unless ($path =~ /^\//) {
        @parts = grep { length($_) } split(/\//,$cwd); 
    }
    push @parts, grep { length($_) and $_ ne "." } split(/\//,$path);
   
    my @final_parts; 
    while (@parts) {
        if ($parts[0] eq  "..") {
            shift @parts;
            pop @final_parts;
        }
        else {
            push @final_parts, shift(@parts);
        }
    }
    return join("", map { "/" . $_ } @final_parts); 
}

use Sys::Hostname;
use File::Basename;
use Time::HiRes;
use DBI;

my ($t1,$t2,$e,$orig_argv,$inc);

BEGIN {
    $t1 = Time::HiRes::time();
    $orig_argv = "@ARGV";

    $inc = "";
    for my $path (@INC) {
        if ($ENV{PERL5LIB} =~ /^$path(:|$)/) {
            last;
        }
        $inc .= ":" if length($inc);
        $inc .= _deconvolve_path($path);        
    }
}


END {
    $t2 = Time::HiRes::time();
    $e = $t2-$t1;
    if (my $test_time_db = $ENV{UR_TEST_RECORD_TIME}) { 
        eval {
            my $database_exists_before_execution = (-e $test_time_db);

            my $dbh = DBI->connect("dbi:SQLite:dbname=$test_time_db","","");
            $dbh->{RaiseError} = 1;

            unless ($database_exists_before_execution) {  
                $dbh->do("create table test_execution("
                    . "test_name text,user_name text,host_name text,log_date date,begin_time float,end_time float,elapsed_time float,params text,inc text)"
                );
            }

            $dbh->do("begin transaction");
            $dbh->do(
                "insert into test_execution(test_name,user_name,host_name,log_date,begin_time,end_time,elapsed_time,params,inc) values (?,?,?,?,?,?,?,?,?)",
                undef,
                $0, $ENV{USER}, Sys::Hostname::hostname(), App::Time->now(), $t1, $t2, $e, $orig_argv, $inc
            );
            $dbh->do("commit");
            
            $dbh->disconnect;
        };

        if ($@) {
            print STDERR "Failed to log timing! $@";
        }
    } 


    if (my $test_coverage_db = $ENV{UR_TEST_RECORD_COVERAGE}) { 
        $DB::single = 1;
        eval {
            my $database_exists_before_execution = (-e $test_coverage_db);

            my $dbh = DBI->connect("dbi:SQLite:dbname=$test_coverage_db","","");
            $dbh->{RaiseError} = 1;

            unless ($database_exists_before_execution) {  
                $dbh->do("create table test_module_use("
                    . "test_name text,module_name text)"
                );
            }

            $dbh->do("begin transaction");
            $dbh->do("delete from test_module_use where test_name = ?", undef, $0);
            my $sth = $dbh->prepare("insert into test_module_use(test_name,module_name) values (?,?)");
            for my $module_name (keys %INC) {
                $sth->execute($0,$module_name);
            }
            $dbh->do("commit");
            
            $dbh->disconnect;
        };

        if ($@) {
            print STDERR "Failed to log module usage! $@";
        }
    } 
        
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

