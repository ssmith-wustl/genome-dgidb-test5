
package Genome::Model::Command::AddReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model   =>  { is => 'String', 
                      doc => "Identifies the genome model to which we'll add the reads." },
        bsub    =>  { is => 'Boolean',
                      doc => 'Sub-commands should be submitted to bsub. Default is yes.',
                      default_value => 1 },
        bsub_queue => { is => 'String',
                      doc => 'Which bsub queue to use for sub-command jobs, default is "long"',
                       default_value => 'long'},
        bsub_args => { is => 'String',
                       doc => 'Additional arguments passed along to bsub (such as -o, for example)',
                       default_value => '' },
        full_path => { is => 'String',
                       doc => 'Pathname for the data produced by the run' },
        limit_regions =>  { is => 'String',
                            doc => 'Which regions should be kept during further analysis',
                            is_optional => 1},
        sequencing_platform => { is => 'String',
                                 doc => 'Type of sequencing instrument used to generate the data'},
        test => { is => 'Boolean',
                  doc => 'Create run information in the database, but do not schedule any sub-commands',
                  is_optional => 1,
                  default_value => 0},
    ]
);

sub help_brief {
    "add reads from all or part of an instrument run to the model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads --model ley_aml_patient1_solexa_cdna /SOME/PATH
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

All of the sub-commands listed below will be executed on the model in succession.
EOS
}

#sub is_sub_command_delegator {
#    return 0;
#}

sub execute {
    my $self = shift;

$DB::single=1;
    my $model_name = $self->model;
    my $model = Genome::Model->get(name => $model_name);
    unless($model) {
        $self->error_message("Genome model named $model_name is unknown");
        return 0;
    }

    my $run = Genome::Run->create(full_path => $self->full_path,
                                  limit_regions => $self->limit_regions,
                                  sequencing_platform => $self->sequencing_platform);
    unless ($run) {
        $self->error_message('Failed to create a new Run record, exiting');
        return 0;
    }

    # Determine what all the sub-commands are going to be
    my @sub_command_classes = sort { $a->sub_command_sort_position
                                     <=>
                                     $b->sub_command_sort_position
                                   } $self->sub_command_classes();
    my @sub_command_names = map { $_->command_name } @sub_command_classes;

    my $last_bsub_job_id;
    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;

    for (my $idx = 0; $idx < @sub_command_names; $idx++) {
        my $cmd = '';
        if ($self->bsub) {
            $cmd .= "bsub -q $queue $bsub_args";
            if ($last_bsub_job_id) {
                $cmd .= " -w $last_bsub_job_id";
            }
        }

        $cmd .= sprintf(' %s --model %s --run-id %d', $sub_command_names[$idx], $model_name, $run->id);

        $self->status_message("Running command: $cmd");
        my($command_output, $retval);
        if ($self->test) {
            $self->status_message("** test mode, above command not executed");
        } else {
            $command_output = `$cmd`;
            $retval = $? >> 8;
        }

        if ($retval) {
            $self->error_message("sub-command \"$cmd\" exited with return value $retval, bailing out\n");
            return 0;
        }

        if ($self->bsub) {
            $command_output =~ m/Job \<(\d+)\>/;
            if ($1 || $self->test) {
                $last_bsub_job_id = $1;
            } else {
                $self->error_message("Couldn't parse job out from bsub's output: $command_output");
                return 0;
            }
            Genome::Model::Event->create(event_type => $sub_command_classes[$idx],
                                         genome_model_id => $model->id,
                                         lsf_job_id => $last_bsub_job_id,
                                         date_scheduled => scalar(localtime),
                                         user_name => $ENV{'USER'},
                                        );
            App::DB->sync_database();
            App::DB->commit();
        }
    }

    return 1; 
}

1;

