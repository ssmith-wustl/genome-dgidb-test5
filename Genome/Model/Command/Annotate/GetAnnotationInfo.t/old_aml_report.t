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

    my $dev = 'oracle';
    my $file = 'old_oracle.dump';
    #my $dev = 'mysql';
    #my $file = 'old_mysql.dump';

    is((system "genome-model annotate aml-report-old --file $file --dev $dev"), 0, "Executed");

    #TODO check files
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReportOld::Test /);

exit 0;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Annotate/AmlReport.t/old_aml_report.t $
#$Id: old_aml_report.t 33535 2008-04-08 22:22:21Z ebelter $
