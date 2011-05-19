package Genome::Project;

use strict;
use warnings;
use Genome;

class Genome::Project {
    is => 'Genome::Notable',
    id_generator => '-uuid',
    id_by => [
        id => {
            is => 'Text',
        },
    ],
    has => [
        name => {
            is => 'Text',
            doc => 'name of the project',
        },
    ],
    has_many_optional => [
        parts => {
            is => 'Genome::ProjectPart',
            reverse_as => 'project',
        },
        entities => {
            via => 'parts',
            to => 'entity',
        },
    ],
    table_name => 'GENOME_PROJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'A project, can contain any number of objects (of any type)!',
};


1;

