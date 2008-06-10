package MGAP::Command::GetFastaFiles;

use strict;
use warnings;

use Workflow;

class MGAP::Command::GetFastaFiles {
    is => ['MGAP::Command'],
    has => [
        seq_set_id => { is => 'SCALAR', doc => 'identifies a whole assembly' },
        fasta_files => { is => 'ARRAY', is_optional => 1, doc => 'array of fasta file names' }
    ],
};

operation MGAP::Command::GetFastaFiles {
    input  => [ 'seq_set_id' ],
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
    $DB::single=1;

    my $seq_set_id = $self->seq_set_id;

## do some stuff

    my @filenames = qw/asdf ghjkl/;

    $self->status_message("Wrote out files: " . join(',',@filenames));
    $self->fasta_files(\@filenames);

    1;
}
 
1;
