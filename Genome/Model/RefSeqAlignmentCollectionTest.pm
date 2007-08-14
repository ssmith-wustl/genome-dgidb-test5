#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::RefSeqAlignmentCollectionTest;
use base('Test::Class');

use Test::More;
use Test::Deep;

sub setup : Test(setup){
    my $self = shift;
    
    $alignments = [
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        [0, ],
        ];

    $alignments = map {
        {   
            last_alignment_number   => undef,
            read_number             => $_[0],
            probability             => $record[2],
            length                  => $record[3],
            orientation             => $record[4],
            number_of_alignments    => $record[5],
            ref_and_mismatch_string => $record[6],
            reads_fh                => $self->{bases_fh},    
        }
    } @$alignments;
    
    my $rsac = Genome::Model::RefSeqAlignmentCollection::Mock->new(
                                                                   mock_alignments => $alignments,
                                                                   );
}

sub test_


