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
        pse_id => {
            is          => 'Number',
            is_optional => 1,
            doc         => 'Ignore other parameters and only process this PSE.',
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

        $lock = Genome::Sys->lock_resource(resource_lock=>$lock_resource, max_try=>1);
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

                my @reference_sequence_builds = ( undef ); # this allows to use a loop to assign
                # These pps require imported reference seq build
                if( $processing_profile->isa('Genome::ProcessingProfile::ReferenceAlignment')
                        or $processing_profile->isa('Genome::ProcessingProfile::GenotypeMicroarray') ) {
                    my @reference_sequence_build_ids = $pse->reference_sequence_build_param_for_processing_profile($processing_profile);
                    if ( not @reference_sequence_build_ids ) {
                        $self->error_message('No imported reference sequence build id found on pse ('.$pse->id.') to create '.$processing_profile->type_name.' model');
                        push @process_errors, $self->error_message;
                        next PP;
                    }

                    @reference_sequence_builds = Genome::Model::Build::ImportedReferenceSequence->get(\@reference_sequence_build_ids);
                    if ( not @reference_sequence_builds or @reference_sequence_builds ne @reference_sequence_build_ids ) {
                        $self->error_message("Failed to get imported reference sequence builds for ids: @reference_sequence_build_ids");
                        push @process_errors, $self->error_message;
                        next PP;
                    }

                }

                if ( $instrument_data_type ne 'genotyper results' ) {
                    my $per_lane_qc = $self->create_default_per_lane_qc_model($genome_instrument_data, $subject, $reference_sequence_builds[0], $pse); # should only be one imp ref seq build for this pp 
                    unless($per_lane_qc) {
                        push @process_errors, $self->error_message;
                    }
                }

                my @models = Genome::Model->get(
                    subject_id            => $subject_id,
                    subject_class_name    => $subject_class_name,
                    processing_profile_id => $processing_profile->id,
                    auto_assign_inst_data => 1,
                );

                for my $reference_sequence_build ( @reference_sequence_builds ) {
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
                        #find or create somatic models if applicable
                        $self->find_or_create_somatic_variation_models(@assigned);

                    } else {
                        # no model found for this PP, make one (or more) and assign all applicable data
                        my @new_models = $self->create_default_models_and_assign_all_applicable_instrument_data($genome_instrument_data, $subject, $processing_profile, $reference_sequence_build, $pse);
                        unless(@new_models) {
                            push @process_errors, $self->error_message;
                            next PP;
                        }
                        #find or create somatic models if applicable
                        $self->find_or_create_somatic_variation_models(@new_models);
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
        Genome::Sys->unlock_resource(resource_lock=>$lock);
    }

    return 1;    
}

