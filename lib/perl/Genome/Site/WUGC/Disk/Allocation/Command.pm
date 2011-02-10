
# review jlolofie:
# notes: -lock file is hardcoded
#        -properties instead of methods?


package Genome::Site::WUGC::Disk::Allocation::Command;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::Disk::Allocation::Command {
    is => 'Command',
    is_abstract => 1,
    has => [
            disk_group_name => {
                                is => 'Text',
                                default_value => 'info_apipe',
                                doc => 'The disk group name to work with for disk allocation',
                            },
        ],
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
                                         is => 'Genome::Site::WUGC::Disk::Allocation',
                                         id_by => ['allocator_id'],
                                     },
                     gsc_disk_allocation => {
                                             calculate_from => 'allocator_id',
                                             calculate => q|
                                                 return GSC::DiskAllocation->get(allocator_id => $allocator_id);
                                             |,
                                         },
                     local_confirm => {
                                       is => 'Boolean',
                                       default_value => 1,
                                       doc => 'A flag to confirm the pse locally',
                                   },
        ],
    doc => 'work with disk allocations',
};

## this needs to happen at load time
if ($ENV{MONITOR_ALLOCATE_LOCK}) {
    if (open my $fh, ">>&=3") {
        DBI->trace(5,$fh);
        UR::DBI->sql_fh($fh);
        App::DBI->sql_fh($fh);
    }
}

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome disk allocation';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'allocation';
}

############################################
sub create {
    my $class = shift;
    
    # this breaks thins if done in modules
    #App->init unless App::Init->initialized;
    
    my $self = $class->SUPER::create(@_);
    return unless $self;
    return $self;
}


############################################


sub get_disk_group {
    my $self = shift;
    return Genome::Disk::Group->get(disk_group_name => $self->disk_group_name);
}

sub get_disk_volumes {
    my $self = shift;
    if ($self->mount_path) {
        return Genome::Disk::Volume->get(mount_path => $self->mount_path);
    }
    return $self->_all_group_disk_volumes;
}

sub _get_all_group_disk_volumes {
    my $self = shift;
    my $dg = $self->get_disk_group;
    return $dg->volumes;
}

sub _get_all_mount_paths {
    my $self = shift;
    my @dvs = $self->_get_all_group_disk_volumes;
    return map { $_->mount_path } @dvs;
}

sub lock_directory {
    return ' /gsc/var/lock/genome_disk_allocation/allocation_lock';
}

sub resource_id {
    return 'GenomeDiskAllocation';
}

sub Xunlock {
    my $self = shift;
    unless (Genome::Utility::FileSystem->unlock_resource(
                                                         lock_directory => $self->lock_directory,
                                                         resource_id => $self->resource_id,
                                                     ) ) {
        $self->error_message('Failed to unlock resource '. $self->command_name
                             .' in lock directory '. $self->lock_directory);
        die;
    }
    return 1;
}

sub Xlock {
    my $self = shift;
    unless (Genome::Utility::FileSystem->lock_resource(
                                                       lock_directory => $self->lock_directory,
                                                       resource_id => $self->resource_id,
                                                       block_sleep => 3,
                                                       max_try => 300,
                                                   ) ) {
        $self->error_message('Failed to lock resource '. $self->command_name
                             .' in lock directory '. $self->lock_directory );
        $self->delete;
        die;
    }
    return 1;
}

sub confirm_scheduled_pse {
    my $self = shift;
    my $pse = shift;

    unless ($pse->pse_status eq 'scheduled') {
        $self->error_message('PSE '. $pse->pse_id .' does not have a scheduled status the status is '. $pse->pse_status);
        return;
    }

    STDERR->autoflush(1);
    
    my $old_cb = App::MsgLogger->message_callback('status');
    if ($ENV{MONITOR_ALLOCATE_LOCK}) {
        App::MsgLogger->message_callback(
            'status', sub {
                my $msg = $_[0]->text;
                print STDERR "genome allocate: STATUS: $msg\n";
            }
        );
    }

    unless ($pse->confirm(no_pse_job_check => 1)) {
        $self->error_message('Failed to confirm PSE: '. $pse->pse_id);
        $pse->uninit_pse;
        return;
    }

    if ($ENV{MONITOR_ALLOCATE_LOCK}) {
        App::MsgLogger->message_callback(
            'status', $old_cb
        );
    }

    unless ($pse->pse_status eq 'inprogress' || $pse->pse_status eq 'completed') {
        $self->error_message('PSE pse_status not inprogress: '. $pse->pse_status);
        $pse->uninit_pse;
        return;
    }
    return 1;
}

sub wait_for_pse_to_confirm {
    my $self = shift;
    my %params = @_;

    my $pse = $params{pse};
    unless ($pse) {
        $self->error_message('Missing pse param for wait_for_pse_to_confirm');
        die($self->error_message);
    }
    if ($pse->has_uncommitted_changes) {
        UR::Context->commit;
    }
    my $max_try = $params{max_try} || 60;
    my $block_sleep = $params{block_sleep} || 30;
    while ($self->pse_not_complete($pse)) {
        return unless $max_try--;
        sleep $block_sleep;
        my $pse_id = $pse->pse_id;
        GSC::PSE->unload;
        $pse = GSC::PSE->get($pse_id);
    }
    unless ($pse->pse_status eq 'inprogress' || $pse->pse_status eq 'completed') {
        $self->error_message('PSE '. $pse->pse_id .' did not confirm. PSE status of '. $pse->pse_status);
        return
    }
    return 1;
}

sub pse_not_complete {
    my $self = shift;
    my $pse = shift;
    my @not_completed = grep { $_ eq $pse->pse_status } ('scheduled', 'wait', 'confirm', 'confirming');
    unless (@not_completed) {
        return;
    }
    return 1;
}

1;

