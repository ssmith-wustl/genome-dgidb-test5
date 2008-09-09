package Genome::Model::Tools::FastaDiff;

use strict;
use warnings;

use Genome;
use Command;
use Bio::SeqIO;
use File::Temp;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "use KDiff3 to show differences between fasta data files";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
For now, it only works with fasta files with one section
EOS
}


sub execute {
    my $self = shift;

$DB::single = $DB::stopper;
    my $fasta_files = $self->bare_args();
    my @flat_files;
    foreach my $fasta_name ( @$fasta_files ) {
        my $fasta = Bio::SeqIO->new(-file => $fasta_name, -format => 'fasta');
        unless ($fasta) {
            $self->error_message("Can't open fasta file $fasta_name");
            return;
        }

        my($fh,$filename) = File::Temp::tempfile;
        my $fseq = $fasta->next_seq();

        $self->status_message("Flattening $fasta_name...\n");
        for (my $i = 1; $i <= $fseq->length; $i++) {
            $fh->print($fseq->subseq($i,$i),"\n");
        }
        $fh->close();
        push(@flat_files, $filename);
    }

    my $cmdline = 'kdiff3 '. join(' ',@flat_files);
    if(system $cmdline) {
        $self->error_message("Problem running kdiff3");
        return;
    }

    return 1;
}

1;


