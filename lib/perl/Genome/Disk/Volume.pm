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
        total_kb => { is => 'Number' },
        unallocated_kb => { is => 'Number' },
        disk_status => { is => 'Text' },
        can_allocate => { is => 'Number' },
        used_kb => {
            calculate_from => ['mount_path'],
            calculate => sub { my $mount_path = shift; my ($used_kb) = qx(df -k $mount_path | grep $mount_path | awk '{print \$3}') =~ /(\d+)/; },
        },
        allocated_kb => { 
            calculate_from => ['total_kb','unallocated_kb'],
            calculate => q{ return ($total_kb - $unallocated_kb); },
        },
        percent_used => {
            calculate_from => ['total_kb', 'used_kb'],
            calculate => sub { my ($total_kb, $used_kb) = @_; return sprintf("%.2f%%", ( $used_kb / $total_kb ) * 100); },
        },
        percent_allocated => {
            calculate_from => ['total_kb', 'allocated_kb'],
            calculate => q{ return sprintf("%.2f%%", ( $allocated_kb / $total_kb ) * 100); },
        },
        reserve_size => {
            calculate_from => ['total_kb', 'unusable_volume_percent', 'maximum_reserve_size'],
            calculate => q{
                my $buffer = int($total_kb * $unusable_volume_percent);
                $buffer = $maximum_reserve_size if $buffer > $maximum_reserve_size;
                return $buffer;
            }
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
    schema_name => 'Oltp',
    data_source => 'Genome::DataSource::Oltp',
    doc => 'Represents a particular disk volume (eg, sata483)',
};

sub unusable_volume_percent { return .05 }
sub maximum_reserve_size { return 1_073_741_824 } # 1 TB

sub most_recent_allocation {
    my $self = shift;
    # Unless otherwise specified, the objects returned by this get will be sorted by increasing
    # id value. This is ONLY true if the id is numeric and single-column. If any fields other than
    # allocator id are ever added to the id_by property of allocations, this get will need to be modified
    my @allocations = Genome::Disk::Allocation->get(mount_path => $self->mount_path);
    return unless @allocations;
    return $allocations[-1];
}

1;
