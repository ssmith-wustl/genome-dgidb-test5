package MGAP::Command::GetFastaFiles;

use strict;
use warnings;

use Bio::SeqIO;
use Bio::Seq;

use BAP::DB::Sequence;
use BAP::DB::SequenceSet;
use Workflow;

use File::Temp;


class MGAP::Command::GetFastaFiles {
    is => ['MGAP::Command'],
    has => [
        dev        => { is => 'SCALAR', doc => "if true set $BAP::DB::DBI::db_env = 'dev'" },
        seq_set_id => { is => 'SCALAR', doc => 'identifies a whole assembly' },
        fasta_files => { is => 'ARRAY', is_optional => 1, doc => 'array of fasta file names' }
    ],
};

operation_io MGAP::Command::GetFastaFiles {
    input  => [ 'dev', 'seq_set_id' ],
    output => [ 'fasta_files' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
    mgap get-fasta-files --seq-set-id 12345
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my $self = shift;

    if ($self->dev()) {
        $BAP::DB::DBI::db_env = 'dev'; 
    }
               
    $DB::single = 1;

    my $seq_set_id = $self->seq_set_id;

    my $sequence_set = BAP::DB::SequenceSet->retrieve($seq_set_id);

    my @filenames = ( );
    
    my @sequences = $sequence_set->sequences();

    foreach my $sequence (@sequences) {

        ##FIXME: The temp dir location should not be hardcoded.  At least not here.
        ##       Move it up to a super class or make it a parameter
        my $tmp_fh = File::Temp->new(
                                     'DIR'      => '/gscmnt/temp212/info/annotation/MGAP_tmp',
                                     'SUFFIX'   => '.tmp',
                                     'TEMPLATE' => 'MGAP_XXXXXXXX',
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
