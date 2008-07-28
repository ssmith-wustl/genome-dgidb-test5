package PAP::Command::FastaChunker;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use English;
use File::Temp;


class PAP::Command::FastaChunker {
    is  => ['PAP::Command'],
    has => [
        fasta_file  => { is => 'SCALAR', doc => 'fasta file name'                     },
        fasta_files => { is => 'ARRAY',  doc => 'array of fasta file names'           },
        chunk_size  => { is => 'SCALAR', doc => 'number of sequences per output file' }
    ],
};

operation PAP::Command::FastaChunker {
    input  => [ 'fasta_file', 'result_file', 'chunk_size' ],
    output => [ 'fasta_files'                             ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Chunk (split) a multi-fasta file into multiple smaller multi-fasta files";
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


    my $input_file   = $self->fasta_file();     ##FIXME:  Should verify input_file is not empty
    my $chunk_size   = $self->chunk_size();     ##FIXME:  Should verify chunk_size > 0
    my @output_files = ( );

    my $seq_in = Bio::SeqIO->new(-file => $input_file, -format => 'Fasta');

    my $chunk_fh;
    my $seq_out;
    
    my $seq_count = 0;
    
    while (my $seq = $seq_in->next_seq()) {

        $seq_count++;

        if (($seq_count > $chunk_size) || (!defined($chunk_fh)))  {
        
            ##FIXME: The temp dir location should not be hardcoded.  At least not here.
            $chunk_fh = File::Temp->new(
                                        'DIR'      => '/gscmnt/temp212/info/annotation/PAP_tmp',
                                        'SUFFIX'   => '.tmp',
                                        'TEMPLATE' => 'PAP_XXXXXXXX',
                                        'UNLINK'   => 0,
                                       );

            $seq_out = Bio::SeqIO->new(-fh => $chunk_fh, -format => 'Fasta');
        
        }

        $seq_out->write_seq($seq);

    }

    $self->fasta_files(\@output_files);

}
 
1;
