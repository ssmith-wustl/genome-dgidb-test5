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
        delete_derivatives => {
                            doc => 'delete any files derived from items in original list',
                            is => 'Boolean',
                            is_optional => 1,
                            default => 0,
                       },
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
    my $delete_derivatives = $self->delete_derivatives;
    
    my @files = @{$self->files()};

    print "deleting these files:  " . join("\n*\t", @files) . "\n";

    foreach my $file (@files) 
    {

    	if (-e $file) 
        {
            if ($delete_derivatives)
            {
                my $derivatives = "$file*";
                foreach (glob($derivatives)) 
                {
                    unlink or warn "Couldn't unlink '$_': $!";
                } 
            }
            else
            {
                unless(unlink($file)) 
                {
                    warn "failed to unlink '$file': $!";
                }	
            }
        }

    }

    return 1;

}
 
1;
