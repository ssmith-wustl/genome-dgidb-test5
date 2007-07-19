#!/usr/bin/env perl

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';

use IO::File;

use Genome::Model::RefSeqAlignmentCollection qw(MAX_READ_LENGTH INDEX_RECORD_SIZE);

use Test::More tests => 22;
use Test::Deep;

BEGIN {
    use_ok('Genome::Model::Command::CalculateCoverage');
}

my @temp_output_prefixes = qw( /tmp/testme_chr_ryan_1 /tmp/testme_chr_ryan_SORTED /tmp/testme_chr_ryan_SORTED_DOUBLE );

my $unsorted = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $temp_output_prefixes[0],
                                                             mode => O_RDWR | O_CREAT | O_TRUNC,
                                                             reference_sequence_length => 40
                                                           );

ok($unsorted,"Created RefSeqAlignmentCollection object to hold the unsorted data");

my $fake_coords = [ # start, stop, last_alignment_number, number of alignments
                    [1, 32, 0, 1],
                    [2, 33, 0, 2],
                    [4, 35, 0, 2],
                    [1, 32, 1, 1],
                    [2, 33, 2, 2], # * index 4
                    [4, 35, 3, 2], # * index 5
                    [1, 32, 4, 1], # * index 6
                   ];

my $read_num = 0;
foreach my $fake ( @$fake_coords ) {
    my $alignment_record = { # last_alignment_number   => $fake->[2],  # The module should fill this in
                             read_number             => $read_num++,
                             probability             => 1,
                             length                  => 32,
                             orientation             => 1,
                             number_of_alignments    => $fake->[0],
                             ref_and_mismatch_string => [(01) x 32, (05) x (MAX_READ_LENGTH - 32)],
                           };

    ok($unsorted->add_alignments_for_position($fake->[0], [$alignment_record]), 'Added alignment record to unsorted object');
}

my $sorted = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $temp_output_prefixes[1],
                                                           mode => O_RDWR | O_CREAT | O_TRUNC,
                                                         );
ok($sorted, "Created RefSeqAlignmentCollection object to hold the sorted data");

ok($sorted->merge($unsorted), "Merged the unsorted data into the sorted object");

my $sorted_double = Genome::Model::RefSeqAlignmentCollection->new( 
                                                             file_prefix => $temp_output_prefixes[2],
                                                             mode => O_RDWR | O_CREAT | O_TRUNC,
                                                             );
ok($sorted_double, "Created RefSeqAlignmentCollection object to hold the doubled sorted data");

ok($sorted_double->merge($sorted, $sorted), "Merged the sorted data twice into the doubled sorted object");

my $REFERENCE_SEQUENCE_LENGTH = 40;

my $expected_array_single = [];
foreach my $position ( 0 .. $REFERENCE_SEQUENCE_LENGTH ) {
    $expected_array_single->[$position] = 0;
}

foreach my $coord ( @{ $fake_coords } ){
    foreach my $pos ($coord->[0] .. $coord->[1]){
        $expected_array_single->[$pos]++;
    }
}
my $expected_array_double = [ map { $_ * 2 } @$expected_array_single ];
# get rid of that blank initial element since refseq coords are 1 based
shift @$expected_array_single;
shift @$expected_array_double;


my $unsorted_results = [];
my $unsorted_coverage_command = Genome::Model::Command::CalculateCoverage->create( 
                                          aln => $unsorted,
                                          start => 1,
                                          length => $REFERENCE_SEQUENCE_LENGTH,
                                          result => $unsorted_results,
                                    );
ok($unsorted_coverage_command, "Create a calculate coverage command object for the unsorted data");
ok($unsorted_coverage_command->execute(), "Executed successfully");

cmp_deeply( $unsorted_results, $expected_array_single,
            "Coverage array is caluclated correctly from UNSORTED binary alignment file" );


my $sorted_results = [];
my $sorted_coverage_command = Genome::Model::Command::CalculateCoverage->create(
                                          aln => $sorted,
                                          start => 1,
                                          length => $REFERENCE_SEQUENCE_LENGTH,
                                          result => $sorted_results,
                                    );
ok($sorted_coverage_command, "Create a calculate coverage command object for the sorted data");
ok($sorted_coverage_command->execute(), "Executed successfully");


cmp_deeply( $unsorted_results, $expected_array_single,
            "Coverage array is caluclated correctly from SORTED binary alignment file");


my $double_results = [];
my $double_coverage_command = Genome::Model::Command::CalculateCoverage->create(
                                          aln => $sorted_double,
                                          start => 1,
                                          length => $REFERENCE_SEQUENCE_LENGTH,
                                          result => $double_results,
                                    );
ok($sorted_coverage_command, "Create a calculate coverage command object for the double sorted data");
ok($sorted_coverage_command->execute(), "Executed successfully");


cmp_deeply( $unsorted_results, $expected_array_single, "Coverage array is caluclated correctly from DOUBLED and SORTED binary alignment file");


