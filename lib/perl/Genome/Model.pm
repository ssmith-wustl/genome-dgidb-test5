package Genome::Model;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;
use File::Path;
use YAML;

class Genome::Model {
    is_abstract     => 1,
    subclassify_by  => 'subclass_name',

    id_by => [
        genome_model_id             => { is => 'Number', len => 11 },
    ],

    has => [
        name                        => { is => 'Text', len => 255 },
        Xsubclass_name               => { is => 'Text', len => 255, is_mutable => 0, 
                                        column_name => 'SUBCLASS_NAME',
                                        calculate_from => ['processing_profile_id'],
                                        calculate => sub {
                                            my $processing_profile_id = $_[0];
                                            # subclass via our processing profile's type_name
                                            return unless $processing_profile_id;
                                            my $pp = Genome::ProcessingProfile->get($processing_profile_id);
                                            Carp::croak("Can't find Processing Profile with ID $processing_profile_id jwhile resolving subclass for Model") unless $pp;
                                            return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($pp->type_name);
                                        } },

        subclass_name           => { is => 'VARCHAR2', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                                     calculate_from => ['processing_profile_id'],
                                     # We subclass via our processing profile's type_name
                                     calculate => sub {
                                                      my($pp_id) = @_;
                                                      return unless $pp_id;
                                                      my $pp = Genome::ProcessingProfile->get($pp_id);
                                                      Carp::croak("Can't find Processing Profile with ID $pp_id while resolving subclass for Model") unless $pp;
                                                      return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($pp->type_name);
                                                  },
                                    },

        subject                     => { # is => 'Genome::Measurable', 
                                        calculate_from => [ 'subject_id', 'subject_class_name' ],
                                        calculate => q|return unless $subject_class_name; return $subject_class_name->get($subject_id); |},
        subject_class_name          => { is => 'Text', len => 500 },
        subject_id                  => { is => 'Number', len => 15 },
        is_default                  => { is => 'Boolean', is_optional => 1,
                                        doc => 'flag the model as the default system "answer" for its subject' },
        
        processing_profile          => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name     => { via => 'processing_profile', to => 'name' },

        type_name                   => { via => 'processing_profile' },
        user_name                   => { is => 'Text', len => 64, is_optional => 1 },
        creation_date               => { is => 'TIMESTAMP', len => 6, is_optional => 1 },
        
        inputs                      => { is => 'Genome::Model::Input', reverse_as => 'model', is_optional => 1, is_many => 1,
                                        doc => 'links to data currently assigned to the model for processing' },
    ],
    has_optional => [
        auto_assign_inst_data       => { is => 'Boolean', is_optional => 1 },
        auto_build_alignments       => { is => 'Boolean', is_optional => 1 }, # TODO: rename to auto_build
        build_requested             => { is => 'Boolean', is_optional => 1 },
        
        builds                      => { is => 'Genome::Model::Build', reverse_as => 'model', is_many => 1, is_optional => 1,
                                        doc => 'versions of a model over time, with varying quantities of evidence' },
        keep_n_most_recent_builds   => { via => 'attributes', to => 'value', is_mutable => 1, 
                                        where => [ property_name => 'keep_n_most_recent_builds', entity_class_name => 'Genome::Model' ] },
        _last_complete_build_id     => { is => 'Number', len => 10, 
                                        column_name => 'last_complete_build_id', 
                                        doc => 'The last complete build id' ,
                                        is_optional => 1 },
    ],
    has_optional_many => [
        # TODO: the new project will internally have generalized assignments of models and other things
        projects                    => { is => 'Genome::Site::WUGC::Project', via => 'project_assignments', to => 'project' },
        project_assignments         => { is => 'Genome::Model::ProjectAssignment', reverse_as => 'model' },
        project_names               => { is => 'Text', via => 'projects', to => 'name' },
        
        # TODO: the new projects will suck in all of the model groups as a special case of a named project containing only models
        model_groups                => { is => 'Genome::ModelGroup', via => 'model_bridges', to => 'model_group', is_many => 1 },
        model_bridges               => { is => 'Genome::ModelGroupBridge', reverse_as => 'model', is_many => 1 },

        group_ids                   => { via => 'model_groups', to => 'id', is_many => 1 },
        group_names                 => { via => 'model_groups', to => 'name', is_many => 1 },
        
        # TODO: replace the internals of these with a specific case of model inputs
        from_model_links            => { is => 'Genome::Model::Link', reverse_as => 'to_model',
                                        doc => 'bridge table entries where this is the "to" model (used to retrieve models this model is "from"' },

        from_models                 => { is => 'Genome::Model', via => 'from_model_links', to => 'from_model',
                                        doc => 'Genome models that contribute "to" this model' },

        to_model_links              => { is => 'Genome::Model::Link', reverse_as => 'from_model',
                                        doc => 'bridge entries where this is the "from" model(used to retrieve models models this model is "to")' },
        
        to_models                   => { is => 'Genome::Model', via => 'to_model_links', to => 'to_model',
                                        doc => 'Genome models this model contributes "to"' },
        
        # TODO: ensure all misc attributes actually go into the db table so we don't need this 
        attributes                  => { is => 'Genome::MiscAttribute', 
                                        reverse_as => '_model', 
                                        where => [ entity_class_name => 'Genome::Model' ] },
        
        # TODO: relocated
        # TODO: these go into a model subclass for models which apply directly to sequencer data
        sequencing_platform         => { via => 'processing_profile' },
        instrument_data_class_name  => { is => 'Text',
                                        calculate_from => 'sequencing_platform',
                                        calculate => q| 'Genome::InstrumentData::' . ucfirst($sequencing_platform) |,
                                        doc => 'the class of instrument data assignable to this model' },
        
        # refactor to use the inputs entirely
        instrument_data_assignments => { is => 'Genome::Model::InstrumentDataAssignment', reverse_as => 'model' },
            instrument_data             => {
                is => 'Genome::InstrumentData',
                via => 'inputs',
                to => 'value', 
                is_mutable => 1, 
                where => [ name => 'instrument_data' ],
                doc => 'Instrument data currently assigned to the model.' 
            },
        ],    
        has_optional_deprecated => [
        # this is all junk but things really use them right now 
        data_directory          => { is => 'Text', len => 1000, is_optional => 1 },
        ref_seqs                => { is => 'Genome::Model::RefSeq', reverse_as => 'model', is_many => 1, is_optional => 1 },
        events                  => { is => 'Genome::Model::Event', reverse_as => 'model', is_many => 1,
            doc => 'all events which have occurred for this model' },
        reports                 => { via => 'last_succeeded_build' },
        reports_directory       => { via => 'last_succeeded_build' },
        
        # these go on refalign models
        last_complete_build_flagstat     => { calculate => q| return $self->lcb_flagstat(); | },
        region_of_interest_set_value     => { is_many => 1, is_mutable => 1, is => 'UR::Value', via => 'inputs', to => 'value', where => [ name => 'region_of_interest_set_name'] },
        region_of_interest_set_name      => { via => 'region_of_interest_set_value', to => 'id', },
    ],
    has_many_optional_deprecated => [
        # these go only on somatic models
        variant_validations               => { is => 'Genome::Model::VariantValidation', reverse_as => 'model',
                                                doc => 'variantvalidation linked to this model... currently only for Somatic models but need this accessor for get_all_objects for successful deletion' },
        
        putative_variant_validations      => { is => 'Genome::Model::VariantValidation', reverse_as => 'model', where => [ validation_type => 'Official', validation_result => 'P' ],
                                                doc => 'putative (only) variantvalidation linked to this model... currently only for Somatic models but need this accessor for get_all_objects for successful deletion' },
    ],
    has_optional_calculated => [
        # TODO: make the subject a Genome::Measurable, and get these through delegation
        subject_name    => { is => 'Text', len => 255, 
                            calculate_from => 'subject',
                            calculate => q|
                                unless($subject) {
                                    #$self->error_message('Subject not found.');
                                    return;
                                }
                                if($subject->class eq 'GSC::Equipment::Solexa::Run') {
                                    return $subject->flow_cell_id;
                                } elsif($subject->class eq 'Genome::Sample') {
                                    return $subject->name or $subject->common_name;
                                } elsif($subject->class eq 'Genome::Individual') {
                                    return $subject->name or $subject->common_name;
                                } elsif($subject->isa('GSC::DNA')) {
                                    return $subject->dna_name;
                                } elsif($subject->can('name')) {
                                    return $subject->name;
                                } else {
                                    #$self->error_message('Unable to determine name for subject');
                                    return;
                                }
                            | },
        subject_type    => { is => 'Text', len => 255, 
                            valid_values => ["species_name","sample_group","flow_cell_id","genomic_dna","library_name","sample_name","dna_resource_item_name"], 
                            calculate_from => 'subject_class_name',
                            calculate => q|
                                if($subject_class_name->class and $subject_class_name->isa('GSC::DNA')) {
                                        $subject_class_name = 'GSC::DNA'; #Avoid needing to list entire DNA heirarchy
                                }
                                #This could potentially live someplace else like the previous giant hash
                                my %types = (
                                        'Genome::Sample' => 'sample_name',
                                        'GSC::DNA' => 'dna_resource_item_name',
                                        'GSC::DNAResourceItem' => 'dna_resource_item_name',
                                        'GSC::Equipment::Solexa::Run' => 'flow_cell_id',
                                        'Genome::ModelGroup' => 'sample_group',
                                        'Genome::PopulationGroup' => 'sample_group',
                                        'Genome::Individual' => 'sample_group',
                                        'Genome::Taxon' => 'species_name',
                                        'Genome::Library' => 'library_name',
                                        'Genome::Sample::Genomic' => 'genomic_dna',
                                );
                                return $types{$subject_class_name};
                            |, },
    ],
    has_deprecated_optional => [
        # we probably don't need to store this do we?
        _printable_property_names_ref   => { is => 'array_ref', is_transient => 1 },
        
        # duplicate of instrument_data, and equivalent of inst_data :(
        assigned_instrument_data        => { is => 'Genome::InstrumentData', via => 'instrument_data_assignments', to => 'instrument_data' },
        
        # TODO: add an is_in_latest_build flag to the input and make these a parameter
        built_instrument_data           => { is => 'Genome::Model::InstrumentDataAssignment',
                                                calculate => q|
                                                    return
                                                        map { $_->instrument_data }
                                                        grep { defined $_->first_build_id }
                                                        $self->instrument_data_assignments;

                                                | },
        
        
        unbuilt_instrument_data           => { is => 'Genome::Model::InstrumentDataAssignment',
                                                calculate => q|
                                                    return
                                                        map { $_->instrument_data }
                                                        grep { !defined $_->first_build_id }
                                                        $self->instrument_data_assignments;
                                                | },
    
        # TODO: add an is_in_latest_build flag to the input and make these a parameter
        # clean up tracking on last_complete_build and make these delegate, or throw them away
        last_complete_build_directory    => { calculate => q|$b = $self->last_complete_build; return unless $b; return $b->data_directory| },
        last_succeeded_build_directory   => { calculate => q|$b = $self->last_succeeded_build; return unless $b; return $b->data_directory| },

        # used in a few odd places 
        build_statuses                  => { via => 'builds', to => 'master_event_status', is_many => 1 },
        build_ids                       => { via => 'builds', to => 'id', is_many => 1 },
   
        # this should match the subject_name for models with samples as subjects
        # sadly, existing capture code uses this method
        sample_name                     => { is => 'Text', doc => 'deprecated column with explicit sample_name tracking' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'GENOME_MODEL',
    doc => 'a versioned data model describing one the sequence and features of a genome' 
};

sub __display_name__ {
    my $self = shift;
    return $self->name . ' (' . $self->id . ')';
}

sub __extend_namespace__ {
    # auto generate sub-classes for any valid processing profile
    my ($self,$ext) = @_;

    my $meta = $self->SUPER::__extend_namespace__($ext);
    return $meta if $meta;

    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    my $pp_subclass_meta = UR::Object::Type->get($pp_subclass_name);
    if ($pp_subclass_meta and $pp_subclass_name->isa('Genome::ProcessingProfile')) {
        my @pp_delegated_properties = map {
            $_ => { via => 'processing_profile' }
        } $pp_subclass_name->params_for_class;

        my $model_subclass_name = 'Genome::Model::' . $ext;
        my $model_subclass_meta = UR::Object::Type->define(
            class_name => $model_subclass_name,
            is => 'Genome::Model',
            has => \@pp_delegated_properties
        );
        die "Error defining $model_subclass_name for $pp_subclass_name!" unless $model_subclass_meta;
        return $model_subclass_meta;
    }
    return;
}

sub create {
    my $class = shift;

    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        # this class is abstract, and the super-class re-calls the constructor from the correct subclass
        return $class->SUPER::create(@_);
    }

    my $params;
    my $entered_subject_name; #So the user gets what they expect, use this when coming up with the default model name

    #Create gets called twice... Only set things up the first time
    #The second time we get the UR::BoolExpr handed to us.
    if(ref $_[0]) {
        $params = $class->define_boolexpr(@_);
    } 
    else {
        my %input_params = @_;

        if(exists $input_params{subject_name} or exists $input_params{subject_type}) {
            $entered_subject_name = delete $input_params{subject_name};
            my $entered_subject_type = delete $input_params{subject_type};

            if(exists $input_params{subject_id} and defined $input_params{subject_id}
                and exists $input_params{subject_class_name} and defined $input_params{subject_class_name}) {
                #They already gave us a subject; we'll test if it's good in _verify_subject below.
                #Just ignore the other parameters--
            } else {
                my $subject = $class->_resolve_subject($entered_subject_name, $entered_subject_type)
                    or return;

                $input_params{subject_id} = $subject->id;
                $input_params{subject_class_name} = $subject->class;
            }
        }

        $params = $class->define_boolexpr(%input_params);
    }

    # Processing profile - gotta validate here or SUPER::create will fail silently
    my $processing_profile_id = $params->value_for('processing_profile_id');
    $class->_validate_processing_profile_id($processing_profile_id)
        or Carp::confess();

    my $self = $class->SUPER::create($params)
        or return;

    # Make sure the subject we got is really an object
    unless ( $self->_verify_subject ) {
        $self->SUPER::delete;
        return;
    }

    #<model name>#
    # set default if none given
    if ( not defined $self->name ) {
        my $default_name = $self->default_model_name;
        if ( not defined $default_name ) {
            $self->error_message("No model name given and cannot get a deafult name from $class");
            $self->SUPER::delete;
            return;
        }
        $self->name($default_name);
    }
    # Check that this model doen't already exist.  If other models with the same name
    #  and type name exist, this method lists them, errors and deletes this model.
    #  Checking after subject verification to catch that error first.
    $self->_verify_no_other_models_with_same_name_and_type_name_exist
        or return;
    #</model name>

    unless ($self->user_name) {
        my $user = getpwuid($<);
        $self->user_name($user);
    }
    unless ($self->creation_date) {
        $self->creation_date(UR::Time->now);
    }

    # If data directory has not been supplied, figure it out
    unless ($self->data_directory) {
        $self->data_directory( $self->resolve_data_directory );
    }

    unless ( $self->_build_model_filesystem_paths() ) {
        $self->error_message('Filesystem path creation failed');
        $self->SUPER::delete;
        return;
    }

    my $processing_profile= $self->processing_profile;
    unless ($processing_profile->_initialize_model($self)) {
        $self->error_message("The processing profile failed to initialize the new model:"
            . $processing_profile->error_message);
        $self->delete;
        return;
    }

    return $self;
}

sub _validate_processing_profile_id {
    my ($class, $pp_id) = @_;
    unless ( $pp_id ) {
        $class->error_message("No processing profile id given");
        return;
    }
    unless ( $pp_id =~ m/^$RE{num}{int}$/) {
        $class->error_message("Processing profile id is not an integer");
        return;
    }
    unless ( Genome::ProcessingProfile->get(id => $pp_id) ) {
        $class->error_message("Can't get processing profile for id ($pp_id)");
        return;
    }
    return 1;
}

sub _verify_no_other_models_with_same_name_and_type_name_exist {
    # Checks that this model doen't already exist.  If other models with the same name
    #  and type name exist, this method lists them, errors and deletes this model.
    #  Should only be called from create.
    my $self = shift;

    my @models = Genome::Model->get(
        id => {
            operator => '!=',
            value => $self->id,
        },
        name => $self->name,
        type_name => $self->type_name
    );

    return 1 unless @models; # ok

    my $message = "\n";
    for my $model ( @models ) {
        $message .= sprintf(
            "Name: %s\nSubject Name: %s\nId: %s\nProcessing Profile Id: %s\nType Name: %s\n\n",
            $model->name,
            $model->subject_name,
            $model->id,
            $model->processing_profile_id,
            $model->type_name,

        );
    }
    $message .= sprintf(
        'Found the above %s with the same name and type name.  Please select a new name.',
        Lingua::EN::Inflect::PL('model', scalar(@models)),
    );
    $self->error_message($message);
    $self->delete;

    return;
}

sub default_model_name {
    my $self  = shift;
    return join(
        '.',
        Genome::Utility::Text::sanitize_string_for_filesystem($self->subject_name),
        $self->processing_profile_name
    );
}

#If a user defines a model with a name (and possibly type), we need to find/make sure there's an
#appropriate subject to use based upon that name/type.
sub _resolve_subject {
    my $class = shift;
    my $subject_name = shift;
    my $subject_type = shift;

    if (not defined $subject_name) {
        $class->error_message("bad data--missing subject_name!");
        return;
    }

    my $try_all_types = 0;
    if (not defined $subject_type) {
        #If they didn't give a subject type, we'll keep trying subjects until we find something that sticks.
        $try_all_types = 1;
    }

    my @subjects = ();

    if($try_all_types or $subject_type eq 'sample_name') {
        my $subject = Genome::Sample->get(name => $subject_name);
        return $subject if $subject; #sample_name is the favoured default.  If we get one, use it.
    }
    if ($try_all_types or $subject_type eq 'species_name') {
        push @subjects, Genome::Taxon->get(species_name => $subject_name);
    }
    if ($try_all_types or $subject_type eq 'library_name') {
        push @subjects, Genome::Library->get(name => $subject_name);
    }
    if ($try_all_types or $subject_type eq 'genomic_dna') {
        push @subjects, Genome::Sample->get(extraction_label => $subject_name, extraction_type => 'genomic dna');
    }
    if ($try_all_types or $subject_type eq 'flow_cell_id') {
        push @subjects, GSC::Equipment::Solexa::Run->get(flow_cell_id => $subject_name);
    }

    #Only resort to a GSC::DNA if nothing else so far has worked
    if (($try_all_types and not scalar(@subjects)) or $subject_type eq 'dna_resource_item_name') {
        #If they specified dna_resource_item_name, they might actually have meant some other sort of "DNA"
        #This will get the GSC::DNAResourceItem if that's what they asked for.
        push @subjects, GSC::DNA->get(dna_name => $subject_name);
    }

    #This case will only be entered if the user asked specifically for a sample_group
    if ($subject_type and $subject_type eq 'sample_group') {
        push @subjects,
            Genome::Individual->get(name => $subject_name),
            Genome::ModelGroup->get(name => $subject_name),
            Genome::PopulationGroup->get(name => $subject_name);
    }

    if(scalar @subjects == 1) {
        return $subjects[0];
    } elsif (scalar @subjects) {
        my $null = '<NULL>';
        $class->error_message('Multiple matches for ' . join(', ',
            'subject_name: ' . ($subject_name || $null),
            'subject_type: ' . ($subject_type || $null),
        ) . '. Please specify a subject_type or use subject_id/subject_class_name instead.'
        );
        $class->error_message('Possible subjects named "' . $subject_name . '": ' . join(', ',
            map($_->class . ' #' . $_->id, @subjects)
        ));
    } else {
        #If we get here, nothing matched.
        my $null = '<NULL>';
        $class->error_message('Unable to determine a subject given ' . join(', ',
            'subject_name: ' . ($subject_name || $null),
            'subject_type: ' . ($subject_type || $null),
        ));
        return;
    }
}

sub _verify_subject {
    my $self = shift;

    my $subject = $self->subject;

    unless($subject) {
        my $null = '<NULL>';
        $self->error_message('Could not verify subject given ' . join(', ',
            'subject_id: ' . ($self->subject_id || $null),
            'subject_class_name: ' . ($self->subject_class_name || $null),
        ));
        return;
    }

    return $subject;
}

sub get_all_possible_samples {
    my $self = shift;

    my @samples;
    if ( $self->subject_class_name eq 'Genome::Taxon' ) {
        my $taxon = Genome::Taxon->get(species_name => $self->subject_name);
        @samples = $taxon->samples;

        #data tracking is incomplete, so sometimes these need to be looked up via the sources
        my @sources = ($taxon->individuals, $taxon->population_groups);
        push @samples,
            map($_->samples, @sources);
    } elsif ($self->subject_class_name eq 'Genome::Sample'){
        @samples = ( $self->subject );
    #} elsif () {
        #TODO Possibly fill in for Genome::Individual, Genome::PopulationGroup and possibly others
    } else {
        @samples = ();
    }

    return @samples;
}

#< Instrument Data >#
sub compatible_instrument_data {
    my $self = shift;
    my %params;

    my $subject_type_class;
    if (my @samples = $self->get_all_possible_samples)  {
        my @sample_ids = map($_->id, @samples);
        %params = (
                   sample_id => \@sample_ids,
               );
        $params{sequencing_platform} = $self->sequencing_platform if $self->sequencing_platform;
    } else {
        %params = (
                   $self->subject_type => $self->subject_name,
               );
        $subject_type_class = $self->instrument_data_class_name;
    }
    unless ($subject_type_class) {
        $subject_type_class = 'Genome::InstrumentData';
    }
    my @compatible_instrument_data = $subject_type_class->get(%params);

    if($params{sequencing_platform} and $params{sequencing_platform} eq 'solexa') {
        # FASTQs with 0 reads crash in alignment.  Don't assign them. -??
        # TODO: move this into the assign logic, not here. -ss
        my @filtered_compatible_instrument_data;
        for my $idata (@compatible_instrument_data) {
            if (defined($idata->total_bases_read)&&($idata->total_bases_read == 0)) {
                $self->warning_message(sprintf("ignoring %s because it has zero bases read",$idata->__display_name__));
                next;
            }
            else {
                push @filtered_compatible_instrument_data, $idata;
            }
        }
        @compatible_instrument_data = @filtered_compatible_instrument_data;
    }

    return @compatible_instrument_data;
}

sub available_instrument_data { return unassigned_instrument_data(@_); }
sub unassigned_instrument_data {
    my $self = shift;

    my @compatible_instrument_data = $self->compatible_instrument_data;
    my @instrument_data_assignments = $self->instrument_data_assignments
        or return @compatible_instrument_data;
    my %assigned_instrument_data_ids = map { $_->instrument_data_id => 1 } @instrument_data_assignments;

    return grep { not $assigned_instrument_data_ids{$_->id} } @compatible_instrument_data;
}
#<>#

# These vary based on the current configuration, which could vary over
# time.  This value is set when the model is created if not specified by the creator.
sub resolve_data_directory {
    my $self = shift;
    return Genome::Config->model_data_directory . '/' . $self->id;
}

sub resolve_archive_file {
    my $self = shift;
    return $self->data_directory . '.tbz';
}

#< Completed (also Suceeded) Builds >#
sub succeeded_builds { return $_[0]->completed_builds; }
sub completed_builds {
    my $self = shift;

    my @completed_builds;
    for my $build ( $self->builds ) {
        my $build_status = $build->status;
        next unless defined $build_status and $build_status eq 'Succeeded';
        next unless defined $build->date_completed; # error?
        push @completed_builds, $build;
    }

    return sort { $a->id <=> $b->id } @completed_builds;
}

sub latest_build {
    # this is the latest build with no filtering on status, etc.
    my ($self) = @_;
    my @builds = $self->builds();
    return $builds[-1] if @builds;
    return;
}

sub last_succeeded_build { return $_[0]->resolve_last_complete_build; }
sub last_complete_build { return $_[0]->resolve_last_complete_build; }
sub resolve_last_complete_build {
    my $self = shift;
    my @completed_builds = $self->completed_builds;
    return unless @completed_builds;
    my $last = pop @completed_builds;
    unless ( defined $self->_last_complete_build_id
            and $self->_last_complete_build_id == $last->id ) {
        $self->_last_complete_build_id( $last->id );
    }
    return $last;
}

sub last_succeeded_build_id { return $_[0]->last_complete_build_id; }
sub last_complete_build_id {
    my $self = shift;
    my $last_complete_build = $self->last_complete_build;
    return unless $last_complete_build;
    return $last_complete_build->id;
}
#<>#

sub builds_with_status {
    my ($self, $status) = @_;
    my @builds = $self->builds;
    unless (scalar(@builds)) {
        return;
    }
    my @builds_with_a_status = grep { $_->status } @builds;
    my @builds_with_requested_status = grep {$_->status eq $status} @builds_with_a_status;
    my @builds_wo_date = grep { !$_->date_scheduled } @builds_with_requested_status;
    if (scalar(@builds_wo_date)) {
        my $error_message = 'Found '. scalar(@builds_wo_date) ." $status builds without date scheduled.\n";
        for (@builds_wo_date) {
            $error_message .= "\t". $_->desc ."\n";
        }
        die($error_message);
    }
    my @sorted_builds_with_requested_status = sort {$a->date_scheduled cmp $b->date_scheduled} @builds_with_requested_status;
    return @sorted_builds_with_requested_status;
}

sub abandoned_builds {
    my $self = shift;
    my @abandoned_builds = $self->builds_with_status('Abandoned');
    return @abandoned_builds;
}
sub failed_builds {
    my $self = shift;
    my @failed_builds = $self->builds_with_status('Failed');
    return @failed_builds;
}
sub running_builds {
    my $self = shift;
    my @running_builds = $self->builds_with_status('Running');
    return @running_builds;
}
sub scheduled_builds {
    my $self = shift;
    my @scheduled_builds = $self->builds_with_status('Scheduled');
    return @scheduled_builds;
}

sub current_running_build {
    my $self = shift;
    my @running_builds = $self->running_builds;
    my $current_running_build = pop(@running_builds);
    return $current_running_build;
}

sub current_running_build_id {
    my $self = shift;
    my $current_running_build = $self->current_running_build;
    unless ($current_running_build) {
        return;
    }
    return $current_running_build->id;
}

sub latest_build_directory {
    my $self = shift;
    my $current_running_build = $self->current_running_build;
    if (defined $current_running_build) {
        return $current_running_build->data_directory;
    }
    my $last_complete_build = $self->last_complete_build;
    if (defined $last_complete_build) {
        return $last_complete_build->data_directory;
    } else {
       die "no builds found";
    }
}

sub resolve_reports_directory {
    my $self=shift;
    my $build_dir = $self->latest_build_directory;
    return $build_dir . "/reports/";
}

sub available_reports {
    my $self=shift;
    #if we don't have a completed build, we don't have reports
    return $self->last_complete_build ? $self->last_complete_build->available_reports : {};
}

# This is called by both of the above.
sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::Model' , $subclass);
    return $class_name;
}

