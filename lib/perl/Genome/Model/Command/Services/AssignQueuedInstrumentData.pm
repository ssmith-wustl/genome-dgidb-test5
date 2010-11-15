package Genome::Model::Command::Services::AssignQueuedInstrumentData;

use strict;
use warnings;

#use Genome;

require Carp;
use Data::Dumper;

class Genome::Model::Command::Services::AssignQueuedInstrumentData {
    is  => 'Command',
    has => [
        test => {
            is          => 'String',
            doc         => "This parameter, if set true, will only process pses with negative id's.",
            is_optional => 1,
            default     => (Genome::Config->dev_mode),
        },
        max_pses => {
            is          => 'Number',
            is_optional => 1,
            len         => 5,
            default     => 200,
            doc         => 'Max # of PSEs to process in one invocation',   
        },
        max_pses_to_check => {
            is          => 'Number',
            is_optional => 1,
            len         => 5,
            default     => 1000,
            doc         => 'Max # of PSEs to check for processability',
        },
        newest_first => {
            is          => 'Boolean',
            is_optional => 1,
            default     => 0,
            doc         => 'Process newest PSEs first',
        },
        _existing_models_with_existing_assignments => {
            is => 'HASH',
            doc => 'Existing models that already had the instrument data for a PSE assigned',
            default_value => {},
            is_output => 1,
        },
        _existing_models_assigned_to => {
            is => 'HASH',
            doc => 'Existing models with the instrument data for a PSE newly assigned',
            default_value => {},
            is_output => 1,
        },
        _newly_created_models => {
            is => 'HASH',
            doc => 'New models created for the instrument data for a PSE',
            default_value => {},
            is_output => 1,
        },
    ],
};

sub help_brief {
'Find all QueueInstrumentDataForGenomeModeling PSEs, create appropriate models, assign instrument data, and finally request a build on the model';
}

