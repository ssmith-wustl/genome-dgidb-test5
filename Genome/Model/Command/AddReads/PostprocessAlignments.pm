package Genome::Model::Command::AddReads::PostprocessAlignments;

use strict;
use warnings;

use Data::Dumper;

use above "Genome";
use Command; 


class Genome::Model::Command::AddReads::PostprocessAlignments {
    is => 'Genome::Model::Event',
    has => [
        model_id   =>  { is => 'Integer', 
                      doc => "Identifies the genome model to which we'll add the reads." },
    ],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "postprocess any incremental alignments generated by a model"
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


our $GENOME_MODEL_BSUBBED_COMMAND = "genome-model";
our @CHILD_JOB_CLASSES = ('Genome::Model::Command::AddReads::MergeAlignments',
                          'Genome::Model::Command::AddReads::UpdateGenotype',
                          'Genome::Model::Command::AddReads::FindVariations',
                          'Genome::Model::Command::AddReads::PostprocessVariations');


sub execute {
    my $self = shift;

    $DB::single=1;
    
    # FIXME there should probably be a more automatic way of getting this list...
    #my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };
    my @sub_command_classes = @CHILD_JOB_CLASSES;

    my $model = Genome::Model->get($self->model_id);
    my @subreferences_names = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    unless (@subreferences_names > 0) {
        @subreferences_names = ('all_sequences');
    }
    
    foreach my $ref (@subreferences_names) { 
        my $prior_event_id = undef;

        THIS_PIPELINE:
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

            #   my $should_bsub = $command->can('should_bsub') ? $command->should_bsub : 0;
            #  if ($should_bsub && $self->bsub) {
                #    $last_bsub_job_id = $self->Genome::Model::Event::run_command_with_bsub($command,$last_command);
                #   $command->lsf_job_id($last_bsub_job_id);
                #     $last_command = $command;
                #    } elsif (! $self->test) {
                    #    my $rv = $command->execute();
                    #    $command->date_completed(UR::Time->now);
                    #  $command->event_status($rv ? 'Succeeded' : 'Failed');

                    #   last THIS_PIPELINE unless ($rv);
                    # }
        }
    }

    return 1; 
}

sub _get_sorted_command_classes{
    my $self = shift;

    # Determine what all the sub-commands are going to be
    my @sub_command_classes = sort { $a->sub_command_sort_position
                                     <=>
                                     $b->sub_command_sort_position
                                   } grep {$_->can('is_not_to_be_run_by_add_reads') && $_->is_not_to_be_run_by_add_reads} $self->sub_command_classes();
    
    return \@sub_command_classes;
}

sub _get_sub_command_class_name{
  return __PACKAGE__; 
  }

1;

