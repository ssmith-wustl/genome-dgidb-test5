#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::Alignment;

sub new{
    my ($pkg, %params) = @_;
    
    if( defined( $params{ aln_record_ar } ) ){
        %params = (%params, %{parse_aln_record( $params{ aln_record_ar } )});
        delete $params{ aln_record_ar };
    }
    
    unless( defined( $params{reference_bases} ) && defined( $params{mismatch_string} ) ){
        ( $params{'mismatch_string'}, $params{'reference_bases'} )
            = decode_match_string( $params{ref_and_mismatch_string} );  
    }
    
    my $self = {
        last_alignment_number           => undef,
        read_number                     => undef,
        probability                     => undef,
        length                          => undef,
        orientation                     => undef,
        number_of_alignments            => undef,
        mismatch_string                 => undef,
        reference_bases                 => undef,
        query_base_probability_vectors  => undef,
        
        current_position                => 0,
    };
    
    $self = { %$self, %params };
    
    $self->{mismatch_string_length} = length($self->{mismatch_string});

    return bless $self, $pkg;
}

# Accessor Methods ------------------------------------------------------------

sub last_alignment_number           {return shift->{last_alignment_number}}
sub read_number                     {return shift->{read_number}}                     
sub probability                     {return shift->{probability}}
sub some_length                     {return shift->{length}}
sub orientation                     {return shift->{orientation}}
sub number_of_alignments            {return shift->{number_of_alignments}}
sub mismatch_string                 {return shift->{mismatch_string}}
sub reference_bases                 {return shift->{reference_bases}}
sub query_base_probability_vectors  {return shift->{query_base_probability_vectors}}
sub current_position                {return shift->{current_position}}
sub mismatch_string_length          {return shift->{mismatch_string_length}}

sub get_current_mismatch_code{
    my $self = shift;
    
    if( $self->spent_q ){
        return undef;
    }else{
        return substr($self->{mismatch_string},$self->{current_position},1);
    }
}
    
# Instance Methods ------------------------------------------------------------

sub increment_position{
    my $self = shift;
    
    $self->{current_position}++;
}

sub rewind{
    my $self = shift;
    
    $self->{current_position} = 0;
}

sub spent_q{
    my $self = shift;
    
    if($self->{current_position} >= $self->{mismatch_string_length}){
        return 1;
    }else{
        return;
    }
}


# Helper Methods --------------------------------------------------------------

sub parse_aln_record{
    my $aln_record = shift;
    
    my ($last_alignment_num, $read_num, $prob, $len, $orient, $number_alignments, $ref_and_mismatch_string) = @$aln_record;
    
    return {
        last_alignment_number           => $last_alignment_num,
        read_number                     => $read_num,
        probability                     => $prob,
        length                          => $len,
        orientation                     => $orient,
        number_of_alignments            => $number_alignments,
        ref_and_mismatch_string         => $ref_and_mismatch_string,
    };
}

# 00 match
# 10 mismatch
# 20 subject-insert
# 30 query-insert

# reference bases
# N  0
# A 1
# C 2
# G 3
# T 4
# missing 5

my $REF_BASE = {
                0 => 'N',
                1 => 'A',
                2 => 'C',
                3 => 'G',
                4 => 'T',
                5 => '-'
               };

sub decode_match_string{
    my $array_of_encoded_values = shift;
    
    my $mismatch_string = '';
    my $reference_bases = '';
    
    foreach my $encoded_value (@$array_of_encoded_values){
        my $ref_base = $REF_BASE->{$encoded_value % 10};
        
        next if $ref_base eq '-';
        
        $mismatch_string .= int ($encoded_value / 10);
	$reference_bases .= $ref_base;
    }

    return ($mismatch_string, $reference_bases);
}

1;
