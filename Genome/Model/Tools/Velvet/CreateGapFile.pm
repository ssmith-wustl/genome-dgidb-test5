package Genome::Model::Tools::Velvet::CreateGapFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use IO::File;

class Genome::Model::Tools::Velvet::CreateGapFile {
    is => 'Genome::Model::Tools::Velvet',
    has => [
	contigs_fasta_file => {
	    is => 'Text',
	    doc => 'Velvet created contigs.fa file',
	},
        directory => {
            is => 'Text',
            doc => 'Assembly build directory',
        },
    ],
};

sub help_brief {
    'Tool to create gap.txt file from velvet created contigs.fa file';
}

sub help_synopsis {
    return <<EOS
gmt velvet create-gap-file --contigs-fasta-file /gscmnt/111/velvet_assembly/contigs.fa --directory /gscmnt/111/velvet_assembly
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    unless (-s $self->contigs_fasta_file) {
	$self->error_message("Failed to find file: ".$self->contigs_fasta_file);
	return;
    }

    unlink $self->gap_sizes_file;
    my $fh = Genome::Utility::FileSystem->open_for_writing($self->gap_sizes_file) ||
	return;

    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $self->contigs_fasta_file);

    while (my $seq = $io->next_seq) {
	my @bases = split (/N+/i, $seq->seq);
	my @n_s = split (/[ACGT]+/i, $seq->seq);
        #SINGLE CONTIG SCAFFOLD .. OR ALL NS .. NO GAP INFO NEEDED
	next if scalar @bases le 1;
	#RESOLVE BLANK ELEMENT IN SHIFTED ARRAY
	if ($seq->seq =~ /^N/i) {
	    shift @bases; #BLANK
	    shift @n_s;   #LEADING NS .. NOT NEEDED
	}
	else {
	    shift @n_s;   #BLANK
	}
	#GET RID OF TAILING NS .. NOT NEEDED
	pop @n_s if $seq->seq =~ /N$/i;
	#DOUBLE CHECK BASES AND GAP COUNTS
	unless (scalar @n_s == scalar @bases - 1) {
	    $self->error_message("Error: Unable to match sequences and gaps properly \n");
	    return;
	}
	#DECIPER SUPERCONTIG/CONTIG NAMES
	my ($node_num) = $seq->primary_id =~ /NODE_(\d+)_/;
	unless ($node_num) {
	    $self->error_message("Can not determine node number, expecting NODE_#?_ but got ".$seq->primary_id);
	    return;
	}
	my $supercontig_number = $node_num - 1;
	my $contig_number = 1;
	#ITERATE THROUGH BASES ARRAY AND ASSIGN GAP SIZE
	while (my $base_string = shift @bases) {
	    next if scalar @bases == 1; #LAST CONTIG OF SCAF .. NO GAP INFO
	    my $gap_size = length (shift @n_s);
	    #PRINT CONTIG NAME AND GAP SIZE: eg Contig855.26 91
	    $fh->print ('Contig'.$supercontig_number.'.'.$contig_number.' '.$gap_size."\n");
	    $contig_number++;
	}
    }
    $fh->close;
    return 1;
}

1;
