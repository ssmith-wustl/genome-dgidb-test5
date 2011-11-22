package Genome::Site::WUGC::SetupWorkOrder; 

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::SetupWorkOrder {
    table_name => <<SQL
    (
        select wo.setup_wo_id id, s.setup_name name 
        from setup_work_order\@oltp wo
        join setup\@oltp s on s.setup_id = wo.setup_wo_id
        where wo.setup_wo_id > 2570000
    ) setup_work_order
SQL
    ,
    id_by => [
        id => { is => 'Text', },
    ],
    has => [
        name => { is => 'Text', },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    return $_[0]->name.' ('.$_[0]->id.')';
}

1;

