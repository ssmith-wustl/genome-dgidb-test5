package Genome::MiscNote;

use strict;
use warnings;

use Genome;
class Genome::MiscNote {
    type_name => 'misc note',
    table_name => 'MISC_NOTE',
    id_by => [
        id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        body_text          => { is => 'VARCHAR2', len => 1000 },
        editor_id          => { is => 'VARCHAR2', len => 200 },
        entry_date         => { is => 'DATE' },
        header_text        => { is => 'VARCHAR2', len => 200 },
        subject_class_name => { is => 'VARCHAR2', len => 255 },
        subject_id         => { is => 'VARCHAR2', len => 255 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
