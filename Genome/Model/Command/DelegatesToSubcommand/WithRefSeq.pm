package Genome::Model::Command::DelegatesToSubcommand::WithRefSeq;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::DelegatesToSubcommand',
    is_abstract => 1,
    has => [ 
             ref_seq_id => { is => 'Integer', doc => 'Identifies the refseq'},
           ], 
);


1;

