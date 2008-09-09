
package Genome::Model::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List { 
    is => ['Genome::Model::Command', 'UR::Object::Command::List'],
};

sub sub_command_sort_position { 2 }

sub help_brief {
    "list information about genome models and available runs"
}

sub help_synopsis {
    return <<"EOS"
    genome-model list
EOS
}

sub help_detail {
    return <<"EOS"
List items related to genome models.
EOS
}

sub create {
    my $self = shift->SUPER::create(@_);
    if ($self->model_id) {
        my $filter = $self->filter;
        if ($filter) {
            $filter .= "," if $filter;
        }
        else {
            $filter = '';
        }
        $filter .= 'model_id=' . $self->model_id;
    }
    return $self;
}


1;

