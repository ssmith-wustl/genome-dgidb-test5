package Genome::Model::ImportedAnnotation;

use strict;
use warnings;

use Data::Dumper;
use Genome;

class Genome::Model::ImportedAnnotation{
    is => 'Genome::Model',
    has =>[
        annotation_source => {
            is => 'String',
            via => 'processing_profile',
        },
        annotation_data_source_directory => {
            via => 'inputs',
            is => 'UR::Value',
            to => 'value_id',
            where => [ name => 'annotation_data_source_directory', value_class_name => 'UR::Value'],
            is_mutable => 1 
        },
        species_name => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'species_name' ],
            is_mutable => 1,
        },
        version => { 
            via => 'inputs',
            is => 'Text',
            to => 'value_id', 
            where => [ name => 'version', value_class_name => 'UR::Value'], 
            is_mutable => 1
        },
    ],
};

sub build_by_version {
    my $self = shift;
    my $version = shift;

    my @builds =  grep { $_->version eq $version } $self->completed_builds;
    if (@builds > 1) {
        my $versions_string = join("\n", map { "model_id ".$_->model_id." build_id ".$_->build_id." version ".$_->version } @builds);
        $self->error_message("Multiple builds for version $version of model " . $self->genome_model_id.", ".$self->name."\n".$versions_string."\n");
        die;
    }
    return $builds[0];
}

sub annotation_data_directory{
    my $self = shift;
    my $build = $self->last_complete_build;
    return $build->determine_data_directory;
}

1;

