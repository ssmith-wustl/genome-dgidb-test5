#Id#

package PAP::Command::InterProScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;
use File::Temp;
use IPC::Run;


class PAP::Command::InterProScan {
    is => ['PAP::Command'],
    has => [
        fasta_file      => {  
                            is  => 'SCALAR', 
                            doc => 'fasta file name'            
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY',
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature' 
                           },
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

    my $tmp_fh = File::Temp->new();
    my $tmp_fn = $tmp_fh->filename();

    $tmp_fh->close();

    my @iprscan_command = (
                           '/gscmnt/974/analysis/iprscan16.1/iprscan/bin/iprscan.hacked',
                           '-cli',
                           '-appl',
                           'hmmpfam',
                           '-goterms',
                           '-verbose',
                           '-iprlookup',
                           '-seqtype',
                           'p',
                           '-format',
                           'ebixml',
                           '-i',
                           $fasta_file,
                           '-o',
                           $tmp_fn,
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

    my $seqio = Bio::SeqIO->new(-file => $tmp_fn, -format => 'interpro');

    my @features = ( );
    
    while (my $seq = $seqio->next_seq()) {
        
        push @features, $seq->get_all_SeqFeatures();
        
    }

    $self->bio_seq_feature(\@features);
    
    return 1;

}
 
1;
