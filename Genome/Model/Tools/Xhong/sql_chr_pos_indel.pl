##############
#__STANDARD PERL PACKAGES
  use strict;
  use warnings;
  use Cwd;
#  use Genome;
##############

########################NORMAL CONSENSUS GENOTYPE LOOKUP#################################


my $sql_snp_site_input = "$ARGV[0]";
my $sql_snp_site_output = "$ARGV[1]";
# Open SNP Input
unless (open(SNP_SQL_IN,"<$sql_snp_site_input")) {
	die "Could not open input file '$sql_snp_site_input' for writing";
}
# Open Output
unless (open(SNP_SQL_OUT,">$sql_snp_site_output")) {
	die "Could not open output file '$sql_snp_site_output' for writing";
  }

#HEADER ON OUTPUT FILE
print SNP_SQL_OUT "Chromosome\tStart\tStop\tIndel\n";
#SJC-7 Validation SV RT54307 - SEQUENCE SV 69003211:69003358:DEL:chr1
my $cue = 0;
my $RT="";
while( my $splitter = <SNP_SQL_IN> ) {
	my @ROI_SNP = split(/\s/, $splitter);
	chomp @ROI_SNP;
	print $splitter;
	if ($ROI_SNP[0] =~ m/---/) {
		$cue = 1;
		next;
	}
	if ($cue == 0) {
		next;
	}
	if ($splitter =~ m/row\(s\)/ && $splitter =~ m/second\(s\)/) {
		next;
	}

	my $size = (@ROI_SNP - 1);
	my $ROI_size = ($size - 1);
	my @ROI_name;
	my $iter = 0;
	while ($iter <= $ROI_size) {
		if ($ROI_SNP[$iter] =~ m/RT/) {
			$RT = $ROI_SNP[$iter];
		}
		$ROI_name[$iter] = $ROI_SNP[$iter];
		$iter++;
	}

	my $project = $ROI_SNP[0];

	my @chr_pos_indel = split(/:/, $ROI_SNP[$size]);

	my $pos_start = $chr_pos_indel[0];
	my $pos_stop = $chr_pos_indel[1];
	my $indel = $chr_pos_indel[2];
	my $Chrom = $chr_pos_indel[3];

	unless ($Chrom =~ m/chr/) {
		$Chrom = $chr_pos_indel[4];
	}

	$Chrom =~ s/chr//g;
	$Chrom =~ s/MITOCHONDRIAL/MT/g;

	my $ROI_set_name = join(' ', @ROI_name);
	print SNP_SQL_OUT "$Chrom\t$pos_start\t$pos_stop\t$indel\n";
#	print SNP_SQL_OUT "$Chrom\t$pos_start\t$pos_stop\t$indel\t$RT\n";
} 
