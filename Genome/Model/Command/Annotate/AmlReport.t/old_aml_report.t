#! /gsc/bin/perl

use strict;
use warnings;

###############

package AmlReportOld::Test;

use base 'Test::Class';

use Test::More;

sub execute : Tests
{
    my $self = shift;

    #my $dev = 'oracle';
    #my $file = 'old_oracle.dump';
    my $dev = 'mysql';
    my $file = 'old_mysql.dump';

    is((system "genome-model annotate aml-report-old --file $file --dev $dev"), 0, "Executed");

    #TODO check files
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReportOld::Test /);

exit 0;

#$HeadURL$
#$Id$
