package Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype;


#REVIEW fdu
#Fix out-of-date help_brief, help_synopsis, and help_detail

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype {
    is => ['Genome::Model::Event'],
};

sub command_subclassing_model_property {
    return 'genotyper_name';
}

1;

