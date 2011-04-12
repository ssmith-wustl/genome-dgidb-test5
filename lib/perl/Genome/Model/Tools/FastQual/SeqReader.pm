package Genome::Model::Tools::FastQual::SeqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqReader {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
    ],
};

1;