sub help_synopsis {
    return <<'EOS'
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;
    
    my $lock;
    unless($self->test) {
        my $lock_resource = '/gsc/var/lock/genome_model_command_services_assign-queued-instrument-data/loader';

        $lock = Genome::Utility::FileSystem->lock_resource(resource_lock=>$lock_resource, max_try=>1);
        unless ($lock) {
            $self->error_message("could not lock, another instance must be running.");
            return;
        }
    }

    my @pses = $self->load_pses;
    $self->status_message('Processing '.scalar(@pses).' PSEs');
    return 1 unless scalar @pses;

    my @completable_pses;    

    PSE: 
    foreach my $pse (@pses) {
        $self->status_message('Starting PSE ' . $pse->id);

        my ($instrument_data_type) = $pse->added_param('instrument_data_type');
        my ($instrument_data_id)   = $pse->added_param('instrument_data_id');
        my ($subject_class_name)   = $pse->added_param('subject_class_name');
        my ($subject_id)           = $pse->added_param('subject_id');

        my @processing_profile_ids = $pse->added_param('processing_profile_id');

        if ( $instrument_data_type =~ /sanger/i ) {
            #for sanger data the pse param actually holds the id of an AnalyzeTraces PSE.
            my $analyze_traces_pse = GSC::PSE::AnalyzeTraces->get($instrument_data_id);

            my $run_name = $analyze_traces_pse->run_name();
            $instrument_data_id = $run_name;
        }

        my $genome_instrument_data = Genome::InstrumentData->get( id => $instrument_data_id );

        my @process_errors;

        if ($subject_class_name and $subject_id and @processing_profile_ids) {
            my $subject      = $subject_class_name->get($subject_id);

            PP: 
            foreach my $processing_profile_id (@processing_profile_ids) {
                my $processing_profile = Genome::ProcessingProfile->get( $processing_profile_id );

                unless ($processing_profile) {
                    $self->error_message(
                        'Failed to get processing profile'
                        . " '$processing_profile_id' for inprogress pse "
                        . $pse->pse_id );
                    push @process_errors, $self->error_message;
                    next PP;
                }

                my $reference_sequence_build;
                if($processing_profile->isa('Genome::ProcessingProfile::ReferenceAlignment')) {
                    my @reference_sequence_build_ids = $pse->reference_sequence_build_param_for_processing_profile($processing_profile);
                    unless ( scalar @reference_sequence_build_ids ) {
                        $self->error_message('No imported reference sequence build id found on pse ('.$pse->id.') to create a reference alignment model');
                        push @process_errors, $self->error_message;
                        next PP;
                    }

                    if( scalar @reference_sequence_build_ids > 1) {
                        $self->error_message('This script is not currently set up to handle multiple reference sequences per processing profile!');
                        push @process_errors, $self->error_message;
                        next PP;
                    }

                    my $reference_sequence_build_id = $reference_sequence_build_ids[0];
                    $reference_sequence_build = Genome::Model::Build::ImportedReferenceSequence->get($reference_sequence_build_id);
                    if ( not defined $reference_sequence_build ) {
                        $self->error_message("Cannot get imported reference sequence build for id $reference_sequence_build_id");
                        push @process_errors, $self->error_message;
                        next PP;
                    }
                }

                my @models = Genome::Model->get(
                    subject_id            => $subject_id,
                    subject_class_name    => $subject_class_name,
                    processing_profile_id => $processing_profile->id,
                    auto_assign_inst_data => 1,
                );


                my @assigned = $self->assign_instrument_data_to_models($genome_instrument_data, $reference_sequence_build, @models);

                #returns an explicit undef on error
                if(scalar(@assigned) eq 1 and not defined $assigned[0]) {
                    push @process_errors, $self->error_message;
                    next PP;
                }

                if(scalar(@assigned > 0)) {
                    for my $m (@assigned) {
                        $pse->add_param('genome_model_id', $m->id);
                    }
                } else {
                    # no model found for this PP, make one (or more) and assign all applicable data
                    my $ok = $self->create_default_models_and_assign_all_applicable_instrument_data($genome_instrument_data, $subject, $processing_profile, $reference_sequence_build, $pse);
                    unless($ok) {
                        push @process_errors, $self->error_message;
                        next PP;
                    }
                }
            } # looping through processing profiles for this instdata, finding or creating the default model

        } else {
            #record that the above code was skipped so we could reattempt it if more information gained later
            $pse->add_param('no_model_generation_attempted',1);
            $self->status_message('No model generation attempted for PSE ' . $pse->id);
        } # done with PSEs which specify a $subject_class_name, $subject_id, and @processing_profile_ids

        if (!$subject_class_name or !$subject_id) {
            $self->warning_message(
                "PSE " . $pse->id . " no subject class/id for instrument data $instrument_data_type $instrument_data_id"
                . " (subject_class_name $subject_class_name subject_id $subject_id)"
            );
        }

        # Handle this instdata for other models besides the default
        {    
            my $sequencing_platform = $instrument_data_type;
            
            # Mismatch between the valid values for a sequencing platform via
            # a processing profile and what is stored as the
            # instrument_data_type PSE param
            if ($sequencing_platform eq 'sanger') {
                $sequencing_platform = '3730';
            }

            my @found_models;
            my @check = qw/sample taxon/;

            for my $check (@check) {
                my $subject = $genome_instrument_data->$check;
                # Should we just hoise this check out of the loop and skip to next PSE?
                if (defined($subject)) {
                    my @some_models= Genome::Model->get(
                        subject_id         => $subject->id,
                        subject_class_name => $subject->class,
                        auto_assign_inst_data => 1,
                    );
                    
                    my $new_models = $self->_newly_created_models;
                    @some_models = grep { not $new_models->{$_->id} } @some_models;
                    push @found_models,@some_models;
                }
            }           
 
            @found_models =
                grep {
                    $_->processing_profile->can('sequencing_platform')
                } @found_models;

            @found_models =
                grep {
                    $_->processing_profile->sequencing_platform() eq $sequencing_platform 
	           } @found_models;

            #Don't care here what ref. seq. was used (if any)
            my @assigned = $self->assign_instrument_data_to_models($genome_instrument_data, undef, @found_models);
            if(scalar(@assigned) eq 1 and not defined $assigned[0]) {
                push @process_errors, $self->error_message;
            }
        } # end of adding instdata to non-autogen models
        
            
        if (@process_errors > 0) {
            $self->error_message(
                "Leaving queue instrument data PSE inprogress, due to errors. \n"
                    . join("\n",@process_errors)
            );
        }
        else {            
            # Set the pse as completed since this is the end of the line
            # for the pses
            push @completable_pses, $pse;
        }

    } # end of PSE loop

    #schedule new builds for the models we found and stored in the output hashes
    $self->request_builds;
    
    $self->status_message("Completing PSEs...");
    for my $pse (@completable_pses) {
        $pse->pse_status("completed");  
    }

    unless($self->test) {
        Genome::Utility::FileSystem->unlock_resource(resource_lock=>$lock);
    }

    return 1;    
}

