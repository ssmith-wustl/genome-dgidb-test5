package EGAP::Protein;

use strict;
use warnings;

use EGAP;
class EGAP::Protein {
    type_name => 'protein',
    table_name => 'PROTEIN',
    id_sequence_generator_name => 'protein_id_seq',
    id_by => [
        protein_id => { is => 'NUMBER', len => 12 },
    ],
    has => [
        cellular_localization => { is => 'VARCHAR2', len => 25, is_optional => 1 },
        cog_id                => { is => 'VARCHAR2', len => 25, is_optional => 1 },
        enzymatic_pathway_id  => { is => 'VARCHAR2', len => 25, is_optional => 1 },
        internal_stops        => { is => 'NUMBER', len => 1 },
        protein_name          => { is => 'VARCHAR2', len => 60 },
        sequence_string       => { is => 'BLOB', len => 2147483647 },
        transcript            => { is => 'EGAP::Transcript', id_by => 'transcript_id', constraint_name => 'PROTEIN_GENE_ID_FK' },
        transcript_id         => { is => 'NUMBER', len => 11 },
    ],
    unique_constraints => [
        { properties => [qw/protein_name transcript_id/], sql => 'PROTEIN_GID_PNAME_U' },
    ],
    schema_name => 'EGAPSchema',
    data_source => 'EGAP::DataSource::EGAPSchema',
};

1;
