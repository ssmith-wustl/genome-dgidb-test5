package Genome::Disk::Volume;

use strict;
use warnings;

class Genome::Disk::Volume {
    table_name => 'DISK_VOLUME',
    id_by => [
        dv_id => {is => 'Number'},
    ],
    has => [
        hostname => { is => 'Text' },
        physical_path => { is => 'Text' },
        mount_path => { is => 'Text' },
        disk_status => { is => 'Text' },
        can_allocate => { is => 'Number' },
        total_kb => { is => 'Number' },
        total_gb => {
            calculate_from => 'total_kb',
            calculate => q{ return int($total_kb / (2**20)) },
        },
        unallocated_kb => { is => 'Number' },
        unallocated_gb => {
            calculate_from => 'unallocated_kb',
            calculate => q{ return int($unallocated_kb / (2**20)) },
        },
        allocated_kb => { 
            calculate_from => ['total_kb','unallocated_kb'],
            calculate => q{ return ($total_kb - $unallocated_kb); },
        },
        percent_allocated => {
            calculate_from => ['total_kb', 'allocated_kb'],
            calculate => q{ return sprintf("%.2f", ( $allocated_kb / $total_kb ) * 100); },
        },
        used_kb => {
            calculate_from => ['mount_path'],
            calculate => sub { 
                my $mount_path = shift; 
                my ($used_kb) = qx(df -k $mount_path | grep $mount_path | awk '{print \$3}') =~ /(\d+)/; 
                return $used_kb
            },
        },
        percent_used => {
            calculate_from => ['total_kb', 'used_kb'],
            calculate => sub { my ($total_kb, $used_kb) = @_; return sprintf("%.2f", ( $used_kb / $total_kb ) * 100); },
        },
        unallocatable_reserve_size => {
            calculate_from => ['total_kb', 'unallocatable_volume_percent', 'maximum_reserve_size'],
            calculate => q{
                my $buffer = int($total_kb * $unallocatable_volume_percent);
                $buffer = $maximum_reserve_size if $buffer > $maximum_reserve_size;
                return $buffer;
            },
            doc => 'Size of reserve in kb that cannot be allocated to but can still be used by reallocations',
        },
        unusable_reserve_size => {
            calculate_from => ['total_kb', 'unusable_volume_percent', 'unallocatable_reserve_size'],
            calculate => q{
                my $buffer = int($total_kb * $unusable_volume_percent);
                $buffer = $unallocatable_reserve_size if $buffer > $unallocatable_reserve_size;
                return $buffer;
            },
            doc => 'Size of reserve in kb that cannot be allocated to in any way',
        },
        allocatable_kb => {
            calculate_from => ['unallocated_kb', 'unallocatable_reserve_size'],
            calculate => q{ 
                my $allocatable = $unallocated_kb - $unallocatable_reserve_size;
                $allocatable = 0 if $allocatable < 0;  # Possible due to reallocation having a smaller reserve
                return $allocatable;
            },
        },
        allocatable_gb => {
            calculate_from => 'allocatable_kb',
            calculate => q{ return int($allocatable_kb / (2**20)) },
        },
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
            calculate => q| return Genome::Disk::Allocation->get(mount_path => $mount_path); |,
        },
    ],
    data_source => 'Genome::DataSource::Oltp',
    doc => 'Represents a particular disk volume (eg, sata483)',
};

sub unallocatable_volume_percent { return .05 } # 5% can't be allocated to, but can be used by reallocates
sub unusable_volume_percent { return .02 } # 2% can't be used at all
sub maximum_reserve_size { return 1_073_741_824 } # maximum size of unallocatable disk

sub get_lock {
    my ($class, $mount_path, $tries) = @_;
    $tries ||= 120;
    my $modified_mount = $mount_path;
    $modified_mount =~ s/\//_/g;
    my $volume_lock = Genome::Sys->lock_resource(
        resource_lock => '/gsc/var/lock/allocation/volume' . $modified_mount,
        max_try => $tries,
        block_sleep => 1,
    );
    return $volume_lock;
}

1;
