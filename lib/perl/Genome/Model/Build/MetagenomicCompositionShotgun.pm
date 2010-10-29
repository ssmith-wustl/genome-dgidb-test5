package Genome::Model::Build::MetagenomicCompositionShotgun;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::MetagenomicCompositionShotgun{
    is => 'Genome::Model::Build',
    has =>[
        _final_metagenomic_bam => {
            is_calculated => 1,
            calculate_from => ['data_directory'],
            calculate => sub {
                my ($data_directory) = @_;
                $data_directory."/metagenomic_alignment.combined.sorted.bam";
            },
        },
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

sub calculate_estimated_kb_usage {
    return 50_000_000;
}

1;

