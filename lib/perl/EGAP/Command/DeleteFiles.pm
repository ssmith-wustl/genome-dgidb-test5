package EGAP::Command::DeleteFiles;

use strict;
use warnings;

use EGAP;
use Carp qw(confess);
use English;

class EGAP::Command::DeleteFiles {
    is => 'EGAP::Command',
    has => [
        files => { 
            is => 'ARRAY', 
            is_input => 1,
            doc => 'array of files to delete' 
        },
    ],
};

sub help_brief {
    return "Deletes all files provided";
}

sub help_synopsis {
    return "Deletes all files in the given array";
}

sub help_detail {
    return "Deletes all filsee in the given array";
}

sub execute {
    my $self = shift;
    my @files = @{$self->files};

    for my $file (@files) {
        unless(unlink $file) {
            confess "Could not remove $file : $OS_ERROR";
        }
    }

    $self->status_message("Deleted files: " . join(',',@files));
    return 1;
}
 
1;
