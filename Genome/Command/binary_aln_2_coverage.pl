#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Command::CalculateCoverage;

my $cov_calculator = Genome::Command::CalculateCoverage->new( binary_aln_filename => $ARGV[0] );

print ">$ARGV[0]\n";

$cov_calculator->print_coverage_by_position('STDOUT');

