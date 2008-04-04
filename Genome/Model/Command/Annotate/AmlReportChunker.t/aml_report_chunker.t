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

    my $db_name = 'mg_dev';
    my $run_id = "'maq wugsc solexa hg amll123t98_q1r07t096'";
    my $file = 'new.dump';
    unlink $file if -e $file;

    is((system "genome-model annotate aml-report-chunker --db-name $db_name --run-id $run_id --file $file"), 0, "Executed");

    # TODO check files
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReportChunker::Test /);

exit 0;

#$HeadURL$
#$Id$
