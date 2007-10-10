package Genome::Model::Command::PostprocessAlignments::MergeAlignments;

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
    "Merge any accumulated alignments on a model";
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments merge-alignments --model-id 5 
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by "postprocess alignments".  

It delegates to the appropriate sub-command for the aligner
specified in the model.
EOS
}

sub sub_command_delegator {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);
    unless ($model) {
        $self->error_message("Can't retrieve a Genome Model with ID ".$self->model_id);
        return;
    }

    return $model->read_aligner_name;
}
  
1;

