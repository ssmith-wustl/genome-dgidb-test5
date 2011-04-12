package Genome::Model::Tools::FastQual::SeqWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqWriter {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
    ],
};

1;

