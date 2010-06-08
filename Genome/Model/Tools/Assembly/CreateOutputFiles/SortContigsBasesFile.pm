package Genome::Model::Tools::Assembly::CreateOutputFiles::SortContigsBasesFile;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use Bio::SeqIO;

class Genome::Model::Tools::Assembly::CreateOutputFiles::SortContigsBasesFile {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	file => {
	    is => 'Text',
	    doc => 'Pcap name formatted contigs.bases or contigs.qual file',
	},
	#overwrite_original => {
	#    is => 'Boolean',
	#    is_optional => 1,
	#    doc => 'Overwrite original contigs.bases file',
	#}
    ],
};

sub help_brief {
    'Tool to sort pcap formatted contigs.bases file numerically by contig number',
}

sub help_synopsis {
    my $self = shift;
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
	'gmt assembly create-output-file sort-contigs-bases-file --file contigs.bases'
EOS
}

sub execute {
    my $self = shift;

    unless (-s $self->file) {
	$self->error_message("Can not find or invalid input contigs file: ".$self->file);
	return
    }

    #check if file is alreay sorted
    my $file_is_not_sorted = 0;
    my $previous_contig_number = 0;
    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $self->file);
    while (my $seq = $io->next_seq) {
	my ($contig_number) = $seq->primary_id =~ /Contig(\d+\.\d+)/;
	unless ($contig_number) {
	    $self->error_message("Invalid contig name format in name: ".$seq->primary_id."\n\tit hould be in Contig12.45 format");
	    return;
	}
	#if file is sorted contigs should be in ascending order
	if ($previous_contig_number > $contig_number) {
	    $file_is_not_sorted = 1;
	    last;
	}
	$previous_contig_number = $contig_number;
    }
    
    return 1 if $file_is_not_sorted == 0;

    #create a hash of fastas .. trim contigs name so it can be numerically sorted
    my $contigs = {};
    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $self->file);
    while (my $seq = $in->next_seq) {
	my ($contig_number) = $seq->primary_id =~ /Contig(\d+\.\d+)/;
	$contigs->{$contig_number} = $seq->seq;
    }

    #print contigs to file .. sort by contig number  
    my $out_file_name = $self->file.'.sorted';
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => ">$out_file_name");

    foreach my $contig_num (sort {$a<=>$b} keys %$contigs) {
	my $seq = Bio::Seq->new(-display_id => 'Contig'.$contig_num, -seq => $contigs->{$contig_num});
	$out->write_seq($seq);
    }

    #rename original file to *unsorted and sorted to original file name
    #if ($self->overwrite_original) {
	rename $self->file, $self->file.'.unsorted';
	rename $self->file.'.sorted', $self->file;
    #}

    return 1;
}

1;
