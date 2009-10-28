package Genome::Model::Command::Input::Names;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;
require Term::ANSIColor;

class Genome::Model::Command::Input::Names {
    is => 'Command',
    english_name => 'genome model input command names',
    doc => 'Lists the inputs names of a model type.',
    has => [
    type_name => {
        is => 'Text',
        doc => 'The type name of the model.'
    },
    ],
};

############################################

sub execute {
    my $self = shift;

    my $type_name = $self->type_name;
    unless ( $type_name ) {
        $self->error_message('No type name given to list model input names.');
        return;
    }

    my @valid_type_names= Genome::Model::Command->get_model_type_names;
    unless ( grep { $type_name eq $_ } @valid_type_names ) { 
        $self->error_message("Invalid type name ($type_name).  Please select from: ".join(', ', @valid_type_names));
        return;
    }

    my @properties = Genome::Model::Command::Input->input_properties_for_model_type($type_name);
    unless ( @properties ) {
        $self->status_message("No input properties for model type ($type_name)");
        return 1;
    }

    print(
        Term::ANSIColor::colored("Input properties for $type_name:", 'bold'),
        "\n",
    );

    for my $property ( @properties ) {
        printf(
            " %s (use %s to modify)\n",
            Term::ANSIColor::colored($property->singular_name, 'blue'),
            ( $property->is_many ? 'add/remove commands ' : 'update command' ),
        );
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
