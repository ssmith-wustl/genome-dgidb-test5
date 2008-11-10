package Genome::Model::Command::Build::ReferenceAlignment::Solexa;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::Solexa {
    is => 'Genome::Model::Command::Build::ReferenceAlignment',
    has => [],

 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "postprocess any alignments generated by a model which have not yet been added to the full assembly"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given reference-alignment model.
EOS
}

sub stages {
    my @stages = qw/
        alignment
        variant_detection
        verify_succesful_completion
    /;
    return @stages;
}

sub alignment_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::ReferenceAlignment::AssignRun
        Genome::Model::Command::Build::ReferenceAlignment::AlignReads
        Genome::Model::Command::Build::ReferenceAlignment::ProcessLowQualityAlignments
    /;
    return @sub_command_classes;
}


sub variant_detection_job_classes {
    my @steps = (
                 'Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments',
                 'Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype',
                 'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
                 (
                  'Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations',
                  'Genome::Model::Command::Build::ReferenceAlignment::AnnotateVariations'
              )
             );

    return @steps;
}

sub verify_succesful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccesfulCompletion
    /;
    return @sub_command_classes;
}

sub alignment_objects {
    my $self = shift;
    return $self->model->unbuilt_read_sets;
}

sub variant_detection_objects {
    my $self = shift;
    my $model = $self->model;
    my @subreferences_names = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    unless (@subreferences_names > 0) {
        @subreferences_names = ('all_sequences');
    }
    return @subreferences_names;
}
sub verify_succesful_completion_objects {
    my $self = shift;
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

