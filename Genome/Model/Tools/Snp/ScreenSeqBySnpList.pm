package Genome::Model::Tools::Snp::ScreenSeqBySnpList;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Snp::ScreenSeqBySnpList {
    is => 'Command',                    
    has => [ 
	screen_file => {
	    is =>  'string',
	    doc   =>  "coordinates for screening list; 1st column chromosome second column coordinate",
	},
	
	fasta => {
	    is =>  'string',
	    doc   =>  "provide a fasta you want screened",
	    is_optional  => 1,
	},
	
	mp_grande => {
	    is  =>  'String',
	    doc   =>  "dump of amplicon info from mp_grande containing chromosome and primer coordinates",
	    is_optional  => 1,
	},
	
	]
	    
};

sub help_brief {
    return <<EOS
	This tool was design to screen either the mp_grande file dump of amplicon info or a fasta with the provided list of coordinates.
EOS
}

sub help_synopsis {
    return <<EOS

gt snp screen-seq-by-snp-list -screen-file -fasta

-or-

gt snp screen-seq-by-snp-list -screen-file -mp-grande

EOS
}


sub help_detail {
    return <<EOS 

The screen_file should conatin at least two columns with the chromosom in column 1 and the coordinate in column 2. The coulmns should be space delimited. Any number of other colums will be diregaurded by this tool.

If using a fasta it should contain Chr Coords and Ori info in the header in this format
 Chr:3, Coords 103057567-103057936, Ori (+)

If screening primers in an mp_grande dump of amplicon info please use the extra info feature so as to get the chromosome

EOS
}


