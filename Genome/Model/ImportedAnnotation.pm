package Genome::Model::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedAnnotation{
    is => 'Genome::Model',
    has =>[
        processing_profile => {
            is => 'Genome::ProcessingProfile::ImportedAnnotation',
            id_by => 'processing_profile_id',
        },
        annotation_source => {
            is => 'String',
            via => 'processing_profile',
        },
        species_name => {
            is => 'String',
            via => 'attributes',
            to => 'value',
            where => [property_name => 'species_name'],
            is_mutable => 1,
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

sub annotation_data_directory{
    my $self = shift;
    my $build = $self->last_complete_build;
    return $build->annotation_data_directory;
}

1;

