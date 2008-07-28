package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;


class PAP::Command::BlastP {
    is => ['PAP::Command'],
    has => [
        fasta_file  => { is => 'SCALAR', doc => 'fasta file name' },
        result_file => { is => 'SCALAR', doc => 'absolute path to the output file from iprscan' },
    ],
};

operation PAP::Command::BlastP {
    input  => [ 'fasta_file', 'result_file' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run iprscan";
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


    my $fasta_file  = $self->fasta_file();


}
 
1;
