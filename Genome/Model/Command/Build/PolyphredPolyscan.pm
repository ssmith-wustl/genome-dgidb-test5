package Genome::Model::Command::Build::PolyphredPolyscan;

use strict;
use warnings;
use Genome;
use File::Copy "cp";
use File::Basename;

class Genome::Model::Command::Build::PolyphredPolyscan {
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

    # Link the input files to the new build 
    my $pending_instrument_data_dir = $model->pending_instrument_data_dir;

    my $next_build_dir = $model->next_build_dir;

    if (-d $next_build_dir){
        $self->error_message("next build dir $next_build_dir already exists!");
        die;
    }

    mkdir $next_build_dir;

    my $current_build_dir = $model->current_build_dir;

    unless ($current_build_dir eq $next_build_dir){
        $self->error_message("created next build dir $next_build_dir does not match current build dir $current_build_dir");
        die;
    }

    unless (-d $current_build_dir){
        $self->error_message("New current build dir $current_build_dir does not exist");
        die;
    }

    my $current_instrument_data_dir = $model->current_instrument_data_dir;

    if (-d $current_instrument_data_dir ){
        $self->error_message("new current instrument data dir $current_instrument_data_dir exists before it should!");
        die;
    }

    mkdir $current_instrument_data_dir;

    unless (-d $current_instrument_data_dir){
        $self->error_message("New current instrument data dir $current_instrument_data_dir does not exist");
        die;
    }

    my @pending_instrument_data_files = $model->pending_instrument_data_files;
    
    for my $file (@pending_instrument_data_files) {
        cp($file, $current_instrument_data_dir);

        my $destination_file = $current_instrument_data_dir . basename($file);
        unless (-e $destination_file) {
            $self->error_message("Failed to copy $file to $destination_file");
            die;
        }
    }
    
    return $model;
}


sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

