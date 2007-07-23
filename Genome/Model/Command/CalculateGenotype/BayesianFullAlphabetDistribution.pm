
package Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution;

use strict;
use warnings;

use UR;
use Command;

use IO::File;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant REFERENCE_INSERT   => 2;
use constant QUERY_INSERT       => 3;

use Genome::Model::Command::IterateOverRefSeq;

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
    ""
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

    our $bases_fh = IO::File->new($self->bases_file);   # Ugly hack until _examine_position can be called as a method
    unless ($bases_fh) {
        $self->error_message("Can't open bases file: $!");
        return undef;
    }

    $self->SUPER::execute();
}

# note that we have (assume?) no information about Maternal / Paternal phasing of the diploid genotypes
# this means that we only have the diagonal and top half of the matrix of possible diploid genotypes.
# We also assume that there cannot be the '--' genotype as it is illogical?
# As a rule then, always lexographically sort haploid genotypes before combining
#my $POSSIBLE_GENOTYPES = [
#                          qw/
#                                   -A -C -G -T
#                                   AA AC AG AT
#                                      CC CG CT
#                                         GG GT
#                                            TT
#                            /
#                          ];

#my $INDEX_OF_DIPLOID_FROM_STRING = {};
#@INDEX_OF_DIPLOID_FROM_STRING{ qw/
#    __ _A _C _G _T
#    A_ AA AC AG AT
#    C_ CA CC CG CT
#    G_ GA GC GG GT
#    T_ TA TC TG TT
#    /} = @$INDEX_OF_DIPLOID_FROM_ORDERED_PAIR;

#my $ALPHABET = [qw/ - A C G T /];

my $INDEX_OF_DIPLOD_FROM_ORDERED_PAIR = [
 [undef,  0,  1,  2,  3, ],
 [    0,  4,  5,  6,  7, ],
 [    1,  5,  8,  9, 10, ],
 [    2,  6,  9, 11, 12, ],
 [    3,  9, 10, 12, 13, ],
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

my $DIPLOID_GENOTYPE_PRIORS = _calculate_diploid_genotype_priors();

sub _examine_position {
    my $alignments = shift;

    my $diploid_genotype_vector = [ @$DIPLOID_GENOTYPE_PRIORS ];
    
    my $evidence = 0;
    
    foreach my $aln (@$alignments){

        our $bases_fh;
        $aln->{'reads_fh'} = $bases_fh;   # another ugly hack.  $aln's constructor should know about this instead

        my $vectors = $aln->get_read_probability_vectors();
        for (my $i = 0; $i < 5; $i++) {
            
            # we have all the positions since we get them all at once for a read and then cache them ...
            # so just use 'current_position' to take the right one
            my $base_likelihood = $vectors->[ $aln->{'current_position'} ]->[$i];
            
            next unless defined $base_likelihood;   # The reference positions can go past the read length
            
            my $base_AND_alignment_likelihood = $base_score * $aln->{'probability'};
            my $base_AND_NOT_alignment_likelihood = $base_score * ( 1 - $aln->{'probability'} );
            
            $evidence += $base_AND_alignment_likelihood;
            $evidence += $base_AND_NOT_alignment_likelihood;
            
            for (my $other_allele_alphabet_index = 0 ; $other_allele_alphabet_index < 5 ; $i++){
                
                $diploid_genotype_vector->[
                                            $INDEX_OF_DIPLOD_FROM_ORDERED_PAIR->[$i]->[$other_allele_alphabet_index]
                                           ]
                    *= ( $base_AND_alignment_likelihood * $BASE_CALL_PRIORS->[$other_allele_alphabet_index] );
            }
        }
        
        @$diploid_genotype_vector = map { $_ / $evidence } @$diploid_genotype_vector;
        
        $aln->{'current_position'}++;
    }

    return $diploid_genotype_vector;
}

# Helper Methods --------------------------------------------------------------

sub _calculate_diploid_genotype_priors{
    
    my $DIPLOID_GENOTYPE_PRIORS = [];
    
    my $evidence_normalizer = 0;
    
    # naive OR
    for (my $i = 0 ; $i < 5 ; $i++){
        
        for( my $j = 0 ; $j < 5 ; $j++){
                    
            next if ($j == 0 && $i == 0);
            
            my $joint_prior = $BASE_CALL_PRIORS->[ $i ] * $BASE_CALL_PRIORS->[ $j ];
            
            $DIPLOID_GENOTYPE_PRIORS->[
                                       $INDEX_OF_DIPLOD_FROM_ORDERED_PAIR->[$i]->[$j]
                                       ]
                +=  $joint_prior;
        }
    }
    
    # OR Correction
    @$DIPLOID_GENOTYPE_PRIORS = map { $_ - ($_ ** 2) } @$DIPLOID_GENOTYPE_PRIORS;
    
    # Calculate evidence normalization constant
    foreach my $prior ( @$DIPLOID_GENOTYPE_PRIORS ){
        $evidence_normalizer += $prior;
    }
    
    # Normalize
    @$DIPLOID_GENOTYPE_PRIORS = map { $_ / $evidence_normalizer } @$DIPLOID_GENOTYPE_PRIORS;
    
    return $DIPLOID_GENOTYPE_PRIORS;
}

1;

