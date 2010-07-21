package Genome::Model::Build::MetagenomicCompositionShotgun;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::MetagenomicCompositionShotgun{
    is => 'Genome::Model::Build',
    has =>[
       _contamination_screen_alignment_build => {
           is => 'Genome::Model::Build::ReferenceAlignment',
           via => 'from_builds',
           where => [role => 'contamination_screen_alignment_build'],
       },
       _metagenomic_alignment_builds => {
           is => 'Genome::Model::Build::ReferenceAlignment',
           is_many => 1,
           via => 'from_builds',
           where => [role => 'metagenomic_alignment_build'],
       },
    ],
};

1;

