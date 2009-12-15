package Genome::Model::Event::Build::PolyphredPolyscan::Run;

#:adukes this looks pretty out of date, I think it should be scrapped if when PolyphredPolyscan is resurrected

use strict;
use warnings;

use File::Basename;
use Genome;
use Cwd;

class Genome::Model::Event::Build::PolyphredPolyscan::Run {
    is => ['Genome::Model::Event'],
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

    $self->create_directory($self->build->data_directory);
    unless (-d $self->build->data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        die;
    }

    my $instrument_data_directory = $self->build->instrument_data_directory;

    unless (-d $instrument_data_directory ){

        $self->create_directory($instrument_data_directory);
    
    }

    unless (-d $instrument_data_directory){
        $self->error_message("New current instrument data dir $instrument_data_directory does not exist");
        die;
    }

    my @pending_instrument_data_files = $model->pending_instrument_data_files;
    $self->status_message("found instrument data files:\n".join("\n", @pending_instrument_data_files));

    for my $file (@pending_instrument_data_files) {
        my $link_to = Cwd::abs_path($file);
        unless ($link_to){
            $self->error_message("couldn't extract source instrumnent data link from instrument data file $file");
            die;
        }
        my $new_link = basename($file);
        $new_link = "$instrument_data_directory/$new_link";
        symlink($link_to, $new_link);

        unless (-e $new_link) {
            $self->error_message("Failed to link $new_link to $file->$link_to $!");
            die;
        }
    }

    $self->build->complete_queue_pses;
    return 1;
}

1;
