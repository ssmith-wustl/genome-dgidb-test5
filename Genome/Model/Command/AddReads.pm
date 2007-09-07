package Genome::Model::Command::AddReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model_id   =>  { is => 'Integer', 
                      doc => "Identifies the genome model to which we'll add the reads." },
        sequencing_platform => { is => 'String',
                                 doc => 'Type of sequencing instrument used to generate the data'},
        full_path => { is => 'String',
                       doc => 'Pathname for the data produced by the run' },
    ],
    has_optional => [
        limit_regions =>  { is => 'String',
                            doc => 'Which regions should be kept during further analysis' },
        bsub    =>  { is => 'Boolean',
                      doc => 'Sub-commands should be submitted to bsub. Default is yes.',
                      default_value => 1 },
        bsub_queue => { is => 'String',
                      doc => 'Which bsub queue to use for sub-command jobs, default is "long"',
                       default_value => 'long'},
        bsub_args => { is => 'String',
                       doc => 'Additional arguments passed along to bsub (such as -o, for example)',
                       default_value => '' },
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
genome-model add-reads --model-id 5 --squencing-platform solexa --full-path=/gscmnt/sata191/production/TEST_DATA/000000_HWI-EAS110-0000_00000/Data/C1-27_Firecrest1.8.28_04-09-2007_lims/Bustard1.8.28_04-09-2007_lims/GERALD_28-01-2007_mhickenb
                    
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

All of the sub-commands listed below will be executed on the model in succession.
EOS
}


our $GENOME_MODEL_BSUBBED_COMMAND = "genome-model";

sub execute {
    my $self = shift;

$DB::single=1;
    
    my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };

    my $run = Genome::RunChunk->get_or_create(full_path => $self->full_path,
                                              limit_regions => $self->limit_regions,
                                              sequencing_platform => $self->sequencing_platform
                                         );
    unless ($run) {
        $self->error_message("Unable to get or create a run record in the database with the parameters provided");
        return;
    }

    my $last_bsub_job_id;
    foreach my $command_class ( @sub_command_classes ) {
        my $command = $command_class->create(run_id => $run->id,
                                             model_id => $self->model_id);

        if ($self->bsub) {
            $last_bsub_job_id = $self->run_command_with_bsub($command,$run,$last_bsub_job_id);
        } elsif (! $self->test) {
            $command->execute();
        }
    }

    return 1; 
}



sub run_command_with_bsub {
    my($self,$command,$run,$last_bsub_job_id) = @_;

    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;

    # In case the command to run on the blades is different than 'genome-model'
    my $cmd = $command->command_name;
    $cmd =~ s/^\S+/$GENOME_MODEL_BSUBBED_COMMAND/;

    my $run_id = $run->id;
    my $model_id = $self->model_id;

    my $cmdline;
    { no warnings 'uninitialized';
        $cmdline = "bsub -q $queue $bsub_args" .
                   ($last_bsub_job_id && " -w $last_bsub_job_id") .
                   " $cmd --run-id $run_id --model-id $model_id";
    }

    if ($self->test) {
        $command->status_message("Test mode, command not executed: $cmdline");
        $last_bsub_job_id = 'test';
    } else {
        $self->status_message("Running command: " . $cmdline);

        my $bsub_output = `$cmdline`;
        my $retval = $? >> 8;

        if ($retval) {
            $self->error_message("bsub returned a non-zero exit code ($retval), bailing out");
            return;
        }

        if ($bsub_output =~ m/Job <(\d+)>/) {
            $last_bsub_job_id = $1;

        } else {
            $self->error_message('Unable to parse bsub output, bailing out');
            $self->error_message("The output was: $bsub_output");
            return;
        }

    }

    return $last_bsub_job_id;
}



sub _get_sorted_sub_command_classes{
    my $self = shift;

    # Determine what all the sub-commands are going to be
    my @sub_command_classes = sort { $a->sub_command_sort_position
                                     <=>
                                     $b->sub_command_sort_position
                                   } $self->sub_command_classes();
    
    return \@sub_command_classes;
}

1;

