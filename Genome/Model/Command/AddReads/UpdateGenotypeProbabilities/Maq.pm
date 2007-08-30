package Genome::Model::Command::AddReads::UpdateGenotypeProbabilities::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [ 
        model   => { is => 'String', is_optional => 0, doc => 'the genome model on which to operate' }
    ]
);

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_detail {                           
    return <<EOS 
not implemented
EOS
}

sub execute {
    my $self = shift;
    my $model = Genome::Model->get(name=>$self->model);
    $self->error_message("running " . $self->command_name . " on " . $model->name . "!");
    $self->status_message("Model Info:\n" . $model->pretty_print_text);
    return 0; 
}

1;

