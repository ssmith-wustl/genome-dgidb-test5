package Genome::Model::Command::Define::GenotypeMicroarray;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::GenotypeMicroarray {
    is => 'Genome::Model::Command::Define',
    has => [
        reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'reference_id',
            doc => 'reference sequence build for this model',
        },
        reference_id => {
            is => 'Text',
            is_input => 1,
            doc => 'id of reference build',
        },
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define genotype-microarray 
  --subject-name SAMPLE_NAME 
  --processing-profile-name PROCESSING_PROFILE_NAME 
  --reference GRCh37-lite-build37
EOS
}

sub help_detail {
    return "Define a new genome model with genotype information based on microarray data."
}

sub type_specific_parameters_for_create {
    my $self = shift;
    return (reference_sequence_build => $self->reference);
}

1;

