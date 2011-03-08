package Genome::Disk::Group::Command::UnderAllocated;

use strict;
use warnings;
use Genome;
use MIME::Lite;

class Genome::Disk::Group::Command::UnderAllocated {
    is => 'Genome::Disk::Group::Command',
    has_optional => [
        disk_group_names => {
            is => 'Text',
            doc => 'comma delimited list of disk groups to be checked',
            default => 'info_alignments,info_genome_models',
        },
        send_alert => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, an alert will be sent out if a disk group is does not have the minimum amount of free space',
        },
        alert_recipients => {
            is => 'Text',
            default => 'jeldred,bdericks,apipebulk',
            doc => 'If an alert is sent, these are the recipients',
        },
    ],
};

sub help_brief {
    return "Finds volumes that are under-allocated (used space exceeds allocated space) and reports them";
}

sub help_synopsis { help_brief() }
sub help_detail { help_brief() }

sub execute {
    my $self = shift;
    my @groups = split(',', $self->disk_group_names);
    
    my %under_allocated_volumes;
    my %under_allocated_allocations; 
    my $under_allocated = 0;
    # Why yes, I do like my if blocks and for loops nested. Thank you for noticing.
    for my $group (@groups) {
        my @volumes = Genome::Disk::Volume->get(disk_group_names => $group, disk_status => 'active', can_allocate => 1);
        next unless @volumes;

        for my $volume (@volumes) {
            my $allocated = $volume->allocated_kb;
            my $percent_allocated = $volume->percent_allocated;
            my $used = $volume->used_kb;
            my $percent_used = $volume->percent_used;
            if ($used > $allocated) {
                push @{$under_allocated_volumes{$group}}, 
                    "Volume " . $volume->mount_path . " using $used kb ($percent_used \%) but only $allocated kb ($percent_allocated \%) allocated";
                $under_allocated = 1;
            }
        }
    }

    my $report;
    for my $group (sort keys %under_allocated_volumes) {
        $report .= "Group $group\n";
        for my $volume (@{$under_allocated_volumes{$group}}) {
            $report .= "\t$volume\n";
        }
        $report .= "\n";
    }

    $self->status_message($report);

    if ($under_allocated and $self->send_alert) {
        my $msg = MIME::Lite->new(
            From => $ENV{USER} . '@genome.wustl.edu',
            To => join(',', map { $_ . '@genome.wustl.edu' } split(',', $self->alert_recipients)),
            Subject => 'Underallocated Volumes Found!',
            Data => $report,
        );
        $msg->send;
        $self->status_message("Alert sent to " . $self->alert_recipients);
    }
    
    return 1;
}

1;

