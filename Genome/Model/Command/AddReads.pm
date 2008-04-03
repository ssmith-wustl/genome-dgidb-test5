package Genome::Model::Command::AddReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Command',
    has => [
        model_id            => { is => 'Integer', 
                                doc => "Identifies the genome model to which we'll add the reads." },
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' },
        sequencing_platform => { is => 'String',
                                doc => 'Type of sequencing instrument used to generate the data'},
        full_path           => { is => 'String',
                                doc => 'Pathname to the directory containing unique and duplicate fastq files for that run',},
    ],
    has_optional => [
        adaptor_file        =>  { is => 'String',
                                  doc => 'Pathname to the adaptor sequence file for these reads' },
        limit_regions       =>  { is => 'String',
                                  doc => 'Which regions should be kept during further analysis' },
        bsub                =>  { is => 'Boolean',
                                  doc => 'Sub-commands should be submitted to bsub. Default is yes.',
                                  default_value => 1 },
        bsub_queue          =>  { is => 'String',
                                  doc => 'Which bsub queue to use for sub-command jobs, default is "long"',
                                  default_value => 'long'},
        bsub_args           => { is => 'String',
                                  doc => 'Additional arguments passed along to bsub (such as -o, for example)',
                                  default_value => '' },
        test                => { is => 'Boolean',
                                  doc => 'Create run and event information in the database, but do not schedule or execute any sub-commands',
                                  is_optional => 1,
                                  default_value => 0},
    ]
};

sub sub_command_sort_position { 3 }

sub help_brief {
    "launch the pipeline of steps which adds reads to a model"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-reads --model-id 5 --squencing-platform solexa --full-path=/gscmnt/sata191/production/TEST_DATA/000000_HWI-EAS110-0000_00000/Data/C1-27_Firecrest1.8.28_04-09-2007_lims/Bustard1.8.28_04-09-2007_lims/GERALD_28-01-2007_mhickenb

genome-model add-reads --model-id 5 --squencing-platform solexa --run_name 000000_HWI-EAS110-0000_00000
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

    my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };

$DB::single=1;
    my $full_path = $self->full_path;
    unless (-d $full_path) {
        $self->error_message("full_path $full_path directory does not exist");
        return;
    }

    if ($self->adaptor_file && ! -f $self->adaptor_file) {
        $self->error_message("Specified adaptor file does not exist");
        return;
    }

    # Determine the correct value for limit_regions
    my $regions;
    if ($self->limit_regions) {
        $regions = $self->limit_regions;

    } else {
        # The default will differ depengin on what the sequencing_patform is
        $regions = $self->_determine_default_limit_regions();
        $self->limit_regions($regions);
    }
    unless ($regions) {
        $self->error_message("limit_regions is empty!");
        return;
    }

    # Make a RunChunk object for each region
    my $model = $self->model;
    my @runs;
    foreach my $region ( split(//,$regions) ) {
        my $run = Genome::RunChunk->get_or_create(full_path => $full_path,
                                                  limit_regions => $region,
                                                  sequencing_platform => $self->sequencing_platform,
                                                  sample_name => $model->sample_name,
                                             );
        unless ($run) {
            $self->error_message("Failed to run record information for region $region");
            return;
        }
        push @runs, $run;
    }

    unless (@runs) {
        $self->error_message("No runs were created, exiting.");
        return;
    }

    foreach my $run ( @runs ) {

        my $last_bsub_job_id;

        THIS_RUN_PIPELINE:
        foreach my $command_class ( @sub_command_classes ) {
            my $command = $command_class->create(run_id => $run->id,
                                                 model_id => $self->model_id);
            unless ($command) {
                $self->error_message("Problem creating subcommand for class $command_class run id ".$run->id." model id ".$self->model_id);
                return;
            }
            
            if (ref($command)) {   # If there's a command to be done at this step
                # FIXME This isn't very clean.  We should come up with a vetter way to do it
                if ($self->adaptor_file and $command->can('adaptor_file')) {
                    $command->adaptor_file($self->adaptor_file);
                }

                $command->event_status('Scheduled');
                my $should_bsub = 0;
                if ($command->can('should_bsub')) {
                    $should_bsub = $command->should_bsub;
                }

                if ($should_bsub && $self->bsub) {
                    #$last_bsub_job_id = $self->run_command_with_bsub($command,$run,$last_bsub_job_id);
                    $last_bsub_job_id = $self->run_command_with_bsub($command,$last_bsub_job_id);
                    return unless $last_bsub_job_id;
                    $command->lsf_job_id($last_bsub_job_id);
                } elsif (! $self->test) {
                    my $rv = $command->execute();
                    $command->date_completed(UR::Time->now());
                    $command->event_status($rv ? 'Succeeded' : 'Failed');

                    last THIS_RUN_PIPELINE unless ($rv);  # Stop the pipline if one of these fails
                } else {
                    print "Created $command_class for run_id ",$run->id," event_id ",$command->genome_model_event_id,"\n";
                }
            }
        }
    }

    return 1; 
}


sub _determine_default_limit_regions {
    my($self) = @_;

    unless ($self->sequencing_platform eq 'solexa') {
        $self->error_message("Don't know how to determine limit-regions for sequencing platform ".$self->sequencing_platform);
        return;
    }
    return '12345678';
}


sub run_command_with_bsub {
    my($self,$command,$last_bsub_job_id) = @_;

    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;

    if ($command->can('bsub_rusage')) {
        $bsub_args .= ' ' . $command->bsub_rusage;
    }

    my $cmd = 'genome-model bsub-helper';

    my $event_id = $command->genome_model_event_id;
    my $model_id = $self->model_id;
    my $cmdline;
    { no warnings 'uninitialized';
        $cmdline = "bsub -q $queue $bsub_args" .
                   ($last_bsub_job_id && " -w $last_bsub_job_id") .
                   " $cmd --model-id $model_id --event-id $event_id";
    }

    if ($self->test) {
        #$command->status_message("Test mode, command not executed: $cmdline");
        print "Test mode, command not executed: $cmdline\n";
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
                                   } grep {! $_->can('is_not_to_be_run_by_add_reads')} $self->sub_command_classes();
    
    return \@sub_command_classes;
}

1;

