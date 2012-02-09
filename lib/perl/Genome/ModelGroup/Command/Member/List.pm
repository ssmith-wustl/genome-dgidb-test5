package Genome::ModelGroup::Command::Member::List;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member::List {
    is => 'UR::Object::Command::List',
    has => [
        model_group => { is => 'Genome::ModelGroup', id_by => 'model_group_id' },
        show => {
            doc => 'properties of the member models to list (comma-delimited)',
            is_optional => 1,
            default_value => 'id,name',
        },
        subject_class_name  => {
            is_constant => 1,
            value => 'Genome::Model'
        },
    ],
    doc => 'list the member models of a model-group',
};

sub help_synopsis {
    return <<"EOS"
genome model-group member list --model-group-id 21
EOS
}

sub help_brief {
    return "list the members of a model-group";
}

sub help_detail {
    return <<EOS
List the member models for a model-group.
EOS
}

sub _resolve_boolexpr {
    my $self = shift;

    my $bx = $self->SUPER::_resolve_boolexpr(@_);

    my @model_ids = map { $_->id } $self->model_group->models;
    $bx = $bx->add_filter(id => \@model_ids);

    return $bx;
}

1;