sub find_or_create_somatic_variation_models{
    my ($self, @models) = @_;
    #only want sample-based models
    @models = grep {$_->subject_type eq "sample_name"} @models;
    #only want TCGA models
    @models = grep {$self->is_tcga($_->subject)} @models;
    for my $model (@models){
        my $sample = $model->subject;
        #find or create mate ref-align model
        if ($sample->name =~ m/([^-]+-[^-]+-[^-]+-)([01]{2}A)(.*)/){
            my ($prefix, $designator, $suffix) = ($1, $2, $3);
            my %designator_pairing = ( 
                '10A' => '01A', 
                '01A' => '10A',
            );
            my $mate_designator = $designator_pairing{$designator};
            $self->error_message("Not processing somatic variation model with sample name: " . $sample->name . " and designator: $designator") and next unless $mate_designator; 
            my $mate_name = join("", $prefix, $mate_designator, $suffix);  
            
            my $subject_for_mate = Genome::Sample->get(name => $mate_name);
            $self->error_message("No sample found for mate_name $mate_name (paired to: " . $model->name . ")") and next unless $subject_for_mate; 

            my %mate_params = (
                subject_id => $subject_for_mate->id, 
                reference_sequence_build => $model->reference_sequence_build, 
                processing_profile => $model->processing_profile, 
                auto_assign_inst_data => '1',
            );
            $mate_params{annotation_reference_build_id} = $model->annotation_reference_build_id if $model->can('annotation_reference_build_id') and $model->annotation_reference_build_id;

            my $mate = Genome::Model::ReferenceAlignment->get( %mate_params );
            unless ($mate){
                my $copy = Genome::Model::Command::Copy->execute(
                    from => $model,
                    to => 'AQID-PLACE_HOLDER',
                    skip_instrument_data_assignments => 1,
                );
                $self->error_message('Failed to create mate for model name: ' . $model->name) and next unless $copy;

                $mate = $copy->_copied_model;
                $self->error_message("Failed to find copied mate with subject name: $mate_name") and next unless $mate;
                
                $mate->subject_id($subject_for_mate->id);

                my $capture_target = eval{$model->target_region_set_name}; 
                my $mate_model_name = $mate->default_model_name(capture_target => $capture_target);
                $self->error_message("Could not name mate model for with subject name: $mate_name") and next unless $mate_model_name;
                $mate->name($mate_model_name);
                
                my $new_models = $self->_newly_created_models;
                $new_models->{$mate->id} = $mate;
            }

            my %somatic_params = (
                auto_assign_inst_data => 1,
                );
            $somatic_params{annotation_build} = Genome::Model::ImportedAnnotation->annotation_build_for_reference($model->reference_sequence_build);
            $self->error_message('Failed to get annotation_build for somatic variation model with model: ' . $model->name) and next unless $somatic_params{annotation_build};
            $somatic_params{previously_discovered_variations_build} = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($model->reference_sequence_build);
            $self->error_message('Failed to get previously_discovered_variations_build for somatic variation model with model: ' . $model->name) and next unless $somatic_params{previously_discovered_variations_build};

            my $capture_somatic_processing_profile_id = '2589271'; #april 11 somatic-variation exome
            my $somatic_processing_profile_id = '2589272'; #april 11 somatic-variation wgs
            my $capture_target = eval{$model->target_region_set_name}; 
            if($capture_target){
                $somatic_params{processing_profile_id} = $capture_somatic_processing_profile_id;
            }
            else{
                $somatic_params{processing_profile_id} = $somatic_processing_profile_id;
            }
            if ($designator eq '10A'){ #$model is normal
                $somatic_params{normal_model} = $model;
                $somatic_params{tumor_model} = $mate;
            }elsif ($designator eq '01A'){ #$model is tumor
                $somatic_params{tumor_model} = $model;
                $somatic_params{normal_model} = $mate;
            }else{
                die $self->error_message("Serious error in sample designators for automated create of somatic-variation models for ".$model->subject_name);
            }
            
            my $somatic_variation = Genome::Model::SomaticVariation->get(%somatic_params);

            unless ($somatic_variation){
                $somatic_params{model_name} = 'AQID-PLACE_HOLDER';
                my $create = Genome::Model::Command::Define::SomaticVariation->execute( %somatic_params );
                $self->error_message('Failed to create somatic variation model with component model: ' . $model->name) and next unless $create;
                
                delete $somatic_params{model_name};
                $somatic_params{name} = 'AQID-PLACE_HOLDER';
                $somatic_variation = Genome::Model::SomaticVariation->get(%somatic_params);
                $self->error_message("Failed to find new somatic variation model with component model: " . $model->name) and next unless $somatic_variation;

                my $somatic_variation_model_name = $somatic_variation->default_model_name(capture_target => $capture_target);
                $self->error_message("Failed to name new somatic variation model with component model: " . $model->name) and next unless $somatic_variation_model_name;
                $somatic_variation->name($somatic_variation_model_name);

                my $new_models = $self->_newly_created_models;
                $new_models->{$somatic_variation->id} = $somatic_variation;
            }
        }
        else{
            $self->error_message("Not processing somatic variation model with sample name: " . $model->subject_name);
        }
             
        
    }
}

