#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use Genome::Command::CalculateCoverage;

package Genome::Command::CalculateCoverageTest;
use base 'Test::Class';

use Fcntl;
use Genome::Model::RefSeqAlignmentCollection qw(MAX_READ_LENGTH);
use Test::Deep;

sub setup : Test(setup){
    my $self = shift;
    
    my $temp_output_prefixes = [
        '/tmp/testme_chr_ryan_1',
        '/tmp/testme_chr_ryan_SORTED',
        '/tmp/testme_chr_ryan_SORTED_DOUBLE',
        ];
    
    my $unsorted = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $temp_output_prefixes->[0], 
                                                               mode => O_RDWR | O_CREAT | O_TRUNC,
                                                               reference_sequence_length => 40
                                                               );
    
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

        $unsorted->add_alignments_for_position($fake->[0], [$alignment_record]);
    }
    
    my $sorted = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $temp_output_prefixes->[1],
                                                             mode => O_RDWR | O_CREAT | O_TRUNC,
                                                             reference_sequence_length => 40,
                                                             );
    
    $sorted->merge($unsorted);
    
    my $sorted_double = Genome::Model::RefSeqAlignmentCollection->new(
                                                             file_prefix => $temp_output_prefixes->[2],
                                                             mode => O_RDWR | O_CREAT | O_TRUNC,
                                                             reference_sequence_length => 40,
                                                             );
    
    $sorted_double->merge($sorted, $sorted);
    
    $self->{cov_calc_unsorted} = Genome::Command::CalculateCoverage->new( ref_seq_alignment_collection => $unsorted );
    $self->{cov_calc_sorted} = Genome::Command::CalculateCoverage->new( ref_seq_alignment_collection => $sorted );
    $self->{cov_calc_sorted_double} = Genome::Command::CalculateCoverage->new( ref_seq_alignment_collection => $sorted_double );

    $self->{fake_coords} = $fake_coords;

}

sub test_get_coverage_by_position : Test(3){
    my $self = shift;
    
    my $coverage_array_unsorted = $self->{cov_calc_unsorted}->get_coverage_by_position();
    my $coverage_array_sorted = $self->{cov_calc_sorted}->get_coverage_by_position();
    my $coverage_array_sorted_double = $self->{cov_calc_sorted_double}->get_coverage_by_position();
    
    
    
    my $expected_array_single = [];
    foreach my $position ( 0 .. $self->{cov_calc_unsorted}->ref_seq_alignment_collection->reference_sequence_length ){
        $expected_array_single->[$position] = 0;
    }
    
    foreach my $coord ( @{ $self->{ fake_coords } } ){
        foreach my $pos ($coord->[0] .. $coord->[1]){
            $expected_array_single->[$pos]++;
        }
    }
    $DB::single=1;
    my $expected_array_double = [ map { $_ * 2 } @$expected_array_single ];
    
    # get rid of that blank initial element since refseq coords are 1 based
    shift @$expected_array_single;
    shift @$expected_array_double;
    
    cmp_deeply( $coverage_array_unsorted, $expected_array_single, "Coverage array is caluclated correctly from UNSORTED binary alignment file" );
    cmp_deeply( $coverage_array_sorted, $expected_array_single, "Coverage array is caluclated correctly from SORTED binary alignment file" );
    cmp_deeply( $coverage_array_sorted_double, $expected_array_double, "Coverage array is caluclated correctly from DOUBLED AND SORTED binary alignment file" );
}

if( $0 eq __FILE__ ){
   Genome::Command::CalculateCoverageTest->new->runtests();
}

1;
