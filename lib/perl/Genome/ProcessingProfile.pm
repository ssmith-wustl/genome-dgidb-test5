package Genome::ProcessingProfile;

use strict;
use warnings;
use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::Text;

class Genome::ProcessingProfile {
    table_name => 'PROCESSING_PROFILE',
    is_abstract => 1,
    attributes_have => [
        is_param => { is => 'Boolean', is_optional => 1 },
    ],
    subclass_description_preprocessor => 'Genome::ProcessingProfile::_expand_param_properties',
    subclassify_by => 'subclass_name',
    id_by => [
        id => { is => 'UR::Value::Number', len => 11 },
    ],
    has => [
        name          => { is => 'VARCHAR2', len => 255, is_optional => 1, 
                           doc => 'Human readable name' },
        type_name     => { is => 'VARCHAR2', len => 255, is_optional => 1, 
                           doc => 'The type of processing profile' },
        supersedes    => { via => 'params', to => 'value', is_mutable => 1, where => [ name => 'supersedes' ], is_optional => 1, 
                           doc => 'The processing profile replaces the one named here.' },
        subclass_name => { is => 'VARCHAR2', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                           calculate_from => ['type_name'],
                           calculate => sub { 
                                            my($type_name) = @_;
                                            confess "No type name given to resolve subclass name" unless $type_name;
                                            return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($type_name);
                                          }
                          },
    ],
    has_many_optional => [
        params => { is => 'Genome::ProcessingProfile::Param', reverse_as => 'processing_profile' },
        models => { is => 'Genome::Model', reverse_as => 'processing_profile' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = $_[0];
    return $self->name . ' (' . $self->id . ')';
}

### Override When Implementing New Pipelines ###

sub _initialize_model {
    # my ($self,$model) = @_;
    # override in sub-classes to get custom mods to the model
    return 1;
}

sub _initialize_build {
    # my ($self,$build) = @_;
    # override in sub-classes to get custom mods to the build
    return 1;
}

sub _build_success_callback {
    my ($self, $build) = @_;
    # override in sub-classes to get custom commit hook when a build succeeds
$DB::single = 1;
    my $model = $build->model;

    #Notify any models set to depend on this one that a new build is ready
    my @to_models = $model->to_models;
    for my $to_model (@to_models) {
        $to_model->notify_input_build_success($build);
    }

    return 1;
}

# Override this method in subclass to use non-default resource requirement string for _execute_build method
#sub _resource_requirements_for_execute_build {
#    my $self = shift;
#    my $resource = "-R ...";
#    return $resource;
#}

sub _resolve_workflow_for_build {
    my ($self,$build, $optional_lsf_queue) = @_;
    
    # override in sub-classes to return the correct workflow
    # for now this is build specific, but should eventually be pp specific,
    # and hopefully pp-subclass specific.

    if ($self->can('_execute_build')) {

        my %opts = (
            name => $build->id . ' all stages',
            input_properties => [ 'build_id' ],
            output_properties => [ 'result' ]
        );

        my $logdir = $build->log_directory;
        if ($logdir =~ /^\/gscmnt/) {
            $opts{log_dir} = $logdir;
        }
 
        my $workflow = Workflow::Model->create(%opts);

        my $operation_type = Workflow::OperationType::Command->get('Genome::Model::Event::Build::ProcessingProfileMethodWrapper');
        #$operation_type->lsf_rusage("-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1]'");
        #$operation_type->lsf_resource("-R 'select[model!=Opteron250 && type==LINUX64] rusage[tmp=90000:mem=16000]' -M 16000000");
        if ($self->can('_resource_requirements_for_execute_build')) {
            $operation_type->lsf_resource($self->_resource_requirements_for_execute_build($build));
        }
        else {
            $operation_type->lsf_resource("-R 'select[model!=Opteron250 && type==LINUX64] rusage[tmp=10000:mem=1000]' -M 1000000");
        }

        my $operation = $workflow->add_operation(
            name => '_execute_build',
            operation_type => $operation_type, 
        );
        
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => 'build_id',
            right_operation => $operation,
            right_property => 'build_id'
        );

        $workflow->add_link(
            left_operation => $operation,
            left_property => 'result',
            right_operation => $workflow->get_output_connector,
            right_property => 'result'
        );

        my @e = $workflow->validate;
        die @e unless $workflow->is_valid;

        return $workflow;
    }

    my $msg = sprintf(
        "\nFailed to either implement _execute_build, or override _resolve_workflow_for_build, in processing profile %s!\n"
        . " for build %s of model %s\n"
        . "And failed to ..\n",
        $self->__display_name__,
        $build->__display_name__,
        $build->model->__display_name__
    );
    Carp::confess($msg);
}

# override in subclasses to compose processing profile parameters and build inputs to the workflow provided above
sub _map_workflow_inputs {
    my ($self, $build) = @_;
    
    return (build_id => $build->id);
}

# override in sub-classes if you want a non-workflow build
#sub _execute_build {
#   # my ($self,$build) = @_;
#    
#    return;
#}

###

# Override in subclass if you want some kind of validation of the processing profile object
sub validate_created_object {
    my $self = shift;
    return 1;
}

sub create {
    my $class = shift;
    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        return $class->SUPER::create(@_);
    }

