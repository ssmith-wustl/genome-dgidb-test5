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
            default_value => 'genome_model_id,name',
        },
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model' 
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

#Replace the default lister iterator with our own that just pulls the models for a group
sub _resolve_boolexpr { 
    my $self = shift;
    
    my @models = $self->model_group->models;

    my @model_ids = map($_->id, @models);

    if ($self->order_by) {
        return Genome::Model->define_boolexpr(id => \@model_ids, -order => $self->order_by);
    } else {
        return Genome::Model->define_boolexpr(id => \@model_ids);
    }
}

1;

