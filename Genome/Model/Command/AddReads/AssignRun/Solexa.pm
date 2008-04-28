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

sub create {
    my $class = shift;
    my $obj = $class->SUPER::create(@_);

    unless ($obj->model_id and $obj->run_id and $obj->event_type) {
        $class->error_message("This step requires the model and run to be specified at construction time for locking concurrency.");
        $obj->delete;
        return;
    }
    
    my $model = $obj->model;
    
    my $resource_id = join(".",$class,'create',$obj->run_id);
    my $lock = $model->lock_resource(resource_id => $resource_id);
    unless ($lock) {
        $class->error_message("Failed to lock $resource_id.");
        $obj->delete;
        return;
    }
    
    my @prev =
        grep { $_ ne $obj }
        $class->load(
            model_id    => $obj->model_id,
            run_id      => $obj->run_id,
            event_type  => $obj->event_type,
        );
        
    if (@prev) {
        $obj->error_message(
            "This run/lane, " 
            . $obj->run_name . "/" . $obj->run_lane . ' ' 
            . '(' . $obj->read_set_id . '),'
            . ' has already been assigned to this model '
            . $model->id . ' (' . $model->name . ')'
            . ' on event '
            . $prev[0]->genome_model_event_id
        );
        $obj->model->unlock_resource(resource_id => $resource_id);
        $obj->delete;
        return;
    }

    my $unlock = sub { $model->unlock_resource(resource_id => $resource_id) };
    $obj->create_subscription(method => 'commit', callback => $unlock);
    $obj->create_subscription(method => 'delete', callback => $unlock);

    return $obj;
}

sub execute {
    my $self = shift;

    $DB::single=1;

    my $model = $self->model;

    my $run = $self->run;
    
    unless ($run) {
        $self->error_message("No run specified?");
        return;
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

