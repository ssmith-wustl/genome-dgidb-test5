package Genome::ProjectPart;

use strict;
use warnings;
use Genome;

class Genome::ProjectPart {
    is => 'Genome::Notable',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        project_id => {
            is => 'Text',
            doc => 'ID of project this part belongs to',
        },
        project => {
            is => 'Genome::Project',
            id_by => 'project_id',
            doc => 'Project this part belongs to',
        },
        entity_class_name => { is => 'Text', column_name => 'PART_CLASS_NAME' },
        entity_id => { is => 'Text', column_name => 'PART_ID' },
        entity => {
            calculate_from => [ 'entity_class_name', 'entity_id' ],
            calculate => q{ return $entity_class_name->get($entity_id); },
            doc => 'Actual object this project part represents',
        },
        label => { is => 'Text' },
        role => { is => 'Text' },
    ],
    table_name => 'GENOME_PROJECT_PART',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Represents a single part of a project',
};

# This generates a unique text ID for the object. The format is <hostname> <PID> <time in seconds> <some number>
sub Genome::ProjectPart::Type::autogenerate_new_object_id {
    return $UR::Object::Type::autogenerate_id_base . ' ' . (++$UR::Object::Type::autogenerate_id_iter);
}


1;

