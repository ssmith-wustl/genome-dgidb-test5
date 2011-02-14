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
        reference_sequence_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'reference_sequence', value_class_name => 'Genome::Model::ImportedReferenceSequence' ],
            is_many => 0,
            is_optional => 1, # TODO: make this non-optional when all data is updated
            is_mutable => 1,
            doc => 'id of the reference sequence model associated with this annotation model',
        },
        reference_sequence => {
            is => 'Genome::Model::ImportedReferenceSequence',
            id_by => 'reference_sequence_id',
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

sub notify_input_build_success {
    my $self = shift;
    my $succeeded_build = shift;

    #TODO We don't want to automatically build anything right now.
    #In the future check for a completed build on the other input model(s)
    #that match(es) the inputs to the one that just completed and thus
    #trigger the running of the combined model.
    #The preceding advice courtesy of jweible --TM

    return 1;
}

sub annotation_build_for_reference {
    my ($class, $reference) = @_;
    my $build;

    #TODO: Remove this hardcoded crap and come up with an intelligent heuristic

    if($reference->name eq 'NCBI-human-build36'){
        $build = Genome::Model::Build::ImportedAnnotation->get(102550711);
    }
    elsif($reference->name eq 'GRCh37-lite-build37' || $reference->name eq 'g1k-human-build37'){
        $build = Genome::Model::Build::ImportedAnnotation->get(2574951);
    }
    return $build;
}

1;

