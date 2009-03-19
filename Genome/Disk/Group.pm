package Genome::Disk::Group;

use strict;
use warnings;

class Genome::Disk::Group {
    table_name => "(select * from disk_group\@oltp) disk_group",
    id_by => [
              dg_id => {is => 'Number'},
          ],
    has => [
            disk_group_name => { is => 'Text' },
            permissions => { is => 'Number' },
            sticky => { is => 'Number' },
            subdirectory => { is => 'Text' },
            unix_uid => { is => 'Number' },
            unix_gid => { is => 'Number' },
        ],
         has_many_optional => [
                          mount_paths => {
                                          via => 'volumes',
                                          to => 'mount_path',
                                      },
                          volumes => {
                                     is => 'Genome::Disk::Volume',
                                     via => 'assignments',
                                     to =>  'volume',
                                 },
                          assignments => {
                                          is => 'Genome::Disk::GroupVolumeAssignment',
                                          reverse_id_by => 'group',
                                      },
                      ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;
