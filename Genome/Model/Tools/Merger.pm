#$Id: FastaMerger.pm 39214 2008-09-30 19:29:40Z mjohnson $

package Genome::Model::Tools::Merger;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;
use File::Temp;


class Genome::Model::Tools::Merger {
    is  => ['Command'],
    has_input => [  
        merged_file => { is => 'String',  doc => 'file merged chunks are written to' },
        file_chunks => { is => 'ARRAY',   doc => 'array of fasta file names', is_optional => 0 },
    ],
    has_optional => [
        force_overwrite => {
            is          => 'Integer',
            doc         => 'overwrite merged file if exists',
            is_input    => 1,
            default     => 0,
        }
    ],

};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Merge file chunks into one file";
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
    my $merged_file = $self->merged_file;
    my $file_chunks = $self->file_chunks;
    my $rv;

    #check for file exists
    if (-e $merged_file)
    {
        #check for overwrite
        if ($self->force_overwrite)
        {
            #clear file contents
            my $clear = "echo -n > $merged_file";
            $rv = system($clear);
            unless ($rv == 0) 
            {
                $self->error_message("non-zero return value($rv) from command $clear");
                return;
            }
        }
        else
        {
            $self->error_message("$merged_file exists");
            return;
        }
    }
    else
    {
        my $touch = "touch $merged_file";
        $rv = system($touch);
        unless ($rv == 0) 
        {
            $self->error_message("non-zero return value($rv) from command $touch");
            return;
        }
    }

    foreach my $chunk (@$file_chunks)
    {
        my $cat;
        
        $cat = "cat $chunk >> $merged_file";
        $rv = system($cat);
        unless ($rv == 0) 
        {
            $self->error_message("non-zero return value($rv) from command $cat");
            return;
        };
    }
    
    return 1;

}
 
1;
