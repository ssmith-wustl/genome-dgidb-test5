package Genome::Info::SnapModelFileAbbreviations;

use strict;
use warnings;

my %model_files = (
    'A.canium.hmm' => 'sn_acan',
    'B.malayi.hmm' => 'sn_bmal',
    'bmal.intronset.hmm' => 'sn_bmal30',
    'C.elegans.hmm' => 'sn_cele',
    'caninum_cegma.hmm' => 'sn_accg',
    'caninum_maker.hmm' => 'sn_acmk',
    'spiralis_cegma_mod.hmm' => 'sn_tscg',
    'spiralis_cegma_mod_intron_min30.hmm' => 'sn_tscg30',
);

sub abbreviation_for_model_file {
    my $model_file = shift;
    return $model_files{$model_file};
}

1;

