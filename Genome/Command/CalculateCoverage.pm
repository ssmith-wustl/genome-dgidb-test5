#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Model::RefSeqAlignmentCollection;

package Genome::Command::CalculateCoverage;

use Fcntl;
use Carp;

use constant MATCH => 0;
use constant MISMATCH => 1;
use constant QUERY_INSERT => 3;
use constant REFERENCE_INSERT => 2;

# Constructor -----------------------------------------------------------------

sub new{
    my ($pkg, %params) = @_;
    
    my $self = {
        binary_aln_filename => undef,
        ref_seq_alignment_collection => undef,
    };
    
    $self = { %$self, %params };

    bless $self, $pkg;

    if(
       ($self->binary_aln_filename && $self->ref_seq_alignment_collection)
       ||
       (!$self->binary_aln_filename && !$self->ref_seq_alignment_collection)
       ){
        
        Carp::croak("You must construct the CalculateCoverage object with EITHER an existing RefSeqAlignmentCollection OR a binary_aln_filename, not both or neither");
    }
    
    if($self->binary_aln_filename){
        $self->{ref_seq_alignment_collection} = Genome::Model::RefSeqAlignmentCollection->new( file_prefix => $self->binary_aln_filename,
                                                                                              reference_sequence_length => $self->{reference_sequence_length},
                                                                                              is_sorted => $params{'is_sorted'},
                                                                                              );
    }
    
    return $self;
}

# Accessor Methods ------------------------------------------------------------

sub binary_aln_filename {shift->{binary_aln_filename}}
sub ref_seq_alignment_collection {shift->{ref_seq_alignment_collection}}

# Instance Methods ------------------------------------------------------------

sub print_coverage_by_position{
    my $self = shift;
    my $print_fh = shift;

    no strict 'refs';
    
    my $print_to_stdout = sub {
        my $result = shift;
        
        print $print_fh $result . ' ';
    };
    
    $self->ref_seq_alignment_collection->foreach_reference_position( \&_calculate_coverage, $print_to_stdout );
    
    print $print_fh "\n";

}

sub get_coverage_by_position{
    my $self = shift;
    my $print_fh = shift;
    
    my $coverage_values = [];
        
    my $accumulate = sub {
        my $result = shift;
        
        push @$coverage_values, $result;
    };
    
    $self->ref_seq_alignment_collection->foreach_reference_position( \&_calculate_coverage, $accumulate );
    
    return $coverage_values;
}

# HELPER METHODS --------------------------------------------------------------

sub _calculate_coverage{
    my $alignments = shift;
    
    my $coverage_depth_at_this_position = 0;
    foreach my $aln (@$alignments){
        
        # skip over insertions in the reference
        my $mm_code;
        do{
            # Moving what get_current_mismatch_code() to here to remove the overhead of a function call
            #$mm_code = $aln->get_current_mismatch_code();
            $mm_code = substr($aln->{mismatch_string},$aln->{current_position},1);

            $aln->{current_position}++; # an ugly but necessary optimization
        } while (defined($mm_code) && $mm_code == REFERENCE_INSERT);
        
        $coverage_depth_at_this_position++ unless (!defined($mm_code) || $mm_code == QUERY_INSERT)
    }
    
    return $coverage_depth_at_this_position;
}

1;
