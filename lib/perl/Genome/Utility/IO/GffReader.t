#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 3;

use_ok('Genome::Utility::IO::GffReader');
my $gff_file = '/gsc/var/cache/testsuite/data/Genome-Utility-IO-GffReader/alignment_summary.gff';
my $reader = Genome::Utility::IO::GffReader->create(
   input => $gff_file,
);
isa_ok($reader,'Genome::Utility::IO::GffReader');
my $data = $reader->next;
my @headers = keys %{$data};
my $expected_headers = Genome::Utility::IO::GffReader->headers;
ok( (scalar(@headers) == scalar(@{$expected_headers}) ), 'Found expected header count.' );

exit;