sub execute {

    my $self = shift;

    my $screen_file = $self->screen_file;
    unless ($screen_file && -e $screen_file) { exit "couldn't see a snp file check your list\n"; }

    my $fasta = $self->fasta;
    my $mp_grande = $self->mp_grande;

    my $screen;
    my $lines;
    my $all_lines;
    
    if ($mp_grande) {
	open(CSV,$mp_grande) || die "couldn't open the mp_grande file\n\n"; 
	
	
	while (<CSV>) {
	    chomp;
	    my $line = $_;
	    my ($Row,$Amplicon_Name,$PCR_Status,$Conf,$Prod_Size,$L_Primer_Coord,$R_Primer_Coord,$Amp_Size,$L_Amp_Coord,$R_Amp_Coord,$Enzyme,$Primer_1,$Primer_1_Seq,$Tail_1_Name,$Primer_2,$Primer_2_seq,$Tail_2_Name,$Amplicon_Sequence,$Project,$ROI_Name,$ROI_List,$Target_Name,$Target_Start,$Target_Stop,$Target_Region_Type,$Hugo_Name,$EntrezGene_Id,$Chrom,$Amplicon_Ref_ID,$SNP_in_primer,$Manually_Designed) = split(/\,/,$line);
	    unless($line =~ /Coord/) {
		$Chrom =~ s/([\S]+)/\U$1/;
		
		$Primer_1_Seq =~ s/TGTAAAACGACGGCCAGT//;
		$Primer_2_seq =~ s/CAGGAAACAGCTATGACC//;
		my $p1l = length($Primer_1_Seq);
		my $p2l = length($Primer_2_seq);
		
		my $lpe = ($L_Primer_Coord + $p1l) - 1;
		my $rps = ($R_Primer_Coord - $p2l) + 1;
		
#	print qq($Chrom  ($L_Primer_Coord + $p1l = $lpe) $L_Amp_Coord $R_Amp_Coord  ($rps = | $p2l - $R_Primer_Coord |)\n);
		$all_lines->{$line}=1;
		for my $pos ($L_Primer_Coord..$lpe) {
		    $lines->{$Chrom}->{$pos}->{$line}=1;
		    $screen->{$Chrom}->{$pos}=1;
		}
		for my $pos ($rps..$R_Primer_Coord) {
		    $lines->{$Chrom}->{$pos}->{$line}=1;
		    $screen->{$Chrom}->{$pos}=1;
		}
	    }
	}
	close (CSV);
	my $snps_in_primer;
	
	my $fh = IO::File->new($screen_file,"r");
	
	unless($fh) {
	    die "Unable to open snp file";
	}
	
#my $test = $self->is_within_primer($t->chrom_name, @primer_genomic_alignments);
	while(my $line = $fh->getline) {
	    my ($chr, $pos) = split /\t/, $line;
	    
	    my $primer_line = $screen->{$chr}->{$pos};
	    if ($primer_line) {
		#print qq($primer_line\n);
		
#	print qq($chr, $pos\n);
		
		#$snps_in_primer->{$primer_line}++;
		$snps_in_primer->{$chr}->{$pos}=1;
	    }
	}
	open(OUT,">$mp_grande.snps_in_primers");
	open(OUT2,">$mp_grande.good_primers");
	my $snp_lines;
	foreach my $chr (sort keys %{$lines}) {
	    foreach my $pos (sort keys %{$lines->{$chr}}) {
		my $snp_pos = $snps_in_primer->{$chr}->{$pos};
		if ($snp_pos) {
		    foreach my $line (sort keys %{$lines->{$chr}->{$pos}}) {
			$snp_lines->{$line}=1;
		    }
		}
	    }
	}
	
	foreach my $line (sort keys %{$all_lines}) {
	    my $snp = $snp_lines->{$line};
	    if ($snp) {
		print OUT qq($line\n);
	    } else {
		print OUT2 qq($line\n);
	    }
	}
	close (OUT);
	close (OUT2);
	print qq(\nsee you're results in the files $mp_grande.snps_in_primers and $mp_grande.good_primers\n\n);
	
	
    }
    if ($fasta) {

	open(OUT,">$fasta.snp_screened");

	my (@fast_a,$chr,$start,$stop,$ori,@seq,$seq_line_length);
	open(FASTA,$fasta) || die ("\n\nCould not open the FASTA file\n\n");
	while (<FASTA>) {
	    chomp;
	    my $line = $_;
	    if ($line =~ /^\>/) {
		($chr) = $line =~ /Chr\:([\S]+)/;$chr =~ s/\,//;
		($start,$stop) = /Coords[\s]+(\d+)\S(\d+)/;
		($ori) = $line =~ /Ori \((\S)\)/;
		unless ($ori) {$ori = "+";}
		print OUT qq($line\n);
	    } else {
		$line =~ s/\s//gi;
		unless($seq_line_length) {$seq_line_length = length($line);}
		my @bases = split(//,$line);
		for my $base (@bases) {
		    push(@seq,$base);
		}
	    }
	}
	close (FASTA);

	($screen)=&get_screen($chr,$start,$stop,$screen_file,$screen);
	my $n = 1;
	for my $base (@seq) {
	    if ($ori eq "-") {$start = $stop;}
	    my $screened = $screen->{$start};
	    if ($ori eq "-") {
		$start--;
	    } else {
		$start++;
	    }
	    if ($screened) {
		$base = "N";
	    }
	    print OUT qq($base);
	    if ($n == $seq_line_length) {
		print OUT qq(\n);
		$n = 0;
	    }
	    $n++;
	}
	print OUT qq(\n);
	close (OUT);
	print qq(\nsee you're screened fasta in the file $fasta.snp_screened\n\n);
    }
}


sub get_screen {
    
    my ($chr,$start,$stop,$screen_file,$screen) = @_;
    open(SCREEN,$screen_file) || die ("couldn't open the screen file\n\n");
    while (<SCREEN>) {
	chomp;
	my $line = $_;
	my ($chrom,$pos) = (split(/[\s]+/,$line))[0,1];
	if ($chr eq $chrom) {
	    if ($pos >= $start && $pos <= $stop) {
		$screen->{$pos}=1;
	    }
	}
    } close (SCREEN);
    return($screen);
}






