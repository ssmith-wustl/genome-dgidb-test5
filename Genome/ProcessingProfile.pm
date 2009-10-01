package Genome::ProcessingProfile;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::Text;

class Genome::ProcessingProfile {
    type_name => 'processing profile',
    table_name => 'PROCESSING_PROFILE',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        name      => { is => 'VARCHAR2', is_optional => 1, len => 255, doc => 'Human readable name', },
        type_name => { is => 'VARCHAR2', is_optional => 1, len => 255, is_optional => 1, doc => 'The type of processing profile' },
    ],
    has_many_optional => [
        params => { is => 'Genome::ProcessingProfile::Param', reverse_id_by => 'processing_profile' },
        models => { is => 'Genome::Model', reverse_id_by => 'processing_profile' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

#< UR >#
sub create {
    my ($class, %params) = @_;

    # Name
    $class->_validate_name($params{name})
        or return;

    # Type name - confesses
    my $subclass;
    if ( $params{type_name} ) {
        $subclass = $class->_resolve_subclass_name_for_type_name($params{type_name});
        unless ( $subclass ) {
            confess "Can't resolve subclass for type name ($params{type_name})";
        }
    }
    else {
        confess __PACKAGE__." is a abstract base class, and no type name was provided to resolve to the appropriate subclass" if $class eq __PACKAGE__;
        $subclass = $class;
        $params{type_name} = $class->_resolve_type_name_for_class;
    }

    # Make sure subclass is a real class
    unless ( $subclass->can('get_class_object') ) {
        confess "Can't find meta for class ($class). Is type name ($params{type_name}) valid?";
    }

    # Identical PPs
    $subclass->_validate_no_existing_processing_profiles_with_idential_params(%params)
        or return;

    # Create
    return $class->SUPER::create(%params);
}

sub _validate_name {
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
        my $describer = Genome::ProcessingProfile::Command::Describe->create(
            processing_profile_id => $existing_name_pp->id,
        ) or confess "Can't create describe command to show existing processing profile";
        $describer->execute;
        $class->error_message("Processing profile (above) with same name ($name) already exists.");
        return;
    }

    return 1;
}

sub _validate_no_existing_processing_profiles_with_idential_params {
    my ($subclass, %params) = @_;
    $DB::single =1;
    # If no params, no need to check
    return 1 unless $subclass->params_for_class;

    # Get existing pp that have the same params
    delete $params{name};
    my @existing_pps = $subclass->get(%params);
    # none ok
    return 1 unless @existing_pps;

    # Collect the undef params.  This new pp may have one of these params undef'd
    my @undef_properties;
    for my $param ( $subclass->params_for_class ) {
        next if defined $params{$param};
        push @undef_properties, $param;
    }

    # Check the undef params.  If one is found return immediatly.
    for my $pp ( @existing_pps ) {
        next if grep { defined $pp->$_ } @undef_properties;
        my $describer = Genome::ProcessingProfile::Command::Describe->create(
            processing_profile_id => $pp->id,
        ) or confess "Can't create describe command to show existing processing profile";
        $describer->execute;
        $subclass->error_message("Found a processing profile with the same params as the one requested to create, but with a different name.  Please use this profile, or change a param.");
        return;
    }

    return 1;
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
#<>#

#< Params >#
sub params_for_class {
    #warn("params_for_class not implemented for class '$_[0]':  $!");
    return;
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

#< Building >#
sub stages {
    my $class = shift;
    $class = ref($class) if ref($class);
    die("Please implement stages in class '$class'");
}

sub classes_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $classes_method_name = $stage_name .'_job_classes';
    #unless (defined $self->can('$classes_method_name')) {
    #    die('Please implement '. $classes_method_name .' in class '. $self->class);
    #}
    return $self->$classes_method_name;
}

sub objects_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $model = shift;
    my $objects_method_name = $stage_name .'_objects';
    #unless (defined $self->can('$objects_method_name')) {
    #    die('Please implement '. $objects_method_name .' in class '. $self->class);
    #}
    return $self->$objects_method_name($model);
}

sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
}

#< SUBCLASSING >#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
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
        my $sub_classification_method_name = $class->get_class_object->sub_classification_method_name;
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

1;

#$HeadURL
#$Id
