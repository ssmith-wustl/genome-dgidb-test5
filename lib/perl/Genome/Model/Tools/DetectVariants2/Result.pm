package Genome::Model::Tools::DetectVariants2::Result;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result {
    is => ['UR::Value'],
    id_by => 'id',
    has => [
        id => { is => 'Text' },
    ],
    doc => 'This class represents the result of a variant detector or a filter.',
};

