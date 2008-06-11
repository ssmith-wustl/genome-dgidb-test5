package MGAP::Command::DeleteFastaFiles;

use strict;
use warnings;

use Workflow;

class MGAP::Command::DeleteFastaFiles {
    is => ['MGAP::Command'],
    has => [
        fasta_files => { is => 'ARRAY', doc => 'array of files to delete' },
    ],
};

operation MGAP::Command::DeleteFastaFiles {
    input  => [ 'fasta_files' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
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
    $DB::single=1;


    1;
}
 
1;
