package Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovCombine;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovCombine{
    is => ['Command'],
    has =>[
        refcov_output_file => {
            is => 'Text',
            doc => 'output from refcov to be organized by species',
        },
        taxonomy => {
            is => 'Text',
            doc => 'taxonomy file linking reference ids to species names',
        },
        viral_taxonomy => {
            is => 'Text',
            doc => 'viral taxonomy file linking reference ids to species names',
        },
        reference_counts_file => {
            is => 'Text',
            doc => 'File containing reference names and read counts'
        },
        output => {
            is => 'Text',
            doc => 'output file',
        },
    ]
};

sub execute{
    my $self = shift;
    my $refcov_output_file = $self->refcov_output_file;

    return 1;
}

1;
