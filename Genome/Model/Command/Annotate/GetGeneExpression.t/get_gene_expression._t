#! /gsc/bin/perl

use strict;
use warnings;

###############

package GetGeneExpression::Test;

use base 'Test::Class';

use Test::More;
use Tie::File;

sub execute : Tests
{
    my $self = shift;

    my $in = 'new_oracle.dump.out';
    my $out = 'new_oracle.dump.out.gge';
    unlink $out if -e $out;
    my $db_name = 'mg_prod';
    
    is((system "genome-model annotate get-gene-expression --db-name $db_name --in $in --out $out"), 0, "Executed");

    my $sort_file = 'new_oracle.dump.out.gge.sort';
    unlink $sort_file if -e $sort_file;
    system "sort $out > $sort_file";
    tie(my @sort, 'Tie::File', $sort_file);
    is(scalar(@sort), 40, "Sorted output file ($out) has 40 lines")
        or die;
    
    my $comp_file = 'old_mysql.dump.out.gge.sort';
    tie(my @comp, 'Tie::File', $comp_file);
    is(scalar(@comp), 40, "Comparison file ($comp_file) has 40 lines")
        or die;

    is_deeply(\@sort, \@comp, 'Compared new and old output');

    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ GetGeneExpression::Test /);

exit 0;

#$HeadURL$
#$Id$
