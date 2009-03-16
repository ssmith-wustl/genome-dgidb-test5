package Genome::ExternalGeneId;

use strict;
use warnings;

use Genome;

class Genome::ExternalGeneId {
    type_name => 'genome external gene id',
    table_name => 'EXTERNAL_GENE_ID',
    id_by => [
        egi_id => { is => 'NUMBER' },
    ],
    has => [
        gene_id => { is => 'NUMBER' },
        id_type => { is => 'String' },
        id_value => { is => 'String' },
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
        },
        gene => {
            calculate_from => [qw/ gene_id build_id/],
            calculate => q|
                Genome::GeneId->get(gene_id => $gene_id, build_id => $build_id);
            |,
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::ExternalGeneIds',
};

1;

