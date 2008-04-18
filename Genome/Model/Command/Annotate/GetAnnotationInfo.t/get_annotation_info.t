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

    my $file = 'ora1000.dump';
    #my $file = 'new_oracle.dump';
    my $db_name = 'mg_prod';
    
    is((system "genome-model annotate aml-report --db-name $db_name --file $file"), 0, "Executed");

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
