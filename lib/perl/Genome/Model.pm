package Genome::Model;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model {
    is => ['Genome::Notable','Genome::Searchable'],
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    subclass_description_preprocessor => __PACKAGE__ . '::_preprocess_subclass_description',
    id_by => [
        genome_model_id => { is => 'Number', },
    ],
    attributes_have => [
        is_input    => { is => 'Boolean', is_optional => 1, },
        is_param    => { is => 'Boolean', is_optional => 1, },
        is_output   => { is => 'Boolean', is_optional => 1, },
        _profile_default_value => { is => 'Text', is_optional => 1, },
    ],
    has => [
        name => { is => 'Text' },
        subclass_name => { 
            is => 'VARCHAR2',is_mutable => 0, column_name => 'SUBCLASS_NAME',
            calculate_from => 'processing_profile_id',
            calculate => sub {
                my $pp_id = shift;
                return unless $pp_id;
                my $pp = Genome::ProcessingProfile->get($pp_id);
                unless ($pp) {
                    Carp::croak "Can't find processing profile with ID $pp_id while resolving subclass for model";
                }
                return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($pp->type_name);
            },
        },
        subject => { 
            is => 'Genome::Subject',
            id_by => 'subject_id',
        },
        # FIXME This can be removed once the subject_class_name column is dropped. 
        subject_class_name => {
            is => 'Text',
            is_optional => 1,
        },
        processing_profile => { 
            is => 'Genome::ProcessingProfile', 
            id_by => 'processing_profile_id' 
        },
    ],
    has_optional => [
        limit_inputs_id => {
            is => 'Text',
            column_name => 'LIMIT_INPUTS_TO_ID',
        },
        limit_inputs_rule => {
            is => 'UR::BoolExpr',
            id_by => 'limit_inputs_id',
        },
        user_name => { is => 'Text' },
        creation_date  => { is => 'Timestamp' },
        build_requested => { is => 'Boolean'},
    ],
    has_optional_many => [
        builds  => { 
            is => 'Genome::Model::Build', 
            reverse_as => 'model',
            doc => 'Versions of a model over time, with varying quantities of evidence' 
        },
        inputs => { 
            is => 'Genome::Model::Input', 
            reverse_as => 'model',
            doc => 'links to data currently assigned to the model for processing' 
        },
        projects => { 
            is => 'Genome::Project', 
            via => 'project_parts', 
            to => 'project', 
            is_many => 1, 
            is_mutable => 1, 
            doc => 'Projects that include this model', 
        },
        project_parts => { 
            is => 'Genome::ProjectPart', 
            reverse_as => 'entity', 
            is_many => 1, 
            is_mutable => 1, 
        },
    ],    
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'GENOME_MODEL',
    doc => 'a versioned data model describing one the sequence and features of a genome' 
};

# Override in subclasses to have additional stuff appended to the model's default name
# FIXME This will probably go away when the default_name method is overhauled
sub _additional_parts_for_default_name { return; }

# Override in subclasses. Given a list of model inputs missing from a build and a list of build
# inputs missing from the model, should return true if those differences are okay and false otherwise
sub _input_differences_are_ok {
    my $self = shift;
    my @inputs_not_found = @{shift()};
    my @build_inputs_not_found = @{shift()};

    return; #by default all differences are not ok
}

# Override in subclasses. Compares the number of inputs between a build and the model.
sub _input_counts_are_ok {
    my $self = shift;
    my $input_count = shift;
    my $build_input_count = shift;

    return ($input_count == $build_input_count);
}

# Override in subclasses for custom behavior. Updates the model as necessary prior to starting a 
# build. Useful for ensuring that the build is incorporating all of the latest information. 
# TODO Make sure this is necessary, could be removed
sub check_for_updates {
    return 1;
}

# Override in subclasses, should figure out an appropriate subject for the model and return it
sub _resolve_subject {
    return;
}

# Override in subclasses, should figure out an appropriate processing profile for the model and return it
sub _resolve_processing_profile {
    return;
}

# Default string to be displayed, can be overridden in subclasses
sub __display_name__ {
    my $self = shift;
    return $self->name . ' (' . $self->id . ')';
}

# Create a model and validate processing profile, subject, etc
sub create {
    my $class = shift;

    # If create is being called directly on this class or on an abstract subclass, SUPER::create will
    # figure out the correct concrete subclass (if one exists) and call create on it.
    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        return $class->SUPER::create(@_);
    }
    my $self = $class->SUPER::create(@_);

    $self->_validate_processing_profile;
    $self->_validate_subject;
    $self->_validate_name;

    $self->user_name(Genome::Sys->username) unless $self->user_name;
    $self->creation_date(UR::Context->now);

    $self->_verify_no_other_models_with_same_name_and_type_exist;

    # If build requested was set as part of model creation, it didn't use the mutator method that's been
    # overridden. Re-set it here so the required actions take place.
    if ($self->build_requested) {
        $self->build_requested($self->build_requested, 'model created with build requested set');
    }

    return $self;
}


