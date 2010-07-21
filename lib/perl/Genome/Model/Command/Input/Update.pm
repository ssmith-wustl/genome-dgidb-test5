package Genome::Model::Command::Input::Update;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;

class Genome::Model::Command::Input::Update {
    is => 'Genome::Model::Command::Input',
    english_name => 'genome model input command add',
    doc => 'Update inputs to a model.',
    has => [
    name => {
        is => 'Text',
        doc => 'The name of the input to add. Use the plural property name - friends to add a friend',
    },
    value => {
        is => 'Text',
        doc => 'The value to set for the input. To undefine property, use string "UNDEF" as value.',
    },
    ],
};

############################################

sub help_detail {
    return <<EOS;
    This command will update an input from a model. The input must be an singular property, meaning there must be only one value (not 'is_many'). If the property has more one value, use the 'add' or 'remove' commands to modify the input.
EOS
}

############################################

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

    # Support setting input to undef - Special handling because the property
    #  does not return undef, it returns an empty string
    if ( $value eq 'UNDEF' ) { 
        $self->_undef_input($name) or return;
    }
    else {
        $self->_set_input($name, $value) or return;
    }

    print "Updated $name to '$value.'\n";

    return 1;
}

sub _set_input {
    my ($self, $name, $value) = @_;

    my $rv = $self->_model->$name($value);
    #print Data::Dumper::Dumper({$name=>$rv});
    if ( not defined($rv) or $rv ne $value ) {
        $self->error_message("Can't update $name to '$value'.");
        return;
    }
 
    return 1;
}

sub _undef_input {
    my ($self, $name) =@_;

    my $rv = $self->_model->$name(undef); # this returns an empty string and not undef
    #print Data::Dumper::Dumper({$name=>$rv});
    if ( defined($rv) and $rv ne '' ) { # have defined here in case this starts working
        $self->error_message("Can't update $name to 'undef'.");
        return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
