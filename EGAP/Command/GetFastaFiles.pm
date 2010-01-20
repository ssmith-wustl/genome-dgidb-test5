package EGAP::Command::GetFastaFiles;

use strict;
use warnings;

use EGAP;
use Workflow;

use Bio::SeqIO;
use Bio::Seq;

use File::Temp;


class EGAP::Command::GetFastaFiles {
    is => ['EGAP::Command'],
    has => [
        seq_set_id => { is => 'SCALAR', doc => 'identifies a whole assembly' },
        fasta_files => { is => 'ARRAY', is_optional => 1, doc => 'array of fasta file names' }
    ],
};

operation EGAP::Command::GetFastaFiles {
    input  => [ 'seq_set_id' ],
    output => [ 'fasta_files' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
    egap get-fasta-files --seq-set-id 12345
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my $self = shift;

    $DB::single = 1;

    my $seq_set_id = $self->seq_set_id;

    my $sequence_set = EGAP::SequenceSet->get($seq_set_id);

    my @filenames = ( );
    
    my @sequences = $sequence_set->sequences();

    foreach my $sequence (@sequences) {

        ##FIXME: The temp dir location should not be hardcoded.  At least not here.
        ##       Move it up to a super class or make it a parameter
        my $tmp_fh = File::Temp->new(
                                     'DIR'      => '/gscmnt/temp212/info/annotation/EGAP_tmp',
                                     'SUFFIX'   => '.tmp',
                                     'TEMPLATE' => 'EGAP_XXXXXXXX',
                                     'UNLINK'   => 0, 
                                  );

        my $bp_fasta = Bio::SeqIO->new(-fh => $tmp_fh, -format => 'Fasta');
        
        my $bp_seq = Bio::Seq->new(
                                   -seq => $sequence->sequence_string(),
                                   -id  => $sequence->sequence_name(),
                               );
        
        $bp_fasta->write_seq($bp_seq);

        push @filenames, $tmp_fh->filename();
        
    }

    $self->status_message("Wrote out files: " . join(',',@filenames));
    $self->fasta_files(\@filenames);

    1;
}
 
1;
