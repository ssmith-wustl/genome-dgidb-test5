package Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::MergeAlignments {
    is => ['Genome::Model::Event'],
};

sub command_subclassing_model_property {
    return 'read_aligner_name';
}

sub is_not_to_be_run_by_add_reads {
    return 1;
}
  
1;

