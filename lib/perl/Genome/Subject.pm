package Genome::Subject;

use strict;
use warnings;
use Genome;

class Genome::Subject {
    is => 'Genome::Notable',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        subject_id => {
            is => 'Text',
        },
    ],
    has => [
        subclass_name => {
            is => 'Text',
        },
    ],
    has_many => [
        attributes => {
            is => 'Genome::SubjectAttribute',
            reverse_as => 'subject',
        },
    ],
    has_optional => [
        name => {
            is => 'Text',
        },
        description => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'description' ],
        },
        nomenclature => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'nomenclature', nomenclature => 'WUGC' ],
        },
    ],
    table_name => 'GENOME_SUBJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Contains all information about a particular subject (library, sample, etc)',
};

1;

