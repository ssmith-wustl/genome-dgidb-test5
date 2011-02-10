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
        subject_attribute_id => {
            is => 'Number',
        },
    ],
    has => [
        nomenclature => {
            is => 'Text',
            default => 'WUGC',
        },
        attribute_label => {
            is => 'Text',
        },
        attribute_value => {
            is => 'Text',
        },
        subject_id => {
            is => 'Text',
        },
        subject => {
            is => 'Genome::Subject',
            id_by => 'subject_id',
        },
    ],
};

1;

