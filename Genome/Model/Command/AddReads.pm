package Genome::Model::Command::AddReads;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::AddReads {
    is => 'Genome::Model::Event',
    has => [
        model_id    => {
            is => 'Integer', 
            doc => 'Identifies the genome model to which we\'ll add the reads.'
        },
    ],
    has_optional => [
        read_set_id => {
            is => 'Number',
            doc => 'The unique ID of the data set produced on the instrument'
        },
        all => {
            is => 'Boolean',
            doc => 'Add all new reads for the associated sample which are not currently part of the model.'
        },
        redo_all    => {
            is  => 'Boolean',
            doc => 'Remove and reproduce all of the add-reads events for the specified model.'
        },
        test        => { 
            is => 'Boolean',
            doc => 'Create run and event information in the database, but do not schedule or execute any sub-commands',
            is_optional => 1,
            default_value => 0
        },
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
    my $self = shift;

    my $model = $self->model;

    my @sub_command_classes = $self->get_sub_command_classes(); 

    my $redo_all = $self->redo_all();
    if ($redo_all) {
        return $self->_redo_all();
    }

    # hack until the GSC.pm namespace is deployed ...after we fix perl5.6 issues...
    Genome::RunChunk->class;
    die $@ if $@;
 
    my @read_sets;
    if ($self->read_set_id) {        
        @read_sets = GSC::Sequence::Item->get($self->read_set_id);
        unless (@read_sets) {
            $self->error_message("Failed to find specified read set: " . $self->read_set_id);
            return;
        }
    }
    else {
        if ($self->all) {
            $self->status_message("Adding all available reads to the model...!");
        }
        else {
            $self->status_message("No reads specified!");
            # continue, b/c we'll list for the user which reads are available to add
        }
        
        my $read_set_class_name = $model->read_set_class_name;
        
        $self->status_message(
            "Checking for read sets for "
            . $model->sample_name 
            . " for the " . $model->sequencing_platform
            . " sequencing platform..."
        );
        
        my @compatible_read_sets = $model->compatible_read_sets();
        $self->status_message("Found " . scalar(@compatible_read_sets) . " for " . $model->sample_name);
        
        my @read_set_assignment_events = $model->read_set_assignment_events();
        $self->status_message("This model has " . scalar(@read_set_assignment_events) . " read sets already assigned.");
        my @desc = sort map { $_->read_set->full_name . " (" . $_->read_set->id . ")" } @read_set_assignment_events;
        for my $desc (@desc) {
            $self->status_message("    " . $desc);
        }
        
        @read_sets = $model->available_read_sets;
        $self->status_message(
            scalar(@read_sets) 
            . " read sets are available to add to the model" 
            . (scalar(@read_sets) > 0 ? ':' : '.')
        );
        @desc = sort map { $read_set_class_name->_desc_dw_obj($_) } @read_sets;
        for my $desc (@desc) {
            $self->status_message("    " . $desc);
        }
        
        if (@read_sets == 0) {
            $self->status_message("No reads to add!");
            if ($self->all) {
                return 1;
            }
            else {
                return;
            }
        }
        unless ($self->all) {
            $self->status_message("Please specify a specific --read-set-id, or run with the --all option to add all of the above to the model.");
            return;
        }
    }
        
    for my $read_set (@read_sets) {
        my $read_set_id = $read_set->id;
        
        my $run_name = $read_set->run_name;
        my $sample_name = $read_set->sample_name;
    
        my ($sequencing_platform,$seq_fs_data_types,$lane,$full_path);
        if ($read_set->isa("GSC::RunLaneSolexa")) {
            $sequencing_platform = 'solexa';
            $lane = $read_set->lane;
    
            use File::Basename;
            my $seq_fs_data_types = ["duplicate fastq path" , "unique fastq path"];
            my @fs_path = GSC::SeqFPath->get(seq_id => $read_set_id, data_type => $seq_fs_data_types);
            if (not @fs_path) {
                # no longer required, we make this ourselves at alignment time as needed
                $self->status_message("Failed to find the path for data set $run_name/$lane ($read_set_id)!");            
            }
            else {
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
        }
        elsif ($read_set->isa("GSC::RunRegion454")) {
            $sequencing_platform = '454';
            $lane = $read_set->region_number;
            $full_path = '/gscmnt/833/info/medseq/sample_data/'. $read_set->run_name .'/'. $read_set->region_id .'/';
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
    
        my $run_chunk = Genome::RunChunk->get(
            seq_id => $read_set_id,
        );
    
        if ($run_chunk) {
            if ($run_chunk->run_name ne $run_name) {
                $self->error_message("Bad run_name value $run_name.  Expected " . $run_chunk->run_name);
                return;
            }
            if ($run_chunk->full_path ne $full_path) {
                $self->warning_message("Run $run_name has changed location to $full_path from " . $run_chunk->full_path);
                $run_chunk->full_path($full_path);
            }
            if ($run_chunk->subset_name ne $lane) {
                $self->error_message("Bad lane/subset value $lane.  Expected " . $run_chunk->subset_name);
                return;
            }
            if ($run_chunk->sample_name ne $model->sample_name) {
                $self->error_message("Bad sample_name.  Model value is " . $model->model. ", run value is " . $run_chunk->sample_name);
                return;
            }
        }
        else {
            $run_chunk = Genome::RunChunk->create(
                genome_model_run_id => $read_set_id,
                seq_id => $read_set_id,
                run_name => $run_name,
                full_path => $full_path,
                subset_name => $lane,
                sequencing_platform => $sequencing_platform,
                sample_name => $sample_name,

            );
            unless ($run_chunk) {
                $self->error_message("Failed to get or create run record information for $run_name, $lane ($read_set_id)");
                return;
            }
        }
        
        my $read_set_link= Genome::Model::ReadSet->get(
            model_id    => $model->id, 
            read_set_id => $run_chunk->id
        );
        
        if ($read_set_link) {
            $self->warning_message(
                "Read set " . $run_chunk->full_name 
                . " has already been added"
            );
            next;
        }
        
        $read_set_link = Genome::Model::ReadSet->create(
            model_id        => $model->id, 
            read_set_id     => $run_chunk->id,
            first_build_id  => undef,  # set when we run the first build with this read set
        );
        
        unless ($read_set_link) {
            $self->error_message("Couldn't create a genome model read set for this run chunk.");
            return;
        }
        
        # TODO: move this section to Genome::Model::Command::Build::ReferenceAlignment
        if ($model->processing_profile->isa("Genome::ProcessingProfile::ReferenceAlignment")) {
            my $prior_event_id = undef;
        
            foreach my $command_class ( @sub_command_classes ) {
                my $command;
        
                eval {
                    $command = $command_class->create(
                        run_id => $run_chunk->id,
                        model_id => $self->model_id,
                        event_status => 'Scheduled',
                        retry_count => 0,
                        prior_event_id => $prior_event_id,
                        parent_event_id => $self->id,
                    );
                };
                unless ($command) {
                    $DB::single = $DB::stopper;
                    $command = $command_class->create(
                        run_id => $run_chunk->id,
                        model_id => $self->model_id,
                        event_status => 'Scheduled',
                        retry_count => 0,
                        prior_event_id => $prior_event_id,
                        parent_event_id => $self->id,
                    );
                    
                    $self->error_message(
                        "Problem creating subcommand for class $command_class run id ".$run_chunk->id
                        . " model id ".$self->model_id
                        . ": " . $command_class->error_message()
                    );
                    return;
                }
                $self->status_message('Launched '. $command_class .' for run_id '. $run_chunk->id
                                      .' event_id '. $command->genome_model_event_id ."\n");
                if ($self->test) {
                    $command->lsf_job_id("test " . UR::Context::Process->get_current());
                }
                $prior_event_id = $command->id;
            }
        }
    }
    
    return 1; 
}

sub _get_sub_command_class_name { 
    return __PACKAGE__;
}

# TODO: move this to Genome::Model::Command::Build::ReferenceAlignment with the event creation logic
sub get_sub_command_classes {
    my $self = shift;

    my @sub_command_classes= qw/
        Genome::Model::Command::AddReads::AssignRun
        Genome::Model::Command::AddReads::AlignReads
        Genome::Model::Command::AddReads::ProcessLowQualityAlignments
    /;

    return @sub_command_classes;
}    

sub _redo_all {
    my $self = shift;
$DB::single = $DB::stopper;
    my $model = $self->model;
    my $model_id = $model->id;
    
    my @prior_add_reads_events = sort { $b->id <=> $a->id } $model->read_set_addition_events;
    my @replacements;
    for my $prior_add_reads_step (@prior_add_reads_events) {
        my $replacement = $prior_add_reads_step->redo;
        push @replacements, $replacement;
    }

    return @replacements;
}

sub redo {
    my $self = shift;
    my @children = $self->child_events;
    my $read_set_id = $self->read_set_id;
    $self->status_message("Found " . scalar(@children) . " child events under " . $self->id . "\n");
    for my $child (sort { $b->id <=> $a->id } @children) {
        $child->event_status("Scheduled");
        next;
        if ($read_set_id) {
            if ($read_set_id != $child->read_set_id) {
                die "Read set for " . $child->id . " is not $read_set_id!?"; 
            }
        }
        else {
            $read_set_id = $child->read_set_id;
        }
        #$child->delete;
    }   
    
    return 1;
         
    if ($read_set_id) {
        my $class = $self->class;
        my $model_id = $self->model_id;
        $self->delete;
        my $retval = $class->execute(
            model_id => $model_id,
            read_set_id => $read_set_id, 
        );
        unless ($retval) {
            die "Error adding read set $read_set_id!";
        }
        return $retval;
    }
    else {
        $self->warning_message("No read sets found for old addition.  " . $self->id . " Just deleting.");
        return 1;
    }
}

1;

