package Genome::Model::Command::AddGoldSnp;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::AddGoldSnp {
    is => 'Genome::Model::Event',
    has => [
        model_id    => {
            is => 'Integer', 
            doc => 'Identifies the genome model to which we\'ll add the reads.'
        },
        file_name => {
            is => 'String',
            doc => 'The gold snp file to be added to the model',
        },
    ],
    has_optional => [
        read_set_id => {
            is => 'Number',
            doc => 'The unique ID of the data set produced on the instrument'
        },
        all => {
            is => 'Boolean',
            doc => 'Add all new reads for the associated sample which are not currently part of the model.'
        },
        redo_all    => {
            is  => 'Boolean',
            doc => 'Remove and reproduce all of the add-reads events for the specified model.'
        },
    ],
};


sub sub_command_sort_position { 3 }

sub help_brief {
    "launch the pipeline of steps which adds reads to a model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads AML-tumor1-new_maq-with_dups --read-set-id 5

genome-model add-reads --model-id 5 --read-set-id 5

EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

Either the --full-path or --run-name option must be specified.  

All of the sub-commands listed below will be executed on the model in succession.

EOS
}


sub execute {
    my $self = shift;

    my $model = $self->model;
    unless ($model) {
        $self->error_message('Failed to find model for '. $self->model_id);
        return;
    }

    #copy gold snp file to model's data directory
    my $cmd = "cp " . $self->file_name . " " . $model->data_directory;
print("cmd:  $cmd\n");
    my $success = system $cmd;
print "success:  $success\n";
#    $model->gold_snp_file($self->file_name) if $success;  #throw error
}

sub _get_sub_command_class_name {
    return __PACKAGE__;
}

# TODO: move this to Genome::Model::Command::Build::ReferenceAlignment with the event creation logic
sub _redo_all {
    my $self = shift;
    my $model = $self->model;
    my $model_id = $model->id;

    my @prior_add_reads_events = sort { $b->id <=> $a->id } $model->read_set_addition_events;
    my @replacements;
    for my $prior_add_reads_step (@prior_add_reads_events) {
        my $replacement = $prior_add_reads_step->redo;
        push @replacements, $replacement;
    }

    return @replacements;
}

sub redo {
    my $self = shift;
    my @children = $self->child_events;
    my $read_set_id = $self->read_set_id;
    $self->status_message("Found " . scalar(@children) . " child events under " . $self->id . "\n");
    for my $child (sort { $b->id <=> $a->id } @children) {
        $child->event_status("Scheduled");
        next;
        if ($read_set_id) {
            if ($read_set_id != $child->read_set_id) {
                die "Read set for " . $child->id . " is not $read_set_id!?"; 
            }
        }
        else {
            $read_set_id = $child->read_set_id;
        }
        #$child->delete;
    }   
    
    return 1;
         
    if ($read_set_id) {
        my $class = $self->class;
        my $model_id = $self->model_id;
        $self->delete;
        my $retval = $class->execute(
            model_id => $model_id,
            read_set_id => $read_set_id, 
        );
        unless ($retval) {
            die "Error adding read set $read_set_id!";
        }
        return $retval;
    }
    else {
        $self->warning_message("No read sets found for old addition.  " . $self->id . " Just deleting.");
        return 1;
    }
}

1;

