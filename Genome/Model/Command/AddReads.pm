package Genome::Model::Command::AddReads;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Genome::Model::Event',
    has => [
        model_id            => { is => 'Integer', 
                                doc => 'Identifies the genome model to which we\'ll add the reads.' },
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

    my $model = $self->model;

    my @sub_command_classes= qw/
        Genome::Model::Command::AddReads::AssignRun
        Genome::Model::Command::AddReads::AlignReads
        Genome::Model::Command::AddReads::ProcessLowQualityAlignments
        Genome::Model::Command::AddReads::AcceptReads
    /;
    
    my $read_set_id = $self->read_set_id;
    
    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    Genome::RunChunk->class;
    die $@ if $@;
    
    my $read_set = GSC::Sequence::Item->get($read_set_id);
    unless ($read_set) {
        $self->error_message("Failed to find run $read_set_id");
        return;
    }

    my ($sequencing_platform,$seq_fs_data_types,$lane,$sample_name,$full_path);
    my $run_name = $read_set->run_name;
    if ($read_set->isa("GSC::RunLaneSolexa")) {
        $sequencing_platform = 'solexa';
        $seq_fs_data_types = ["duplicate fastq path" , "unique fastq path"];
        $lane = $read_set->lane;
        $sample_name = $read_set->sample_name;
        use File::Basename;

        my @fs_path = GSC::SeqFPath->get(seq_id => $read_set_id, data_type => $seq_fs_data_types);
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
        ($full_path) = keys %dirs;
        $full_path .= '/' unless $full_path =~ m|\/$|;
    }
    elsif ($read_set->isa("GSC::RunRegion454")) {
        $sequencing_platform = '454';
        $seq_fs_data_types = ["fasta file path"];
        $lane = $read_set->region_number;
        $sample_name = $read_set->incoming_dna_name;
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

    unless ($model->sample_name eq $sample_name) {
        $self->error_message(
                             "Bad sample name "
                             . $sample_name
                             . " on $run_name/$lane ($read_set_id) "
                             . " does not match model sample "
                             . $model->sample_name
                         );
        return;
    }


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
        if ($run->subset_name ne $lane) {
            $self->error_message("Bad lane/subset value $lane.  Expected " . $run->subset_name);
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
            subset_name => $lane,
            sequencing_platform => $sequencing_platform,
            sample_name => $sample_name,
        );
        unless ($run) {
            $self->error_message("Failed to get or create run record information for $run_name, $lane ($read_set_id)");
            return;
        }
    }

    my $prior_event_id = undef;

    foreach my $command_class ( @sub_command_classes ) {

        my $command = $command_class->create(
            run_id => $run->id,
            model_id => $self->model_id,
            event_status => 'Scheduled',
            retry_count => 0,
            prior_event_id => $prior_event_id,
            parent_event_id => $self->id,
        );
        unless ($command) {
            $self->error_message(
                "Problem creating subcommand for class $command_class run id ".$run->id
                . " model id ".$self->model_id
                . ": " . $command_class->error_message()
            );
            return;
        }
        $self->status_message('Launched '. $command_class .' for run_id '. $run->id
                              .' event_id '. $command->genome_model_event_id ."\n");
        if ($self->test) {
            $command->lsf_job_id("test " . UR::Context::Process->get_current());
        }
        $prior_event_id = $command->id;
    }

    return 1; 
}

sub _get_sub_command_class_name { 
    return __PACKAGE__;
}

1;

