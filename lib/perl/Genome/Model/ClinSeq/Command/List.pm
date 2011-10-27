package Genome::Model::ClinSeq::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::ClinSeq::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model::ClinSeq' 
        },
        show => { default_value => 'id,name,wgs_data,exome_data,rna_data' },
    ],
    doc => 'list clinseq genome models',
};

1;

