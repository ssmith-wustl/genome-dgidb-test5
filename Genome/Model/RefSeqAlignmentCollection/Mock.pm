#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::RefSeqAlignmentCollection::Mock;
use base('Genome::Model::RefSeqAlignmentCollection');

sub new {
    my ($pkg, %params) = @_;
    
    # please pass in a list of lists of alignments indexed by position
    # called "mock_alignments", each should be formatted:
    # {
    # last_alignment_number => $record[0],
    # read_number => $record[1],
    # probability => $record[2],
    # length => $record[3],
    # orientation => $record[4],
    # number_of_alignments => $record[5],
    # ref_and_mismatch_string => $record[6],
    # reads_fh     => $self->{bases_fh},
    # };
    
    $params{is_sorted} = 1;
    
    my $self = {%params};
    
    $self = { %$self, %params };
    
    return bless $self, $pkg;
}

sub get_alignments_for_sorted_position{
    my $self = shift;
    
    my $pos = shift;
    
    return $self->{mock_alignments}->[$pos];
}

1;

