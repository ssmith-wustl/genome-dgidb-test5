package Genome::Model::Command::Input;

use strict;
use warnings;

use Genome;
      
use Genome::Utility::Text;
use Carp 'confess';

class Genome::Model::Command::Input {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    english_name => 'genome model input command',
    has => [
        model => { 
            is => 'Genome::Model',
            shell_args_position => 1,
            doc => 'Model to modify inputs. Resolved from command line via text string.',
        },
    ],
    doc => 'work with model inputs.',
};

############################################

sub help_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->get_class_object->doc if not $class or $class eq __PACKAGE__;
    my ($func) = $class =~ /::(\w+)$/;
    return sprintf('%s a model input', ucfirst($func));
}

sub help_detail {
    return help_brief(@_);
}

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model input';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'input';
}

############################################

#< Input Properties >#
sub input_properties_for_model_type {
    my ($self, $type_name) = @_;

    confess "No type name given to get input properties." unless $type_name;

    my $model_class = 'Genome::Model::'.Genome::Utility::Text::string_to_camel_case($type_name);
    my $model_class_meta = $model_class->__meta__;
    
    return grep { $_->via and $_->via eq 'inputs' } $model_class_meta->direct_property_metas;
}

sub _get_input_property_for_name {
    my ($self, $name) = @_;

    my $model_class_meta = $self->model->__meta__;
    
    my $property = $model_class_meta->property_meta_for_name($name);
    unless ( $property ) {
        $self->error_message("Can't find property for name ($name)");
        return;
    }

    while ($property->via) {
        if ($property->via eq 'inputs') {
            return $property;
        }
        $property = $model_class_meta->property_meta_for_name($property->via);
    }

    $self->error_message("Property ($name) is not a model input, and  cannot be modified by this command.");
    return;
}

sub _get_singular_input_property_for_name { # this requires that the input property is 'is_many'
    my ($self, $name) = @_;

    my $property = $self->_get_input_property_for_name($name)
        or return;

    if ( $property->is_many ) {
        $self->error_message("Found input ($name), but it is an 'is_many' property (not singular). Use the 'add' or 'remove' commands to modify this input.");
        return;
    }

    return $property;
}

sub _get_is_many_input_property_for_name { # this requires that the input property is 'is_many'
    my ($self, $name) = @_;

    my $property = $self->_get_input_property_for_name($name)
        or return;

    unless ( $property->is_many ) {
        $self->error_message("Found input ($name), but it is a singular property (not 'is_many').  Use the 'update' command to modify this input.");
        return;
    }

    return $property;
}

sub _determine_and_validate_add_or_remove_method_name {
    my ($self, $property, $add_or_remove) = @_;

    # derive form subclass if not given
    unless ( $add_or_remove ) { # Get add or remove from class name
        my ($subclass) = $self->class =~ /::([\w\d]+)$/;
        unless ( $subclass ) {
            $self->error_message('Trying to determine add or remove method, and was not given which to get, so attempted to resolve subclass from class ('.$self->class.') and could not.');
            return;
        }
        $add_or_remove = lc $subclass;
    }

    # Make sure it's add/remove
    unless ( grep { $add_or_remove eq $_ } (qw/ add remove /) ) {
        $self->error_message("Trying to determine add or remove method, and was given (or derived from subclass) the value '$add_or_remove'. This needs to be 'add' or 'remove'.");
        return;
    }
    
    # Validate that the model can add this property
    my $method = $add_or_remove.'_'.$property->singular_name;
    unless ( $self->model->can($method) ) {
        $self->error_message(
            sprintf(
                "Found model input property (%s), but model can't %s it using '%s'",
                $self->name,
                $add_or_remove,
                $method,
            ),
        );
        return;
    }

    return $method;
}

sub _validate_where_and_resolve_value_class_name_or_data_type_for_property {
    # NOTE: value_class_name and data_type are scalar references
    my ($self, $property, $value_class_name, $data_type) = @_;

    my $property_name = $property->property_name;
    my $where = $property->where;
    unless ( $where ) {
        $self->error_message("No where clause found for input property, $property_name. This is required to at least have an attribut 'name', and optionally, 'value_class_name.'");
        return;
    }

    # where has gotta have 'name'
    my %where = @$where;
    unless ( exists $where{name} ) {
        $self->error_message("The where clause for input property, $property_name, does not have required attribute 'name.'");
        return;
    }

    if ( exists $where{value_class_name} ) {
        $$value_class_name = $where{value_class_name};
        return 1;
    }

    $$data_type = $property->data_type;
    unless ( $data_type ) {
        $self->error_message("Can't determine value_class_name for input property ".$property->property_name.". Tried looking in the 'where' clause and data_type");
        return;
    }

    # Make sure the data_type is not some primitive class or a UR::Object
    if ( grep { $data_type eq $_ } (qw/ Number Real Integer Text UR::Object /) ) {
        $self->error_message('Trying to resolve the add or remove sub for property '.$property->property_name.', but can\'t resolve the value_class_name.  It is not in the where clause, and no data_type is set.');
        return;
    }

    return 1;
}

1;

