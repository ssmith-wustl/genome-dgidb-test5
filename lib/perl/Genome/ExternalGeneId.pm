package Genome::ExternalGeneId;

use strict;
use warnings;

use Genome;

class Genome::ExternalGeneId {
    type_name => 'genome external gene id',
    table_name => 'EXTERNAL_GENE_ID',
    id_by => [
        egi_id => { is => 'UR::Value::Number' },
        species => { is => 'varchar',
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            is_optional => 1,
        },
        version => { is => 'VARCHAR',
            is_optional => 1,
        },
    ],
    has => [
        gene_id => { is => 'Text' },
        id_type => { is => 'Text' },
        id_value => { is => 'Text' },
        data_directory => {
                    is => "Path",
        },
        gene => {
            calculate_from => [qw/ gene_id data_directory/],
            calculate => q|
                Genome::Gene->get(id => $gene_id, data_directory => $data_directory);
            |,
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::ExternalGeneIds',
};

1;

