package Genome::Disk::GroupVolumeAssignment;

use strict;
use warnings;

class Genome::Disk::GroupVolumeAssignment {
    table_name => "(select * from disk_volume_group\@oltp) group_volume_assignment",
    id_by => [
              dg_id => {is => 'Number'},
              dv_id => {is => 'Number'},
          ],
    has => [
            group => {
                      is => 'Genome::Disk::Group',
                      id_by => 'dg_id',
                  },
            volume => {
                       is => 'Genome::Disk::Volume',
                       id_by => 'dv_id',
                   },
        ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;
