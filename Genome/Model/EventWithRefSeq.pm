package Genome::Model::EventWithRefSeq;

use strict;
use warnings;

use above "Genome";
use Genome::Model::Event; 

class Genome::Model::EventWithRefSeq {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
        ref_seq_id => { is => 'Integer', doc => 'Identifies the refseq'},
    ],
};


1;

