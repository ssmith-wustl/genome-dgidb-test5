package Genome::Model::Command::AddReads::UpdateGenotype::BayesDiploid;

use strict;
use warnings;

use above "Genome";
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

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities bayes-diploid --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
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

