package Genome::Model::Tools::Assembly::ConvertToPcap::Velvet;

use strict;
use warnings;
use Genome;
use IO::File;
use Bio::SeqIO;

class Genome::Model::Tools::Assembly::ConvertToPcap::Velvet {
    is => 'Genome::Model::Tools::Assembly::ConvertToPcap',
    has => [
	    contigs_fa_file => {
		is => 'String',
		doc => 'Velvet generated contigs_fa file',
	    },
	    out_file => {
		is => 'String',
		doc => 'Output file',
		is_optional => 1,
	    },
   ],
};

sub help_brief {
    "Tool to create pcap scaffolded ace and gap file",
}

sub help_synopsis {
    return <<"EOS"
gt assembly convert-to-pcap -contigs-fa-file <FILE>
EOS
}

sub help_detail {
    return <<EOS
Tool to create pcap scaffolded ace and gap file
EOS
}

sub execute {
    my $self = shift;

    my $contigs_file = $self->contigs_fa_file;
    unless (-s $contigs_file) {
	$self->error_message("Unable to access file: $contigs_file");
	return;
    }

    my $gap_out_file = ($self->out_file) ? $self->out_file : 'velvet.gap.txt';

    my $gap_fh = IO::File->new("> $gap_out_file");
    unless ($gap_fh) {
	$self->error_message("Failed to create file handle for velvet.gap.txt file");
	return;
    }

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $contigs_file);
    while (my $seq = $in->next_seq) {
	my $id = $seq->primary_id;
	my ($node_num) = $id =~ /NODE_(\d+)_/;
	my $contig_num = 0;
	my $supercontig_num = $node_num - 1;
	my $sequence = $seq->seq;
	#CREATE AN ARRAY OF BASE STRINGS 
	my @bases = split (/N+/i, $sequence);
	#CREATE AN ARRAY OF N STRINGS
	my @n_s = split (/[ACGT]+/i, $sequence);
	#SHIFT OF THE FIRST ELEMENT WHICH IS NOTHING
	my $blank = shift @n_s;
	foreach my $contig_sequence (@bases) {
	    $contig_num++;
	    my $contig_name = 'Contig'.$supercontig_num.'.'.$contig_num;
	    my $contig_length = length $sequence;
	    my $gap_seq = shift @n_s;
	    my $gap_size = ($gap_seq) ? length $gap_seq : 100 ;
	    $gap_fh->print("$contig_name $gap_size\n");
	}
	$supercontig_num++;
	$contig_num++;
    }
    $gap_fh->close;
    return 1;
}

1;