# Delete the model and all of its builds/inputs
sub delete {
    my $self = shift;
    $self->debug_message("Deleting model " . $self->__display_name__);

    my @build_directories;

    for my $input ($self->inputs) {
        $self->debug_message("Deleting model input " . $input->__display_name__);
        my $rv = $input->delete;
        unless ($rv) {
            Carp::confess $self->error_message("Could not delete model input " . $input->__display_name__ . 
                " prior to deleting model " . $self->__display_name__);
        }
    }

    for my $build ($self->builds) {
        $self->debug_message("Deleting build " . $build->__display_name__);
        my $rv = $build->delete;
        unless ($rv) {
            Carp::confess $self->error_message("Could not delete build " . $build->__display_name__ .
                " prior to deleting model " . $self->__display_name__);
        }
    }

    return $self->SUPER::delete;
}

# Returns a list of builds (all statuses) sorted from oldest to newest
sub sorted_builds {
    my $self = shift;
    my @builds = $self->builds;
    return sort { $a->date_scheduled cmp $b->date_scheduled } @builds;
}

# Returns a list of succeeded builds sorted from oldest to newest
sub succeeded_builds { return $_[0]->completed_builds; }
sub completed_builds {
    my $self = shift;
    my @completed_builds = grep { 
        defined $_->status and 
        $_->status eq 'Succeeded' and
        $_->date_completed
    } $self->sorted_builds;
    return @completed_builds;
}

# Returns the latest build of the model, regardless of status
sub latest_build {
    my $self = shift;
    my @builds = $self->sorted_builds;
    if (@builds) {
        return $builds[-1];
    }
    return;
}

# Returns the latest build of the model that successfully completed
sub last_succeeded_build { return $_[0]->resolve_last_complete_build; }
sub last_complete_build { return $_[0]->resolve_last_complete_build; }
sub resolve_last_complete_build {
    my $self = shift;
    my @completed_builds = $self->completed_builds;
    if (@completed_builds) {
        return $completed_builds[-1];
    }
    return;
}

# Returns a list of builds with the specified status sorted from oldest to newest
sub builds_with_status {
    my ($self, $status) = @_;
    return grep {
        $_->status and
        $_->status eq $status
    } $self->sorted_builds;
}
    
# Overriding build_requested to add a note to the model with information about who requested a build
sub build_requested {
    my ($self, $value, $reason) = @_; 
    # Writing the if like this allows someone to do build_requested(undef)
    if (@_ > 1) {
        my ($calling_package, $calling_subroutine) = (caller(1))[0,3];
        my $default_reason = 'no reason given';
        $default_reason .= ' called by ' . $calling_package . '::' . $calling_subroutine if $calling_package;
        $self->add_note(
            header_text => $value ? 'build_requested' : 'build_unrequested',
            body_text => defined $reason ? $reason : $default_reason,
        );
        return $self->__build_requested($value);
    }
    return $self->__build_requested;
}

# Returns the latest non-abandoned build that has inputs that match the current state of the model
sub current_build {
    my $self = shift;
    my @builds = $self->builds('status not like' => 'Abandoned');
    my $build_iterator = $self->build_iterator(
        'status not like' => 'Abandoned',
        '-order_by' => '-build_id',
    );
    while (my $build = $build_iterator->next) {
        return $build if $build->is_current;
    }
    return;
}

# Returns true if no non-abandoned build is found that has inputs that match the current state of the model
sub build_needed {
    return not shift->current_build;
}

# Returns the current status of the model with the corresponding build (if available)
sub status_with_build {
    my $self = shift;
    my ($status, $build);
    if ($self->build_requested) {
        $status = 'Build Requested';
    } elsif ($self->build_needed) {
        $status = 'Build Needed';
    } else {
        $build = $self->current_build;
        $status = $build->status;
    }
    return ($status, $build);
}

# Returns the current status of the model
sub status {
    my $self = shift;
    my ($status) = $self->status_with_build;
    return $status;
}

