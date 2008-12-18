package Genome::Model::Tools::Velvet::ToReadFasta;

use strict;
use warnings;

use Genome;
use IO::File;
use Bio::SeqIO;
use GSC::IO::Assembly::Ace::Reader;

class Genome::Model::Tools::Velvet::ToReadFasta {
    is           => 'Command',
    has          => [
        ace_file    => {
            is      => 'String', 
            doc     => 'ace file name with path',
        }
    ],
    has_optional => [
        out_file    => {
            is      => 'String', 
            doc     => 'output fasta file name with path, default: ./reads.fasta',
            default => './reads.fasta',
        },
    ],
};
        

sub help_brief {
    'This tool grabs read_ids and their sequences from velvet_converted acefile',
}


sub help_detail {
    return <<EOS
This tool is needed to make read fasta for making fake Phds/Scfs for consed.
EOS
}


sub execute {
    my $self    = shift;
    my $acefile = $self->ace_file;
    
    unless (-s $acefile) {
        $self->error_message("Acefile $acefile not existing");
        return;
    }
    
    my $io = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$self->out_file);
    my $fh = IO::File->new($acefile) or die "can't open $acefile\n";

    my $reader = GSC::IO::Assembly::Ace::Reader->new($fh);

    while (my $obj = $reader->next_object) {
        if ($obj->{type} eq 'read') {
            my $seq = $obj->{sequence};
            $seq =~ s/\*//g;
            $io->write_seq(Bio::Seq->new(-seq => $seq, -id => $obj->{name}));
        }
    }
    $fh->close;
    
    return 1;
}

1;

