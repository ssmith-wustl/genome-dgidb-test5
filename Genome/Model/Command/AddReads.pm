package Genome::Model::Command::AddReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Genome::Model::Command',
    has => [
        model_id            => { is => 'Integer', 
                                doc => 'Identifies the genome model to which we\'ll add the reads.' },
        model               => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' 
                                },
        read_set_id         => { is => 'String',
                                doc => 'The unique ID of the data set produced on the instrument' },
    ],
    has_optional => [
        test                => { is => 'Boolean',
                                  doc => 'Create run and event information in the database, but do not schedule or execute any sub-commands',
                                  is_optional => 1,
                                  default_value => 0},
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
$DB::single=1;

    my $self = shift;
$DB::single=1;

    my $model = $self->model;

    my @sub_command_classes= qw/
        Genome::Model::Command::AddReads::AssignRun
        Genome::Model::Command::AddReads::AlignReads
        Genome::Model::Command::AddReads::ProcessLowQualityAlignments
        Genome::Model::Command::AddReads::AcceptReads
    /;

    my $read_set_id = $self->read_set_id;
    
    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    eval "use GSCApp; App::DB->db_access_level('rw'); App->init;";
    die $@ if $@;
    
    my $read_set = GSC::Sequence::Item->get($read_set_id);
    unless ($read_set) {
        $self->error_message("Failed to find run $read_set_id");
        return;
    }

    my $sequencing_platform;
    if ($read_set->isa("GSC::RunLaneSolexa")) {
        $sequencing_platform = 'solexa';
    }
    elsif ($read_set->isa("GSC::RunRegion454")) {
        $sequencing_platform = '454';
    }
    else {
        $self->error_message("Cannot resolve sequencing platform for "
            . ref($read_set)
            . " " 
            . $read_set->name 
            . " (" . $read_set->id . ")"
        );
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
            sequencing_platform => $sequencing_platform,
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
        my $command = $command_class->create(
            run_id => $run->id,
            model_id => $self->model_id,
            event_status => 'Scheduled',
            retry_count => 0,
        );
        unless ($command) {
            $self->error_message(
                "Problem creating subcommand for class $command_class run id ".$run->id
                . " model id ".$self->model_id
                . ": " . $command_class->error_message()
            );
            return;
        }
        
        $self->status_message("Launched $command_class for run_id ",$run->id," event_id ",$command->genome_model_event_id,"\n");
        
        if ($self->test) {
            $command->lsf_job_id("test " . UR::Context::Process->get_current());
        }
    }

    return 1; 
}

1;

