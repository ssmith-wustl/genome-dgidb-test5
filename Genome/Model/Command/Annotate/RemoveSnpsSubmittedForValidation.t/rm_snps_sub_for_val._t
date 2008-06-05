#! /gsc/bin/perl

use strict;
use warnings;

###############

package FilterValidation::Test;

use base 'Test::Class';

use Test::More;
use Tie::File;

sub execute : Tests
{
    my $self = shift;

    my $in = 'prioritize';
    my $out = 'prioritize.out';
    
    is((system "genome-model annotate filter-validation --input-file $in --output-file $out"), 0, "Executed");

    tie(my @out, 'Tie::File', $out);

    my $old = 'old_prioritize.out';
    tie(my @old, 'Tie::File', $old);

    is_deeply(\@out, \@old, 'Compared new and old filtered prioritized files');

    untie @out;
    untie @old;

    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ FilterValidation::Test /);

exit 0;

#$HeadURL$
#$Id$
