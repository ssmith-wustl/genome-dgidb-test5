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
    data_source => 'Genome::DataSource::GMSchema',
};

sub group_volume_assignments {
    my $self = shift;
    return Genome::Disk::GroupVolumeAssignment->get(dg_id => $self->dg_id);
}

sub volumes {
    my $self = shift;
    my @group_volume_assignments = $self->group_volume_assignments;
    my @volumes = map { $_->volume } @group_volume_assignments;
    return @volumes;
}

1;