# There may be a model with auto assign off already using the
# default model name just determined previously.  Thus this lame
# attempt to create a unique name;
sub find_unused_model_name {
    my $self = shift;
    my $desired_model_name = shift;

    my $existing_model = Genome::Model->get( name => $desired_model_name );

    my $name_counter = 0;
    my $new_model_name;

    while ( defined($existing_model) ) {
        $name_counter++;

        $new_model_name = $desired_model_name . '_auto' . $name_counter;
        $existing_model = Genome::Model->get( name => $new_model_name );
    }

    #new_model_name is only set if we ran into an existing model with the desired one.
    return $new_model_name || $desired_model_name;
}

sub load_pses {
    my $self = shift;

    my $pse_sorter;

    if ($self->newest_first) {
        $pse_sorter = sub { $b->id <=> $a->id };
    }
    else {
        $pse_sorter = sub { $a->id <=> $b->id };
    }

    my $ps = GSC::ProcessStep->get( process_to => 'queue instrument data for genome modeling' );

    my @pses = GSC::PSE->get(
        ps_id      => $ps->ps_id,
        pse_status => 'inprogress',
    );
    return unless @pses;

    if($self->test) {
        @pses = grep($_->pse_id < 0, @pses);
    }

    @pses = sort $pse_sorter @pses;

    $self->status_message('Found '.scalar(@pses));

    # Don't try to check more PSEs than we might be able to hold information for in memory.
    if(scalar(@pses) > $self->max_pses_to_check) {
        @pses = splice(@pses, 0, $self->max_pses_to_check);
        $self->status_message('Limiting checking to ' . $self->max_pses_to_check);
    }

    $self->preload_data(@pses); #The checking uses this data, so need to load it first

    @pses = grep($self->check_pse($_), @pses);
    $self->status_message('Of those, '.scalar(@pses). ' PSEs passed check_pse.');

    # Don't bite off more than we can process in a couple hours
    my $max_pses = $self->max_pses;

    if (@pses > $max_pses) {
        @pses = splice(@pses, 0, $max_pses);
        $self->status_message('Limiting processing to ' . $max_pses);
    }

    return @pses;
}

#for efficiency--load these together instead of separate queries for each one
sub preload_data {
    my $self = shift;
    my @pses = @_;

    my @pse_params = GSC::PSEParam->get(pse_id => [ map { $_->pse_id } @pses ]);

    my @instrument_data_ids = 
        map { $_->param_value } 
        grep { $_->param_name eq 'instrument_data_id' } 
        @pse_params;

    $self->status_message("Pre-loading " . scalar(@instrument_data_ids) . " instrument data");
    my @instrument_data = Genome::InstrumentData->get(\@instrument_data_ids);
    my @sample_ids = map { $_->sample_id } @instrument_data;

    $self->status_message("Pre-loading " . scalar(@sample_ids) . " samples");
    my @samples = Genome::Sample->get(\@sample_ids);

    $self->status_message("Pre-loading models for " . scalar(@sample_ids) . " samples");
    my @models = Genome::Model->get(subject_id => \@sample_ids);
    $self->status_message("  got " . scalar(@models) . " models");

    my %taxon_ids = map { $_->taxon_id => 1 } grep($_->taxon_id, @samples);
    my @taxon_ids = sort keys %taxon_ids;
    $self->status_message("Pre-loading models for " . scalar(@taxon_ids) . " taxons");
    push @models, Genome::Model->get(subject_id => \@taxon_ids);
    $self->status_message("  got " . scalar(@models) . " models");        

    if(scalar @models > 0) {
        $self->status_message("Pre-loading instrument data assignments for " . scalar(@models) . " models");
        my @instrument_data_assignments = Genome::Model::InstrumentDataAssignment->get(model_id => [ map { $_->id } @models]);
    }

    return 1;
}

