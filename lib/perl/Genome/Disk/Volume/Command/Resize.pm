package Genome::Disk::Volume::Command::Resize;

use strict;
use warnings;

use Genome;

class Genome::Disk::Volume::Command::Resize {
    is => 'Genome::Command::Base',
    has => [
        volume => {
            is => 'Genome::Disk::Volume',
            shell_args_position => 1,
        },
    ],
};

sub execute {
    my $self = shift;
    my $volume = $self->volume;

    my $mount_path = $volume->mount_path;
    my @df_output = qx(df -k $mount_path);
    unless (@df_output == 2) {
        $self->error_message('\'df\' output does not match expected pattern, exiting');
        return;
    }

    my $df_total_kb = (split(/\s+/, $df_output[1]))[1];
    my $volume_total_kb = $volume->total_kb;
    my $delta_total_kb = $df_total_kb - $volume_total_kb;

    if ($delta_total_kb == 0) {
        $self->status_message('No resize needed.');
        return 1;
    }

    my $question = "Would you like to resize $mount_path by $delta_total_kb kb? From $volume_total_kb kb to $df_total_kb kb.";
    if($self->_ask_user_question($question) eq 'yes') {
        $self->resize_by_kb($delta_total_kb);
        $self->status_message('Volume has been resized.');
        return 1;
    }
    else {
        $self->status_message('Aborting due to user response.');
        return;
    }

    return 1;
}

sub resize_by_kb {
    my $self = shift;
    my $delta_total_kb = shift;
    my $volume = $self->volume;

    $volume->total_kb($volume->total_kb + $delta_total_kb);
    $volume->unallocated_kb($volume->unallocated_kb + $delta_total_kb);

    return 1;
}

1;

