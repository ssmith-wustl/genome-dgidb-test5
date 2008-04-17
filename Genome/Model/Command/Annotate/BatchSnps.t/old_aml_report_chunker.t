#! /gsc/bin/perl

use strict;
use warnings;

###############

package AmlReportChunker::Test;

use base 'Test::Class';

#use Genome::Model::Command::Annotate::AmlReportChunker;
use Test::More;

sub execute : Tests
{
    my $self = shift;

    my $dev = 'mg_prod';
    my $list1 = "'maq wugsc solexa hg amll123t100_q1r07t096'";
    my $file = 'old';

    is((system "genome-model annotate aml-report-chunker-old --dev $dev --list1 $list1 --output $file"), 0, "Executed");

    # TODO check files? currently more data is being added, so this query should return moer and more data

    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReportChunker::Test /);

exit 0;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Annotate/AmlReportChunker.t/old_aml_report_chunker.t $
#$Id: old_aml_report_chunker.t 33536 2008-04-08 22:24:46Z ebelter $
