package Genome::Disk::AllocationNew;

use strict;
use warnings;

use Genome;

class Genome::Disk::AllocationNew {
    id_by => [
        id => {
            is => 'Number',
            doc => 'The id for the allocator event',
        },
    ],
    has => [
        disk_group_name => {
            is => 'Text',
            doc => 'The name of the disk group',
        },
        mount_path => {
            is => 'Text',
            doc => 'The mount path of the disk volume',
        },
        allocation_path => {
            is => 'Text',
            doc => 'The sub-dir of the disk volume for which space is allocated',
        },
        kilobytes_requested => {
            is => 'Number',
            doc => 'The disk space allocated in kilobytes',
        },
        kilobytes_used => {
            is => 'Number',
            doc => 'The actual disk space used by owner',
        },
        owner_class_name => {
            is => 'Text',
            doc => 'The class name for the owner of this allocation',
        },
        owner_id => {
            is => 'Text',
            doc => 'The id for the owner of this allocation',
        },
        owner => { 
            id_by => 'owner_id', 
            is => 'UR::Object', 
            id_class_by => 'owner_class_name' 
        },
        group_subdirectory => {
            is => 'Text',
            doc => 'The group specific subdirectory where space is allocated',
        },
        absolute_path => {
            calculate_from => ['mount_path','group_subdirectory','allocation_path'],
            calculate => q|
                return $mount_path .'/'. $group_subdirectory .'/'. $allocation_path;
            |,
        },
    ],
    has_optional => [
        volume => { 
            is => 'Genome::Disk::Volume',
            calculate_from => 'mount_path',
            calculate => q{
                return Genome::Disk::Volume->get(mount_path => $mount_path);
            },
        }
    ],
    table_name => 'GENOME_DISK_ALLOCATION',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
