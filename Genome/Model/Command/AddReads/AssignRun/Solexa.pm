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

# The Previous PSE puts files starting in this directory.  
# There's a subdir for each run name, and then the fastqs are
# under there
sub fastq_directory { '/gscmnt/sata181/info/medseq/sample_data/fastq_dir_from_pse/' }

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

    # The LIMS PSE that ran before us has done some preparation already
    # by making 2 files for each lane in the run.  1 containing sequences
    # that are unique for that sample's library, and another containing
    # sequences that have been seen before, both are fastq files

    # Convert the original solexa sequence files into maq-usable files
    my $lane = $self->run->limit_regions;

    my $orig_unique_file = sprintf("%s/%s/s_%s_sequence.unique.sorted.fastq",
                                   $self->fastq_directory,
                                   $run->name,
                                   $lane,
                                 );
    unless (-f $orig_unique_file) {
        $self->error_message("Source fastq $orig_unique_file does not exist");
        return;
    }

    my $our_unique_file = sprintf("%s/s_%s_sequence.unique.sorted.fastq",
                                   $run_dir,
                                   $lane,
                                 );

    # make a symlink in our model directory pointing to the unique fastq data
    unless (symlink($orig_unique_file,$our_unique_file)) {
        $self->error_message("Unable to create symlink $our_unique_file -> $orig_unique_file: $!");
        return;
    }

    if (! $model->multi_read_fragment_strategy  or
        $model->multi_read_fragment_strategy ne 'EliminateAllDuplicates') {

        my $orig_duplicate_file = sprintf("%s/%s/s_%s_sequence.duplicate.sorted.fastq",
                                       $self->fastq_directory,
                                       $run->name,
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

        unless (symlink($orig_duplicate_file, $our_duplicate_file)) {
            $self->error_message("Unable to create symlink $our_duplicate_file -> $orig_duplicate_file: $!");
            return;
        }
    }

    return 1;
}
    


1;

