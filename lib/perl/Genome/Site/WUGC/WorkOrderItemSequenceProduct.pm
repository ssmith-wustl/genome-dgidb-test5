package Genome::Site::WUGC::WorkOrderItemSequenceProduct; 

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::WorkOrderItemSequenceProduct {
    table_name => 'GSC.WOI_SEQUENCE_PRODUCT',
    id_by => [
        work_order_item => {
            is => 'Genome::WorkOrderItem',
            id_by => 'woi_id',
        },
        sequence_item => {
            is => 'Genome::Site::WUGC::SequenceItem',
            id_by => 'seq_id',
        },
    ],
    has_optional => [ 
        instrument_data => { # optional b/c seq item may be a read or entire region
            is => 'Genome::InstrumentData',
            id_by => 'seq_id',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

