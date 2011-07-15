package Genome::Model::Tools::Soap::CreateContigsBasesFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use Data::Dumper;

class Genome::Model::Tools::Soap::CreateContigsBasesFile {
    is => 'Genome::Model::Tools::Soap',
    has => [
	assembly_directory => {
	    is => 'Text',
	    doc => 'Soap assembly directory',
	},
        min_contig_length => {
            is => 'Integer',
            doc => 'Minimum contig length',
        },
    ],
};

sub help_brief {
    'Tool to create contigs fasta file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-contigs-bases-file --scaffold-sequence-file /gscmnt/111/soap_asm/61EFS.cafSeq --assembly-directory /gscmnt/111/soap_asm
EOS
}

sub execute {
    my $self = shift;

    unless (-d $self->assembly_directory) {
	$self->error_message("Failed to find assembly directory: ".$self->assembly_directory);
	return;
    }

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $self->assembly_scaffold_sequence_file);
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$self->contigs_bases_file);

    my $supercontig_number = 0;
    while (my $seq = $in->next_seq) {
        #filter out scaffolds less than min_contig_length
        next unless length $seq->seq >= $self->min_contig_length;
	my $contig_number = 0;
	my @seqs = split (/N+/, $seq->seq);
	foreach my $bases (@seqs) {
            #filter out contigs less than min contig length
            next unless length $bases >= $self->min_contig_length;
            my $id = 'Contig'.$supercontig_number.'.'.++$contig_number;
	    my $seq_obj = Bio::Seq->new(-seq => $bases, -id => $id );
            $out->write_seq($seq_obj);
	}
	$supercontig_number++;
    }

    return 1;
}


1;
