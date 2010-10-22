package EGAP::Command::CleanupTempFiles;

use strict;
use warnings;
use EGAP;
use Carp 'confess';

class EGAP::Command::CleanupTempFiles {
    is => 'EGAP::Command',
    has => [
       directories => {
           is => 'ARRAY',
           is_input => 1,
           doc => 'An array of directories to be removed',
        },
    ],
};

sub help_brief { 
    return "Removes temp files and directories";
}

sub help_synopsis {
    return "Removes temp files and directories";
}

sub help_detail {
    return "Removes temp files and directories";
}

sub execute {
    my $self = shift;

    my @dirs = @{$self->directories};
    for my $dir (@dirs) {
        $self->status_message("Removing $dir");
        next unless -d $dir;
        my $rv = system("rm -rf $dir");
        confess "Trouble removing $dir!" unless defined $rv and $rv == 0;
    }

    return 1;
}
     
1;

