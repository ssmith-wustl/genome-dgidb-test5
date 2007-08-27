#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::RefSeqAlignmentCollectionTest;
use base('Test::Class');

use Test::More;
use Test::Deep;

use Genome::Model::RefSeqAlignmentCollection::Mock;
use Genome::Model::Alignment::Mock;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant QUERY_INSERT       => 3;
use constant REFERENCE_INSERT   => 2;

# ACGTACGTACGT
#
# ACGT-CGT-CGT
# ACGT--GTA--T
# AC---CG-A-GT
sub setup : Test(setup){
    my $self = shift;
    
    my $alignments = [
        [
         10,
         join('', (MATCH,MATCH,MATCH,MATCH,QUERY_INSERT,MATCH,MATCH,MATCH,QUERY_INSERT,MATCH,MATCH,MATCH)),
         'ACGTACGTACGT',
         [
          [.7,.1,.1,.1],
          [.1,.7,.1,.1],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          [.1,.7,.1,.1],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          [.1,.7,.1,.1],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          ]
         ],
        [
         8,
         join('', (MATCH,MATCH,MATCH,MATCH,QUERY_INSERT,QUERY_INSERT,MATCH,MATCH,MATCH,QUERY_INSERT,QUERY_INSERT,MATCH)),
         'ACGTACGTACGT',
         [
          [.7,.1,.1,.1],
          [.1,.7,.1,.1],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          [.7,.1,.1,.1],
          [.1,.1,.1,.7],
          ]
         ],
        [
         7,
         join('', (MATCH,MATCH,QUERY_INSERT,QUERY_INSERT,QUERY_INSERT,MATCH,MATCH,QUERY_INSERT,MATCH,QUERY_INSERT,MATCH,MATCH)),
         'ACGTACGTACGT',
         [
          [.7,.1,.1,.1],
          [.1,.7,.1,.1],
          [.1,.7,.1,.1],
          [.1,.1,.7,.1],
          [.7,.1,.1,.1],
          [.1,.1,.7,.1],
          [.1,.1,.1,.7],
          ]
         ],
        ];

    $alignments = [ map {
        Genome::Model::Alignment::Mock->new(   
            probability                     => 1,
            length                          => $_->[0],
            orientation                     => 1,
            number_of_alignments            => 1,
            mismatch_string                 => $_->[1],
            reference_bases                 => $_->[2],
            read_bases_probability_vectors  => $_->[3],
        )
    } @$alignments ];
    
    my $rsac = Genome::Model::RefSeqAlignmentCollection::Mock->new(
                                                                   mock_alignments => $alignments,
                                                                   );
    $self->{rsac} = $rsac;
}

sub test_foreach_aligned_position : Test(2){
    my $self = shift;
    
    my $rsac = $self->{rsac};
    
    my $expected_bases = [];
    my $passed_in_aligned_bases = [];
    my $work_sub = sub {
        my $alignments = shift;
        push @$passed_in_aligned_bases, $alignments;
        return scalar(@$passed_in_aligned_bases);
    };
    
    my $expected_result_calls = [1..15];
    my $result_calls = [];
    my $result_sub = sub{
        push @$result_calls, shift;
    };
    
     $rsac->foreach_aligned_position( $work_sub, $result_sub, 1, 1 );
    
    cmp_deeply($result_calls, $expected_result_calls, 'Results are transferred from one coderef to the other');
    cmp_deeply($passed_in_aligned_bases, $expected_bases, 'Windowing correctly iterates over pseudo-multi aligned sequences');
}

if ($0 eq __FILE__){
    Genome::Model::RefSeqAlignmentCollectionTest->new->runtests();
}