#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Model::RefSeqAlignmentCollection;

package Genome::Command::CalculateCoverage;

# Constructor -----------------------------------------------------------------

sub new{
    my ($pkg, %params) = @_;
    
    my $self = {
        binary_aln_filename => undef,    
    };
    
    $self = { %$self, %params };
    
    return bless $self, $pkg;
}

# Accessor Methods ------------------------------------------------------------

sub binary_aln_filename {shift->{binary_aln_filename}}

# Instance Methods ------------------------------------------------------------

sub print_coverage_by_position{
    my $self = shift;
    my $print_fh = shift;
    
    my $alns = Genome::Model::RefSeqAlignmentCollection->new( file_prefix => $self->binary_aln_filename );
    
    # 0 match
    # 1 mismatch
    # 2 subject-insert
    # 3 query-insert
    
    my $QUERY_INSERT = 3;
    my $REFERENCE_INSERT = 2;
    
    my $count_coverage = sub {
        my $alignments = shift;
        
        my $coverage_depth_at_this_position = 0;
        foreach my $aln (@$alignments){
            
            # skip over insertions in the reference
            my $mm_code;
            do{
                $mm_code = $aln->get_current_mismatch_code();
                $aln->increment_position();
            } while (defined($mm_code) && $mm_code == $REFERENCE_INSERT);
            
            $coverage_depth_at_this_position++ unless (!defined($mm_code) || $mm_code == $QUERY_INSERT)
        }
        
        return $coverage_depth_at_this_position;
    };

    {
        no strict 'refs';
        
        my $print_to_stdout = sub {
            my $result = shift;
            
            print $print_fh $result . ' ';
        };
        
        $alns->foreach_reference_position( $count_coverage, $print_to_stdout );
        
        print $print_fh "\n";
    }
}

1;
