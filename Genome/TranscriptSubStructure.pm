package Genome::TranscriptSubStructure;

use strict;
use warnings;

use Genome;

class Genome::TranscriptSubStructure {
    type_name => 'genome transcript sub structure',
    table_name => 'TRANSCRIPT_SUB_STRUCTURE',
    id_by => [
        transcript_structure_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        transcript_id => { is => 'NUMBER', len => 10 },
        structure_type => { is => 'VARCHAR', len => 10, is_optional => 1 },
        structure_start => { is => 'NUMBER', len => 10, is_optional => 1 },
        structure_stop => { is => 'NUMBER', len => 10, is_optional => 1 },
        ordinal => { is => 'NUMBER', len => 10, is_optional => 1},
        phase => { is => 'NUMBER', len => 7, is_optional => 1},
        nucleotide_seq => { is => 'CLOB', is_optional => 1},

        transcript => { is => 'Genome::Transcript', id_by => 'transcript_id' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::TranscriptSubStructures',
};


1;
