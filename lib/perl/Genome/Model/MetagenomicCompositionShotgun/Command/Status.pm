package Genome::Model::MetagenomicCompositionShotgun::Command::Status;

use Genome;
use strict;
use warnings;

class Genome::Model::MetagenomicCompositionShotgun::Command::Status {
    is => 'Genome::Model::MetagenomicCompositionShotgun::Command',
    doc => 'display status of sub-models of a metagenomic shotgun composition build',
    has => [
        build_id => {
            is => 'Integer',
        },
    ],
};

sub execute {
    my $self = shift;

    my $mcs_build = Genome::Model::Build->get($self->build_id);
    my $mcs_model = $mcs_build->model;
    my $hcs_model = $mcs_model->_contamination_screen_alignment_model;
    my @meta_models = $mcs_model->_metagenomic_alignment_models;

    my $hcs_build = $hcs_model->latest_build;
    my $hcs_status = $hcs_build->status if ($hcs_build);
    $hcs_status = 'Not running' unless($hcs_status);
    $self->status_message($hcs_model->name . ": " . $hcs_build->status) if ($hcs_build);
    for my $meta_model (@meta_models) {
        my $meta_build = $meta_model->latest_build;
        my $meta_status = $meta_build->status if ($meta_build);
        $meta_status = 'Not running' unless($meta_status);
        $self->status_message($meta_model->name . ": " . $meta_status);
    }
}

1;
