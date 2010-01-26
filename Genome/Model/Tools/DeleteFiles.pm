#$Id: DeleteFiles.pm 40741 2008-11-10 18:36:34Z mjohnson $

package Genome::Model::Tools::DeleteFiles;

use strict;
use warnings;

use Genome;
use Workflow;

use English;

class Genome::Model::Tools::DeleteFiles {
    is  => ['Command'],
    has_input => [
        files => { is => 'ARRAY', doc => 'array of files to delete' },
    ],
    has_output => [
        
    ],
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

    	if (-e $file) {
            unless(unlink($file)) {

                die "failed to unlink '$file': $OS_ERROR";

         	}	
        }

    }

    return 1;

}
 
1;
