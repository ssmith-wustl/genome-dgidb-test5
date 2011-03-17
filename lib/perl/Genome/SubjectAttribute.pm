package Genome::SubjectAttribute;

use strict;
use warnings;
use Genome;

class Genome::SubjectAttribute {
    table_name => 'GENOME_SUBJECT_ATTRIBUTE',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Represents a particular attribute of a subject',
    id_by => [
        attribute_label => {
            is => 'Text',
        },
        subject_id => {
            is => 'Text',
        },
        attribute_value => {
            is => 'Text',
        },
    ],
    has => [
        nomenclature => {
            is => 'Text',
            default => 'WUGC',
        },
        subject => {
            is => 'Genome::Subject',
            id_by => 'subject_id',
        },
    ],
};

1;

