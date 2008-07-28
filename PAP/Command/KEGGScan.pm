package PAP::Command::KEGGScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;


class PAP::Command::KEGGScan {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { is => 'SCALAR', doc => 'fasta file name'            },
        bio_seq_feature => { is => 'ARRAY',  doc => 'array of Bio::Seq::Feature' },
    ],
};

operation PAP::Command::KEGGScan {
    input  => [ 'fasta_file'      ],
    output => [ 'bio_seq_feature' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run KEGGscan";
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
