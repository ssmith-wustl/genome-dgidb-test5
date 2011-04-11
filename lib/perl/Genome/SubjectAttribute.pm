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
            column_name => 'ATTRIBUTE_LABEL',
        },
        subject_id => {
            is => 'Text',
            column_name => 'SUBJECT_ID',
        },
        attribute_value => {
            is => 'Text',
            column_Name => 'ATTRIBUTE_VALUE',
        },
    ],
    has => [        
        # TODO Should be in id_by, but currently can't have a property in id_by that
        # also has a default value
        nomenclature => {
            is => 'Text',
            column_name => 'NOMENCLATURE',
            default => 'WUGC',
        },
        subject => {
            is => 'Genome::Subject',
            id_by => 'subject_id',
        },
    ],
};

1;

