package Genome::Site::WUGC::ProjectWorkOrder; 

use strict;
use warnings;

class Genome::Site::WUGC::ProjectWorkOrder {
    table_name => '(select * from PROJECT_WORK_ORDER@oltp) project_work_order',
    id_by => [
        project_id => { is => 'Number', len => 10, column_name => 'PROJECT_ID' },
        setup_wo_id => { is => 'Number', column_name => 'SETUP_WO_ID' }
    ],
    has => [
        creation_event_id => { is => 'Number', column_name => 'CREATION_EVENT_ID' },
        administration_project => { is => 'Genome::Site::WUGC::AdministrationProject', id_by => 'project_id' },
    ],
    doc => 'LIMS bridge table',
    data_source => 'Genome::DataSource::GMSchema',
};


1;


#PROJECT_WORK_ORDER  GSC::ProjectWorkOrder   oltp    production
#
#    CREATION_EVENT_ID creation_event_id NUMBER(10)  (fk)    
#    PROJECT_ID        project_id        NUMBER(10)  (pk)(fk)
#    SETUP_WO_ID       setup_wo_id       NUMBER(10)  (pk)(fk)



