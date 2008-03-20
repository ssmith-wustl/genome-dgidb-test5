
package Genome::Model::Command::Remove;

use strict;
use warnings;

use above "Genome";
use Command; 
use Data::Dumper;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        model_name    => { is => 'String', doc => 'Identify a model by name', is_optional => 1 },
        model_id      => { is => 'Integer', doc => 'Identify a model by id', is_optional => 1 },
    ]
);

sub help_brief {
    "remove a genome-model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model remove --model-name 'Foo Bar Model'
EOS
}

sub help_detail {
    return <<"EOS"
This command deletes the specified genome models.  Either --model-name or --model-id are required, but not both.
EOS
}

sub execute {
    my $self = shift;    

$DB::single=1;
    unless ($self->model_name || $self->model_id) {
        $self->error_message("either model_name or model_id are required");
        return
    }
    if ($self->model_name && $self->model_id) {
        $self->error_message("cannot specify both a model name and id");
        return;
    }

    my %args;
    if ($self->model_name) {
        %args = ( name => $self->model_name);
    } else {
        %args = ( genome_model_id => $self->model_id);
    }
    my @models = Genome::Model->get(%args);
    unless (@models) {
        $self->error_message("No model found matching those params");
        return;
    } 
    for (@models) {
        $self->status_message("Removing " . $_->name . "(id " . $_->id . ")...");
        $_->delete;
    }

}

1;

sub sub_command_sort_position { 6 }
