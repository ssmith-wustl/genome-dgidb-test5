package Genome::Model::ImportedVariations;

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedVariations{
    is => 'Genome::Model',
    has =>[
        processing_profile => {
            is => 'Genome::ProcessingProfile::ImportedVariations',
            id_by => 'processing_profile_id',
        },
    ],
};


sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @builds =  grep { $_->version eq $version} $self->builds;
    if (@builds > 1) {
        my $versions_string = join("\n", map { "model_id ".$_->model_id." build_id ".$_->build_id." version ".$_->version } @builds);
        $self->error_message("Multiple builds for version $version for model " . $self->genome_model_id.", ".$self->name."\n".$versions_string."\n");
        die;
    }
    return $builds[0];
}

sub variation_data_directory{
    my $self = shift;
    my $build = $self->last_complete_build;
    return $build->variation_data_directory;
}

1;

