
package Genome::Model::Tools::Old::Genotype::SeparateAllele;

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';
use above "Genome";
use Command;

use IO::File;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant REFERENCE_INSERT   => 2;
use constant QUERY_INSERT       => 3;

use Genome::Model::Command::IterateOverRefSeq;
use Genome::Model::Tools::Old::Genotype;

# Class Methods ---------------------------------------------------------------

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Tools::Old::Genotype',
    has => [
        result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' },
        bases_file => { type => 'String', doc => 'The pathname of the binary file containing prb values' },
    ],
);

sub help_brief {
    return "gives the consensus posterior per position using all combinations of allele distribution";
}

sub help_synopsis {
    return <<EOS

EOS
}

sub help_detail {
    return <<"EOS"

This logic will probably not scale, but seems to be correct in some cases.

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
    shift if $_[0]->isa(__PACKAGE__);
    my $p = shift;
    print "----\n";
    for my $base (0..4) {
        print $alphabet->[$base] . ": " . $p->[0][$base] . "\t" . $p->[1][$base], "\n";
    }
    print "----\n";
}

sub _print_diploid {
    shift if $_[0]->isa(__PACKAGE__);
    my $all_combos = shift;
    print "====\n";
    for my $m (0..4) {
        for my $p (0..4) {
            print $alphabet->[$m] . $alphabet->[$p] . ": " . $all_combos->[$m][$p] . "\n";
        }
    }
    print "====\n";
}

sub _examine_position {
    my ($self, $alignments) = @_;

    my @all_combos = map { [0,0,0,0,0] } (0..4);
 
    my $max_combos = (2 ** scalar(@$alignments));
    my $combo_prob = 1; # /$max_combos;
    for my $combo (0..($max_combos-1)) {
        # $p[$allele][$base] = $probability 
        
        # start with basic priors for both alleles
        # TODO: make this work w/o going back into old reads
        my @p = ([@$BASE_CALL_PRIORS],[@$BASE_CALL_PRIORS]);
        
        # this array will, for a given alignment, tell us which allele it gets for this combination
        my @allele_for_alignment; 
        my $combo_tmp = $combo;
        for (0..$#$alignments) {
            push @allele_for_alignment, ($combo_tmp % 2);
            $combo_tmp = int($combo_tmp/2);
        }
        ##print "$combo has pattern @allele_for_alignment\n";

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
            }
            
            # normalize the base calls across the alignment
            my $sum = $sum[$allele];
            for my $base (0..4) {
                next unless $sum[$allele];
                $p[$allele][$base] /= $sum[$allele];
            }
        }

        #_print_probs(\@p);       
    
        # now shift to the diploid data structure
        my $sum = 0;
        my @diploid = map { [1,1,1,1,1] } (0..4);
        for my $mbase (0..4) {
            for my $pbase (0..4) {
                my $l = $p[0][$mbase] * $p[1][$pbase];
                $sum += (1-$diploid[$mbase][$pbase]);
                $diploid[$mbase][$pbase] *= $l;
                $sum += $diploid[$mbase][$pbase];
            }
        }    
        for my $mbase (0..4) {
            for my $pbase (0..4) {
                next unless $sum;
                $diploid[$mbase][$pbase] /= $sum;
            }
        }    
        
        #_print_diploid(\@diploid);       
    
        # merge with all of the other combinations of allele distribution 
        $sum = 0;
        for my $mbase (0..4) {
            for my $pbase (0..4) {
                #next unless $diploid[$mbase][$pbase];
                $all_combos[$mbase][$pbase] += $diploid[$mbase][$pbase];
                $sum += $all_combos[$mbase][$pbase];
            }
        }
    }
    # normalize
    my $sum = 0;
    for my $mbase (0..4) {
        for my $pbase (0..4) {
            $sum += $all_combos[$mbase][$pbase];
        }
    }
    for my $mbase (0..4) {
        for my $pbase (0..4) {       
            $all_combos[$mbase][$pbase] /= $sum;
        }
    }
    return \@all_combos;    
}

1;
