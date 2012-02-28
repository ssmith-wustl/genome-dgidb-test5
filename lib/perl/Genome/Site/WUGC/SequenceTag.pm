package Genome::Site::WUGC::SequenceTag; 

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::SequenceTag {
    table_name => 'GSC.SEQUENCE_TAG',
    id_by => [
        stag_id => {
            is => 'Text', 
            column_name => 'STAG_ID', 
        },
    ],
    has_optional => [
        ref_id => { 
            is => 'Text', 
            column_name => 'REF_ID',
        },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

