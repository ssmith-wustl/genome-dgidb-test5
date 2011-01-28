package Genome::Model::Build::SomaticVariation::IdentifyPreviouslyDiscoveredVariations;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::SomaticVariation::IdentifyPreviouslyDiscoveredVariations{
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
        }
    ],
};

sub execute{
    my $self = shift;
    my $build = $self->build;
    unless ($build){
        die $self->error_message("no build provided!");
    }
    $self->status_message("ID Previoud: Build id: ". $build->id);
    $self->error_message("ID Previoud: Build id: ". $build->id);
    return 1;
}

1;

