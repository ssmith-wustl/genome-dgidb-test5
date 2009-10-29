package Genome::Model::Variant;

use strict;
use warnings;

use Genome;
class Genome::Model::Variant {
    type_name => 'genome model variant',
    table_name => 'GENOME_MODEL_VARIANT',
    id_by => [
        variant_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        chromosome         => { is => 'VARCHAR2', len => 255 },
        start_pos          => { is => 'NUMBER', len => 12 },
        stop_pos           => { is => 'NUMBER', len => 12 },
        reference_allele   => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        variant_allele     => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        amino_acid_change  => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        c_position         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        domain             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        gene_name          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        strand             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        transcript_name    => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        transcript_source  => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        transcript_status  => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        transcript_version => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        trv_type           => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        ucsc_cons          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        validation_status  => { is => 'VARCHAR2', len => 5, is_optional => 1 },
    ],
    unique_constraints => [
        { properties => [qw/chromosome reference_allele start_pos stop_pos variant_allele/], sql => 'GMV_UK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
