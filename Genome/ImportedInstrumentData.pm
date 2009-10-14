package Genome::ImportedInstrumentData;

use strict;
use warnings;

use Genome;
class Genome::ImportedInstrumentData {
    type_name => 'imported instrument data',
    table_name => 'IMPORTED_INSTRUMENT_DATA',
    id_by => [
        id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        base_count          => { is => 'NUMBER', len => 20, is_optional => 1 },
        description         => { is => 'VARCHAR2', len => 512, is_optional => 1 },
        import_date         => { is => 'DATE' },
        import_format       => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        import_source_name  => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        original_data_path  => { is => 'VARCHAR2', len => 256 },
        read_count          => { is => 'NUMBER', len => 20, is_optional => 1 },
        sample_id           => { is => 'NUMBER', len => 20 },
        sample_name         => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        sequencing_platform => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        user_name           => { is => 'VARCHAR2', len => 256 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
