package Genome::Model::Command::AddReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Genome::Model::Command',
    has => [
        model_id            => { is => 'Integer', 
                                doc => "Identifies the genome model to which we'll add the reads." },
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' },
        sequencing_platform => { is => 'String',
                                doc => 'Type of sequencing instrument used to generate the data'},
        read_set_id         => { is => 'String',
                                doc => 'The unique ID of the data set produced on the instrument' },
    ],
    has_optional => [
        adaptor_file        =>  { is => 'String',
                                  doc => 'Pathname to the adaptor sequence file for these reads' },
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
genome-model add-reads --model-id 5 --squencing-platform solexa --read-set-id 5 
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
$DB::single=1;

    my $self = shift;
$DB::single=1;

    my $model = $self->model;

    #my @sub_command_classes = @{ $self->_get_sorted_sub_command_classes };
    my @sub_command_classes= qw/
        Genome::Model::Command::AddReads::AssignRun
        Genome::Model::Command::AddReads::AlignReads
        Genome::Model::Command::AddReads::ProcessLowQualityAlignments
        Genome::Model::Command::AddReads::AcceptReads
    /;

    if ($self->adaptor_file && ! -f $self->adaptor_file) {
        $self->error_message("Specified adaptor file does not exist");
        return;
    }

    my $read_set_id = $self->read_set_id;
    
    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    eval "use GSCApp; App::DB->db_access_level('rw'); App->init;";
    die $@ if $@;
    
    my $read_set = GSC::Sequence::Item->get($read_set_id);
    unless ($read_set) {
        $self->error_message("Failed to find run $read_set_id");
        return;
    }

    my $run_name = $read_set->run_name;
    my $lane = $read_set->lane;

    unless ($model->sample_name eq $read_set->sample_name) {
        $self->error_message(
            "Bad sample name " 
            . $read_set->sample_name 
            . " on $run_name/$lane ($read_set_id) "
            . " does not match model sample "
            . $model->sample_name
        );
        return;
    }

    use File::Basename;
    my @fs_path = GSC::SeqFPath->get(seq_id => $read_set_id);
    
    unless (@fs_path) {
        $self->error_message("Failed to find the path for data set $run_name/$lane ($read_set_id)!");
        return;
    }
    my %dirs = map { File::Basename::dirname($_->path) => 1 } @fs_path;    
    if (keys(%dirs)>1) {
        $self->error_message("Multiple directories for run $run_name/$lane ($read_set_id) not supported!");
        return;
    }
    elsif (keys(%dirs)==0) {
        $self->error_message("No directories for run $run_name/$lane ($read_set_id)??");
        return;
    }
    my ($full_path) = keys %dirs;
    $full_path .= '/' unless $full_path =~ m|\/$|;
    
    my $run = Genome::RunChunk->get(
        seq_id => $read_set_id,
    );

    if ($run) {
        if ($run->run_name ne $run_name) {
            $self->error_message("Bad run_name value $run_name.  Expected " . $run->run_name);
            return;
        }
        if ($run->full_path ne $full_path) {
            $self->warning_message("Run $run_name has changed location to $full_path from " . $run->full_path);
            $run->full_path($full_path);
        }
        if ($run->limit_regions ne $lane) {
            $self->error_message("Bad lane/region value $lane.  Expected " . $run->limit_regions);
            return;
        }
        if ($run->sample_name ne $model->sample_name) {
            $self->error_message("Bad sample_name.  Model value is " . $model->model. ", run value is " . $run->sample_name);
            return;
        }
    }
    else {
        $run = Genome::RunChunk->create(
            genome_model_run_id => $read_set_id,
            seq_id => $read_set_id,
            run_name => $run_name,
            full_path => $full_path,
            limit_regions => $lane, #TODO: platform-neutral name for lane/region!!
            sequencing_platform => $self->sequencing_platform,
            sample_name => $model->sample_name,
        );
        unless ($run) {
            $self->error_message("Failed to get or create run record information for $run_name, $lane ($read_set_id)");
            return;
        }
    }

    my $last_bsub_job_id;
    my $last_command;

    foreach my $command_class ( @sub_command_classes ) {
        my $command = $command_class->create(run_id => $run->id,
                                             model_id => $self->model_id);
        unless ($command) {
            $self->error_message(
                "Problem creating subcommand for class $command_class run id ".$run->id
                . " model id ".$self->model_id
                . ": " . $command_class->error_message()
            );
            return;
        }
        
        if (ref($command)) {   # If there's a command to be done at this step
            # FIXME This isn't very clean.  We should come up with a vetter way to do it
            # TODO: instead of passing the adaptor, have the code which cares look it up
            #       since the logic which passes this just checks genomic vs. cdna
            if ($self->adaptor_file and $command->can('adaptor_file')) {
                $command->adaptor_file($self->adaptor_file);
            }

            $command->event_status('Scheduled');
            $command->retry_count(0);
            my $should_bsub = 0;
            if ($command->can('should_bsub')) {
                $should_bsub = $command->should_bsub;
            }

            if ($should_bsub && $self->bsub) {
                $last_bsub_job_id = $self->Genome::Model::Event::run_command_with_bsub($command,$last_command);
                return unless $last_bsub_job_id;
                $command->lsf_job_id($last_bsub_job_id);
                $last_command  = $command;
            } elsif (! $self->test) {
                my $rv = $command->execute();
                $command->date_completed(UR::Time->now());
                $command->event_status($rv ? 'Succeeded' : 'Failed');

                last unless ($rv);  # Stop the pipline if one of these fails
            } else {
                print "Created $command_class for run_id ",$run->id," event_id ",$command->genome_model_event_id,"\n";
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

## used for a special test case, needs to be fixed to be a run-time option
sub XXXXX_sub_command_classes {
    my $self = shift;
    
    my @classes = $self->SUPER::sub_command_classes(@_);
    
    return grep { /::Test(A|B|C|D|E)/ } @classes;
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

