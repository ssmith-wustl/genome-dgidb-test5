package Genome::Model::Command::AddReads::UploadDatabase;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddReads::UploadDatabase {
    is => ['Genome::Model::Command::DelegatesToSubcommand::WithRefSeq'],
};

sub sub_command_sort_position { 9 }

sub help_brief {
    "upload the current variation set to the medical genomics database";
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments upload-database --model-id 5 
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

    my $model = Genome::Model->get(id => $self->model_id);
    unless ($model) {
        $self->error_message("Can't retrieve genome model with ID ".$self->model_id);
        return;
    }

    return $model->genotyper_name;
}

sub is_not_to_be_run_by_add_reads {
    return 1;
}


1;

