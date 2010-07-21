package Genome::Model::Command::Services::BuildQueuedInstrumentData;

use strict;
use warnings;

use Genome;
use Data::Dumper;


class Genome::Model::Command::Services::BuildQueuedInstrumentData {
    is  => 'Command',
    has => [
        test => {
            is => 'String',
            doc => "This parameter, if set true, will only process pses with negative id's, allowing your test to complete in a reasonable time frame.",
            is_optional => 1,
            default     => 0,
        }
    ],
};

sub help_brief {
'Find all QueueInstrumentDataForGenomeModeling PSEs, create appropriate models, assign instrument data, and finally trigger Build on the model';
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
    $DB::single = 1;
    my $self = shift;
    
    my $ps =
        GSC::ProcessStep->get(
            process_to => 'queue instrument data for genome modeling' );

    my @pses = sort { $a->id <=> $b->id } GSC::PSE->get(
        ps_id      => $ps->ps_id,
        pse_status => 'inprogress',
    );

    # Don't bite off more than we can process in a couple hours
    @pses = splice(@pses, 0, 100);

    my @cached_pse_params = GSC::PSEParam->get(pse_id => [ map { $_->pse_id } @pses ]);
    my %skip = map { ( ($_->param_value =~ /genotyper/) ? ($_->pse_id => 1) : () ) } @cached_pse_params;
    #my @pses = GSC::PSE->get(id => [keys %skip]);
    #for my $pse(@pses) { $_->pse_status("wait") };
    #(App::DB->sync_database and App::DB->commit) or die;
    #exit;
    $self->status_message("Skipping " . scalar(%skip) . " PSEs with genotyper data");

    if (1) {
        my @iids = 
            map { $_->param_value } 
            grep { $_->param_name eq 'instrument_data_id' } 
            grep { not $skip{$_->pse_id} }
            @cached_pse_params;

        $self->status_message("Pre-loading " . scalar(@iids) . " instrument data");
        my @i = Genome::InstrumentData->get(\@iids);
        my @sample_ids = map { $_->sample_id } @i;

        $self->status_message("Pre-loading " . scalar(@sample_ids) . " samples");
        my @samples = Genome::Sample->get(\@sample_ids);

        $self->status_message("Pre-loading models for " . scalar(@sample_ids) . " samples");
        my @models = Genome::Model->get(subject_id => \@sample_ids);
        $self->status_message("  got " . scalar(@models) . " models");

        my %taxon_ids = map { $_->taxon_id => 1 } @samples;
        my @taxon_ids = sort keys %taxon_ids;
        $self->status_message("Pre-loading models for " . scalar(@taxon_ids) . " taxons");
        push @models, Genome::Model->get(subject_id => \@taxon_ids);
        $self->status_message("  got " . scalar(@models) . " models");        

        $self->status_message("Pre-loading instrument data assignments for " . scalar(@models) . " models");
        my @a = Genome::Model::InstrumentDataAssignment->get(model_id => [ map { $_->id } @models]);
    }


    my %new_models                 = ( );    
    my %models_with_new_instdata   = ( );
    my %models_with_found_instdata = ( );
    my @completable_pses;    

    PSE: 
    foreach my $pse (@pses) {
        
        my $pse_id = $pse->id();
        next if $skip{$pse_id};

        if ( $self->test ) {
            next if $pse_id > 0;
        }

        my ($instrument_data_type) = $pse->added_param('instrument_data_type');
        my ($instrument_data_id)   = $pse->added_param('instrument_data_id');
        my ($subject_class_name)   = $pse->added_param('subject_class_name');
        my ($subject_id)           = $pse->added_param('subject_id');

        my @processing_profile_ids =
            $pse->added_param('processing_profile_id');

        
        unless ( 
                ( $instrument_data_type =~ /sanger/i )
                || 
                ( $instrument_data_type =~ /solexa/i )
                || 
                ( $instrument_data_type =~ /454/ ) 
            ) {
            
            $self->error_message(
                'encountered unkown instrument data type'
                    . " '$instrument_data_type'");
                next PSE;
        }
        
        if ( $instrument_data_type =~ /sanger/i ) {
            
            my $pse = GSC::PSE::AnalyzeTraces->get($instrument_data_id);

            unless ( defined($pse) ) {
                $self->error_message(
                    'failed to fetch pse for sanger instrument data with'
                     . " id '$instrument_data_id'" 
                     . " and pse_id '$pse_id'"

                );
                next PSE;
            }

            my $run_name = $pse->run_name();

            unless ( defined($run_name) ) {
                $self->error_message(
                    'failed to get a run_name for sanger instrument data with'
                        . " id '$instrument_data_id'" 
                        . " and pse_id '$pse_id'" 
 

                );
                next PSE;
            }

            $instrument_data_id = $run_name;
            
        }

        my $genome_instrument_data =
            Genome::InstrumentData->get( id => $instrument_data_id );

        unless ( defined($genome_instrument_data) ) {            
            $self->error_message(
                "Failed to get a Genome::InstrumentData ($instrument_data_type) via"
                . " id '$instrument_data_id'.  PSE_ID is '$pse_id'");
            next PSE;
        }
        
        my @process_errors;

        if ($subject_class_name and $subject_id and @processing_profile_ids) {
            my $subject      = $subject_class_name->get($subject_id);

            unless (defined $subject) {
                $self->error_message(
                    'failed to get a subject via'
                    . ' subject_class_name'
                    . " '$subject_class_name'"
                    . ' with subject_id'
                    . " '$subject_id'"
                );
                next PSE;
	        }

	        my $subject_name = $subject->name();
	            
            PP: 
            foreach my $processing_profile_id (@processing_profile_ids) {
                
                my $pp =
                    Genome::ProcessingProfile->get(
                        id => $processing_profile_id );
                
                unless ($pp) {
                    $self->error_message(
                        'Failed to get processing profile'
                        . " '$processing_profile_id' for inprogress pse "
                        . $pse->pse_id );
                    push @process_errors, $self->error_message;
                    next PP;
                }

                my $processing_profile_name = $pp->name();
                
                my @models = Genome::Model->get(
                    subject_id            => $subject_id,
                    subject_class_name    => $subject_class_name, 
                    processing_profile_id => $pp->id,
                    auto_assign_inst_data => 1,
                );
                  
                # we don't want to (automagically) assign capture and non-capture data to the same model.
                if ( @models and $genome_instrument_data->can('target_region_set_name') ) {
                    my $id_capture_target =
                        $genome_instrument_data->target_region_set_name();                 
                    
                    if ($id_capture_target) {
                        # keep only models with the specified capture target
                        my @inputs =
                            Genome::Model::Input->get(
                                model_id => [ map { $_->id } @models ], 
                                name => 'target_region_set_name',
                                value_id => $id_capture_target,
                            );
                        @models = map { $_->model } @inputs;    
                    }
                    else {
                        # keep only models with NO capture target
                        my %capture_model_ids = map { $_->model_id => 1 } Genome::Model::Input->get(
                            model_id => [ map { $_->id } @models ], 
                            name => 'target_region_set_name',
                        );
                        @models = grep { not $capture_model_ids{$_->id} } @models;
                    }
                }

                if (@models) {
                    MODEL_IDA: 
                    foreach my $model (@models) {
                        
                        my @existing_instrument_data =
                            Genome::Model::InstrumentDataAssignment->get(
                                instrument_data_id => $instrument_data_id,
                                model_id           => $model->id,
                            );
                        
                        if (@existing_instrument_data) {
                            warn "instrument data '$instrument_data_id'"
                                 . ' already assigned to model '
                                 . "'"
                                 . $model->id()
                                 . "'";
                            $models_with_found_instdata{$model->id} = $model;
                            next MODEL_IDA;
                        }
                       
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
                            push @process_errors, $self->error_message;
                            next PP;
                        }

                        $models_with_new_instdata{$model->id} = $model;                        
                    }
                    
                    # skip on to the next PSE
                    next PP;
                }

                # no model for this PP, make one and start

                my $model_name = $subject_name . '.' . $pp->name;
                
                my $capture_target;

                # Label Solexa/454 capture stuff as such
                if ( $genome_instrument_data->can('target_region_set_name') ) {
                    
                    $capture_target =
                      $genome_instrument_data->target_region_set_name();
                    
                    if ( defined($capture_target) ) {
                        $model_name =
                            join( '.', $model_name, 'capture', $capture_target );
                    }
                    
                }

                # There may be a model with auto assign off already using the
                # default model name just determined above.  Thus this lame
                # attempt to create a unique name;
                my $name_counter = 0;
                
                my $existing_model = Genome::Model->get( name => $model_name );

                my $new_model_name;

                while ( defined($existing_model) ) {

                    $name_counter++;
                    
                    $new_model_name = $model_name . '_auto' . $name_counter;
                    $existing_model =
                        Genome::Model->get( name => $new_model_name );
                }
                
                if ( defined($new_model_name) ) {
                    $model_name = $new_model_name;
                }

                my $model = Genome::Model->create(
                    name                  => $model_name,
                    subject_id            => $subject_id,
                    subject_class_name    => $subject_class_name,
                    processing_profile_id => $pp->id(),
                    auto_assign_inst_data => 1,
                );


                unless ( defined($model) ) {
                    $self->error_message(
                        "Failed to create model '$model_name'");
                    push @process_errors, $self->error_message;
                    next PP;
                }

                if ( defined($capture_target) ) {                
                    my $target_input = $model->add_input(
                        name             => "target_region_set_name",
                        value_class_name => "UR::Value",
                        value_id         => $capture_target
                    );

                    unless ( defined($target_input) ) {
                        $self->error_message(
                                'Failed to set capture target input for model '
                              . $model->id
                              . ' and instrument data '
                              . $instrument_data_id );
                        push @process_errors, $self->error_message;
                        $model->delete();
                        next PP;
                    }
                    
                    # By default the "region of interest" for analysis is the same
                    # as the capture target in sequencing
                    # 
                    # Eventually the roi list / validation SNP list will be
                    # looked up / validated here
                    my $roi_input = $model->add_input(
                        name             => "region_of_interest_set_name",
                        value_class_name => "UR::Value", value_id => $capture_target
                      );
                    
                    unless (defined($roi_input)) {
                        $self->error_message('Failed to set region of instrument input for model '
                                             . $model->id
                                             . ' and instrument data '
                                             . $instrument_data_id);
                        push @process_errors, $self->error_message;
                        $model->delete();
                        next PP;
                    }
                }
                
                my $assign_all =
                    Genome::Model::Command::InstrumentData::Assign->create(
                        model_id => $model->id,
                        all      => 1,
                    );
                
                unless ( $assign_all->execute ) {
                    $self->error_message(
                        'Failed to execute instrument-data assign --all for model '
                        . $model->id );
                    push @process_errors, $self->error_message;
                    $model->delete();
                    next PP;
                }

                #TODO: should we ensure that assign-all get the instdata we wanted???

                my @existing_instrument_data =
                    Genome::Model::InstrumentDataAssignment->get(
                        instrument_data_id => $instrument_data_id,
                        model_id           => $model->id,
                    );
                
                unless (@existing_instrument_data) {
                    $self->error_message(
                        "instrument data '$instrument_data_id' already assigned to model ????? '" . $model->id() . "'"
                    );
                    push @process_errors, $self->error_message;
                    $model->delete();
                    next PP;
                }

                $new_models{$model->id} = $model;

            } # looping through processing profiles for this instdata, finding or creating the default model

        } # done with PSEs which specify a $subject_class_name, $subject_id, and @processing_profile_ids
        #elsif ($subject_class_name or $subject_id or @processing_profile_ids) {
        #    $self->error_message(
        #        "PSE " . $pse->id . " specifies incomplete model find/create fields: "
        #        . " subject_class_name $subject_class_name subject_id $subject_id"
        #        . " processing_profile_ids @processing_profile_ids"
        #    );
        #    next PSE;
        #}

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
                    @some_models = grep { not $new_models{$_->id} } @some_models;
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
            

            # we don't want to (automagically) assign capture and non-capture data to the same model.
            my @models = @found_models;
            if ( @models and $genome_instrument_data->can('target_region_set_name') ) {
                my $id_capture_target =
                    $genome_instrument_data->target_region_set_name();                 
                
                if ($id_capture_target) {
                    # keep only models with the specified capture target
                    my @inputs =
                        Genome::Model::Input->get(
                            model_id => [ map { $_->id } @models ], 
                            name => 'target_region_set_name',
                            value_id => $id_capture_target,
                        );
                    @models = map { $_->model } @inputs;    
                }
                else {
                    # keep only models with NO capture target
                    my %capture_model_ids = map { $_->model_id => 1 } Genome::Model::Input->get(
                        model_id => [ map { $_->id } @models ], 
                        name => 'target_region_set_name',
                    );
                    @models = grep { not $capture_model_ids{$_->id} } @models;
                }
            }


            FOUND_MODEL: 
            foreach my $model (@found_models) {
                
                my @existing_assignments =
                    Genome::Model::InstrumentDataAssignment->get(
                        instrument_data_id => $instrument_data_id,
                        model_id           => $model->id,
                    );
                
                # Previous processing could have had problems, in which case
                # the instrument data might already be assigned.  This is not
                # something worth complaining about.
                if (@existing_assignments) {
                    $models_with_found_instdata{$model->id} = $model;                    
                    next FOUND_MODEL;
                }
                
                my $assign =
                    Genome::Model::Command::InstrumentData::Assign->create(
                        instrument_data_id => $instrument_data_id,
                        model_id           => $model->id,
                    );
                
                unless ( $assign->execute ) {
                    $self->error_message(
                        'Failed to execute instrument-data assign for'
                        . ' model '
                        . $model->id
                        . ' and instrument data '
                        . $instrument_data_id );
                        
                    push @process_errors, $self->error_message;
                    
                    next FOUND_MODEL;

                }
                
                $models_with_new_instdata{$model->id} = $model;               
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
        
    # commit all model creations and instrument data updates before building...
    $self->status_message("Saving model/assignment changes...");   
    UR::Context->commit();
    
    my %definitely_build = (%new_models, %models_with_new_instdata);

    $self->status_message("Finding models which need to build...");   
    my %possibly_build = (%models_with_found_instdata); # TODO don't include the above
    for my $model (values %possibly_build) {
        my @builds = $model->builds;

        my %last_build_instdata = ( );

        my $last_build = $builds[-1];

        if (defined($last_build)) {
            my @last_build_inputs = $last_build->inputs;
            @last_build_inputs   = grep { $_->name eq 'instrument_data' } @last_build_inputs;
            %last_build_instdata = map  { $_->value_id => 1 }             @last_build_inputs;
        }

        my @assignments = $model->instrument_data_assignments;
        my @missing_assignments_in_last_build = grep { not $last_build_instdata{$_->instrument_data_id} } @assignments;

        if (@missing_assignments_in_last_build) {
                $self->status_message("rebuilding model " . $model->__display_name__ . " because it does not have a final build with all assignments");
            $definitely_build{$model->id} = $model;
        }		
        else {
                $self->status_message("skipping rebuild of model " . $model->__display_name__ . " because all instrument data assignments are on the last build");
        }        
    }

    $self->status_message("Starting builds...");   
    for my $model_id (sort keys %definitely_build) {
        my $model = Genome::Model->get($model_id); 
        eval {
            Genome::Model::Build::Command::Start->execute(
                model_identifier => $model_id,
                force            => 1,
            ) or die 'Failed to start a build for model ' . $model_id;
        };
    
        if ($@) {
            warn $@;
            UR::Context->rollback();
            next MODEL;
        }
        
        UR::Context->commit();
    }
    
    $self->status_message("Completing PSEs...");
    for my $pse (@completable_pses) {
        $pse->pse_status("completed");  
    }

    $self->status_message("Saving completed PSEs.");
    UR::Context->commit();

    $self->status_message("Saving completed PSEs.");
    return 1;    
}

1;
