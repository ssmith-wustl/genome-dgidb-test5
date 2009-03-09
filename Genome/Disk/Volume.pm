package Genome::Disk::Volume;

use strict;
use warnings;

class Genome::Disk::Volume {
    table_name => "(select * from disk_volume\@oltp) disk_volume",
    id_by => [
              dv_id => {is => 'Number'},
              ],
    has => [
            hostname => { is => 'Text' },
            physical_path => { is => 'Text' },
            mount_path => { is => 'Text' },
            total_kb => { is => 'Number' },
            unallocated_kb => { is => 'Number' },
            disk_status => { is => 'Text' },
            can_allocate => { is => 'Number' },
        ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;
