package Genome::Model::Command::AddReads;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Genome::Model::Event',
    has => [
        model_id    => {
            is => 'Integer', 
            doc => 'Identifies the genome model to which we\'ll add the reads.'
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
        test        => { 
            is => 'Boolean',
            doc => 'Create run and event information in the database, but do not schedule or execute any sub-commands',
            is_optional => 1,
            default_value => 0
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


our $GENOME_MODEL_BSUBBED_COMMAND = "genome-model";

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $read_set_query_method_name = $model->read_set_query_method_name;

    my $redo_all = $self->redo_all();
    if ($redo_all) {
        return $self->_redo_all();
    }

    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    Genome::RunChunk->class;
    die $@ if $@;

    my @available_read_sets;
    if ($self->read_set_id) {
        @available_read_sets = GSC::Sequence::Item->get($self->read_set_id);
        unless (@available_read_sets) {
            $self->error_message('Failed to find specified read set: '. $self->read_set_id);
            return;
        }
        if (@available_read_sets > 1) {
            $self->error_message('Found more than one read set for: '. $self->read_set_id);
            return;
        }
    } else {
        if ($self->all) {
            $self->status_message("Adding all available reads to the model...!");
        }
        else {
            $self->status_message("No reads specified!");
            # continue, b/c we'll list for the user which reads are available to add
        }
        my $read_set_class_name = $model->read_set_class_name;
        $self->status_message('Checking for '. $read_set_class_name .' read sets by '. $read_set_query_method_name
                              .' with a value of '. $model->$read_set_query_method_name
                              .' for the '. $model->sequencing_platform .' sequencing platform...');

        # How many potential read sets exist for read_set_class_name
        my @input_read_sets = $model->compatible_input_read_sets();
        $self->status_message('Found '. scalar(@input_read_sets) .' by '. $read_set_query_method_name
                              .' with a value of '. $model->$read_set_query_method_name
                              .' from the class '. $read_set_class_name);

        # How many read sets have been assigned to this model
        my @read_set_assignment_events = $model->read_set_assignment_events();
        $self->status_message('This model has '. scalar(@read_set_assignment_events) .' read sets already assigned.');
        my @desc = sort map { $_->read_set->full_name . " (" . $_->read_set->id . ")" } @read_set_assignment_events;
        for my $desc (@desc) {
            $self->status_message("    " . $desc);
        }

        # Determine which read sets are available
        @available_read_sets = $model->available_read_sets;
        $self->status_message(
                              scalar(@available_read_sets)
                              .' read sets are available to add to the model'
                              . (scalar(@available_read_sets) > 0 ? ':' : '.')
                          );
        @desc = sort map { $read_set_class_name->_desc_dw_obj($_) } @available_read_sets;
        for my $desc (@desc) {
            $self->status_message("    " . $desc);
        }

        if (@available_read_sets == 0) {
            $self->status_message("No reads to add!");
            if ($self->all) {
                return 1;
            }
            else {
                return;
            }
        }
        unless ($self->all) {
            $self->status_message("Please specify a specific --read-set-id, or run with the --all option to add all of the above to the model.");
            return;
        }
    }

    for my $available_read_set (@available_read_sets) {
        my $read_set_class_name = $model->read_set_class_name;
        unless ($model->$read_set_query_method_name eq $available_read_set->$read_set_query_method_name) {
            $self->error_message(
                                 'Bad '. $read_set_query_method_name .' value '.
                                 $available_read_set->$read_set_query_method_name
                                 .' on '. $read_set_class_name->_desc_dw_obj($available_read_set)
                                 .' does not match model '. $read_set_query_method_name .' '.
                                 $model->$read_set_query_method_name
                             );
            return;
        }
        my $run_chunk = $read_set_class_name->get_or_create_from_read_set($available_read_set,$read_set_query_method_name);
        unless ($run_chunk) {
            $self->error_message('Could not create a genome model run chunk for this read set.');
            return;
        }

        my $read_set_link= Genome::Model::ReadSet->get(
                                                       model_id    => $model->id,
                                                       read_set_id => $run_chunk->id
                                                   );
        if ($read_set_link) {
            $self->warning_message('Read set '. $run_chunk->full_name .' has already been added');
            next;
        }

        $read_set_link = Genome::Model::ReadSet->create(
            model_id        => $model->id,
            read_set_id     => $run_chunk->id,
            first_build_id  => undef,  # set when we run the first build with this read set
        );

        unless ($read_set_link) {
            $self->error_message('Could not create a genome model read set for this run chunk.');
            return;
        }

        # TODO: move this section to Genome::Model::Command::Build::ReferenceAlignment
       
        
    }
    return 1;
}

sub _get_sub_command_class_name { 
    return __PACKAGE__;
}

# TODO: move this to Genome::Model::Command::Build::ReferenceAlignment with the event creation logic
sub get_sub_command_classes {
    my $self = shift;

    my @sub_command_classes= qw/
        Genome::Model::Command::AddReads::AssignRun
        Genome::Model::Command::AddReads::AlignReads
        Genome::Model::Command::AddReads::ProcessLowQualityAlignments
    /;

    return @sub_command_classes;
}    

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

