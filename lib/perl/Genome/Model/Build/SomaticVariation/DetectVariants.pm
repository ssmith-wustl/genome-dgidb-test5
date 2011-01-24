package Genome::Model::Build::SomaticVariation::DetectVariants;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::SomaticVariation::DetectVariants{
    is => 'Genome::Command::Base',
    has =>[
        build_id => {
            is => 'Integer',
            is_input => 1,
            is_output => 1,
            doc => 'build id of SomaticVariation model',
        },
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
            id_by => 'build_id',
        },
    ],
};

sub execute{
    my $self = shift;
    my $build = $self->build;
    unless ($build){
        die $self->error_message("no build provided!");
    }

    my %params;
    $params{snv_detection_strategy} = $self->snv_detection_strategy if $self->snv_detection_strategy;
    $params{indel_detection_strategy} = $self->indel_detection_strategy if $self->indel_detection_strategy;
    $params{sv_detection_strategy} = $self->sv_detection_strategy if $self->sv_detection_strategy;
    $self->status_message("Detect Variants: Build id: ". $build->id);
    $self->error_message("Detect Variants: Build id: ". $build->id);
    return 1;
}

1;

