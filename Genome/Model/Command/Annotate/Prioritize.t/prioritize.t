#! /gsc/bin/perl

use strict;
use warnings;

###############

package Priority::Test;

use base 'Test::Class';

use Test::More;
use Tie::File;

sub execute : Tests
{
    my $self = shift;

    my $input = 'report.out';
    my $out1 = $input . '.1';
    my $out2 = $input . '.2';
    
    is((system "genome-model annotate prioritze --input $input --priorty1_output $out1 --priorty2_output $out2"), 0, "Executed");

    tie(my @out1, 'Tie::File', $out1);

    my $p1 = 'old_prioritize.1';
    tie(my @p1, 'Tie::File', $p1);

    is_deeply(\@out1, \@p1, 'Compared new and old prioritize 1');

    untie @out1;
    untie @p1;

    tie(my @out2, 'Tie::File', $out2);

    my $p2 = 'old_prioritize.2';
    tie(my @p2, 'Tie::File', $p2);

    is_deeply(\@out2, \@p2, 'Compared new and old prioritize 2');

    untie @out2;
    untie @p2;

    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ Priority::Test /);

exit 0;

#$HeadURL$
#$Id$
