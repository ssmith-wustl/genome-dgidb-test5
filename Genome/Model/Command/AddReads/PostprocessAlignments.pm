package Genome::Model::Command::AddReads::PostprocessAlignments;

use strict;
use warnings;

use Data::Dumper;

use above "Genome";
use Command; 


class Genome::Model::Command::AddReads::PostprocessAlignments {
    is => 'Genome::Model::Event',
    has => [],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "postprocess any alignments generated by a model which have not yet been added to the full assembly"
}

sub help_synopsis {
    return <<"EOS"
genome-model postprocess-alignments --model-id 5
                    
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to postprocess alignments accumulated on a temporary basis

All of the sub-commands listed below will be executed on the model in succession.
EOS
}

sub subordinate_job_classes {
    return (
        'Genome::Model::Command::AddReads::MergeAlignments',
        'Genome::Model::Command::AddReads::UpdateGenotype',
        'Genome::Model::Command::AddReads::FindVariations',
        'Genome::Model::Command::AddReads::PostprocessVariations',
        'Genome::Model::Command::AddReads::AnnotateVariations',
        'Genome::Model::Command::AddReads::FilterVariations'
    );
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    
    my @sub_command_classes = $self->subordinate_job_classes;

    my $model = Genome::Model->get($self->model_id);
    my @subreferences_names = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    unless (@subreferences_names > 0) {
        @subreferences_names = ('all_sequences');
    }
    
    foreach my $ref (@subreferences_names) { 
        my $prior_event_id = undef;
        foreach my $command_class ( @sub_command_classes ) {
            my $command = $command_class->create(
                model_id => $self->model_id, 
                ref_seq_id=>$ref,
                prior_event_id => $prior_event_id,
                parent_event_id => $self->id,
            );
            $command->parent_event_id($self->id);
            $command->event_status('Scheduled');
            $command->retry_count(0);

            $prior_event_id = $command->id;
        }
    }

    return 1; 
}

sub extend_last_execution {
    my ($self) = @_;

    # like execute, but get the existing steps, see which ones never got executed, and generates those.

    my @sub_command_classes = $self->subordinate_job_classes;

    my $model = Genome::Model->get($self->model_id);
    my @subreferences_names = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    unless (@subreferences_names > 0) {
        @subreferences_names = ('all_sequences');
    }

    my @new_events;    
    foreach my $ref (@subreferences_names) { 
        my $prior_event_id = undef;
        foreach my $command_class ( @sub_command_classes ) {
            my $command = $command_class->get(
                model_id => $self->model_id, 
                ref_seq_id => $ref,
                parent_event_id => $self->id,
            );

            unless ($command) {
                $command = $command_class->create(
                    model_id => $self->model_id, 
                    ref_seq_id=>$ref,
                    prior_event_id => $prior_event_id,
                    parent_event_id => $self->id,
                );
                unless ($command) {
                    die "Failed to create command object: $command_class!" . $command_class->error_message;
                }
                push @new_events, $command;
                $command->parent_event_id($self->id);
                $command->event_status('Scheduled');
                $command->retry_count(0);
            }

            $prior_event_id = $command->id;
        }
    }

    return @new_events; 
}

sub _get_sub_command_class_name{
  return __PACKAGE__; 
}

1;

