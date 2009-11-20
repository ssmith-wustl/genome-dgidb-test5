package Genome::Model::Command::Build::ReferenceAlignment;

#REVIEW fdu 11/19/2009
#command_subclassing_model_property becomes obsolete because its
#subclass implement with their own command_subclassing_model_property

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment {
    is => 'Genome::Model::Command::Build',
    has => [],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "align reads to a reference genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build reference-alignment 
EOS
}

sub help_detail {
    return <<"EOS"
build a model of the alignment to a reference genome
EOS
}

sub command_subclassing_model_property {
    return 'sequencing_platform';
}

1;

