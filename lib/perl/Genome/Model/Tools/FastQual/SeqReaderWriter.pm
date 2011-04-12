package Genome::Model::Tools::FastQual::SeqReaderWriter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::SeqReaderWriter {
    is_abstract => 1,
    has => [
        files => { is => 'Text', is_many => 1, },
    ],
};

1;

