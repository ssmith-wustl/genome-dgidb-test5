package Genome::Model::Command::Input::Update;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Command::Input::Update {
    is => 'Genome::Model::Command::Input',
    english_name => 'genome model input command add',
    doc => 'Update inputs to a model.',
    has => [
        name => {
            is => 'Text',
            shell_args_position => 2,
            doc => 'The name of the input to add. Use the plural property name - friends to add a friend',
        },
        value => {
            is => 'Text',
            shell_args_position => 3,
            doc => "The value to set for the input. To undefine property, use an empty string ('').",
        },
    ],
};

sub help_detail {
    return <<EOS;
    This command will update an input from a model. The input must be an singular property, meaning there must be only one value (not 'is_many'). If the property has more one value, use the 'add' or 'remove' commands to modify the input.
EOS
}

sub execute {
    my $self = shift;

    my $name = $self->name;
    unless ( $name ) {
        $self->error_message('No name given to update model input.');
        return;
    }

    my $property = $self->_get_singular_input_property_for_name($name)
        or return;

    my $value = $self->value;
    unless ( defined $value ) {
        $self->error_message('No value given to update model input.');
        $self->delete;
        return;
    }

    my $rv = $self->model->$name($value);
    #print Data::Dumper::Dumper({$name=>$rv});
    if ( not defined($rv) or $rv ne $value ) {
        $self->error_message("Can't update $name to '$value'.");
        return;
    }

    $self->status_message("Updated $name to ".( $value eq '' ? 'undef' : $value));

    return 1;
}

1;

