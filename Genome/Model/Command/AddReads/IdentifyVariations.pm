package Genome::Model::Command::AddReads::IdentifyVariations;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::DelegatesToSubcommand',
);

sub sub_command_sort_position { 4 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the genotyper
specified in the model.
EOS
}

sub sub_command_delegator {
    my $self = shift;

    my $model = Genome::Model->get(name => $self->model);
    return unless $model;

    return $model->indel_finder_name;
}


1;

