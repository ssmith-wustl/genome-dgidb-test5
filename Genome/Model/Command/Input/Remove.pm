package Genome::Model::Command::Input::Remove;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;

class Genome::Model::Command::Input::Remove {
    is => 'Genome::Model::Command::Input',
    english_name => 'genome model input command remove',
    doc => 'Remove inputs to a model.',
    has => [
    name => {
        is => 'Text',
        doc => 'The name of the input to remove. Use the plural property name - friends to remove a friend',
    },
    'values' => {
        is => 'Text',
        doc => 'The value(s) for the input. Separate multiple values by commas.'
    },
    ],
};

############################################

sub help_detail {
    return <<EOS;
    This command will remove inputs from a model. The input must be an 'is_many' property, meaning there must be more than one input allowed (eg: instrument_data). If the property only has one value, use the 'update' command.
    
    Use the plural name of the property. To remove multiple values, separate them by a comma.
EOS
}

############################################

sub execute {
    my $self = shift;

    unless ( $self->name ) {
        $self->error_message('No input name given to remove from model.');
        return;
    }

    my $property = $self->_get_is_many_input_property_for_name( $self->name )
        or return;

    unless ( defined $self->values ) {
        $self->error_message('No input values given to remove  from model.');
        $self->delete;
        return;
    }

    my @values = split(',', $self->values);
    unless ( @values ) {
        $self->error_message("No values found in split of ".$self->values);
        return;
    }
    
    my $sub = $self->_get_remove_sub_for_property($property)
        or return;

    for my $value ( @values ) {
        unless ( $sub->($value) ) {
            $self->error_message("Can't remove input '".$self->name." ($value) from model.");
            return;
        }
    }

    printf(
        "Removed %s (%s) from model.\n",
        ( @values > 1 ? $property->property_name : $property->singular_name ),
        join(', ', @values),
    );

    return 1; 
}

sub _get_remove_sub_for_property {
    my ($self, $property) = @_;

    my $property_name = $property->property_name;
    
    my $method = $self->_determine_and_validate_add_or_remove_method_name($property, 'remove')
        or return;
    
    #< Get the value class name or data type and createthe sub >#
    my ($value_class_name, $data_type);
    $self->_validate_where_and_resolve_value_class_name_or_data_type_for_property(
        $property, \$value_class_name, \$data_type
    ) or return;

    if ( $value_class_name ) {
        return sub{
            my $value = shift;
            
            my ($existing_value) = grep { $value eq $_ } $self->_model->$property_name;
            unless ( $existing_value ) {
                $self->error_message("Can't find existing value ($value) for model property ($property_name).");
                return;
            }

            return $self->_model->$method($value);
        };
    }

    return sub{
        my $value = shift;

        my ($existing_obj) = grep { $value eq $_->id } $self->_model->$property_name;
        unless ( $existing_obj ) {
            $self->error_message("Can't find existing $property_name ($data_type) for id ($value) to remove from model.");
            return;
        }

        return $self->_model->$method($existing_obj);
    };
}

1;

#$HeadURL$
#$Id$
