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

    my $file = 'AmlReportChunker.t/amll123t100_q1r07t096';
    my $dump_file = 'AmlReportChunker.t/amll123t100_q1r07t096.dump';
    unlink $dump_file if -e $dump_file;

    is((system "genome-model annotate aml-report-chunker --dev mysql --list1 'maq wugsc solexa hg amll123t98_q1r07t096' --output $file --create-input"), 0, "Executed");

    return 1;
    
    
    my $chunker = Genome::Model::Command::Annotate::AmlReportChunker->new
    (
        dev => 'oracle',
        list1 => 'maq wugsc solexa hg amll123t100_q1r07t096',
        create_input => 1,
        output => $file,
    );

    ok($chunker, 'Ccreated chunker');
    ok($chunker->execute, 'Executed chunker');

    #TODO check files
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReportChunker::Test /);

exit 0;

#$HeadURL$
#$Id$
