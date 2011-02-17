package Genome::Disk::Group::Command::AvailableSpace;

use strict;
use warnings;
use Genome;
use MIME::Lite;

class Genome::Disk::Group::Command::AvailableSpace {
    is => 'Genome::Disk::Group::Command',
    has => [
        disk_group_name => {
            is => 'Text',
            doc => 'name of disk group for which available space will be found',
        },
    ],
    has_optional => [
        send_alert => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, an alert will be sent out if a disk group is does not have the minimum amount of free space',
        },
        alert_recipients => {
            is => 'Text',
            default => 'jeldred,bdericks',
            doc => 'If an alert is sent, these are the recipients',
        },
    ],
};

my %minimum_space_for_group = (
    info_apipe => 512_000,                # 500MB
    info_apipe_ref => 1_073_741_824,      # 1TB
    info_alignments => 12_884_901_888,    # 12TB
    info_genome_models => 25_769_803_776  # 24TB
);

sub help_brief {
    return "Sums up the unallocated space for every volume of a group";
}

sub help_synopsis {
    help_brief();
}

sub help_detail {
    help_brief();
}

sub execute {
    my $self = shift;
    
    my $group = Genome::Disk::Group->get(disk_group_name => $self->disk_group_name);
    unless ($group) {
        Carp::confess "Could not find disk group with name " . $self->disk_group_name;
    }

    my @volumes = $group->volumes;
    unless (@volumes) {
        Carp::confess "Found no volume belonging to group " . $self->disk_group_name;
    }

    $self->status_message("Found " . scalar @volumes . " disk volumes belonging to group " . $self->disk_group_name);

    my $sum;
    for my $volume (@volumes) {
        my $space = $volume->unallocated_kb - $volume->reserve_size;
        $sum += $space unless $space < 0;  # I've learned not to trust the system to be consistent
    }

    my $sum_gb = $self->kb_to_gb($sum);
    my $sum_tb = $self->kb_to_tb($sum);
    $self->status_message("Group " . $self->disk_group_name . " has $sum KB ($sum_gb GB, $sum_tb TB) of free space");

    if (exists $minimum_space_for_group{$self->disk_group_name}) {
        my $min = $minimum_space_for_group{$self->disk_group_name};
        if ($sum < $min) {
            my $min_gb = $self->kb_to_gb($min);
            my $min_tb = $self->kb_to_tb($min);
            $self->warning_message("Free space below minimum $min kb ($min_gb GB, $min_tb TB)!");

            if ($self->send_alert) {
                my $data = 'Disk group ' . $self->disk_group_name . " has $sum KB ($sum_gb GB, $sum_tb TB) of free space, " .
                    "which is below the minimum of $min KB ($min_gb GB, $min_tb TB). Either free some disk or request more!";
                my $msg = MIME::Lite->new(
                    From => $ENV{USER} . '@genome.wustl.edu',
                    To => join(',', map { $_ . '@genome.wustl.edu' } split(',', $self->alert_recipients)),
                    Subject => 'Disk Group ' . $self->disk_group_name . ' Running Low!',
                    Data => $data,
                );
                $msg->send();

                $self->warning_message("Sent alert to " . $self->alert_recipients);
            }
        }
    }

    return 1;
}

sub kb_to_gb {
    my ($class, $kb) = @_;
    return int($kb / (2**20));
}

sub kb_to_tb {
    my ($class, $kb) = @_;
    return int($kb / (2**30));
}

1;

