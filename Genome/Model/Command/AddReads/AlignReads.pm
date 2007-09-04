package Genome::Model::Command::AddReads::AlignReads;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => ['Genome::Model::Command::DelegatesToSubcommand'],
);

sub sub_command_sort_position { 2 }

sub help_brief {
    "Run the aligner tool on the reads being added to the model"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "add reads".  

It delegates to the appropriate sub-command for the aligner
specified in the model.
EOS
}

sub sub_command_delegator {
    my $self = shift;

    my $model = Genome::Model->get(name => $self->model);
    return unless $model;

    return $model->read_aligner_name;
}
  
1;

