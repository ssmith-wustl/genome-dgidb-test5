package Genome::Model::Command::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedAnnotation {
    is => 'Genome::Model::Command::Build',
    has => [
        annotation_directory => {
            is => 'Path',
            doc => 'path to imported_annotation folder, not needed if this is a composite annotation model, not needed for composite annotation models(combined-annotation)',
            is_optional => 1,
        },
        version => {
            is => 'String',
            doc => 'Version number of the annotation db, for ensembl, genbank, and esembl/genbank combined this take the form of <ensembl_version_number>_<human_build_version><Ensembl_iteration_letter> ie. 53_36n',
        },
    ]
};

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation db (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation db
EOS
}

sub create{
    #TODO remove build if conditions aren't met after create.  Ask jwalker for an example of this
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self){
        $self->error_message("Failed to create instance of class $class with params @_");
        die;
    }
    
    #Make sure this is a composite model if not annotation directory is given
    my $model = $self->model;
    unless ($self->annotation_directory){
        my @from_models = $model->from_models;
        unless (@from_models){
            $self->error_message("No annotation directory and this is not a build for a composite model!");
            die;
        }
    }

    my $build = $self->build;
    $build->version($self->version);
    $build->annotation_data_source_directory($self->annotation_directory);

    return $self;
}

1;