# TODO Clean this up
sub copy {
    my ($self, %overrides) = @_;

    # standard properties
    my %params = ( subclass_name => $self->subclass_name );
    $params{name} = delete $overrides{name} if defined $overrides{name};
    my @standard_properties = (qw/ subject processing_profile auto_assign_inst_data auto_build_alignments /);
    for my $name ( @standard_properties ) {
        if ( defined $overrides{$name} ) { # override
            $params{$name} = delete $overrides{$name};
        }
        elsif ( exists $overrides{$name} ) { # rm undef
            delete $overrides{$name};
        }
        else {
            $params{$name} = $self->$name;
        }
    }

    # input properties
    for my $property ( $self->real_input_properties ) {
        my $name = $property->{name};
        if ( defined $overrides{$name} ) { # override
            my $ref = ref $overrides{$name};
            if ( $ref and $ref eq  'ARRAY' and not $property->{is_many} ) {
                $self->error_message('Cannot override singular input with multiple values: '.Data::Dumper::Dumper({$name => $overrides{$name}}));
                return;
            }
            $params{$name} = delete $overrides{$name};
        }
        elsif ( exists $overrides{$name} ) { # rm undef
            delete $overrides{$name};
        }
        else {
            if ( $property->{is_many} ) {
                $params{$name} = [ $self->$name ];
            }
            else {
                if( defined $self->$name ) {
                    $params{$name} = $self->$name;
                }
            }
        }
    }

    # make we covered all overrides
    if ( %overrides ) {
        $self->error_message('Unrecognized overrides sent to model copy: '.Data::Dumper::Dumper(\%overrides));
        return;
    }

    $params{subject_class_name} = $params{subject}->class; # set here in case subject is overridden

    my $copy = eval{ $self->class->create(%params) };
    if ( not $copy ) {
        $self->error_message('Failed to copy model: '.$@);
        return;
    }

    return $copy;
}

sub params_for_class {
    my $meta = shift->class->__meta__;
    
    my @param_names = map {
        $_->property_name
    } sort {
        $a->{position_in_module_header} <=> $b->{position_in_module_header}
    } grep {
        defined $_->{is_param} && $_->{is_param}
    } $meta->property_metas;
    
    return @param_names;
}

# Ensures that processing profile is set. If not, an attempt is made to resolve one before exiting
sub _validate_processing_profile {
    my $self = shift;
    unless ($self->processing_profile) {
        my $pp = $self->_resolve_processing_profile;
        if ($pp and $pp->isa('Genome::ProcessingProfile')) {
            $self->processing_profile($pp);
        }
        else {
            $self->delete;
            Carp::confess "Could not resolve processing profile for model";
        }
    }
    return 1;
}

# Ensures that subject is set. If not, an attempt is made to resolve one before exiting
sub _validate_subject {
    my $self = shift;
    unless ($self->subject) {
        my $subject = $self->_resolve_subject;
        if ($subject and $subject->isa('Genome::Subject')) {
            $self->subject($subject);
        }
        else {
            $self->delete;
            Carp::confess "Could not resolve subject for model";
        }
    }
    return 1;
}

# Ensures that a name is set. If not, a default is used if possible.
sub _validate_name {
    my $self = shift;
    unless ($self->name) {
        my $name = $self->default_model_name;
        if ($name) {
            $self->name($name);
        }
        else {
            $self->delete;
            Carp::confess "Could not resolve default name for model!";
        }
    }
    return 1;
}

# TODO This method should return a generic default model name and be overridden in subclasses.
sub default_model_name {
    $DB::single = 1;
    my ($self, %params) = @_;

    my $auto_increment = delete $params{auto_increment};
    $auto_increment = 1 unless defined $auto_increment;

    my $name_template = ($self->subject_name).'.';
    $name_template .= 'prod-' if ($self->user_name eq 'apipe-builder' || $params{prod});

    my $type_name = $self->processing_profile->type_name;
    my %short_names = (
        'genotype microarray' => 'microarray',
        'reference alignment' => 'refalign',
        'de novo assembly' => 'denovo',
        'metagenoic composition 16s' => 'mc16s',
    );
    $name_template .= ( exists $short_names{$type_name} )
    ? $short_names{$type_name}
    : join('_', split(/\s+/, $type_name));

    $name_template .= '%s%s';

    my @parts;
    push @parts, 'capture', $params{capture_target} if defined $params{capture_target};
    push @parts, $params{roi} if defined $params{roi};
    my @additional_parts = eval{ $self->_additional_parts_for_default_name(%params); };
    if ( $@ ) {
        $self->error_message("Failed to get addtional default name parts: $@");
        return;
    }
    push @parts, @additional_parts if @additional_parts;
    $name_template .= '.'.join('.', @parts) if @parts;

    my $name = sprintf($name_template, '', '');
    my $cnt = 0;
    while ( $auto_increment && Genome::Model->get(name => $name) ) {
        $name = sprintf($name_template, '-', ++$cnt);
    }

    return $name;
}

