package Genome::Model::Tools::Velvet::CreateContigsFiles;

use strict;
use warnings;

use Genome;
use AMOS::AmosLib;

class Genome::Model::Tools::Velvet::CreateContigsFiles {
    is => 'Genome::Model::Tools::Velvet',
    has => [
        afg_file => {
            is => 'Text',
            doc => 'Velvet afg file to get fasta and qual info from',
            is_optional => 1,
        },
        assembly_directory => {
            is => 'Text',
            doc => 'Main assembly directory .. above edit_dir',
        },
    ],
};

sub help_brief {
    'Tool to create contigs.bases and contigs.qual files from velvet afg file';
}

sub help_synopsis {
    my $self = shift;
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
gmt velvet create-contigs-files --afg-file /gscmnt/111/velvet_assembly/velvet_asm.afg --assembly_directory /gscmnt/111/velvet_assembly
EOS
}

sub execute {
    my $self = shift;

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    my $afg_file = ($self->afg_file) ? $self->afg_file : $self->velvet_afg_file;

    unless (-s $afg_file) {
	$self->error_message("Can't find velvet afg file: ".$afg_file);
	return;
    }

    #read in afg file
    my $afg_fh = Genome::Sys->open_file_for_reading($afg_file)
	or return;

    #make edit_dir
    unless (-d $self->assembly_directory.'/edit_dir') {
	Genome::Sys->create_directory($self->assembly_directory.'/edit_dir');
    }

    #write out contigs.bases file
    my $f_io = Bio::SeqIO->new(-format => 'fasta', -file => ">".$self->contigs_bases_file);

    #write out contigs.quals file
    my $q_io = Bio::SeqIO->new(-format => 'qual', -file => ">".$self->contigs_quals_file);

    while (my $record = getRecord($afg_fh)) {
	my ($rec, $fields, $recs) = parseRecord($record);

	if ($rec eq 'CTG') { #contigs
	    #convert to pcap id .. 2-1 converts to Contig1.2
	    my ($sctg_num, $ctg_num) = split('-', $fields->{eid});
	    my $contig_id = 'Contig'.--$sctg_num.'.'.++$ctg_num;

	    #write fasta
	    my $seq = $fields->{seq};
	    $seq =~ s/\n//g; #contig seq is written in multiple lines .. remove end of line
	    my $seq_obj = Bio::Seq->new(-display_id => $contig_id, -seq => $seq);
	    $f_io->write_seq($seq_obj);
	    #write qual
	    my $qual = $fields->{qlt};
	    $qual =~  s/\n//g;
	    my @quals;
	    for my $i (0..length($qual)-1) {
                unless (substr($seq, $i, 1) eq '*') {
                    push @quals, ord(substr($qual, $i, 1)) - ord('0');
                }
            }
	    my $qual_obj = Bio::Seq::Quality->new(-display_id => $contig_id, -seq => $seq, -qual => \@quals);
	    $q_io->write_seq($qual_obj);
	}
    }

    $afg_fh->close;
    return 1;
}

1;
