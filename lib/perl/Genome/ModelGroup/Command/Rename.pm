package Genome::ModelGroup::Command::Rename;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Rename {
    is => 'Genome::Command::Base',
    has => [
        from => {
            is => 'Genome::ModelGroup',
            id_by => 'group_id',
            shell_args_position => 1,
            doc => 'the model to rename, specified by name or id',
        },
        to => {
            is => 'Text',
            shell_args_position => 2,
            doc => 'the new name',
        },
    ],
    doc => "change the name of a model-group (not the models in the group)",
};

sub sub_command_sort_position { 5 }

sub help_synopsis {
    return <<"EOS"
    genome model-group rename OLDNAME NEWNAME
    genome model-group rename 12345 NEWNAME
EOS
}

sub execute {
    my $self = shift;

    if ( $self->to eq $self->from->name ) {
        $self->error_message("New name is the same as the model's current name.");
        return;
    }

    my $old_name = $self->from->name;
    $self->from->name( $self->to );

    unless ( $self->to eq $self->from->name ) {
        $self->error_message(
            sprintf(
                'Could not rename model (<Id> %s <Name> %s) to new name (%s) for unkown reasons', 
                $self->from->id, 
                $self->from->name, 
                $self->to,
            )
        );
        return;
    }

    printf(
        "Renamed model (<Id> %s) from %s to %s\n",
        $self->from->id, 
        $old_name,
        $self->from->name,
    );

    return 1;
}

1;