# Ensures there are no other models of the same class that have the same name. If any are found, information
# about them is printed to the screen the create fails.
sub _verify_no_other_models_with_same_name_and_type_exist {
    my $self = shift;
    my @models = Genome::Model->get(
        'id ne' => $self->id,
        name => $self->name,
        subclass_name => $self->subclass_name,
    );

    if (@models) {
        my $message = "\n";
        for my $model ( @models ) {
            $message .= sprintf(
                "Name: %s\nSubject Name: %s\nId: %s\nProcessing Profile Id: %s\nSubclass: %s\n\n",
                $model->name,
                $model->subject_name,
                $model->id,
                $model->processing_profile_id,
                $model->subclass_name,
            );
        }
        $message .= sprintf(
            'Found the above %s with the same name and type name.  Please select a new name.',
            Lingua::EN::Inflect::PL('model', scalar(@models)),
        );

        $self->delete;
        Carp::confess $message;
    }

    return 1
}

sub _preprocess_subclass_description {
    my ($class, $desc) = @_;
    my @names = keys %{ $desc->{has} };
    for my $prop_name (@names) {
        my $prop_desc = $desc->{has}{$prop_name};
        # skip old things for which the developer has explicitly set-up indirection
        next if $prop_desc->{id_by};
        next if $prop_desc->{via};
        next if $prop_desc->{reverse_as};
        next if $prop_desc->{implied_by};
        
        if ($prop_desc->{is_param} and $prop_desc->{is_input}) {
            die "class $class has is_param and is_input on the same property! $prop_name";
        }

        if (exists $prop_desc->{'is_param'} and $prop_desc->{'is_param'}) {
            $prop_desc->{'via'} = 'processing_profile',
            $prop_desc->{'to'} = $prop_name;
            $prop_desc->{'is_mutable'} = 0;
            $prop_desc->{'is_delegated'} = 1;
            if ($prop_desc->{'default_value'}) {
                $prop_desc->{'_profile_default_value'} = delete $prop_desc->{'default_value'};
            }
        }

        if (exists $prop_desc->{'is_input'} and $prop_desc->{'is_input'}) {

            my $assoc = $prop_name . '_association' . ($prop_desc->{is_many} ? 's' : '');
            next if $desc->{has}{$assoc};

            $desc->{has}{$assoc} = {
                property_name => $assoc,
                implied_by => $prop_name,
                is => 'Genome::Model::Input',
                reverse_as => 'model', 
                where => [ name => $prop_name ],
                is_mutable => $prop_desc->{is_mutable},
                is_optional => $prop_desc->{is_optional},
                is_many => 1, #$prop_desc->{is_many},
            };

            # We hopefully don't need _id accessors
            # If we do duplicate the code below for value_id

            %$prop_desc = (%$prop_desc,
                via => $assoc, 
                to => 'value',
            );
        }
    }

    my ($ext) = ($desc->{class_name} =~ /Genome::Model::(.*)/);
    return $desc unless $ext;
    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    
    my $pp_data = $desc->{has}{processing_profile} = {};
    $pp_data->{data_type} = $pp_subclass_name;
    $pp_data->{id_by} = ['processing_profile_id'];

    $pp_data = $desc->{has}{processing_profile_id} = {};
    $pp_data->{data_type} = 'Number';

    return $desc;
}

my $depth = 0;
sub __extend_namespace__ {
    # auto generate sub-classes for any valid processing profile
    my ($self,$ext) = @_;

    my $meta = $self->SUPER::__extend_namespace__($ext);
    if ($meta) {
        return $meta;
    }

    $depth++;
    if ($depth>1) {
        $depth--;
        return;
    }

    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    my $pp_subclass_meta = UR::Object::Type->get($pp_subclass_name);
    if ($pp_subclass_meta and $pp_subclass_name->isa('Genome::ProcessingProfile')) {
        my @pp_delegated_properties = map {
            $_ => { via => 'processing_profile' }
        } $pp_subclass_name->params_for_class;

        my $model_subclass_name = 'Genome::Model::' . $ext;
        my $model_subclass_meta = UR::Object::Type->define(
            class_name => $model_subclass_name,
            is => 'Genome::ModelDeprecated',
            has => \@pp_delegated_properties
        );
        die "Error defining $model_subclass_name for $pp_subclass_name!" unless $model_subclass_meta;
        $depth--;
        return $model_subclass_meta;
    }
    $depth--;
    return;
}

1;