sub check_pse {
    my $self = shift;
    my $pse = shift;

    my $pse_id = $pse->id;

    $self->status_message('Check PSE for #' . $pse_id);

    my @pse_params = GSC::PSEParam->get(pse_id => $pse_id);
    if(grep{ $_->param_value =~ /genotyper/ } @pse_params) {
        $self->status_message("Skipping PSE with genotyper data");
        return;
    }

    my ($instrument_data_type) = $pse->added_param('instrument_data_type');
    my ($instrument_data_id)   = $pse->added_param('instrument_data_id');

    my @expected_types = ('sanger', 'solexa', '454');
    unless ( grep($instrument_data_type =~ /$_/i, @expected_types)) {
        $self->error_message('encountered unkown instrument data type: ' . $instrument_data_type);
        return;
    }

    if ( $instrument_data_type =~ /sanger/i ) {
        my $analyze_traces_pse = GSC::PSE::AnalyzeTraces->get($instrument_data_id);

        unless ( defined($analyze_traces_pse) ) {
            $self->error_message(
                'failed to fetch pse for sanger instrument data with id ' . 
                $instrument_data_id .  ' and pse_id ' . $pse_id);
            return;
        }

        my $run_name = $analyze_traces_pse->run_name();

        unless ( defined($run_name) ) {
            $self->error_message(
                'failed to get a run_name for sanger instrument data with'
                    . " id '$instrument_data_id' and pse_id '$pse_id'" 
            );
            return;
        }

        $instrument_data_id = $run_name;
    }

    my $genome_instrument_data = Genome::InstrumentData->get( id => $instrument_data_id );

    unless ( defined($genome_instrument_data) ) {            
        $self->error_message(
            "Failed to get a Genome::InstrumentData ($instrument_data_type) via"
            . " id '$instrument_data_id'.  PSE_ID is '$pse_id'");
        return;
    }

    if ( $instrument_data_type =~ /solexa/i ) {
        # solexa inst data nee to have the copy sequence file pse successful
        my $index_illumina = $genome_instrument_data->index_illumina;
        if ( not $index_illumina ) {
            $self->error_message('No index illumina for solexa instrument data '.$instrument_data_id);
            return;
        }
        if ( not $index_illumina->copy_sequence_files_confirmed_successfully ) {
            $self->error_message(
                'Solexa instrument data ('.$instrument_data_id.') does not have a successfully confirmed copy sequence files pse. This means it is not ready or may be corrupted.'
            );
            return;
        }
    }

    my ($subject_class_name)   = $pse->added_param('subject_class_name');
    my ($subject_id)           = $pse->added_param('subject_id');

    my @processing_profile_ids = $pse->added_param('processing_profile_id');

    #If specified, they must exist!
    if($subject_class_name or $subject_id or @processing_profile_ids) {
        my $subject = $subject_class_name->get($subject_id);
        unless (defined $subject) {
            $self->error_message(
                'failed to get a subject via subject_class_name'
                . " '$subject_class_name' with subject_id"
                . " '$subject_id'"
            );
            return;
        }
    }

    $self->status_message('Check PSE OK');

    return 1;
}

sub assign_instrument_data_to_models {
    my $self = shift;
    my $genome_instrument_data = shift;
    my $reference_sequence_build = shift;
    my @models = @_;

    my $instrument_data_id = $genome_instrument_data->id;

    # we don't want to (automagically) assign capture and non-capture data to the same model.
    if ( @models and $genome_instrument_data->can('target_region_set_name') ) {
        my $id_capture_target = $genome_instrument_data->target_region_set_name();                 
                    
        if ($id_capture_target) {
            # keep only models with the specified capture target
            my @inputs =
                Genome::Model::Input->get(
                    model_id => [ map { $_->id } @models ], 
                    name => 'target_region_set_name',
                    value_id => $id_capture_target,
                );
            @models = map { $_->model } @inputs;    
        } else {
            # keep only models with NO capture target
            my %capture_model_ids = map { $_->model_id => 1 } Genome::Model::Input->get(
                model_id => [ map { $_->id } @models ], 
                name => 'target_region_set_name',
            );
            @models = grep { not $capture_model_ids{$_->id} } @models;
        }
    }

    if($reference_sequence_build) {
        @models = grep($_->reference_sequence_build eq $reference_sequence_build, @models);
    }

    foreach my $model (@models) {
        my @existing_instrument_data =
            Genome::Model::InstrumentDataAssignment->get(
                instrument_data_id => $instrument_data_id,
                model_id           => $model->id,
            );

        if (@existing_instrument_data) {
            $self->warning_message(
                "instrument data '$instrument_data_id'" .
                ' already assigned to model ' . $model->id
            );

            my $existing_models = $self->_existing_models_with_existing_assignments;
            $existing_models->{$model->id} = $model;
        } else {
            my $assign =
                Genome::Model::Command::InstrumentData::Assign->create(
                    instrument_data_id => $instrument_data_id,
                    model_id           => $model->id,
                );

            unless ( $assign->execute ) {
                $self->error_message(
                    'Failed to execute instrument-data assign for '
                    . 'model '
                    . $model->id
                    . ' and instrument data '
                    . $instrument_data_id );
                return undef;
            }

            my $existing_models = $self->_existing_models_assigned_to;
            $existing_models->{$model->id} = $model;
        }
    }

    return @models;
}

