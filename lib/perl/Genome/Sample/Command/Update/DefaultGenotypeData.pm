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
        genotype => {
            is => 'Genome::InstrumentData::Imported',
            is_many => 0,
            doc => 'Genotype to use as the default genotype data for sample. Resolved by Genome::Command::Base.',
            require_user_verify => 1,
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
    my $genotype = $self->genotype;
    
    my $rv = eval {
        $sample->set_default_genotype_data(
            $genotype,
            $self->overwrite,
        );
    };
    unless (defined $rv and $rv) {
        Carp::confess 'Could not assign genotype data ' . $genotype->id . ' to sample ' . $sample->id . ": $@";
    }
    
    return 1 unless $self->launch_builds;

    my @models = Genome::Model::ReferenceAlignment->get(
        subject_id => $sample->id,
    );
    for my $model (@models) {
        my $genotype_model = $model->default_genotype_model;
        next if $genotype_model->id eq $model->genotype_microarray_model_id;
        $model->genotype_microarray_model_id($genotype_model->id);
        $model->build_requested(1);
    }

    
    return 1;
}
1;
