package Genome::Disk::Assignment;

use strict;
use warnings;

class Genome::Disk::Assignment {
    # TODO This is really really site specific and needs to be changed
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
	    percent_full => {
		    calculate_from => ['absolute_path'],
			calculate => q|
			    my @pct_full = `df -h $absolute_path`;
				my @split_pct_full = split(/%/,$pct_full[-1]);
				@split_pct_full = split (/ /,$split_pct_full[0]);
				return $split_pct_full[-1]; |,
		},
        absolute_path => {
            calculate_from => ['mount_path','subdirectory'],
            calculate => q| return $mount_path .'/'. $subdirectory; |,
        },
    ],
    data_source => 'Genome::DataSource::Oltp',
};

1;
