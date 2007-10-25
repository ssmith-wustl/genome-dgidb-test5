
package Genome::Model::Command::Tools::Genotype::BayesianFullAlphabetDistribution;

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
use Genome::Model::Command::Tools::Genotype;

# Class Methods ---------------------------------------------------------------

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::Tools::Genotype',
    has => [
        #result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' },
        #bases_file => { type => 'String', doc => 'The pathname of the binary file containing prb values' },
    ],
);

sub help_brief {
    return "Gives the per-position, unphased, consensus Posterior over Maternal,Paternal ∊ {-,A,C,G,T}";
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
my ( $BASE_PRIOR, $INSERTION_PRIOR, $BASE_PRIOR_GIVEN_HETERO, $PRIOR_HETERO ) = ( .25, .00001, 1/3, 1/1_200 ); # 1:1200 is per Elaine Mardis

my $BASE_CALL_PRIORS = [
                            $INSERTION_PRIOR,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR - $INSERTION_PRIOR / 4
                        ];

my $BASE_CALL_PRIORS_GIVEN_HETERO = [
                            $INSERTION_PRIOR,
                            $BASE_PRIOR_GIVEN_HETERO - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR_GIVEN_HETERO - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR_GIVEN_HETERO - $INSERTION_PRIOR / 4,
                            $BASE_PRIOR_GIVEN_HETERO - $INSERTION_PRIOR / 4
                        ];

sub _examine_position {
    my $alignments = shift;

    # Deep copy up a fresh one
    my $diploid_genotype_matrix = _calculate_diploid_genotype_priors();
    my $original_priors = _calculate_diploid_genotype_priors();

    #print_matrix($diploid_genotype_matrix);
    
    foreach my $aln (@$alignments){

        my $evidence = 0;

        my $aln_prob = $aln->{'alignment_probability'};
        my $vector = $aln->{base_probability_vector};
        
        unless ($aln_prob && defined($vector->[4])){
            #warn "Bases File Error\n";
            #next;
            use Data::Dumper;
            die Data::Dumper::Dumper([$aln]) . "\n" . Data::Dumper::Dumper($alignments);
        }
        
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
                    
                    my $likelihood = $vector->[$sampled_allele] * $aln_prob;

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

my $ORIGINAL_PRIORS_MATRIX = _calculate_diploid_genotype_priors();
my $ORIGINAL_PRIORS_VECTOR = [];
foreach my $ordering ( 1, 2 ){
        foreach my $i (0 .. 4) {
            foreach my $j (0 .. 4){
                
                $ORIGINAL_PRIORS_VECTOR->[$INDEX_OF_DIPLOD_FROM_ORDERED_PAIR->[$i]->[$j]]
                    += $ORIGINAL_PRIORS_MATRIX->[$i]->[$j]->[$ordering];
            }
        }
    }

use constant UNPHASED_DIPLOID_ALPHABET => [qw/ -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT/];
use constant TOLERANCE => 100000000;
sub _print_result{
    my ($position, $result) = @_;
    
    no warnings;
    
    # note that we could just loop over the list once and keep a list of the flat maxes
    
    my $max = 0;
    my $next_max = 0;
    my $max_index = 0;
    my $same = 1;
    for( my $i = 0 ; $i < @$result ; $i++){
        my $is_equal = $result->[$i] == $ORIGINAL_PRIORS_VECTOR->[$i];
        $is_equal ||= 0;
        $same *= $is_equal;
        
        if(
           int($result->[$i]*TOLERANCE)/TOLERANCE
           >=
           int($max*TOLERANCE)/TOLERANCE
           ){
            $next_max = $max;
            $max_index = $i;
            $max = $result->[$i];
        }
    }
    
    print $position . ':';
    unless($same){
        if(
           int($max*TOLERANCE)/TOLERANCE
           ==
           int($next_max*TOLERANCE)/TOLERANCE
           ){
            
            my $votes = {};
            
            for( my $call_index = 0 ; $call_index < @$result ; $call_index++){
                
                if( int($max*TOLERANCE)/TOLERANCE == int($result->[$call_index]*TOLERANCE)/TOLERANCE ){
                    foreach my $base ( split(//, UNPHASED_DIPLOID_ALPHABET->[$call_index]) ){
                        $votes->{$base}++;   
                    }
                }
            }
            
            my $certain_call = '';
            
            foreach my $vote (keys %$votes){
                if($votes->{$vote} >= 2){
                    $certain_call .= $vote;
                }
            }
            
            if(length $certain_call){
                print "$certain_call/FLAT";
            }else{
                print "FLAT"
            }
        }else{
            print UNPHASED_DIPLOID_ALPHABET->[$max_index];
        }
    }
    print ':';
    
    #print join(' ', @$result) unless $same;
    
    print "\n";
}

# Helper Methods --------------------------------------------------------------

sub _calculate_diploid_genotype_priors{
    
    my $DIPLOID_GENOTYPE_PRIORS = [];
    
    my $evidence_normalizer = 0;
    
    # OR of mutually exclusive events
    foreach my $ordering (1,2){
        foreach my $i (0 .. 4){
            foreach my $j (0 .. 4){
                
                my $joint_prior = 1;
                
                if($i == $j){ # Homo
                    $joint_prior *= (1-$PRIOR_HETERO) * $BASE_CALL_PRIORS->[$i];
                }else{ # Hetero
                    $joint_prior *= $PRIOR_HETERO * $BASE_CALL_PRIORS->[$i] * $BASE_CALL_PRIORS_GIVEN_HETERO->[$j];
                }
                
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

