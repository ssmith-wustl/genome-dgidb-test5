#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Command::CalculateCoverage;

my $cov_calculator = Genome::Command::CalculateCoverage->new(
                                                             binary_aln_filename => $ARGV[0],
                                                             reference_sequence_length => 247249719,
                                                             is_sorted => 1
                                                             ); #chr 1

print ">$ARGV[0]\n";

$cov_calculator->print_coverage_by_position('STDOUT');

