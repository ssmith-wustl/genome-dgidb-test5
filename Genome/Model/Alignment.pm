#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::Alignment;

sub new{
    my $pkg = shift;

    my $self;

    if (ref($_[0]) eq 'HASH') {  # The first arg was a pre-made hashref.  For speed, just bless it in place
        $self = $_[0];

    } else {
        $self = { last_alignment_number           => undef,
                  read_number                     => undef,
                  probability                     => undef,
                  length                          => undef,
                  orientation                     => undef,
                  number_of_alignments            => undef,
                  mismatch_string                 => undef,
                  reference_bases                 => undef,
                  query_base_probability_vectors  => undef,
                  @_,
               };
    }

    if( defined( $self->{'aln_record_ar'} ) ){
        $self = {%$self, %{parse_aln_record( $self->{'aln_record_ar'})} };
        delete $self->{ aln_record_ar };
    }
    
    unless( defined( $self->{'reference_bases'} ) && defined( $self->{'mismatch_string'} ) ) {
        ( $self->{'mismatch_string'}, $self->{'reference_bases'} )
            = decode_match_string( $self->{'ref_and_mismatch_string'} );  
    }
    
    $self->{'current_position'} = 0;
    $self->{mismatch_string_length} = length($self->{mismatch_string});

    return bless $self, $pkg;
}

# read-only Accessor Methods ------------------------------------------------------------
foreach my $key ( qw ( last_alignment_number read_number probability orientation number_of_alignments
                       mismatch_string reference_bases query_base_probability_vectors current_position
                       mismatch_string_length ) ) {
    my $sub = sub ($) { return $_[0]->{$key} };
    no strict 'refs';
    *{$key} = $sub;
}
# Why isn't this called just length?
sub some_length                     {return $_[0]->{length}}


sub get_current_mismatch_code{
    my $self = shift;
    
#    if( $self->spent_q ){
#        return undef;
#    }else{
        return substr($self->{mismatch_string},$self->{current_position},1);
#    }
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
my $REF_BASE = ['N', 'A', 'C', 'G', 'T', '-'];

my @DECODE_MATCH_STRING;
foreach my $match_code ( 0, 10, 20, 30 ) {
    foreach my $ref_base ( 0 .. 5 ) {
        @DECODE_MATCH_STRING[$match_code + $ref_base] = [int($match_code/10), $REF_BASE->[$ref_base]];
    }
}

sub decode_match_string{
    my $array_of_encoded_values = shift;
    
    my $string_lengths = scalar @$array_of_encoded_values;
    my $mismatch_string = 'x' x $string_lengths;
    my $reference_bases = 'x' x $string_lengths;
    
    for (my $i = 0; $i < $string_lengths; $i++) {
        my $encoded_value = $array_of_encoded_values->[$i];
        #my $ref_base = $REF_BASE->[$encoded_value % 10];
        my $decode_values = $DECODE_MATCH_STRING[$encoded_value];
        my $ref_base = $decode_values->[1];
        
        next if $ref_base eq '-';
         
        #$mismatch_string .= int ($encoded_value / 10);
        substr($mismatch_string, $i, 1 $decode_values->[0]);

        substr($reference_bases, $i, 1, $ref_base);

    }

    return ($mismatch_string, $reference_bases);
}

1;