sub create_default_models_and_assign_all_applicable_instrument_data {
    my $self = shift;
    my $genome_instrument_data = shift;
    my $subject = shift;
    my $processing_profile = shift;
    my $reference_sequence_build = shift;
    my $pse = shift;

    my @new_models;

    my $model_name = $subject->name . '.' . $processing_profile->name;

    my $capture_target;

    # Label Solexa/454 capture stuff as such
    if ( $genome_instrument_data->can('target_region_set_name') ) {
        $capture_target = $genome_instrument_data->target_region_set_name();
        
        if ( defined($capture_target) ) {
            $model_name =
                join( '.', $model_name, 'capture', $capture_target );
        }
    }

    #make sure the name we'd like isn't already in use
    $model_name = $self->find_unused_model_name($model_name);

    my %model_params = (
        name                    => $model_name,
        subject_id              => $subject->id,
        subject_class_name      => $subject->class,
        processing_profile_id   => $processing_profile->id,
        auto_assign_inst_data   => 1,
    );

    if($reference_sequence_build) {
        $model_params{reference_sequence_build} = $reference_sequence_build;
    }

    my $model = Genome::Model->create(%model_params);
    unless ( defined($model) ) {
        $self->error_message("Failed to create model '$model_name'");
        return;
    }

    push @new_models, $model;

    if ( defined($capture_target) ) {
        unless($self->assign_capture_inputs($model, $capture_target, $capture_target)) {
            for (@new_models) {
                $_->delete;
                return;
            }
        }

        #Also want to make a second model against a standard region of interest
        my $wuspace_model_name = $self->find_unused_model_name($model_name . '.wu-space');
        $model_params{name} = $wuspace_model_name;

        my $wuspace_model = Genome::Model->create(
            %model_params
        );

        unless ( defined($wuspace_model) ) {
            $self->error_message("Failed to create model '$model_name'");
            for (@new_models) {
                $_->delete;
            }
            return;
        }

        push @new_models, $wuspace_model;

        unless($self->assign_capture_inputs($wuspace_model, $capture_target, 'NCBI-human.combined-annotation-54_36p_v2_CDSome_w_RNA')) {
            for (@new_models) {
                $_->delete;
                return;
            }
        }
    }

    for my $m (@new_models) {
        my $assign_all =
            Genome::Model::Command::InstrumentData::Assign->create(
                model_id => $m->id,
                all      => 1,
            );

        unless ( $assign_all->execute ) {
            $self->error_message(
                'Failed to execute instrument-data assign --all for model '
                . $m->id );
            for (@new_models) {
                $_->delete;
            }
            return;
        }

        my @existing_instrument_data =
            Genome::Model::InstrumentDataAssignment->get(
                instrument_data_id => $genome_instrument_data->id,
                model_id           => $m->id,
            );

        unless (@existing_instrument_data) {
            $self->error_message(
                'instrument data ' . $genome_instrument_data->id . ' not assigned to model ????? (' . $m->id . ')'
            );
            for (@new_models) {
                $_->delete;
            }
            return;
        }

        my @project_names = $self->_resolve_project_names($pse);
        $self->add_model_to_default_modelgroups($m, @project_names);

        my $new_models = $self->_newly_created_models;
        $new_models->{$m->id} = $m;

        $pse->add_param('genome_model_id', $m->id);
    }

    return scalar @new_models;
}


