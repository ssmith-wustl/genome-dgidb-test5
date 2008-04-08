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

    my $db_name = 'mg_prod';
    my $pp_id = "'maq wugsc solexa hg amll123t100_q1r07t096'";
    my $file_base = 'new_oracle/out';
    my $batch_size = 300000;

    is((system "genome-model annotate aml-report-chunker --db-name $db_name --process-profile-id $pp_id --file-base $file_base --batch-size $batch_size"), 0, "Executed");

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
