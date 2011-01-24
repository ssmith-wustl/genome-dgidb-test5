package Genome::Model::Tools::Velvet::CreateSupercontigsFiles;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;

class Genome::Model::Tools::Velvet::CreateSupercontigsFiles {
    is => 'Genome::Model::Tools::Velvet',
    has => [
        contigs_fasta_file => {
            is => 'Text',
	    is_optional => 1,
            doc => 'Velvet contigs.fa file',
        },
        assembly_directory => {
            is => 'Text',
            doc => 'Assembly directory',
        },
    ],
};

sub help_brief {
    'Tool to create velvet supercontigs.agp and supercontigs.fasta files from velvet contigs.fa file'
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
gmt velvet create-supercontigs-files --contigs-fasta-file /gscmnt/111/velvet_asm/contigs.fa --assembly-directory /gscmnt/111/velvet_asm
EOS
}

sub execute {
    my $self = shift;

    #create edit_dir
    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    #need contigs.fa file
    my $contigs_fa_file = ($self->contigs_fasta_file) ? $self->contigs_fasta_file : $self->velvet_contigs_fa_file;

    #filehandle to print supercontigs.agp file
    unlink $self->supercontigs_agp_file;
    my $agp_fh = Genome::Sys->open_file_for_writing($self->supercontigs_agp_file) ||
	return;

    #IO to output supercontigs.fasta
    my $fa_out = Bio::SeqIO->new(-format => 'fasta', -file => ">".$self->supercontigs_fasta_file);

    #read in input contigs.fa file
    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $contigs_fa_file);
    while (my $seq = $io->next_seq) {

	#write seq to supercontigs.fasta
	unless ($self->_write_fasta ($seq, $fa_out)) {
	    $self->error_message("Failed to write sequence to supercontigs fasta");
	    return;
	}

	#write seq description to agp file
	unless ($self->_write_agp($seq, $agp_fh)) {
	    $self->error_message("Failed to write sequence description to agp file");
	    return;
	}
    }

    $agp_fh->close;

    return 1;
}

sub _write_fasta {
    my ($self, $seq, $fa_out) = @_;
    #convert id to pcap format supercontig name
    my $pcap_sctg = $self->_convert_to_pcap_name($seq->id);
    unless ($pcap_sctg) {
	$self->error_message("Failed to convert newbler supercontig to pcap name");
	return;
    }
    #totol length inc gap
    my $total_length = length $seq->seq;
    #length w/o gaps
    my $sequence = $seq->seq;
    $sequence =~ s/N//g; #remove gaps
    my $bases_length = length $sequence;
    #rename id and add desc .. (base_length total_length)
    $seq->id($pcap_sctg);
    $seq->desc($bases_length.' '.$total_length);
    $fa_out->write_seq($seq);
    return 1;
}

sub _write_agp {
    my ($self, $seq, $fh) = @_;

    #writing fasta in prev step already changed seq->id to pcap name
    my $pcap_sctg = $seq->id;

    #put a space between bases and gaps for splitting
    my $string = $self->_separate_bases_and_gaps($seq->seq);
    unless ($string) {
	$self->error_message("Failed to separate bases from gaps for sequence: ".$seq->seq);
	return;
    }

    my $contig_number = 0;
    my $start = 1;
    my $stop = 0;

    my $fragment_order = 0;
    foreach (split(/\s+/, $string)) {
	$fragment_order++;
	if ($_ =~ /^[ACTG]/) { #bases
	    my $length = length $_;
	    $contig_number++;
	    my $contig_name = $pcap_sctg.'.'.$contig_number;
	    $stop = $start - 1 + $length;
	    #printing: Contig1 1       380     1       W       Contig1.1       1       380     +
	    $fh->print( "$pcap_sctg\t$start\t$stop\t$fragment_order\tW\t$contig_name\t1\t$length\t+\n");
	    $start += $length;
	}
	elsif ($_ =~ /^N/) { #gaps
	    my $length = length $_;
	    $stop = $start - 1 + $length;
	    #printing: Contig1 381     453     2       N       73      fragment        yes 
	    $fh->print("$pcap_sctg\t$start\t$stop\t$fragment_order\tN\t$length\tfragment\tyes\n");
	    $start += $length;
	}
	else { #probably not necessary
	    $self->error_message("Found none base or gap string in sequence: ".$_);
	    return;
	}
    }
    
    return 1;
}

sub _convert_to_pcap_name {
    my ($self, $id) = @_;
    #convert velvet NODE_2_ to pcap Contig1
    my ($num) = $id =~ /NODE_(\d+)_/;
    unless (defined $num) {
	$self->error_message("Expecting id like: NODE_2_ but got: $id");
	return;
    }
    return 'Contig'.--$num;
}

sub _separate_bases_and_gaps {
    my ($self, $seq) = @_;
    #TODO - better way?
    $seq =~ s/AN/A N/g;
    $seq =~ s/CN/C N/g;
    $seq =~ s/GN/G N/g;
    $seq =~ s/TN/T N/g;
    $seq =~ s/NA/N A/g;
    $seq =~ s/NC/N C/g;
    $seq =~ s/NG/N G/g;
    $seq =~ s/NT/N T/g;
    return $seq;
}

1;
