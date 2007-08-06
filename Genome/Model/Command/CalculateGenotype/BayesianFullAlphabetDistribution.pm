
package Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution;

use strict;
use warnings;
use utf8;

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
    return "Gives the unphased consensus Posterior over Maternal,Paternal ∊ {-,A,C,G,T} for every position";
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

sub execute {
    my($self) = @_;

    $self->SUPER::execute(
                          iterator_method => 'foreach_aligned_position',
                          );
}

# 1D Version:
# -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT
# This table converts 2D to 1D
my $INDEX_OF_DIPLOD_FROM_ORDERED_PAIR = [
 [    0,  1,   2,   3,  4, ],
 [    1,  5,   6,   7,  8, ],
 [    2,  6,   9,  10, 11, ],
 [    3,  7,  10,  12, 13, ],
 [    4,  8,  11,  13, 14, ],
];

# we should maybe estimate this from known GC content of reference
my ( $BASE_PRIOR, $INSERTION_PRIOR ) = ( .25, .00001 );

my $BASE_CALL_PRIORS = [
                            $INSERTION_PRIOR,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4
                        ];

sub _examine_position {
    my ($self, $alignments) = @_;

    # Deep copy up a fresh one
    my $diploid_genotype_matrix = _calculate_diploid_genotype_priors();
    my $original_priors = _calculate_diploid_genotype_priors();

    #print_matrix($diploid_genotype_matrix);

    foreach my $aln (@$alignments){

        my $evidence = 0;

        my $aln_prob = $aln->{'alignment_probability'};
        my $vector = $aln->{base_probability_vector};
        
        #print "VECTOR to incorporate: @$vector\n";
        
        foreach my $ordering ( 1, 2 ){
            foreach my $allele_maternal (0 .. 4) {
                foreach my $allele_paternal (0 .. 4){
    
                    my ($sampled_allele, $other_allele);
                    if($ordering == 1){
                        ($sampled_allele, $other_allele) = ($allele_maternal, $allele_paternal);
                    }else{
                        ($sampled_allele, $other_allele) = ($allele_paternal, $allele_maternal);
                    }
                    
                    my $likelihood = $vector->[$sampled_allele] * $aln_prob
                                        + $BASE_CALL_PRIORS->[$sampled_allele] * (1 - $aln_prob);

                    $diploid_genotype_matrix->[$allele_maternal]->[$allele_paternal]->[$ordering] *= $likelihood;
                    
                    $evidence += $diploid_genotype_matrix->[$allele_maternal]->[$allele_paternal]->[$ordering];
                }
            }
        }
        
        # The intermediate matrix allows us to spread our uncertainty evenly over
        # both possible Maternal/Paternal phasings for the next iteration in which
        # we no longer know from which allele we sampled and that allele from which
        # we did sample may be different from those on previous iterations
        my $intermediate_matrix = [];
        
        foreach my $ordering ( 1, 2 ){
            foreach my $i (0 .. 4) {
                foreach my $j (0 .. 4){
                    
                    $diploid_genotype_matrix->[$i]->[$j]->[$ordering] /= $evidence;
                    $intermediate_matrix->[$i]->[$j] += $diploid_genotype_matrix->[$i]->[$j]->[$ordering];
                }
            }
        }
        
        foreach my $ordering ( 1, 2 ){
            foreach my $i (0 .. 4) {
                foreach my $j (0 .. 4){
                    
                    $diploid_genotype_matrix->[$i]->[$j]->[$ordering] =
                        $intermediate_matrix->[$i]->[$j] / 2;
                }
            }
        }
        
        #print_matrix($diploid_genotype_matrix);
    }
    
    my $diploid_genotype_vector = [];
    foreach my $ordering ( 1, 2 ){
        foreach my $i (0 .. 4) {
            foreach my $j (0 .. 4){
                
                $diploid_genotype_vector->[$INDEX_OF_DIPLOD_FROM_ORDERED_PAIR->[$i]->[$j]]
                    += $diploid_genotype_matrix->[$i]->[$j]->[$ordering];
            }
        }
    }
    
    return $diploid_genotype_vector;
}

# Helper Methods --------------------------------------------------------------

sub _calculate_diploid_genotype_priors{
    
    my $DIPLOID_GENOTYPE_PRIORS = [];
    
    my $evidence_normalizer = 0;
    
    # OR of mutually exclusive events
    foreach my $ordering (1,2){
        foreach my $i (0 .. 4){
            foreach my $j (0 .. 4){
                
                my $joint_prior = $BASE_CALL_PRIORS->[ $i ]
                                    * $BASE_CALL_PRIORS->[ $j ];
                
                $DIPLOID_GENOTYPE_PRIORS->[$i]->[$j]->[$ordering]
                    = $joint_prior;
                
                $evidence_normalizer += $joint_prior;
            }
        }
    }
    
    # Normalize
    foreach my $ordering (1,2){
        foreach my $i (0 .. 4){
            foreach my $j (0 .. 4){
                
                $DIPLOID_GENOTYPE_PRIORS->[$i]->[$j]->[$ordering] /= $evidence_normalizer;
            }
        }
    }
    
    return $DIPLOID_GENOTYPE_PRIORS;
}


## A Helpful debugging method
#
#
#my $ALPHABET = [qw/ - A C G T /];
#sub print_matrix {
#    my $matrix = shift;
#
#    foreach my $ordering (1,2){
#        print "   ", join("\t", @$ALPHABET), "\n";
#        for (my $i = 0 ; $i < 5 ; $i++){
#            print $ALPHABET->[$i], " ";
#            for( my $j = 0 ; $j < 5 ; $j++){
#                
#                my $value = $matrix->[$i]->[$j]->[$ordering]  ;
#                $value = int($value*10000)/10000;
#                print $value, "\t";
#            }
#            print "\n";
#        }
#        print "\n";
#    }
#}

1;

