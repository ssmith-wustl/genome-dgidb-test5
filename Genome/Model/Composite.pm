package Genome::Model::Composite;

use strict;
use warnings;

class Genome::Model::Composite{
    is => 'Genome::Model',
    is_abstract =>, 
    id_by => 'model_id',
    has_many_optional => [
        child_bridges => { via => 'genome_model_composite_member', reverse_id_by => 'parent_id'},
        child_models => { is => 'Genome::Model', via => 'child_bridges', id_by => 'child_id'},
    ]
}

sub _is_child_valid{
    $self->error_message("abstract validation method _is_child_valid not overridden in class ". ref $self);
    return 0;
}

sub add_child_model{
    my ($self, $model) = @_;
    $self->error_message("no child model provided!") and die unless $model;
    $self->error_message("invalid child model provided!") and die unless $self->_is_child_valid($model);
    my $id = $self->id;
    my $child_id = $model->id;
    unless( $id and $child_id){
        $self->error_message ( "No value for this model id: <$id> or child id: <$child_id>");
        die;
    }
    my $bridge = Genome::Model::Composite::Member->create(parent_id => $id, child_id => $child_id);
    UR::Context->commit;
}