sub _resolve_type_name_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::Model::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $type_name = lc(join(" ", @words));
    return $type_name;
}

# TODO: please rename this -ss
sub get_all_objects {
    my $self = shift;
    my $sorter = sub { # not sure why we sort, but I put it in a anon sub for convenience
        return unless @_;
        if ( $_[0]->id =~ /^\-/) {
            return sort {$b->id cmp $a->id} @_;
        }
        else {
            return sort {$a->id cmp $b->id} @_;
        }
    };

    return map { $sorter->( $self->$_ ) } (qw{ inputs builds project_assignments to_model_links from_model_links putative_variant_validations});
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        $string .= $object->yaml_string;
    }
    return $string;
}

# please rename this -ss
sub add_to_model{
    my $self = shift;
    my (%params) = @_;
    my $model = delete $params{to_model};
    my $role = delete $params{role};
    $role||='member';

    $self->error_message("no to_model provided!") and die unless $model;
    my $from_id = $self->id;
    my $to_id = $model->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this model(from_model) id: <$from_id> or to_model id: <$to_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Link->get(from_model_id => $to_id, to_model_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A model link already exists for these two models, and in the opposite direction than you specified:\n";
        $string .= "to_model: ".$reverse_bridge->to_model." (this model)\n";
        $string .= "from_model: ".$reverse_bridge->from_model." (the model you are trying to set as a 'to' model for this one)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Link->get(from_model_id => $from_id, to_model_id => $to_id);
    if ($bridge){
        my $string =  "A model link already exists for these two models:\n";
        $string .= "to_model: ".$bridge->to_model." (the model you are trying to set as a 'to' model for this one)\n";
        $string .= "from_model: ".$bridge->from_model." (this model)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Link->create(from_model_id => $from_id, to_model_id => $to_id, role => $role);
    return $bridge;
}

# please rename this -ss
sub add_from_model{
    my $self = shift;
    $DB::single = 1;
    my (%params) = @_;
    my $model = delete $params{from_model};
    my $role = delete $params{role};
    $role||='member';

    $self->error_message("no from_model provided!") and die unless $model;
    my $to_id = $self->id;
    my $from_id = $model->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this model(to_model) id: <$to_id> or from_model id: <$from_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Link->get(from_model_id => $to_id, to_model_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A model link already exists for these two models, and in the opposite direction than you specified:\n";
        $string .= "to_model: ".$reverse_bridge->to_model." (the model you are trying to set as a 'from' model for this one)\n";
        $string .= "from_model: ".$reverse_bridge->from_model." (this model)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Link->get(from_model_id => $from_id, to_model_id => $to_id);
    if ($bridge){
        my $string =  "A model link already exists for these two models:\n";
        $string .= "to_model: ".$bridge->to_model." (this model)\n";
        $string .= "from_model: ".$bridge->from_model." (the model you are trying to set as a 'from' model for this one)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Link->create(from_model_id => $from_id, to_model_id => $to_id, role => $role);
    return $bridge;
}

sub notify_input_build_success {
    my $self = shift;
    my $succeeded_build = shift;

    if($self->auto_build_alignments) {
        my @from_models = $self->from_models;
        my @last_complete_builds = map($_->last_complete_build, @from_models);

        #all input models have a succeeded build
        if(scalar @from_models eq scalar @last_complete_builds) {
            $self->build_requested(1);
        }
    }

    return 1;
}

# this goes into refalign models only
sub lcb_flagstat {
    my $self = shift;

    my $fs_report = $self->last_complete_build->data_directory . "/alignments/" . $self->last_complete_build->id . "_merged_rmdup.bam.flagstat";

    if (-e $fs_report) {
        my $fs_stats = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($fs_report);
        return $fs_stats;
    } else {
        $self->warning_message("Last complete build's flagstat report requested, but none found.");
        return undef;
    }
}

sub delete {
    my $self = shift;
    my %params = @_;
    my $keep_model_directory = $params{keep_model_directory};
    my $keep_build_directories = $params{keep_build_directories};
    my @build_directories;

    # If the model is a member of model groups, it will not delete due to foreign key constraints.
    # The easy solution here is to simply tack on "model_bridges" onto the end of get_all_objects and they will be deleted automatically (though some solution would have to be devised to update convergence model builds when this happens).
    # For now it has been decided to simply let the user know what model groups the model is a part of, so they can remove them from those groups manually so we can be sure that is really what should happen.
    my @model_bridges = $self->model_bridges;
    if (@model_bridges) {
        # Make a list of commands to run for each model group to which the model being removed belongs
        my $deletion_commands = join ("", map("\tgenome model-group member remove --model-group-id " . $_->model_group_id . " --model-id " . $self->genome_model_id . "\n", @model_bridges) );
        $self->error_message("Cannot delete this model because it is a member of one or more model groups. If you are sure you wish you delete this model, you may do so after removing the model from these group(s) by running the following command(s):\n$deletion_commands");
        die $self->error_message();
    }

    # This may not be the way things are working but here is the order of operations for removing db events
    # 1.) Remove all instrument data assignment entries for model
    # 2.) Set model last_complete_build_id and current_running_build_id to null
    # 3.) Remove all genome_model_build entries
    # 4.) Remove all genome_model_event entries
    # 5.) Remove the genome_model entry

    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        my $status;
        if($object->isa('Genome::Model::Build'))
        {
            push @build_directories,$object->data_directory;
            $status = $object->delete(keep_build_directory => $keep_build_directories);
        }
        else
        {
             $status = $object->delete;
        }

        unless ($status) {
            $self->error_message('Failed to remove object '. $object->class .' '. $object->id);
            die $self->error_message();
        }
    }
    # Get the remaining events like create and assign instrument data
    for my $event ($self->events) {
        unless ($event->delete) {
            $self->error_message('Failed to remove event '. $event->class .' '. $event->id);
            die $self->error_message();
        }
    }
    #make sure the model directory doesn't contain any builds if we are saving them
    if ($keep_build_directories && !$keep_model_directory) {
        my $model_directory = $self->data_directory;
        $keep_model_directory = grep { /$model_directory/ } @build_directories;
    }
    if (-e $self->data_directory && !$keep_model_directory) {
        unless (rmtree $self->data_directory) {
            $self->warning_message('Failed to rmtree model data directory '. $self->data_directory);
        }
    }

    return $self->SUPER::delete;
}

sub _build_model_filesystem_paths {
    my $self = shift;

    # This is actual data directory on the filesystem
    # Currently the disk is hard coded in Genome::Config->root_directory
    my $model_data_dir = $self->data_directory;
    unless (Genome::Sys->create_directory($model_data_dir)) {
        $self->warning_message("Can't create dir: $model_data_dir");
        return;
    }

    # Fix when models are created, ensure the directory is group-writable.
    my $chmodrv = system(sprintf("chmod g+w %s", $model_data_dir));
    unless ($chmodrv == 0) {
        $self->warning_message("Error attempting to set group write permissions on model directory $model_data_dir: rv $chmodrv");
    }

    return 1;
}

sub inputs_necessary_for_copy {
    my $self = shift;
    # skip instrument data assignments; these should be handled by applying the instrument data assign command
    # to the target model
    my @inputs_to_copy = grep {$_->name ne "instrument_data"} $self->inputs;
    return @inputs_to_copy; 
}

sub additional_params_for_copy {
    return();
}

sub dependent_properties {
    my ($self, $property_name) = @_;
    return;
}

1;

