package Genome::Model::Command::AddReads::AssignRun::Solexa;

use strict;
use warnings;

use above "Genome";
use File::Path;
use GSC;

use IO::File;

class Genome::Model::Command::AddReads::AssignRun::Solexa {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
        run_id => { is => 'Integer', is_optional => 0, doc => 'the genome_model_run on which to operate' },
        adaptor_file => { is => 'String', is_optional => 1, doc => 'pathname to the adaptor file used for these reads'},
    ]
};

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run solexa --model-id 5 --run-id 10
EOS
}

sub help_brief {
    "Creates the appropriate items on the filesystem for a new Solexa run"
}

sub help_detail {                           
    return <<EOS 
This command is normally run automatically as part of "add-reads assign-run"
when it is determined that the run is from Solexa.  
EOS
}

sub should_bsub { 0;}

sub execute {
    my $self = shift;

    $DB::single=1;

    my $model = Genome::Model->get(id => $self->model_id);

    my $run = Genome::RunChunk->get(id => $self->run_id);
    unless ($run) {
        $self->error_message("Did not find run info for run_id " . $self->run_id);
        return 0;
    }

    unless (-d $model->data_parent_directory) {
        eval { mkpath $model->data_parent_directory };
				if ($@) {
					$self->error_message("Couldn't create run directory path $model->data_parent_directory: $@");
					return;
				}
        unless(-d $model->data_parent_directory) {
            $self->error_message("Failed to create data parent directory: ".$model->data_parent_directory. ": $!");
            return;
        }
    }

    my $run_dir = $self->resolve_run_directory;
    unless (-d $run_dir) {
        eval { mkpath($run_dir) };
        if ($@) {
            $self->error_message("Couldn't create run directory path $run_dir: $@");
            return;
        }
    }
    my $log_dir = $self->resolve_log_directory;
    unless (-d $log_dir) {
        eval { mkpath($log_dir) };
        if ($@) {
            $self->error_message("Couldn't create run directory path $log_dir: $@");
            return;
        }
    }
    # Copy the given adaptor file to the run's directory
    if ($self->adaptor_file) {
        my $given_adaptor_pathname = $self->adaptor_file;
        my $local_adaptor_pathname = $self->adaptor_file_for_run;
        `cp $given_adaptor_pathname $local_adaptor_pathname`;
    }

    # The LIMS PSE that ran before us has done some preparation already
    # by making 2 files for each lane in the run.  1 containing sequences
    # that are unique for that sample's library, and another containing
    # sequences that have been seen before, both are fastq files

    # Convert the original solexa sequence files into maq-usable files
    my $lane = $self->run->limit_regions;

    my $orig_unique_file = sprintf("%s/%s_sequence.unique.sorted.fastq",
                                   $run->full_path, 
                                   $lane);
    unless (-f $orig_unique_file) {
        $self->error_message("Source fastq $orig_unique_file does not exist");
        return;
    }

    my $our_unique_file = sprintf("%s/s_%s_sequence.unique.sorted.fastq",
                                   $run_dir,
                                   $lane,
                                 );

    # make a symlink in our model directory pointing to the unique fastq data
    if (-f $our_unique_file) {
        $self->warning_message("The file $our_unique_file already exists.  Removing...");
        unlink ($our_unique_file);
    }
    unless (symlink($orig_unique_file,$our_unique_file)) {
        $self->error_message("Unable to create symlink $our_unique_file -> $orig_unique_file: $!");
        return;
    }

    if (! $model->multi_read_fragment_strategy  or
        $model->multi_read_fragment_strategy ne 'EliminateAllDuplicates') {

        my $orig_duplicate_file = sprintf("%s/%s_sequence.duplicate.sorted.fastq",
                                       $run->full_path,
                                       $lane,
                                     );
        unless (-f $orig_duplicate_file) {
            $self->error_message("Source fastq $orig_duplicate_file does not exist");
            return;
        }


        my $our_duplicate_file = sprintf("%s/s_%s_sequence.duplicate.sorted.fastq",
                                       $run_dir,
                                       $lane,
                                     );

        if (-f $our_duplicate_file) {
            $self->warning_message("The file $our_duplicate_file already exists.  Removing...");
            unlink ($our_duplicate_file);
        }
        unless (symlink($orig_duplicate_file, $our_duplicate_file)) {
            $self->error_message("Unable to create symlink $our_duplicate_file -> $orig_duplicate_file: $!");
            return;
        }
    }

    return 1;
}
    


1;

