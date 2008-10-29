package Genome::Model::Command::Build::CombineVariants;

use strict;
use warnings;
use Genome;
use File::Copy "cp";
use File::Basename;

class Genome::Model::Command::Build::CombineVariants {
    is => 'Genome::Model::Command::Build',

 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "copies any pending input files to a new build and runs variant analysis"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given PolyphredPolyscan model.
EOS
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    unless ($model){
        $self->error_message("Couldn't find model for id ".$self->model_id);
        die;
    }
    $self->status_message("Found Model: " . $model->name);

    $self->create_directory($self->data_directory);
    unless (-d $self->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->data_directory);
        die;
    }

    $model->current_running_build_id($self->build_id);

    $self->status_message("Combining variants");
    $model->combine_variants();
    
    $self->status_message("Annotating variants");
    $model->annotate_variants();
    
    $self->status_message("Writing maf files");
    $model->write_post_annotation_maf_files();

    $model->last_complete_build_id($self->build_id);

    return $model;
}


sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;
