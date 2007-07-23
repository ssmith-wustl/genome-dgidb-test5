#!/usr/bin/env perl

package Genome::Model::Alignment;

use IO::File;

use strict;
use warnings;

_initialize_decode_table(1);  # Calls the C function at the bottom

sub new{
    my $pkg = shift;


    my $self;

    if (ref($_[0]) eq 'HASH') {  # The first arg was a pre-made hashref.  For speed, just bless it in place
        $self = $_[0];

    } else {
        $self = {
                    last_alignment_number           => undef,
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
    
    if (defined $self->{'reads_file'}) {
        $self->{'reads_fh'} = IO::File->new($self->{'reads_file'});
        unless ($self->{'reads_fh'}) {
            return undef;
        }
        delete $self->{'reads_file'};
    } 
        
    $self->{'current_position'} = 0;
    $self->{mismatch_string_length} = length($self->{mismatch_string});

    return bless $self, $pkg;
}

# read-only Accessor Methods ------------------------------------------------------------
foreach my $key ( qw ( last_alignment_number read_number probability orientation number_of_alignments
                       mismatch_string reference_bases current_position mismatch_string_length ) ) {
    my $sub = sub ($) { return $_[0]->{$key} };
    no strict 'refs';
    *{$key} = $sub;
}

sub read_length                     {return $_[0]->{length}}


sub get_current_mismatch_code{
    my $self = shift;
    
    return substr($self->{mismatch_string},$self->{current_position},1);
}
    
# Instance Methods ------------------------------------------------------------


use constant READ_LENGTH => 33;
use constant READ_RECORD_LENGTH => READ_LENGTH * 4;  # 4 base scores for each position
# Get all the probability values for all the bases in the read
sub get_read_probability_vectors {
    my($self) = @_;

    die 'this needs to include a field for gaps "-"\n';

    unless ($self->{'read_bases_probability_vectors'}) {
    
        my $read_number = $self->read_number % 1_000_000_000;
        $self->{'reads_fh'}->seek($read_number * READ_RECORD_LENGTH, SEEK_SET);
        my $buf;
        $self->{'reads_fh'}->read($buf, READ_RECORD_LENGTH);
    
        my @all_probs;
        $#all_probs = READ_LENGTH - 1;
        for (my $i = 0; $i < READ_LENGTH; $i++) {
            $all_probs[$i] = [ unpack('cccc', substr($buf, $i, 4)) ];
        }
        
        $self->{'read_bases_probability_vectors'} = \@all_probs;
    }
    
    return $self->{'read_bases_probability_vectors'};
}

# Get the probability values for one base in the read
sub get_read_position_probability_vector {
    my($self,$pos) = @_;

    die 'this needs to include a field for gaps "-"\n';

    return [] unless $self->{'reads_fh'};

    my $read_number = $self->read_number % 1_000_000_000;
    $self->{'reads_fh'}->seek(($read_number * READ_RECORD_LENGTH) + $pos, SEEK_SET);
    my $buf;
    $self->{'reads_fh'}->read($buf, 4);  
    my @probs = unpack('cccc', $buf);

    # convert solexa style log-odds scores back into probs,
    # note that because of the rounding in log odds space to integers, these will not sum exactly to 1
    @probs = map { 1 - ( ( 1 ) / ( 1 + 10 ** ( $_ / 10 ) ) ) } @probs;

    return \@probs;
}
    
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
# N 0
# A 1
# C 2
# G 3
# T 4
# missing 5
my $REF_BASE = ['N', 'A', 'C', 'G', 'T', '-'];

my @DECODE_MATCH_STRING;
foreach my $match_code ( 0, 10, 20, 30 ) {
    foreach my $ref_base ( 0 .. 5 ) {
        $DECODE_MATCH_STRING[$match_code + $ref_base] = [int($match_code/10), $REF_BASE->[$ref_base]];
    }
}

sub decode_match_string_perl {
    my $array_of_encoded_values = shift;
    
    my $string_lengths = scalar @$array_of_encoded_values;
    my $mismatch_string = 'x' x $string_lengths;
    my $reference_bases = 'x' x $string_lengths;
    
    my $ev_idx = 0;
    my $str_idx = 0;
    for ( ; $ev_idx < $string_lengths; $ev_idx++) {

        my $encoded_value = $array_of_encoded_values->[$ev_idx];
        #my $ref_base = $REF_BASE->[$encoded_value % 10];
        my $decode_values = $DECODE_MATCH_STRING[$encoded_value];
        unless ($decode_values) {
            $DB::single=1;
            1;
        }
        my $ref_base = $decode_values->[1];
        
        next if $ref_base eq '-';
         
        #$mismatch_string .= int ($encoded_value / 10);
        substr($mismatch_string, $str_idx, 1, $decode_values->[0]);

        substr($reference_bases, $str_idx, 1, $ref_base);

        $str_idx++;

    }

    my $missing = $str_idx - $ev_idx;
    if($missing) {
        $DB::single=1;
    
        substr($mismatch_string, $missing) = '';
        substr($reference_bases, $missing) = '';
    }

    return ($mismatch_string, $reference_bases);
}

sub decode_match_string {
    _decode_match_string(length($_[0]), $_[0]);
}

use Inline C => <<'END_C';

struct decoder_table_entry {
    char match_code;
    char reference_base;
} decodetable[36];

void _initialize_decode_table(int arg1) {
    int match,base;
    char bases[6] = { 'N', 'A', 'C', 'G', 'T', '-' };

    for (match = 0; match < 4; match++) {
        for (base = 0; base < 6; base++) {
            decodetable[match * 10 + base].match_code = match + '0';
            decodetable[match * 10 + base].reference_base = bases[base];
        }
    }

}

void _show_decode_table(int arg1) {
    int i;
    printf("Decode table values:\n");
    for (i = 0; i < 36; i++) {
        printf("At position %d, match_code %c %d reference_base %c %d\n",
               i,
               decodetable[i].match_code, decodetable[i].match_code,
               decodetable[i].reference_base, decodetable[i].reference_base);
    }
}

void _decode_match_string(int count, char *encoded_values) {
    /* These string lengths need to match MAX_READ_LENGTH
     * in Genome::Model::RefSeqAlignmentCollection */
    char mismatch_string[60];
    char reference_bases[60];
    unsigned int str_idx = 0;   // Index into the above 2 strings where we will put the next char
    unsigned int ev_idx;        // Index into the encoded_values string
    char ref_base;

//printf("starting decode, count is %d\n", count);
    for (ev_idx = 0; ev_idx < count; ev_idx++) {
//printf("at ev_idx %d encoded_value %d str_idx %d\n", ev_idx, encoded_values[ev_idx],str_idx);
        ref_base = decodetable[ encoded_values[ev_idx] ].reference_base;

//printf("ref base is %c %d\n", ref_base, ref_base);
        if (ref_base != '-') {
//printf("adding to strings at position %d base %c %d mismatch %c %d\n",
//       str_idx,
//       ref_base, ref_base,
//       decodetable[ encoded_values[ev_idx] ].match_code, decodetable[ encoded_values[ev_idx] ].match_code);

            reference_bases[str_idx] = ref_base;
            mismatch_string[str_idx] = decodetable[ encoded_values[ev_idx] ].match_code;
            str_idx++;
        }
    }

    // null-terminate the strings
    mismatch_string[str_idx] = 0;
    reference_bases[str_idx] = 0;
//printf("reference_bases is %s\n", reference_bases);
//printf("mismatch_string is %s\n", mismatch_string);


    Inline_Stack_Vars;
    Inline_Stack_Reset;
    // The string length is really str_idx-1 because str_idx points to the char to put the _next_ char in to
    Inline_Stack_Push(sv_2mortal(newSVpv(mismatch_string, str_idx - 1)));
    Inline_Stack_Push(sv_2mortal(newSVpv(reference_bases, str_idx - 1)));
    Inline_Stack_Done;
}

END_C

1;

