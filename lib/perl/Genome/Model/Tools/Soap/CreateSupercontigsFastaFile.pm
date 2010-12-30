package Genome::Model::Tools::Soap::CreateSupercontigsFastaFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;

class Genome::Model::Tools::Soap::CreateSupercontigsFastaFile {
    is => 'Genome::Model::Tools::Soap',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Soap assembly directory',
        },
	output_file => {
	    is => 'Text',
	    doc => 'User supplied output file name',
	    is_optional => 1,
	},
	scaffold_sequence_file => {
            is => 'Text',
	    is_optional => 1,
            doc => 'Soap created scaffolds fasta file',
        },
    ],
};

sub help_brief {
    'Tool to create supercontigs.fasta file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-supercontigs-fasta-file --scaffold-sequence-file /gscmnt/111/soap_assembly/61EFS.cafSeq --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub execute {
    my $self = shift;

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to creat edit_dir");
	return;
    }

    unless (-d $self->assembly_directory) {
        $self->error_message("Failed to find assembly directory: ".$self->assembly_directory);
        return;
    }

    my $scaf_seq_file = ($self->scaffold_sequence_file) ? $self->scaffold_sequence_file : $self->assembly_scaffold_sequence_file;

    my $out_file = ( $self->output_file ) ? $self->output_file : $self->supercontigs_fasta_file;

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $scaf_seq_file);
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$out_file);

    my $supercontig_number = -1;
    while (my $seq = $in->next_seq) {
	$seq->id('Contig'.++$supercontig_number);
	$out->write_seq($seq);
    }

    return 1;
}

1;
