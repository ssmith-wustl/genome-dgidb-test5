package MGAP::Command::CalculateGcPercent;

use strict;
use warnings;

use Workflow;

class MGAP::Command::CalculateGcPercent {
    is => ['MGAP::Command'],
    has => [
        fasta_files => { is => 'ARRAY', doc => 'array of fasta file names' },
        gc_percent => { is => 'Integer', doc => 'GC content' }
    ],
};

operation MGAP::Command::CalculateGcPercent {
    input  => [ 'fasta_files' ],
    output => [ 'gc_percent' ],
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
