package Genome::Model::Build::PolyphredPolyscan;
#:adukes short-term remove parent bridges and models, long-term this was part of a messy project, reevaluate what is being accomplished here and decide if we still want to support it.

use strict;
use warnings;

use Genome;

use File::Copy "cp";
use File::Basename;

class Genome::Model::Build::PolyphredPolyscan {
    is => 'Genome::Model::Build',

};

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


# Sets all of the appropriate queue pse's to complete
# i.e. queue pse's concerned with the model for this build
sub complete_queue_pses {
    my $self = shift;
    my $model = $self->model;
    my $processing_profile_id = $model->processing_profile_id;
    my $subject_name = $model->subject_name;

    my $process_step = GSC::ProcessStep->get(process_to => 'queue instrument data for genome modeling');
    unless ($process_step) {
        $self->error_message("Failed to get queue process step in complete_queue_pses");
        return;
    }

    my @pses = GSC::PSE->get(
                                ps_id => $process_step->ps_id,
                                pse_status => 'inprogress',
                            );
    for my $pse (@pses) {
        # We only care about pse's that have the same processing profile and sample name
        unless(defined($pse->added_param('subject_name')) && 
              ($pse->added_param('subject_name') eq $subject_name)) {
            next;
        }

        my $processing_profile_id = $pse->added_param('processing_profile');
        next unless (defined($processing_profile_id)); 
        my $processing_profile = Genome::ProcessingProfile->get($processing_profile_id);
        
        unless($pse->added_param('processing_profile_name') eq $processing_profile->name) {
            next;
        }

        # Now that we are sure this is one of ours... complete it
        $pse->pse_status('complete');
    }
}

1;

