package Genome::ProcessingProfileShortRead;

use strict;
use warnings;

use Genome;
class Genome::ProcessingProfileShortRead {
    type_name => 'processing profile short read',
    table_name => 'PROCESSING_PROFILE_SHORT_READ',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        indel_finder_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_aligner_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_name         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        indel_finder_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        sequencing_platform          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        align_dist_threshold         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_params       => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_aligner_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        multi_read_fragment_strategy => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        genotyper_params             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        reference_sequence_name      => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        genotyper_name               => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        prior_ref_seq                => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        dna_type                     => { is => 'VARCHAR2', len => 64, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
