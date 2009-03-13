package Genome::Disk::Allocation::Command::Allocate;

use strict;
use warnings;

use Genome;

class Genome::Disk::Allocation::Command::Allocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
            allocation_path => {
                                is => 'Text',
                                doc => 'The sub-dir of the disk volume for which space is allocated',
                            },
            kilobytes_requested => {
                                    is => 'Number',
                                    doc => 'The disk space allocated in kilobytes',
                                },
            owner_class_name => {
                                 is => 'Text',
                                 doc => 'The class name for the owner of this allocation',
                             },
            owner_id => {
                         is => 'Number',
                         doc => 'The id for the owner of this allocation',
                     },
        ],
    has_optional => [
                     mount_path => {
                                    is => 'Text',
                                    doc => 'The mount path of the disk volume',
                                },
                     kilobytes_used => {
                                        is => 'Number',
                                        doc => 'The actual disk space used by owner',
                                    },
                     local_confirm => {
                                       is => 'Boolean',
                                       default_value => 1,
                                       doc => 'A flag to confirm the pse locally',
                                   },
              ],
    doc => 'An allocate command to create and confirm GSC::PSE::AllocateDiskSpace and GSC::DiskAllocation',
};

sub create {
    my $class = shift;

    App->init unless App::Init->initialized;

    my %params = @_;
    my $self = $class->SUPER::create(%params);
    unless ($self) {
        return;
    }
    if ($self->mount_path) {
        my @mps = $self->_get_all_mount_paths;
        unless (grep {$_ eq $self->mount_path} @mps) {
            my $error_message = "Disk mount path '". $self->mount_path
                ."' is not an available disk mount path.  Choose one of the following:\n";
            $error_message .= join("\n",@mps);
            $self->error_message($error_message);
            $self->delete;
            return;
        }
    }
    my $owner_class_name = $self->owner_class_name;
    unless ($owner_class_name) {
        $self->error_message('Owner class name is required!  See --help.');
        $self->delete;
        return;
    }
    my $owner_id = $self->owner_id;
    unless ($owner_id) {
        $self->error_message('Owner id is required!  See --help.');
        $self->delete;
        return;
    }
    my $owner_object = $owner_class_name->get($owner_id);
    unless ($owner_object) {
        $self->error_message('Failed to get object of class '.
                             $owner_class_name .' and id '. $owner_id);
        $self->delete;
        return;
    }

    unless ($self->allocation_path) {
        $self->error_message('Allocation path is required! See --help.');
        $self->delete;
        return;
    }
    unless ($self->verify_no_parent_allocation($self->allocation_path)) {
        $self->error_message('Parent allocation found for path '. $self->allocation_path);
        $self->delete;
        return;
    }

    unless ($self->kilobytes_requested) {
        $self->error_message('Kilobytes requested is required! See --help.');
        $self->delete;
        return;
    }

    my $disk_volume;
    if ($self->mount_path) {
        ($disk_volume) = $self->get_disk_volumes;
    }
    unless ($self->allocator_id) {
        my %pse_params = (
                          process_to => 'allocate disk space',
                          disk_group_name => $self->disk_group_name,
                          space_needed => $self->kilobytes_requested,
                          allocation_path => $self->allocation_path,
                          owner_class_name => $self->owner_class_name,
                          owner_id => $self->owner_id,
                          control_pse_id => '1',
                      );
        if ($disk_volume) {
            $pse_params{dv_id} = $disk_volume->dv_id;
        }
        my $allocator = GSC::ProcessStep->schedule(%pse_params);
        unless ($allocator) {
            $self->error_message('Failed to schedule allocate PSE.');
            $self->delete;
            return;
        }
        $self->allocator_id($allocator->pse_id);
    }
    unless ($self->allocator) {
        $self->error_message('Allocator not found for allocator id '. $self->allocator_id);
        $self->delete;
        return;
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $allocator = $self->allocator;

    $self->status_message('Confirming allocate PSE id: '. $allocator->pse_id);

    my $rv;
    if ($self->local_confirm) {
        $rv = $self->confirm_scheduled_pse($allocator);
    } else {
        $rv = $self->wait_for_pse_to_confirm(pse => $allocator);
    }

    unless ($rv) {
        $self->error_message('Failed to confirm pse '. $allocator->pse_id);
        return;
    }
    return 1;
}

sub verify_no_parent_allocation {
    my $self = shift;
    my $path = shift;

    my ($allocation) = Genome::Disk::Allocation->get(allocation_path => $path);
    if ($allocation) {
        return;
    }
    my $dir = File::Basename::dirname($path);
    if ($dir ne '.' && $dir ne '/') {
        return $self->verify_no_parent_allocation($dir);
    }
    return 1;
}

1;
