package Genome::Model::Tools::Assembly::CreateOutputFiles::ReadsPlaced;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Assembly::CreateOutputFiles::ReadsPlaced {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to create assembly reads.placed file'
}

sub help_synopsis {
    my $self = shift;
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    #check for necessary input files
    unless ($self->_validate_input_files()) {
	$self->error_message("Failed to validate necessary input files");
	return;
    }

    my $gap_sizes;
    unless ($gap_sizes = $self->_get_gap_sizes()) {
	$self->error_message("Failed to get gap sizes");
	return;
    }

    my $lengths;
    unless ($lengths = $self->_get_contig_lengths()) {
	$self->error_message("Failed to get contig lengths");
	return;
    }
    
    my $in = IO::File->new("<" . $self->directory.'/edit_dir/readinfo.txt') ||
	die "Can not create file handle for readinfo.txt file\n";

    my $out = IO::File->new(">" . $self->directory.'/edit_dir/reads.placed') ||
	die "Can not create file handle for reads.placed file\n";

    while (my $line = $in->getline) {
	chomp $line;

	my ($read_name, $ctg_name, $dir, $read_pos, $read_length) = split (/\s+/, $line);
	my ($sctg, $ctg) = $ctg_name =~ /(Contig\d+)\.(\d+)/;

	unless ($sctg && $ctg) {
	    $self->error_message("Incorrect contig name format for $ctg_name");
	    return;
	}

	my $u_or_c = ($dir eq 'U') ? 0 : 1;
	my $cumulative_length = 0;

	for (my $i = 1; $i < $ctg; $i++) {
	    next unless exists $gap_sizes->{$sctg}->{$i};
	    next unless exists $lengths->{$sctg}->{$i};

	    my $ctg_len = $lengths->{$sctg}->{$i};
	    my $gap_len = $gap_sizes->{$sctg}->{$i};

	    $cumulative_length = $cumulative_length + $ctg_len + $gap_len;
	}

	my ($sctg_number) = $sctg =~ /Contig(\d+)/;
	my $sctg_name = 'Supercontig'.$sctg_number;
	my $sctg_pos = $cumulative_length + $read_pos;

	$out->print("* $read_name 1 $read_length $u_or_c $ctg_name $sctg_name $read_pos $sctg_pos\n");
    }

    $out->close;
    $in->close;

    return 1;
}

sub _get_contig_lengths {
    my $self = shift;
    
    my $bases_file = $self->directory.'/edit_dir/contigs.bases';
    unless (-s $bases_file) {
	$self->error_message("You must have contigs.bases file to create reads.placed file");
	return;
    }

    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $bases_file);
    my $lengths = {};
    while (my $seq = $in->next_seq) {
	my ($sctg, $ctg) = $seq->primary_id =~ /(Contig\d+)\.(\d+)/;
	unless ($sctg && $ctg) {
	    $self->error_message("Incorrect contig name format: ".$seq->primary_id);
	    return;
	}
	$lengths->{$sctg}->{$ctg} = length $seq->seq;
    }

    return $lengths;
}

sub _get_gap_sizes {
    my $self = shift;
    
    my $gap_file = $self->directory.'/edit_dir/gap.txt';
    unless (-s $gap_file) {
	$self->error_message("You must have gap.txt file to create reads.placed file");
	return;
    }

    my $gaps = {};
    my $fh = IO::File->new("< $gap_file") ||
	die "Can not create file handle for $gap_file";
    while (my $line = $fh->getline) {
	chomp $line;
	my ($sctg, $ctg, $gap) = $line =~ /(Contig\d+)\.(\d+)\s+(\d+)/;
	unless ($sctg && $ctg && $gap) {
	    $self->error_message("Incorrect gap.txt file line format in line: $line");
	    return;
	}
	$gaps->{$sctg}->{$ctg} = $gap;
    }
    $fh->close;

    return $gaps;
}

sub _input_files {
    return ('gap.txt', 'contigs.bases', 'readinfo.txt');
}

sub _validate_input_files {
    my $self = shift;

    my @input_files = $self->_input_files();
    foreach my $file_name (@input_files) {
	unless (-s $self->directory.'/edit_dir/'.$file_name) {
	    $self->error_message("Failed to find file: ".$self->directory.'/edit_dir/'.$file_name);
	    return;
	}
    }

    return 1;
}

1;
