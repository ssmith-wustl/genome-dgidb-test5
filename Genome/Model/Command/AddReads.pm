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
        sequencing_platform => { is => 'String',
                                doc => 'Type of sequencing instrument used to generate the data'},
        full_path           => { is => 'String',
                                doc => 'Pathname for the data produced by the run',
                                is_optional => 1 },
        run_name            => { is => 'String',
                                 doc => "Name of the run.  It will determine the pathname automaticly and add all lanes for the model's sample",
                                 is_optional => 1 },
    ],
    has_optional => [
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
                                    doc => 'Create run information in the database, but do not schedule any sub-commands',
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
                    
EOS
}

sub help_detail {
    return <<"EOS"
This command launches all of the appropriate commands to add a run,
or part of a run, to the specified model.

All of the sub-commands listed below will be executed on the model in succession.

Either the --full-path or --run-name option must be specified
EOS
}


our $GENOME_MODEL_BSUBBED_COMMAND = "genome-model";

sub execute {
    my $self = shift;

    my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };

$DB::single=1;
    # Determine the pathname for the run
    my $full_path;
    if ($self->full_path) {
        $full_path = $self->full_path;

    } elsif ($self->run_name) {
        require GSCApp;
        my @paths = $self->_find_full_path_by_run_name_and_sequencing_platform();

        if (! @paths) {
            $self->error_message("No analysis pathname found for that run name");
            return;
        } elsif (@paths > 1) {
            my $message = "Multiple analysis pathnames found:\n" . join("\n",@paths);
            $self->warning_message($message);
            $self->error_message("Use the --full-path option to directly specify one pathname");
            return;
        } else {
            $full_path = $paths[0];
        }
    }


    # Determine the correct value for limit_regions
    my $regions;
    if ($self->limit_regions) {
        $regions = $self->limit_regions;

    } else {
        # The default will differ depengin on what the sequencing_patform is
        $regions = $self->_determine_default_limit_regions();
    }

    # Make a RunChunk object for each region
    my @runs;
    foreach my $region ( split(//,$regions) ) {
        my $run = Genome::RunChunk->get_or_create(full_path => $full_path,
                                                  limit_regions => $region,
                                                  sequencing_platform => $self->sequencing_platform
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
        foreach my $command_class ( @sub_command_classes ) {
            my $command = $command_class->create(run_id => $run->id,
                                                 model_id => $self->model_id);
    
            if ($self->bsub) {
                $last_bsub_job_id = $self->run_command_with_bsub($command,$run,$last_bsub_job_id);
            } elsif (! $self->test) {
                $last_bsub_job_id = $command->execute();
            }

            # This will be false if something went wrong.
            # We should probably stop the pipeline at this point
            return unless $last_bsub_job_id;
           
        }
    }

    return 1; 
}


# For solexa runs, return the gerald directory path
sub _find_full_path_by_run_name_and_sequencing_platform {
    my($self) = @_;

    my $run_name = $self->run_name;
    my $sequencing_platform = $self->sequencing_platform;

    unless ($sequencing_platform eq 'solexa') {
        $self->error_message("Don't know how to determine run paths for sequencing platform $sequencing_platform");
        return;
    }

    my $solexa_run = GSC::Equipment::Solexa::Run->get(run_name => $run_name);
    unless ($solexa_run) {
        $self->error_message("No Solexa run found by that name");
        return;
    }

    my $glob = $solexa_run->run_directory . '/Data/*Firecrest*/Bustard*/GERALD*/';
    my @gerald_dirs = glob($glob);

    return @gerald_dirs;
}


sub _determine_default_limit_regions {
    my($self) = @_;

    unless ($self->sequencing_platform eq 'solexa') {
        $self->error_message("Don't know how to determine limit-regions for sequencing platform ".$self->sequencing_platform);
        return;
    }
  
    my $flowcell;
    if ($self->run_name) {
        ($flowcell) = ($self->run_name =~ m/_(\d+)$/);
    } elsif ($self->full_path) {
        my @path_parts = split('/', $self->full_path);
        foreach my $part ( @path_parts ) {
            ($flowcell) = m/_(\d+)$/;
            last if $flowcell;
        }
    }
    unless ($flowcell) {
        $self->error_message("Couldn't determine flow_cell_id from run name ".$self->run_name." or full path ".$self->full_path);
        return;
    }

    my $solexa_run = GSC::Equipment::Solexa::Run->get(flow_cell_id => $flowcell);
    unless ($solexa_run) {
        $self->error_message("No Solexa run record for flow cell id $flowcell");
        return;
    }

    my @dnapses = GSC::DNAPSE->get(pse_id => $solexa_run->creation_event_id);
    my $model = Genome::Model->get(genome_model_id => $self->model_id);

    my %location_to_dna =
               map { GSC::DNALocation->get(dl_id => $_->dl_id)->location_order => GSC::DNA->get(dna_id => $_->dna_id) }
               grep { $_->get_dna->dna_name eq $model->sample_name }
               @dnapses;

    return join('',keys %location_to_dna);
}


sub run_command_with_bsub {
    my($self,$command,$run,$last_bsub_job_id) = @_;

    my $queue = $self->bsub_queue;
    my $bsub_args = $self->bsub_args;

    if ($command->can('bsub_rusage')) {
        $bsub_args .= ' ' . $command->bsub_rusage;
    }

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
                                   } grep {! $_->can('is_not_to_be_run_by_add_reads')} $self->sub_command_classes();
    
    return \@sub_command_classes;
}

1;

