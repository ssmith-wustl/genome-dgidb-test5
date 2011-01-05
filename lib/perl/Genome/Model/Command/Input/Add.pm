package Genome::Model::Command::Input::Add;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Command::Input::Add {
    is => 'Genome::Model::Command::Input',
    english_name => 'genome model input command add',
    doc => 'Add inputs to a model.',
    has => [
        name => {
            is => 'Text',
            shell_args_position => 2,
            doc => 'The name of the input to add. Use the plural property name - friends to add a friend',
        },
        'values' => {
            is => 'Text',
            is_many => 1,
            shell_args_position => 3,
            doc => 'The ids of the values of the inputs.'
        },
    ],
};

sub help_detail {
    return <<EOS;
    This command will add inputs from a model. The input must be an 'is_many' property, meaning there must be more than one input allowed (eg: instrument_data). If the property is singular, use the 'update' command.  Use the plural name of the property.
EOS
}

sub execute {
    my $self = shift;

    unless ( $self->name ) {
        $self->error_message('No input name given to add to model.');
        return;
    }

    my $property = $self->_get_is_many_input_property_for_name( $self->name )
        or return;

    my @values = $self->values;
    unless ( @values ) {
        $self->error_message('No input value ids given to add to model.');
        $self->delete;
        return;
    }

    my $sub = $self->_get_add_sub_for_property($property)
        or return;

    for my $value_id ( @values ) {
        unless ( $sub->($value_id) ) {
            $self->error_message("Can't add input ".$self->name." ($value_id) to model.");
            return;
        }
    }

    printf(
        "Added %s (%s) to model.\n",
        ( @values > 1 ? $property->property_name : $property->singular_name ),
        join(', ', @values),
    );

    return 1; 
}

sub _get_add_sub_for_property {
    my ($self, $property) = @_;

    my $property_name = $property->property_name;
    
    my $method = $self->_determine_and_validate_add_or_remove_method_name($property, 'add')
        or return;
    
    #< Get the value class name or data type and createthe sub >#
    my ($value_class_name, $data_type);
    $self->_validate_where_and_resolve_value_class_name_or_data_type_for_property(
        $property, \$value_class_name, \$data_type
    ) or return;

    if ( $value_class_name ) {
        return sub{
            my $value = shift;
            
            my ($existing_input) = grep { $value eq $_ } $self->model->$property_name;
            if ( $existing_input ) {
                $self->error_message("Value ($value) already exists for model property ($property_name).");
                return;
            }

            return $self->model->$method($value);
        };
    }

    return sub{
        my $value = shift;

        my $obj = $data_type->get($value);
        unless ( $obj ) {
            $self->error_message("Can't get $property_name ($data_type) for id: $value to add to model.");
            return;
        }

        return $self->model->$method($obj);
    };
}

1;

#$HeadURL$
#$Id$
