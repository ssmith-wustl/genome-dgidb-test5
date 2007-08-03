
package Genome::Model::Command::CalculateGenotype::SeparateAllele;

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';
use UR;
use Command;

use IO::File;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant REFERENCE_INSERT   => 2;
use constant QUERY_INSERT       => 3;

use Genome::Model::Command::IterateOverRefSeq;
use Genome::Model::Command::CalculateGenotype;

# Class Methods ---------------------------------------------------------------

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::CalculateGenotype',
    has => [
        result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' },
        bases_file => { type => 'String', doc => 'The pathname of the binary file containing prb values' },
    ],
);

sub help_brief {
    return "gives the consensus posterior over {A,C,G,T} for every position";
}

sub help_synopsis {
    return <<EOS

EOS
}

sub help_detail {
    return <<"EOS"


EOS
}

# Instance Methods ------------------------------------------------------------

my $alphabet = [qw/ - A C G T /];

# we should maybe estimate this from known GC content of reference
my ( $BASE_PRIOR, $INSERTION_PRIOR ) = ( .25, .00001 );

my $BASE_CALL_PRIORS = [
                            $INSERTION_PRIOR,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4
                        ];

sub _print_probs {
    my $p = shift;
    print "----\n";
    for my $base (0..4) {
        print $alphabet->[$base] . ": " . $p->[0][$base] . "\t" . $p->[1][$base], "\n";
    }
    print "----\n";
}

sub _examine_position {
    my ($self, $alignments) = @_;

    # $p[$allele][$base] = $probability 
 
    my $max_combos = (2 ** scalar(@$alignments));
    my $combo_prob = 1; # /$max_combos;
    for my $combo (0..($max_combos-1)) {
        my @p = ([@$BASE_CALL_PRIORS],[@$BASE_CALL_PRIORS]);
        my @allele_for_alignment; 
        my $combo_tmp = $combo;
        for (0..$#$alignments) {
            push @allele_for_alignment, ($combo_tmp % 2);
            $combo_tmp = int($combo_tmp/2);
        }
        
        print "$combo has pattern @allele_for_alignment\n";

        my $paternal_count = 0; 
        for (@allele_for_alignment) { $paternal_count += $_ }
        
        print "  paternal count is $paternal_count\n";

        # Build a probability for the M and P alleles given the alignments.
        for my $anum (0..$#$alignments) {
            my $allele = $allele_for_alignment[$anum];
            my $alignment = $alignments->[$anum];
            my @sum = (0,0);
            for my $base_possibility (0..4) {
                my $base_prob = $alignment->{base_probability_vector}[$base_possibility];
                #print "  $anum: base $base_possibility has p $base_prob\n";
                my $align_prob = $base_prob * $alignment->{alignment_probability} * $combo_prob;
                my $not_align_prob = (1 - $alignment->{alignment_probability}) * $combo_prob;
                
                $sum[$allele] += $p[$allele][$base_possibility] * $not_align_prob;
                $p[$allele][$base_possibility] *= $align_prob;
                $sum[$allele] += $p[$allele][$base_possibility];
                
                #$c[$allele][$base_possibility] += $adj_prob;
            }
            
            # Normalize M and P independently
            my $sum = $sum[$allele];
            for my $base (0..4) {
                $p[$allele][$base] /= $sum[$allele];
            }
        }

        _print_probs(\@p);       
        
        # Combine the above.
    }
    
    return { AT => .5, TA => .5 };
}

1;
