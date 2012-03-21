package Genome::Disk::Assignment;

use strict;
use warnings;

class Genome::Disk::Assignment {
    table_name => 'DISK_VOLUME_GROUP',
    id_by => [
        dg_id => {
            is => 'Number',
            doc => 'disk group ID',
        },
        dv_id => {
            is => 'Number',
            doc => 'disk volume ID'
        },
    ],
    has => [
        group => {
            is => 'Genome::Disk::Group',
            id_by => 'dg_id',
        },
        disk_group_name => { via => 'group' },
        user_name => { via => 'group' },
        group_name => { via => 'group' },
        subdirectory => { via => 'group' },
        volume => {
            is => 'Genome::Disk::Volume',
            id_by => 'dv_id',
        },
        mount_path => { via => 'volume' },
        total_kb   => { via => 'volume' },
        unallocated_kb => { via => 'volume' },
        percent_allocated => { via => 'volume' },
        percent_used => { via => 'volume' },
        absolute_path => {
            calculate_from => ['mount_path','subdirectory'],
            calculate => q| return $mount_path .'/'. $subdirectory; |,
        },
    ],
    data_source => 'Genome::DataSource::Oltp',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_) or die "Could not create group assignment!";

    my $volume = $self->volume;
    unless ($volume) {
        $self->delete;
        die "Could not get volume for group assignment!";
    }

    my $group = $self->group;
    unless ($group) {
        $self->delete;
        die "Could not get group from group assignment!";
    }

    my $path = join('/', $volume->mount_path, $group->subdirectory);
    unless (-d $path) {
        unless (Genome::Sys->create_directory($path)) {
            die "Could not create $path!";
        }
    }

    return $self;
}


1;
