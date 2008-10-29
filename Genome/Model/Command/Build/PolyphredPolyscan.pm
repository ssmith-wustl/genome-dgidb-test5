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

    $self->create_directory($self->data_directory);
    unless (-d $self->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->data_directory);
        die;
    }
    $model->current_running_build_id($self->build_id);

    my $instrument_data_directory = $self->instrument_data_directory;

    if (-d $instrument_data_directory ){
        $self->error_message("new current instrument data dir $instrument_data_directory exists before it should!");
        die;
    }

    $self->create_directory($instrument_data_directory);

    unless (-d $instrument_data_directory){
        $self->error_message("New current instrument data dir $instrument_data_directory does not exist");
        die;
    }

    my @pending_instrument_data_files = $model->pending_instrument_data_files;
    
    for my $file (@pending_instrument_data_files) {
        cp($file, $instrument_data_directory);

        my $destination_file = $instrument_data_directory . basename($file);
        unless (-e $destination_file) {
            $self->error_message("Failed to copy $file to $destination_file");
            die;
        }
    }
    
    $model->last_complete_build_id($self->build_id);
    return $model;
}

# Returns full path to the input data in the current build
sub instrument_data_directory {
    my $self = shift;
    my $build_data_directory = $self->data_directory;

    my $instrument_data_directory = "$build_data_directory/instrument_data/";

    # Remove spaces, replace with underscores
    $instrument_data_directory =~ s/ /_/;
    
    return $instrument_data_directory;
}

# Returns an array of the files in the current input dir
sub instrument_data_files {
    my $self = shift;

    my $instrument_data_directory = $self->instrument_data_directory;
    my @current_instrument_data_files = `ls $instrument_data_directory`;
    
    foreach my $file (@current_instrument_data_files){  #gets rid of the newline from ls, remove this if we switch to IO::Dir
        $file = $instrument_data_directory . $file;
        chomp $file;
    }

    return @current_instrument_data_files;
}



sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

