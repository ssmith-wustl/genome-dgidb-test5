package Genome::ProjectPart;

use strict;
use warnings;
use Genome;

class Genome::ProjectPart {
    is => 'Genome::Notable',
    id_generator => '-uuid',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        entity_class_name => { is => 'Text', column_name => 'PART_CLASS_NAME' },
        entity_id => { is => 'Text', column_name => 'PART_ID' },
        entity => { is => 'entity_class_name', id_by => 'entity_id' },
        entity => {
            is => 'UR::Object',
            id_by => 'entity_id',
            id_class_by => 'entity_class_name',
            doc => 'Actual object this project part represents',
        },
        project => {
            is => 'Genome::Project',
            id_by => 'project_id',
            doc => 'Project this part belongs to',
        },
    ],
    has_optional => [
        label => { is => 'Text' },
        role => { is => 'Text' }
    ],
    table_name => 'GENOME_PROJECT_PART',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Represents a single part of a project',
};


1;
