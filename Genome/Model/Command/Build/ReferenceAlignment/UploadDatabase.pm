package Genome::Model::Command::Build::ReferenceAlignment::UploadDatabase;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::Build::ReferenceAlignment::UploadDatabase {
    is => ['Genome::Model::EventWithRefSeq'],
};

sub sub_command_sort_position { 90 }

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


sub command_subclassing_model_property {
    return 'genotyper_name';
}

sub is_not_to_be_run_by_add_reads {
    return 1;
}


1;

