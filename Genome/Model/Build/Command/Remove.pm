package Genome::Model::Build::Command::Remove;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::Command::Remove {
    is => 'Genome::Command::Remove',
    has_input => [
        items => { 
            is => 'Genome::Model::Build',
            shell_args_position => 1,
            is_many => 1,
            doc => 'builds to remove, specified by id or expression'
        },
        keep_build_directory => {
            is => 'Boolean',
            default_value => 0,
            is_optional => 1,
            doc => 'A boolean flag to allow the retention of the model directory after the model is purged from the database.(default_value=0)',
        }    
    ],
    doc => 'delete a build and all of its data from the system',
};

sub sub_command_sort_position { 7 }

sub help_detail {
    "This command will remove a build from the system.  The rest of the model remains the same, as does independent data like alignments.";
}

sub execute {
    my $self = shift;
    $self->_deletion_params([keep_build_directory => $self->keep_build_directory]);
    return $self->SUPER::_execute_body();
}

1;
