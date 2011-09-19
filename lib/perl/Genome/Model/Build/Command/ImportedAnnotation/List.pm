package Genome::Model::Build::Command::ImportedAnnotation::List;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::ImportedAnnotation::List {
    is => 'UR::Object::Command::List', 
    has => [
        show => {
            doc => 'properties of the member models to list (comma-delimited)',
            is_optional => 1,
            default_value => 'id,model_id,name,snapshot_date',
        },
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model::Build::ImportedAnnotation' 
        },
        filter => { #Provide a value to keep this from showing up in the options
            is_constant => 1,
            value => '',
            is_optional => 1,
        }
    ],
    doc => 'list the member models of a model-group',
};

sub help_synopsis {
    return <<"EOS"
genome model build imported-annotation list
EOS
}

sub help_brief {
    return "list imported annotation builds";
}

sub help_detail {                           
    return <<EOS 
List imported annotation builds
EOS
}

1;

