package Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use AMOS::AmosLib;

class Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles {
    is => 'Genome::Model::Tools::Velvet',
    has => [
	sequences_file => {
	    is => 'Text',
	    doc => 'Velvet create Sequences file',
	},
	afg_file => {
	    is => 'Text',
	    doc => 'Velvet created velvet_asm.afg file',
	},
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to create velvet reads.unplaced file'
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    unless (-d $self->directory) {
	$self->error_message("Can't find or invalid directory: ".$self->directory);
	return;
    }

    #validate sequences file
    unless (-s $self->sequences_file) {
	$self->error_message("Failed to find Sequences file: ".$self->sequences_file);
	return;
    }

    #TODO - move this to velvet base class - used multiple times
    my $read_names_and_pos = $self->_load_read_names_and_seek_pos();
    unless ($read_names_and_pos) { #arrayref
	$self->error_message("Failed to get read names and seek_pos from Sequences file");
	return;
    }

    my $unplaced_reads = $self->_remove_placed_reads($read_names_and_pos);
    unless ($unplaced_reads) {
	#TODO - make sure this works for empty array ref too
	$self->error_message("Failed to remove placed reads from input reads");
	return;
    }

    unless ($self->_print_unplaced_reads($unplaced_reads)) {
	$self->error_message("Failed to print unplaced reads");
	return;
    }

    return 1;
}

sub _print_unplaced_reads {
    my ($self, $unplaced_reads) = @_;

    unlink $self->reads_unplaced_file;
    my $unplaced_fh = Genome::Utility::FileSystem->open_file_for_writing($self->reads_unplaced_file) ||
	return;
    my $fasta_out = Bio::SeqIO->new(-format => 'fasta', -file => '>'.$self->reads_unplaced_fasta_file) ||
	die;
    for (0 .. $#$unplaced_reads) {
	next unless defined @$unplaced_reads[$_];
	my $read_name = ${$unplaced_reads}[$_][1];
	unless ($read_name) {
	    $self->error_message("Failed to get read name for afg read index $_");
	    return;
	}
	$unplaced_fh->print("$read_name unused\n");
	my $seek_pos = ${$unplaced_reads}[$_][0];
	unless (defined $seek_pos) {
	    $self->error_message("Failed to get read seek position for afg read index $_");
	    return;
	}
	#This doesn't seek to work properly if fh is held open constantly
	my $seq_fh = Genome::Utility::FileSystem->open_file_for_reading($self->sequences_file) || 
	    return;
	$seq_fh->seek($seek_pos, 0);
	my $io = Bio::SeqIO->new(-fh => $seq_fh, -format => 'fasta');
	#$fasta_out->write_seq($io->next_seq);
	my $seq = $io->next_seq;
	my $seq_obj = Bio::Seq->new(-display_id => $seq->primary_id, -seq => $seq->seq);
	$fasta_out->write_seq($seq_obj);
	$seq_fh->close;
    }
    $unplaced_fh->close;

    return 1;
}

sub _remove_placed_reads {
    my ($self, $input_reads) = @_;

    unless (-s $self->afg_file) {
	$self->error_message("Failed to find afg file: ".$self->afg_file);
	return;
    }
    my $afg_fh = Genome::Utility::FileSystem->open_file_for_reading($self->afg_file) ||
	return;
    while (my $record = getRecord($afg_fh)) {
	my ($rec, $fields, $recs) = parseRecord($record);
	if ($rec eq 'CTG') {
	    for my $r (0 .. $#$recs) {
		my ($srec, $sfields, $srecs) = parseRecord($recs->[$r]);
		if ($srec eq 'TLE') {
		    #sfields:
		    #'src' => '19534',  #read id number
		    #'clr' => '0,90',   #read start, stop 0,90 = uncomp 90,0 = comp
		    #'off' => '75'      #read off set .. contig start position
		    @$input_reads[$sfields->{src}] = undef;
		}
	    }
	}
    }

    $afg_fh->close;
    return $input_reads;
}

sub _load_read_names_and_seek_pos {
    my $self = shift;

    my @seek_positions;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($self->sequences_file) ||
	return;
    my $seek_pos = $fh->tell;
    my $io = Bio::SeqIO->new(-format => 'fasta', -fh => $fh);
    while (my $seq = $io->next_seq) {
	my ($read_index) = $seq->desc =~ /(\d+)\s+\d+$/;
	unless ($read_index) {
            $self->error_message("Failed to get read index number from seq->desc: ".$seq->desc);
            return;
        }
        push @{$seek_positions[$read_index]}, $seek_pos;
        push @{$seek_positions[$read_index]}, $seq->primary_id;

        $seek_pos = $fh->tell;
    }
    $fh->close;
    return \@seek_positions;
}

1;
