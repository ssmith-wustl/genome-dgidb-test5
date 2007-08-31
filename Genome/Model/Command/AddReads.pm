
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
    my @sub_command_classes = sort { $a->sub_command_sort_position
                                     <=>
                                     $b->sub_command_sort_position
                                   } $self->sub_command_classes();
    my @sub_command_names = map { $_->command_name } @sub_command_classes;

    my $last_bsub_job_id;
    my $queue = $self->bsub_queue;
    my $model = $self->model;

    foreach my $sub_command ( @sub_command_names ) {
        my $cmd = '';
        if ($self->bsub) {
            $cmd .= "bsub -q $queue -o ~/bsub_output -e ~/bsub_output";
            if ($last_bsub_job_id) {
                $cmd .= " -w $last_bsub_job_id";
            }
        }

        $cmd .= " $sub_command --model $model";

        $self->status_message("Running command: $cmd");
        my $command_output = `$cmd`;
#our $fake_id ||= 5;
#my $command_output = "Job <" . $fake_id++ . "> is submitted to queue $queue\n";
        my $retval = $? >> 8;

        if ($retval) {
            $self->error_message("sub-command \"$cmd\" exited with return value $retval, bailing out\n");
            return 0;
        }

        if ($self->bsub) {
            $command_output =~ m/Job \<(\d+)\>/;
            if ($1) {
                $last_bsub_job_id = $1;
            } else {
                $self->error_message("Couldn't parse job out from bsub's output: $command_output");
                return 0;
            }
        }
    }

    return 1; 
}

1;

