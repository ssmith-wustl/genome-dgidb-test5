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
    has_many_optional => [
                          disk_group_names => {
                                               via => 'groups',
                                               to => 'disk_group_name',
                                           },
                          groups => {
                                     is => 'Genome::Disk::Group',
                                     via => 'assignments',
                                     to =>  'group',
                                 },
                          assignments => {
                                          is => 'Genome::Disk::Assignment',
                                          reverse_id_by => 'volume',
                                      },
                          allocations => {
                                        is => 'Genome::Disk::Allocation',
                            calculate_from => 'mount_path',
                            calculate => q{
                                return Genome::Disk::Allocation->get(mount_path => $mount_path);
                            },
                          }
                      ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;
