package Genome::Sample::Command::Update::DefaultGenotypeData;

use strict;
use warnings;
use Genome;

class Genome::Sample::Command::Update::DefaultGenotypeData {
    is => 'Genome::Command::Base',
    doc => 'Update the default genotype data for any given sample.',
    has => [
        sample => {
            is => 'Genome::Sample',
            is_many => 0,
            doc => 'Sample for which default genotype data will be set. Resolved by Genome::Command::Base.',
        },
        genotype_id => {
            is => 'Text',
            is_many => 0,
            doc => 'Used to identify a single genotype instrument data that will be set as the sample default',
        },
        overwrite => {
            is => 'Boolean',
            default => 0,
            doc => 'Allow the current default genotype data to be overwrittern.',
        },
        launch_builds => {
            is => 'Boolean',
            default => 1,
            doc => 'If set, new reference alignment builds will be launched if their sample is updated',
        },
    ],
};

sub help_detail {
    'Update the default genotype data for any given sample.'
}

sub execute {
    my $self = shift;

    my $sample = $self->sample;
    Carp::confess 'Could not resolve a sample!' unless $sample and $sample->isa('Genome::Sample');

    # Default genotype models currently relying on the sample and those that will be after the sample is updated
    # both need to be rebuilt. 
    my @genotype_models = $sample->default_genotype_models;

    my $rv = eval {
        $sample->set_default_genotype_data(
            $self->genotype_id,
            $self->overwrite,
        );
    };
    unless (defined $rv and $rv) {
        Carp::confess 'Could not assign genotype data ' . $self->genotype_id . ' to sample ' . $sample->id . ": $@";
    }
    
    if ($self->launch_builds) {    
        push @genotype_models, $sample->default_genotype_models;
        for my $genotype_model (@genotype_models) {
            $genotype_model->request_builds_for_dependent_ref_align;
        }
    }

    return 1;
}
1;
