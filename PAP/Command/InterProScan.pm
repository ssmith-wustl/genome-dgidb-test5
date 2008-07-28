package PAP::Command::InterProScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;


class PAP::Command::InterProScan {
    is => ['PAP::Command'],
    has => [
        fasta_file      => { is => 'SCALAR', doc => 'fasta file name'            },
        bio_seq_feature => { is => 'ARRAY',  doc => 'array of Bio::Seq::Feature' },
    ],
};

operation PAP::Command::InterProScan {
    input  => [ 'fasta_file'      ],
    output => [ 'bio_seq_feature' ],
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
    my $result_file = $self->result_file();

    my @iprscan_command = (
                           '/gscmnt/974/analysis/iprscan16.1/iprscan/bin/iprscan.hacked',
                           '-cli',
                           '-appl hmmpfam',
                           '-goterms',
                           '-verbose',
                           '-iprlookup',
                           '-seqtype p',
                           '-format ebixml',
                           "-i $fasta_file",
                           "-o $result_file",
                          );

    my ($iprscan_stdout, $iprscan_stderr);

    IPC::Run::run(
                  \@iprscan_command, 
                  \undef, 
                  '>', 
                  \$iprscan_stdout, 
                  '2>', 
                  \$iprscan_stderr, 
                 ); 

}
 
1;