    my $bx = $class->define_boolexpr(@_);
    my %params = $bx->params_list;

    $class->_validate_name_and_uniqueness($params{name})
        or return;

    my $subclass;
    if ( $params{type_name} ) {
        $subclass = $class->_resolve_subclass_name_for_type_name($params{type_name});
        unless ( $subclass ) {
            confess "Can't resolve subclass for type name ($params{type_name})";
        }
    }
    else {
        confess __PACKAGE__ . " is a abstract base class, and no type name was provided to resolve to the appropriate subclass" 
            if $class eq __PACKAGE__;
        $subclass = $class;
        $params{type_name} = $class->_resolve_type_name_for_class;
    }

    # Make sure subclass is a real class
    my $meta;
    eval {
        $meta = $subclass->__meta__;
    };
    unless ( $meta ) {
        confess "Can't find meta for class ($subclass). Is type name ($params{type_name}) valid?";
    }

    # Go thru params - set defaults, validate required and valid values
    foreach my $property_name ( $subclass->params_for_class ) {
        my $property_meta = $meta->property_meta_for_name($property_name);
        if ( !defined $params{$property_name} ) {
            my $default_value = $property_meta->default_value;
            if ( defined $default_value ) {
                $params{$property_name} = $default_value;
                # let this fall thru to check valid values
            }
            elsif ( $property_meta->is_optional ) {
                next;
            }
            else {
                $class->error_message(
                    sprintf('Invalid value (undefined) for %s', $property_name)
                );
                return;
            }
        }
        next unless defined $property_meta->valid_values; 
        unless ( grep { $params{$property_name} eq $_ } @{ $property_meta->valid_values } ) {
            $class->error_message(
                sprintf(
                    'Invalid value (%s) for %s.  Valid values: %s.',
                    $params{$property_name},
                    $property_name,
                    join(', ', @{ $property_meta->valid_values }),
                )
            );
            return;
        }
    }

    # Identical PPs
    $subclass->_validate_no_existing_processing_profiles_with_idential_params(%params)
        or return;

    #unless ($params{'subclass_name'}) {
    #    $params{'subclass_name'} = $class;
    #}

    # Create
    my $self = $class->SUPER::create(%params)
       or return;
   
    unless ($self->validate_created_object) {
        $self->error_message("Could not validate processing profile!");
        $self->delete;
        return;
    }

    return $self;
}

sub _validate_name_and_uniqueness {
    my ($class, $name) = @_;

    # defined? 
    unless ( $name ) {
        # TODO resolve??
        $class->error_message("No name provided for processing profile");
        return;
    }

    # Is name unique?
    my ($existing_name_pp) = $class->get(name => $name);
    if ( $existing_name_pp ) {
        Genome::ProcessingProfile::Command::Describe->execute(
            processing_profiles => [ $existing_name_pp ],
        ) or confess "Can't create describe command to show existing processing profile";
        $class->error_message("Processing profile (above) with same name ($name) already exists.");
        return;
    }

    return 1;
}

sub _validate_no_existing_processing_profiles_with_idential_params {
    my ($subclass, %params) = @_;
    my @existing_pp = _profiles_matching_subclass_and_params($subclass,%params);

    if (@existing_pp) {
        # If we get here we have one that is identical, describe and return undef
        Genome::ProcessingProfile::Command::Describe->execute(
            processing_profiles => [ $existing_pp[0] ],
        ) or confess "Can't execute describe command to show existing processing profile";
        my $qty = scalar @existing_pp;
        my $plural = $qty > 1 ? "s" : "";
        $subclass->error_message("Found $qty processing profile$plural with the same params as the one requested to create, but with a different name."
            ." Please use an existing profile, or change a param.\nExisting profile$plural:\n\t" . join("\n\t", map { $_->__display_name__ } @existing_pp));
        return;
    }

    return 1;
}

