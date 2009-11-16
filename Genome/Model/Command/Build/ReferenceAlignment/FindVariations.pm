package Genome::Model::Command::Build::ReferenceAlignment::FindVariations;

#REVIEW fdu
#1. Fix out-of-date help_brief/synopsis/detail
#2. indel_finder_name is a really bad name for this because the
#process in FindVariation step generates both indel and snp output. We
#should change indel_finder_name/version/params to
#variant_finder_name/version/params in
#G::ProcessingProfile::ReferenceAlignment and replace indel_finder_xxx
#with variant_finer_xxxx cross all pipeline codes


use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations {
    is => ['Genome::Model::Event'],
};

sub sub_command_sort_position { 80 }

sub help_brief {
    "identify genotype variations"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads find-variations --model-id 5 --ref-seq-id all_sequences
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
    return 'indel_finder_name';
}

1;

