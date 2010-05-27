package Genome::WorkOrder;

use strict;
use warnings;

use Genome;

class Genome::WorkOrder {
    table_name => '(SELECT * FROM setup_work_order@oltp) work_order',
    id_by => [
        id => {
            is => 'Integer',
            len => 10,
            column_name => 'SETUP_WO_ID',
        },
    ],    
    has => [
        acct_id => {
            is => 'Integer',
            len => 10,
        },
        wo_facilitator => {
            is => 'Integer',
            len => 10,
        },
        deadline => {
            is => 'Date',
        },
        project_tracking_number => {
            is => 'Text',
            len => 32,
        },
        pipeline => {
            is => 'Text',
            len => 256,
        },
        project_id => {
            is => 'Integer',
            len => 10,
        },
        project => { 
            is => 'Genome::Project', 
         id_by => 'project_id' 
        },
        file_storage_id => {
            is => 'Integer',
            len => 20,
        },
        estimate_file_storage_id => {
            is => 'Integer',
            len => 20,
        },
        estimate_id => {
            is => 'Text',
            len => 32,
        },
        is_test => {
            is => 'Integer',
            len => 1,
        },
        setup_ss_id => {
            is => 'Integer',
            len => 10,
        },
        barcode => {
            is => 'Text',
            len => 16,
        },
        requester_gu_id => {
                is => 'Integer',
                len => 10,
        },
        models => {
            is => 'Genome::Model',
            via => 'items',
            to => 'models',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub items {
    return Genome::WorkOrderItem->get(setup_wo_id => $_[0]->id);
}

#$HeadURL$
#$Id$
