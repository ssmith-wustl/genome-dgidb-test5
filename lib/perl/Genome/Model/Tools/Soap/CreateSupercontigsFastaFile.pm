package Genome::Model::Tools::Soap::CreateSupercontigsFastaFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;

class Genome::Model::Tools::Soap::CreateSupercontigsFastaFile {
    is => 'Genome::Model::Tools::Soap',
    has => [
        scaffold_fasta_file => {
            is => 'Text',
            doc => 'Soap created scaffolds fasta file',
        },
        assembly_directory => {
            is => 'Text',
            doc => 'Soap assembly directory',
        },
    ],
};

sub help_brief {
    'Tool to create supercontigs.fasta file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-supercontigs-fasta-file --scaffold-fasta-file /gscmnt/111/soap_assembly/61EFS.cafSeq --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub execute {
    my $self = shift;

    unless (-s $self->scaffold_fasta_file) {
        $self->error_message("Failed to find scaffold file: ".$self->scaffold_fasta_file);
        return;
    }

    unless (-d $self->assembly_directory) {
        $self->error_message("Failed to find assembly directory: ".$self->assembly_directory);
        return;
    }

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $self->scaffold_fasta_file);
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$self->assembly_directory.'/edit_dir/supercontigs.fasta');

    my $supercontig_number = -1;
    while (my $seq = $in->next_seq) {
	$seq->id('Contig'.++$supercontig_number);
	$out->write_seq($seq);
    }

    return 1;
}

1;