sub assign_capture_inputs {
    my $self = shift;
    my $model = shift;
    my $target_region_set_name = shift;
    my $region_of_interest_set_name = shift;

    my $target_input = $model->add_input(
        name             => "target_region_set_name",
        value_class_name => "UR::Value",
        value_id         => $target_region_set_name
    );

    unless ( defined($target_input) ) {
        $self->error_message('Failed to set capture target input for model ' . $model->id);
        return;
    }

    my $roi_input = $model->add_input(
        name             => "region_of_interest_set_name",
        value_class_name => "UR::Value",
        value_id         => $region_of_interest_set_name
    );

    unless (defined($roi_input)) {
        $self->error_message('Failed to set region of instrument input for model ' . $model->id);
        return;
    }

    return 1;
}

sub add_model_to_default_modelgroups {
    my $self = shift;
    my $model = shift;
    my @project_names = @_;

    my $subject = $model->subject;

    my $source;
    if($subject->isa('Genome::Sample')) {
        $source = $subject->source;
    } elsif($subject->isa('Genome::Individual')) {
        $source = $subject;
    } elsif($subject->isa('Genome::Library')) {
        my $sample = $subject->sample;
        $source = $sample->source;
    } else {
        $self->error_message('Unhandled subject for model--not adding to model-groups');
        return;
    }

    unless($source) {
        $self->error_message('Failed to get source for subject.');
        return;
    }

    my @group_names = @project_names;

    my $common_name = $source->common_name;
    if($common_name) {
        my ($source_grouping) = $common_name =~ /^([a-z]+)\d+$/i;
        push @group_names, $source_grouping if $source_grouping;
    }

    for my $group_name (@group_names) {
        my $name = 'apipe-auto ' . $group_name;
        if(length($name) > 50) {
            $name = substr($name,0,50);
        }
        my $model_group = Genome::ModelGroup->get(name => $name);

        unless($model_group) {
            $model_group = Genome::ModelGroup->create(name => $name);
            unless($model_group) {
                $self->error_message('Failed to create a default model-group: ' . $name);
                return;
            }
        }

        unless(grep($_ eq $model, $model_group->models)) {
            $model_group->assign_models($model);
        }
    }

    return 1;
}

sub _resolve_project_names {
    my $self = shift;
    my $pse = shift;

    my @work_orders = $pse->get_inherited_assigned_directed_setups_filter_on('setup work order');
    unless(scalar @work_orders) {
        $self->warning_message('No work order found for PSE ' . $pse->id);
    }

    return map($_->research_project_name, @work_orders);
}

sub request_builds {
    my $self = shift;

    my $new_models = $self->_newly_created_models;
    my $assigned_to = $self->_existing_models_assigned_to;
    my %models_to_build = (%$new_models, %$assigned_to);

    $self->status_message("Finding models which need to build...");   
    my $possibly_build = ($self->_existing_models_with_existing_assignments);
    for my $model (values %$possibly_build) {
        my @builds = $model->builds;

        my $last_build = $builds[-1];

        unless(defined $last_build) {
            #no builds--can't possibly have built with all data
            $self->status_message('Requesting build of model ' . $model->__display_name__ . ' because it has no builds.');
            $models_to_build{$model->id} = $model;
        } else {
        
            my %last_build_instdata = ( );

            my @last_build_inputs = $last_build->inputs;
            @last_build_inputs   = grep { $_->name eq 'instrument_data' } @last_build_inputs;
            %last_build_instdata = map  { $_->value_id => 1 }             @last_build_inputs;

            my @assignments = $model->instrument_data_assignments;
            my @missing_assignments_in_last_build = grep { not $last_build_instdata{$_->instrument_data_id} } @assignments;

            if (@missing_assignments_in_last_build) {
                    $self->status_message("Requesting build of model " . $model->__display_name__ . " because it does not have a final build with all assignments");
                    $models_to_build{$model->id} = $model;
            } else {
                $self->status_message("skipping rebuild of model " . $model->__display_name__ . " because all instrument data assignments are on the last build");
            }
        }
    }

    $self->status_message("Requesting builds...");
 
    for my $model (values %models_to_build) {
        #Will be picked up by next run of `genome model services build-queued-models`
        $model->build_requested(1);
    }

    return 1;
}

1;
