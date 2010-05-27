package Genome::Model::Tools::Assembly::CreateOutputFiles::ContigsFromAce;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Assembly::CreateOutputFiles::ContigsFromAce {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	acefile => {
	    is => 'Text',
	    doc => 'Ace file to get fasta and qual from',
	    is_optional => 1,
	},
	directory => {
	    is => 'Text',
	    doc => 'Assembly build directory',
	},
    ],
};

sub help_brief {
    'Tool to create contigs.bases and contigs.qual files from ace file';
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

    my $ace = ($self->acefile) ? $self->ace_file : $self->directory.'/edit_dir/velvet_asm.ace';
    unless (-s $ace) {
	$self->error_message("Can find ace file: $ace");
	return;
    }
    
    #existing ace parser are not used to speed up this process
    #need to clean this up a bit ..

    my $ace_fh = IO::File->new("<$ace");
    my $fasta_file = $self->directory.'/edit_dir/contigs.bases';
    my $fasta_fh = IO::File->new(">$fasta_file");
    my $qual_file = $self->directory.'/edit_dir/contigs.quals';
    my $qual_fh = IO::File->new(">$qual_file");
    
    my $is_fasta = 0;
    my $is_qual = 0;
    my $contig_name;
    my $base_line_count = 0;
    
    while (my $line = $ace_fh->getline) {
	next if $line =~ /^\s+$/;
	chomp $line;
	if ($line =~ /^CO\s+/) {
	    ($contig_name) = $line =~ /^CO\s+(\S+)\s?/;
	    $fasta_fh->print (">$contig_name\n");
	    $is_fasta = 1;
	    next;
	}
	if ($line =~ /^BQ/) {
	    $is_fasta = 0;
	    $fasta_fh->print ("\n") if $base_line_count != 0;
	    $base_line_count = 0;
	    $is_qual = 1;
	    $qual_fh->print (">$contig_name\n");
	    next;
	}
	if ($is_fasta == 1) {
	    my @bases = split (//, $line);
	    foreach my $base (@bases) {
		if ($base =~ /^[acgtxn]$/i) {
		    $base_line_count++;
		    $fasta_fh->print ($base);
		    if ($base_line_count == 60) {
			$fasta_fh->print ("\n");
			$base_line_count = 0;
		    }
		}
		else {
		    next;
		}
	    }
	}
	if ($line =~ /^AF\s+/) {
	    $qual_fh->print ("\n") if $base_line_count != 0;
	    $base_line_count = 0;
	    $is_qual = 0;
	    next;
	}
	if ($is_qual == 1) {
	    my @quals = split (/\s+/, $line);
	    foreach my $qual (@quals) {
		next unless $qual =~ /^\d+$/;
		$base_line_count++;
		if ($base_line_count == 60) {
		    $qual_fh->print ("$qual\n");
		    $base_line_count = 0;
		}
		else {
		    $qual_fh->print ("$qual ");
		}
	    }
	}
    }

    $ace_fh->close;
    $fasta_fh->close;
    $qual_fh->close;
    
    return 1;
}

1;
