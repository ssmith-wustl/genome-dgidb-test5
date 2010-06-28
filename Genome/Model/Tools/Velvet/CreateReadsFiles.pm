package Genome::Model::Tools::Velvet::CreateReadsFiles;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use AMOS::AmosLib;

class Genome::Model::Tools::Velvet::CreateReadsFiles {
    is => 'Genome::Model::Tools::Velvet',
    has => [
	sequences_file => {
	    is => 'Text',
	    doc => 'Velvet created sequences file: Sequences',
	},
	afg_file => {
	    is => 'Text',
	    doc => 'Velvet created afg file: velvet_asm.afg',
	},
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to create velvet readinfo.txt file'
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
gmt velvet create-reads-files --sequences-file /gscmnt/111/velvet_assembly/Sequences --contigs-fasta-file /gscmnt/111/velvet_assembly/contigs.fa --directory /gscmnt/111/velvet_assembly
EOS
}

sub execute {
    my $self = shift;

    #validate assembly directory
    unless(-d $self->directory) {
	$self->error_message("Can't find or invalid assembly directory: ".$self->directory);
	return;
    }

    #TODO - need to make sure edit_dir is there
    #readinfo.txt
    unlink $self->read_info_file;
    my $ri_fh = Genome::Utility::FileSystem->open_file_for_writing($self->read_info_file) ||
	return;

    #reads.placed file
    unlink $self->reads_placed_file;
    my $rp_fh = Genome::Utility::FileSystem->open_file_for_writing($self->reads_placed_file) ||
	return;

    #handle sequences file
    unless (-s $self->sequences_file) {
	$self->error_message("Can't find velvet sequences file: ".$self->sequences_file);
	return;
    }

    #load gap sizes
    my $gap_sizes = $self->get_gap_sizes;
    unless ($gap_sizes) {
	$self->error_message("Failed to get gap sizes");
	return;
    }

    #load contigs lengths
    my $contig_lengths = $self->get_contig_lengths($self->afg_file);
    unless ($contig_lengths) {
	$self->error_message("Failed to get contigs lengths");
	return;
    }

    #load read names db for look up
    my $read_names_db = Genome::Model::Tools::Velvet::ReadNamesDatabase->create (
	sequences_file => $self->sequences_file,
	directory => $self->directory,
	);
    unless ($read_names_db->execute) {
	$self->error_message("Failed to execute creating/loading of velvet read names db");
	return;
    }

    #parse afg file to get read info
    unless (-s $self->afg_file) {
	$self->error_message("Can't find velvet afg file: ".$self->afg_file);
	return;
    }
    my $afg_fh = Genome::Utility::FileSystem->open_file_for_reading($self->afg_file)
        or return;

    while (my $record = getRecord($afg_fh)) {
	my ($rec, $fields, $recs) = parseRecord($record);
	#iterating through contigs
	if ($rec eq 'CTG') {
	    #seq is in multiple lines
	    my $contig_length = $self->_contig_length_from_fields($fields->{seq});
	    unless ($contig_length) {
		$self->error_message("Failed get contig length for seq: ");
		return;
	    }
	    #convert afg contig format to pcap format
	    my ($sctg_num, $ctg_num) = split('-', $fields->{eid});
	    my $contig_name = 'Contig'.--$sctg_num.'.'.++$ctg_num;
	    #iterating through reads
	    for my $r (0 .. $#$recs) {
		my ($srec, $sfields, $srecs) = parseRecord($recs->[$r]);
		if ($srec eq 'TLE') {

		    #sfields:
		    #'src' => '19534',  #read id number
		    #'clr' => '0,90',   #read start, stop 0,90 = uncomp 90,0 = comp
		    #'off' => '75'      #read off set .. contig start position

		    #this may to too time comsuming and not necessary
		    unless ($self->_validate_read_field($sfields)) {
			$self->error_message("Failed to validate read field");
			return;
		    }

		    #get read contig start, stop and orientaion
		    my ($ctg_start, $ctg_stop, $c_or_u) = $self->_read_start_stop_positions($sfields); 

		    #look up read name from read_names sqlite db
		    my ($read_name, $seek_pos) = $read_names_db->get_read_name_from_afg_index($sfields->{src});
		    unless ($read_name and defined $seek_pos) {
			$self->error_message("Failed to get read name and/or seek position for read id: ".$sfields->{src});
			return;
		    }

		    #TODO - look into storing read length too so this can be avoided??
		    my $read_length = $self->_read_length_from_sequences_file($seek_pos);

		    #print to readinfo.txt file
		    $ri_fh->print("$read_name $contig_name $c_or_u $ctg_start $read_length\n");

		    #convert C U to 1 0 for reads.placed file
		    $c_or_u = ($c_or_u eq 'U') ? 0 : 1;

		    #calculate contig start pos in supercontig
		    my $sctg_start = $self->_get_supercontig_position($contig_lengths, $gap_sizes, $contig_name);
		    $sctg_start += $ctg_start;

		    $rp_fh->print("* $read_name 1 $read_length $c_or_u $contig_name Supercontig$sctg_num $ctg_start $sctg_start\n");
		}
	    }
	}
    }

    $afg_fh->close;
    $ri_fh->close;
    $rp_fh->close;

    return 1;
}

sub _validate_read_field { #too much??
    my ($self, $fields) = @_;
    #sfields:
    #'src' => '19534',  #read id number
    #'clr' => '0,90',   #read start, stop 0,90 = uncomp 90,0 = comp
    #'off' => '75'      #read off set .. contig start position
    foreach ('src', 'clr', 'off') {
	unless (exists $fields->{$_}) {
	    $self->error_message("Failed to find $_ element in read fields");
	    return;
	}
	if ($_ eq 'clr') {
	    unless ($fields->{$_} =~ /^\d+\,\d+$/) {
		$self->error_message("Value for $_ read field key should be two comma separated numbers and not ".$fields->{clr});
		return;
	    }
	}
	elsif ($_ eq 'src') { #should be integers
	    unless ($fields->{$_} =~ /^\d+$/) {
		$self->error_message("Value for $_ read field key should be a number and not ".$fields->{$_});
		return;
	    }
	}
	elsif ($_ eq 'off') {
	    unless ($fields->{$_} =~ /-?\d+$/) {
		$self->error_message("value for $_ read field key should be an + or - integer not ".$fields->{$_});
		return;
	    }
	}
    }
    return 1;
}

sub _contig_length_from_fields {
    my ($self, $seq) = @_;

    #seq is in multiple lines
    $seq =~ s/\n//g;
    
    return length $seq;
}

sub _read_start_stop_positions {
    my ($self, $fields) = @_;

    my ($start, $stop) = split(',', $fields->{clr});
    unless (defined $start and defined $stop) {
	$self->error_message("Failed to get read start, stop positions from record: ".$fields->{clr});
	return;
    }
    #read complementation
    my $c_or_u = ($start > $stop) ? 'C' : 'U';
    #re-direct start, stop to physical contig positions .. regardless of u or c
    ($start, $stop) = $start < $stop ? ($start, $stop) : ($stop, $start);
    $start += $fields->{off} + 1;
    $stop += $fields->{off} + 1;
    
    return $start, $stop, $c_or_u;
}

sub _get_supercontig_position {
    my ($self, $contig_lengths, $gap_sizes, $contig_name) = @_;

    my ($supercontig_number, $contig_number) = $contig_name =~ /Contig(\d+)\.(\d+)/;
    unless (defined $contig_number and defined $supercontig_number) {
	$self->error_message("Failed to get contig number from contig_name: $contig_name");
	return;
    }
    my $supercontig_position;
    #add up contig length and gap sizes 
    while ($contig_number > 0) {
	$contig_number--;
	
	if ($contig_number == 0) {
	    $supercontig_position += 0;
	}
	else {
	    my $name = 'Contig'.$supercontig_number.'.'.$contig_number;
	    #total up contig lengths
	    unless (exists $contig_lengths->{$name}) {
		$self->error_message("Failed to get contig length for contig: $name");
		return;
	    }
	    $supercontig_position += $contig_lengths->{$name};
	    #total up gap lengths
	    unless (exists $gap_sizes->{$name}) {
		$self->error_message("Failed to get gap size for contig: $name");
		return;
	    }
	    $supercontig_position += $gap_sizes->{$name};
	}
    }
    return $supercontig_position;
}

sub _read_length_from_sequences_file {
    my ($self, $seek_pos) = @_;

    my $seq_fh = Genome::Utility::FileSystem->open_file_for_reading($self->sequences_file) or return;
    $seq_fh->seek($seek_pos, 0);
    my $io = Bio::SeqIO->new(-fh => $seq_fh, -format => 'fasta');

    my $read_length = length ($io->next_seq->seq);

    unless ($read_length > 0) {
	$self->error_message("Read length must be a number greater than zero and not ".$read_length);
	return;
    }
    $seq_fh->close;
    return $read_length;
}

1;
