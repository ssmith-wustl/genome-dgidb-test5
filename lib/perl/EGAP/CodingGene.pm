package EGAP::CodingGene;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::CodingGene {
    type_name => 'coding gene',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::CodingGenes',
    id_by => [
        gene_name => { is => 'Text' },
        directory => { is => 'Path' },
    ],
    has => [
        fragment => { is => 'Boolean' },
        internal_stops => { is => 'Boolean' },
        missing_start => { is => 'Boolean' },
        missing_stop => { is => 'Boolean' },
        source => { is => 'Text' },
        strand => { is => 'Number' },
        sequence_name => { is => 'Number' },
        start => { is => 'Number' },
        end => { is => 'Number' },
    ],
};

1;
