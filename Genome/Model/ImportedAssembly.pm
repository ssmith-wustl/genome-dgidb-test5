package Genome::Model::ImportedAssembly;

use strict;
use warnings;

use Genome;

#CREATING MODEL SOLELY FOR TRACKING IT'S LOCATION
#VIA $model->data_directory

class Genome::Model::ImportedAssembly {
    is => 'Genome::Model',
};

1;
