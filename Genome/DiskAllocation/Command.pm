package Genome::DiskAllocation::Command;

use strict;
use warnings;

use Genome;

class Genome::DiskAllocation::Command {
    is => 'Command',
    is_abstract => 1,
    has_optional => [
                     allocator_id => {
                                      is => 'Number',
                                      doc => 'The id for the allocator event',
                                  },
                     allocator => {
                                   calculate_from => 'allocator_id',
                                   calculate => q|
                                       return GSC::PSE::AllocateDiskSpace->get($allocator_id);
                                   |,
                               },
                     disk_allocation => {
                                         is => 'Genome::DiskAllocation',
                                         id_by => ['allocator_id'],
                                     },
                     gsc_disk_allocation => {
                                             calculate_from => 'allocator_id',
                                             calculate => q|
                                                 return GSC::DiskAllocation->get(allocator_id => $allocator_id);
                                             |,
                                         },
        ],
    doc => 'work with disk allocations',
};

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome disk-allocation';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'disk-allocation';
}

############################################



############################################

sub disk_group_name {
    return 'info_apipe';
}

sub get_disk_group {
    return GSC::DiskGroup->get(disk_group_name => __PACKAGE__->disk_group_name);
}

sub get_disk_volumes {
    my $self = shift;
    if ($self->mount_path) {
        return GSC::DiskVolume->get(mount_path => $self->mount_path);
    }
    return $self->_all_group_disk_volumes;
}

sub _get_all_group_disk_volumes {
    my $self = shift;
    my $dg = $self->get_disk_group;
    return $dg->get_volumes;
}

sub _get_all_mount_paths {
    my $self = shift;
    my @dvs = $self->_get_all_group_disk_volumes;
    return map { $_->mount_path } @dvs;
}

sub lock_directory {
    return '/gscmnt/839/info/medseq/allocation_lock';
}

sub unlock {
    my $self = shift;
    unless (Genome::Utility::FileSystem->unlock_resource(
                                                         lock_directory => $self->lock_directory,
                                                         resource_id => $self->command_name,
                                                     ) ) {
        $self->error_message('Failed to unlock resource '. $self->command_name
                             .' in lock directory '. $self->lock_directory);
        die;
    }
    return 1;
}

sub lock {
    my $self = shift;
    my %params = @_;
    unless (Genome::Utility::FileSystem->lock_resource(
                                                       lock_directory => $self->lock_directory,
                                                       resource_id => $self->command_name,
                                                       %params,
                                                   ) ) {
        $self->error_message('Failed to lock resource '. $self->command_name
                             .' in lock directory '. $self->lock_directory );
        $self->delete;
        die;
    }
    return 1;
}


1;