sub is_tcga {
    my $self = shift;
    my $sample = shift;

    return 1 if $sample->nomenclature =~ m/^TCGA/i;
    return grep{$_->nomenclature =~ m/^TCGA/i} $sample->attributes;
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

    my @pses;
    if($self->pse_id) { #process a specific PSE
        @pses = GSC::PSE->get(
            ps_id => $ps->ps_id,
            pse_status => 'inprogress',
            id => $self->pse_id,
        );
    } else {
        @pses = GSC::PSE->get(
            ps_id      => $ps->ps_id,
            pse_status => 'inprogress',
        );

        if($self->test) {
            @pses = grep($_->pse_id < 0, @pses);
        }
    }
    return unless @pses;

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

    my ($instrument_data_id)   = $pse->added_param('instrument_data_id');
    my ($instrument_data_type) = $pse->added_param('instrument_data_type');
    $instrument_data_type = lc $instrument_data_type;

    my @expected_types = ('sanger', 'solexa', '454', 'genotyper results');
    unless ( grep { $instrument_data_type eq $_ } @expected_types) {
        $self->error_message('encountered unkown instrument data type: ' . $instrument_data_type);
        return;
    }

    if ( $instrument_data_type eq 'sanger' ) {
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

    my $genome_instrument_data = Genome::InstrumentData->get(id => $instrument_data_id);

    unless ( $genome_instrument_data ) {            
        $self->error_message(
            "Failed to get a Genome::InstrumentData ($instrument_data_type) via"
            . " id '$instrument_data_id'.  PSE_ID is '$pse_id'");
        return;
    }

    if ( $instrument_data_type eq 'solexa' ) {
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

sub create_default_per_lane_qc_model {
    my $self = shift;
    my $genome_instrument_data = shift;
    my $subject = shift;
    my $reference_sequence_build = shift;
    my $pse = shift;

    my ($processing_profile, $model_name);
    my $dbsnp_build;
    my $ncbi_human_build36 = Genome::Model::Build->get(101947881);
    if ($reference_sequence_build && $reference_sequence_build->is_compatible_with($ncbi_human_build36)) {
        my $subset_name = $genome_instrument_data->subset_name || 'unknown-subset';
        my $run_name_method = $genome_instrument_data->can('short_name') ? 'short_name' : 'run_name';
        my $run_name = $genome_instrument_data->$run_name_method || 'unknown-run';
        $model_name = $run_name . '.' . $subset_name . '.prod-qc';

        $processing_profile = Genome::ProcessingProfile->get(2581081);
        $dbsnp_build = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($reference_sequence_build); 
    } else {
        $self->status_message('Per lane QC only configured for human reference alignments');
        return 1;
    }

    my %model_params = (
        name                    => $model_name,
        subject_id              => $subject->id,
        subject_class_name      => $subject->class,
        processing_profile_id   => $processing_profile->id,
        reference_sequence_build => $reference_sequence_build,
        auto_assign_inst_data   => 0,
    );
    $model_params{dbsnp_build} = $dbsnp_build if $dbsnp_build;

    my @models = Genome::Model->get(name => $model_name);
    if (@models) {
        $self->status_message("Model already exists, not creating new per lane QC model.");
        return 1;
    }

    my $model = Genome::Model->create(%model_params);
    unless ( defined($model) ) {
        $self->error_message("Failed to create model '$model_name'");
        return;
    }

    my $assign_instrument_data = Genome::Model::Command::InstrumentData::Assign->create(
        model_id => $model->id,
        instrument_data_id => $genome_instrument_data->id,
    );

    unless ( $assign_instrument_data->execute ) {
        $self->error_message('Failed to execute instrument-data assign for model ' . $model->__display_name__ . '.');
        $model->delete;
        return;
    }

    my $new_models = $self->_newly_created_models;
    $new_models->{$model->id} = $model;

    #singular value, don't want to override the "real" model
    #$pse->add_param('genome_model_id', $model->id);

    return 1;
}

sub create_default_models_and_assign_all_applicable_instrument_data {
    my $self = shift;
    my $genome_instrument_data = shift;
    my $subject = shift;
    my $processing_profile = shift;
    my $reference_sequence_build = shift;
    my $pse = shift;

    my @new_models;

    my %model_params = (
        name                    => 'AQID-PLACE_HOLDER',
        user_name               => 'apipe-builder',
        subject_id              => $subject->id,
        subject_class_name      => $subject->class,
        processing_profile_id   => $processing_profile->id,
        auto_assign_inst_data   => 1,
    );

    if ($processing_profile->isa('Genome::ProcessingProfile::GenotypeMicroarray') ) {
        $model_params{auto_assign_inst_data} = 0;
    }

    if ( $reference_sequence_build ) {
        $model_params{reference_sequence_build} = $reference_sequence_build;
        my $dbsnp_build = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($reference_sequence_build);
        $model_params{dbsnp_build} = $dbsnp_build if $dbsnp_build;
        if ( $processing_profile->isa('Genome::ProcessingProfile::ReferenceAlignment')){
            my $annotation_build = Genome::Model::ImportedAnnotation->annotation_build_for_reference($reference_sequence_build);
            $model_params{annotation_reference_build} = $annotation_build if $annotation_build;
        }
    }

    my $regular_model = Genome::Model->create(%model_params);
    unless ( $regular_model ) {
        $self->error_message('Failed to create model with params: '.Dumper(\%model_params));
        return;
    }
    push @new_models, $regular_model;

    my $capture_target = eval{ $genome_instrument_data->target_region_set_name; };

    my $name = $regular_model->default_model_name(capture_target => $capture_target);
    if ( not $name ) {
        $self->error_message('Failed to get model name for params: '.Dumper(\%model_params));
        for my $model ( @new_models ) { $model->delete; }
        return;
    }
    $regular_model->name($name);

    if ( $capture_target ) {
        my $roi_list;
        #FIXME This is a lame hack for these capture sets
        my %build36_to_37_rois = (
            'agilent sureselect exome version 2 broad refseq cds only' => 'agilent_sureselect_exome_version_2_broad_refseq_cds_only_hs37',
            'agilent sureselect exome version 2 broad' => 'agilent sureselect exome version 2 broad hg19 liftover',
            'hg18 nimblegen exome version 2' => 'hg19 nimblegen exome version 2',
            'NCBI-human.combined-annotation-54_36p_v2_CDSome_w_RNA' => 'NCBI-human.combined-annotation-54_36p_v2_CDSome_w_RNA_build36-build37_liftOver',
        );

        my $root_build37_ref_seq = Genome::Model::Build::ImportedReferenceSequence->get(name =>'g1k-human-build37') || die;

        if($reference_sequence_build and $reference_sequence_build->is_compatible_with($root_build37_ref_seq) 
                and exists $build36_to_37_rois{$capture_target}) {
            $roi_list = $build36_to_37_rois{$capture_target};
        } else {
            $roi_list = $capture_target;
        }

        unless($self->assign_capture_inputs($regular_model, $capture_target, $roi_list)) {
            for my $model ( @new_models ) { $model->delete; }
            return;
        }

        #Also want to make a second model against a standard region of interest
        my $wuspace_model = Genome::Model->create(%model_params);
        unless ( $wuspace_model ) {
            $self->error_message('Failed to create wu-space model: '.Dumper(\%model_params));
            for my $model (@new_models) { $model->delete; }
            return;
        }
        push @new_models, $wuspace_model;

        my $wuspace_name = $wuspace_model->default_model_name(capture_target => $capture_target, roi => 'wu-space');
        if ( not $wuspace_name ) {
            $self->error_message('Failed to get wu-space model name for params: '.Dumper(\%model_params));
            for my $model (@new_models) { $model->delete; }
            return;
        }
        $wuspace_model->name($wuspace_name);

        my $wuspace_roi_list;
        if($reference_sequence_build and $reference_sequence_build->is_compatible_with($root_build37_ref_seq)) {
            $wuspace_roi_list = 'NCBI-human.combined-annotation-58_37c_cds_exon_and_rna_merged_by_gene';
        } else {
            $wuspace_roi_list = 'NCBI-human.combined-annotation-54_36p_v2_CDSome_w_RNA';
        }

        unless($self->assign_capture_inputs($wuspace_model, $capture_target, $wuspace_roi_list)) {
            for my $model (@new_models) { $model->delete; }
            return;
        }
    }

    for my $m (@new_models) {
        my $assign =
        Genome::Model::Command::InstrumentData::Assign->create(
            model_id => $m->id,
            instrument_data_id => $genome_instrument_data->id,
            include_imported => 1,
            force => 1,
        );

        unless ( $assign->execute ) {
            $self->error_message(
                'Failed to execute instrument-data assign for model '
                . $m->id . ' instrument data '.$genome_instrument_data->id );

            $m->delete;
            next;
        }

        my $assign_all =
        Genome::Model::Command::InstrumentData::Assign->create(
            model_id => $m->id,
            all => 1,
        );

        unless ( $assign_all->execute ) {
            $self->error_message(
                'Failed to execute instrument-data assign --all for model '
                . $m->id );
            $m->delete;
            next;
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
            $m->delete;
            next;
        }

        my @group_names = $self->_resolve_project_and_work_order_names($pse);
        push @group_names, $self->_resolve_pooled_sample_name_for_instrument_data($genome_instrument_data);
        $self->add_model_to_default_modelgroups($m, @group_names);

        my $new_models = $self->_newly_created_models;
        $new_models->{$m->id} = $m;

        $pse->add_param('genome_model_id', $m->id);
    }

    return @new_models;
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
        $self->error_message('Unhandled subject for model--not adding to common name model-groups');
    }

    my @group_names = @project_names;

    unless($source) {
        $self->error_message('Failed to get source for subject.');
    } else {
        my $common_name = $source->common_name;
        if($common_name) {
            my ($source_grouping) = $common_name =~ /^([a-z]+)\d+$/i;
            push @group_names, $source_grouping if $source_grouping;
        }
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

sub _resolve_project_and_work_order_names {
    my $self = shift;
    my $pse = shift;

    my @work_orders = $pse->get_inherited_assigned_directed_setups_filter_on('setup work order');
    unless(scalar @work_orders) {
        $self->warning_message('No work order found for PSE ' . $pse->id);
    }

    return map(($_->setup_name, $_->research_project_name), @work_orders);
}

sub _resolve_pooled_sample_name_for_instrument_data {
    my $self = shift;
    my $instrument_data = shift;

    return unless $instrument_data->can('index_sequence');
    my $index = $instrument_data->index_sequence;
    if($index) {
        my $instrument_data_class = $instrument_data->class;
        my $pooled_subset_name = $instrument_data->subset_name;
        $pooled_subset_name =~ s/${index}$/unknown/;

        my $pooled_instrument_data = $instrument_data_class->get(
            run_name => $instrument_data->run_name,
            subset_name => $pooled_subset_name,
            index_sequence => 'unknown',
        );
        return unless $pooled_instrument_data;

        my $sample = $pooled_instrument_data->sample;
        return unless $sample;

        return $sample->name;
    }

    return;
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
