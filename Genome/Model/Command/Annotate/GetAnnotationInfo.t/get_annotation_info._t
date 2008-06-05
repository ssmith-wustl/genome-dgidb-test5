#! /gsc/bin/perl

use strict;
use warnings;

###############

package AmlReport::Test;

use base 'Test::Class';

#use Genome::Model::Command::Annotate::AmlReportChunker;
use Test::More;

sub execute : Tests
{
    my $self = shift;

    #my $input = 'ora1000.dump';
    my $input = 'new_oracle.dump';
    my $db_name = 'mg_prod';
    
    is((system "genome-model annotate get-annotation-info --db-name $db_name --input $input"), 0, "Executed");

    #TODO check files
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AmlReport::Test /);

exit 0;

#$HeadURL$
#$Id$
