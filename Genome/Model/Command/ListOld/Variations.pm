# FIXME ebelter
#  remove
#
package Genome::Model::Command::List::Variations;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List::Variations {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
             is_constant => 1, 
            value => 'Genome::Model::VariationPosition' 
        },
        show => { default_value => 'ref_seq_name,position,reference_base,consensus_base,consensus_quality,read_depth,avg_num_hits,max_mapping_quality,min_conensus_quality' },
    ],
};


1;

