package MGAP::Command::CalculateGcPercent;

use strict;
use warnings;

use Bio::Seq;
use Bio::SeqIO;
use Workflow;

class MGAP::Command::CalculateGcPercent {
    is => ['MGAP::Command'],
    has => [
        fasta_files => { is => 'ARRAY', doc => 'array of fasta file names' },
        gc_percent => { is => 'Float', is_optional => 1, doc => 'GC content' }
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
    
    my @files = @{$self->fasta_files()};

    my $gc_count;
    my $seq_length;
    
    foreach my $file (@files) {

        my $seqio = Bio::SeqIO->new(-file => $file, -format => 'Fasta');

        my $seq        = $seqio->next_seq();
        my $seq_string = $seq->seq();

        ## Ns are usually gaps...
        my $n_count = $seq_string =~ tr/nN/nN/;
        
        $gc_count   += $seq_string =~ tr/gcGC/gcGC/;

        ## ...so don't count them when determining the sequence length
        $seq_length += ($seq->length() - $n_count); 
        
    }

    $self->gc_percent(sprintf("%.1f", (($gc_count / $seq_length) * 100)));

    return 1;
    
}