sub _profiles_matching_subclass_and_params {
    my ($subclass, %params) = @_;

    # If no params, no need to check
    my @params_for_class = $subclass->params_for_class;
    return unless @params_for_class;

    for my $param (@params_for_class) {
        unless (exists $params{$param}) {
            $params{$param} = undef;
        }
    }

    # Ignore these params.
    delete $params{type_name};
    delete $params{name};
    delete $params{supersedes};
    
    my @matches = $subclass->get(%params);
    return @matches;
}

sub delete {
    my $self = shift;
    
    # Check if there are models connected with this pp
    if ( Genome::Model->get(processing_profile_id => $self->id) ) {
        $self->error_message(
            sprintf(
                'Processing profile (%s <ID: %s>) has existing models and cannot be removed. Delete the models first, then remove this processing profile',
                $self->name,
                $self->id,
            )
        );
        return;
    }
 

    # Delete params
    for my $param ( $self->params ) {
        unless ( $param->delete ) {
            $self->error_message(
                sprintf(
                    'Can\'t delete param (%s: %s) for processing profile (%s <ID: %s>), ',
                    $param->name,
                    $param->value,
                    $self->name,
                    $self->id,
                )
            );
            for my $param ( $self->params ) {
                $param->resurrect if $param->isa('UR::DeletedRef');
            }
            return;
        }
    }   

    $self->SUPER::delete
        or return;

    return 1;
}


#< Params >#
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

sub param_summary {
    my $self = shift;
    my @params = $self->params_for_class();
    my $summary;
    for my $param (@params) {
        my @values;
        eval { @values = $self->$param(); };

        if (@values == 0) {
            next;
        }
        elsif (not defined $values[0] or $values[0] eq '') {
            next; 
        };

        if (defined $summary) {
            $summary .= ' '
        }
        else {
            $summary = ''
        }

        $summary .= $param . '=';
        if ($@) {
            $summary .= '!ERROR!';
        } 
        elsif (@values > 1) {
            $summary .= join(",",@values)
        } 
        elsif ($values[0] =~ /\s/) {
            $summary .= '"$values[0]"'
        }
        else {
            $summary .= $values[0]
        }
    }
    return $summary;
}

#< SUBCLASSING >#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _X_resolve_subclass_name {
    my $class = shift;

    my $type_name;
    if ( ref($_[0]) and $_[0]->can('type_name') ) {
        $type_name = $_[0]->type_name;
    } else {
        my %params = @_;
        $type_name = $params{type_name};
    }

    unless ( $type_name ) {
        my $rule = $class->get_rule_for_params(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    if ( defined $type_name ) {
        my $subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
        my $sub_classification_method_name = $class->__meta__->sub_classification_method_name;
        if ($sub_classification_method_name) {
            if ( $subclass_name->can($sub_classification_method_name)
                 eq $class->can($sub_classification_method_name)) {
                return $subclass_name;
            } else {
                return $subclass_name->$sub_classification_method_name(@_);
            }
        } else {
            return $subclass_name;
        }
    } else {
        return undef;
    }
}

sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    confess "No type name givent to resolve subclass name" unless $type_name;
    return 'Genome::ProcessingProfile::'.Genome::Utility::Text::string_to_camel_case($type_name);
}

sub _resolve_type_name_for_class {
    my $class = shift;
    my ($subclass) = $class =~ /^Genome::ProcessingProfile::([\w\d]+)$/;
    return unless $subclass;
    return Genome::Utility::Text::camel_case_to_string($subclass);
}

sub _expand_param_properties {
    my ($class, $desc) = @_;
    while (my ($prop_name, $prop_desc) = each(%{ $desc->{has} })) {
        if (exists $prop_desc->{'is_param'} and $prop_desc->{'is_param'}) {
            $prop_desc->{'to'} = 'value';
            $prop_desc->{'is_delegated'} = 1;
            $prop_desc->{'where'} = [
                'name' => $prop_name
            ];
            $prop_desc->{'via'} = 'params';
            $prop_desc->{'is_mutable'} = 1;
        }
    }

    return $desc;
}

sub _resolve_log_resource {
    my ($self, $event) = @_;
    $event->create_log_directory; # dies upon failure
    return ' -o '.$event->output_log_file.' -e '.$event->error_log_file;
}

sub _resolve_disk_group_name_for_build {
    return 'info_genome_models';
}

1;

