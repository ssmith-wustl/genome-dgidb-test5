package Genome::Model::Event::Build::ReferenceAlignment::FindVariations;

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

class Genome::Model::Event::Build::ReferenceAlignment::FindVariations {
    is => ['Genome::Model::Event'],
};

sub command_subclassing_model_property {
    return 'indel_finder_name';
}

1;

