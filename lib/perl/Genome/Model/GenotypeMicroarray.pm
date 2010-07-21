package Genome::Model::GenotypeMicroarray;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sort::Naturally;
use IO::File;

class Genome::Model::GenotypeMicroarray{
    is => 'Genome::Model',
    has => [
        input_format    => { via => 'processing_profile' },
        instrument_type => { via => 'processing_profile' },
    ],
};

1;

