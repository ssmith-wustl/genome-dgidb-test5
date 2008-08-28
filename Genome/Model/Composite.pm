package Genome::Model::Composite;

use strict;
use warnings;

class Genome::Model::Composite{
    is => 'Genome::Model',
    is_abstract => 1, 
    id_by => 'model_id',
    has_many_optional => [
        child_bridges => { is => 'Genome::Model::CompositeMember', reverse_id_by => 'genome_model_composite'},
        child_models => { is => 'Genome::Model', via => 'child_bridges', to => 'genome_model_member'},
    ]
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    my @children = $self->child_models;
    foreach my $child_model(@children){
        $self->error_message("Child model supplied to constructor is invalid!") and die unless $self->_is_valid_child($child_model);
    }

    return $self;
}

sub _is_valid_child {
    my $self = shift;

    $self->error_message("abstract validation method _is_valid_child not overridden in class ". ref $self);
    return 0;
}

sub add_child_model{
    my ($self, $model) = @_;
    $self->error_message("no child model provided!") and die unless $model;
    $self->error_message("invalid child model provided!") and die unless $self->_is_valid_child($model);
    my $id = $self->id;
    my $child_id = $model->id;
    unless( $id and $child_id){
        $self->error_message ( "No value for this model id: <$id> or child id: <$child_id>");
        die;
    }
    my $bridge = Genome::Model::CompositeMember->create(composite_id => $id, member_id=> $child_id);
}

1;
