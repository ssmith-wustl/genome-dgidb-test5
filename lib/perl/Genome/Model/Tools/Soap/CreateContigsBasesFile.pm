package Genome::Model::Tools::Soap::CreateContigsBasesFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use Data::Dumper;

class Genome::Model::Tools::Soap::CreateContigsBasesFile {
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
	output_file => {
	    is => 'Text',
	    doc => 'User supplied output file name',
	    is_optional => 1,
	}
    ],
};

sub help_brief {
    'Tool to create contigs fasta file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-contigs-bases-file --scaffold-fasta-file /gscmnt/111/soap_asm/61EFS.cafSeq --assembly-directory /gscmnt/111/soap_asm
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

    my $out_file = ($self->output_file) ? $self->output_file : $self->contigs_bases_file;

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $self->scaffold_fasta_file);
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$out_file);

    my $supercontig_number = 0;
    while (my $seq = $in->next_seq) {
	my $contig_number = 0;
	my @seqs = split (/N+/, $seq->seq);
	foreach my $bases (@seqs) {
	    my $seq_obj = Bio::Seq->new(-seq => $bases, -id => 'Contig'.$supercontig_number.'.'.++$contig_number);
	    $out->write_seq($seq_obj);
	}
	$supercontig_number++;
    }

    return 1;
}


1;
