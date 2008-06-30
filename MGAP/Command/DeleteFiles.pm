package MGAP::Command::DeleteFiles;

use strict;
use warnings;

use Workflow;

use English;

class MGAP::Command::DeleteFiles {
    is => ['MGAP::Command'],
    has => [
        files => { is => 'ARRAY', doc => 'array of files to delete' },
    ],
};

operation MGAP::Command::DeleteFiles {
    input  => [ 'files' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Delete a set of files";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;

    
    my @files = @{$self->files()};

    foreach my $file (@files) {

        unless(unlink($file)) {

            die "failed to unlink '$file': $OS_ERROR";

        }

    }

    $self->status_message("Deleted files: " . join(',',@files));
    
}
 
1;
