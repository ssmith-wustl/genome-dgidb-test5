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
print SNP_SQL_OUT "Chromosome\tStart\tStop\n";

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
	my $ROI_size = ($size - 2);
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

	my $Position = $ROI_SNP[$size - 1];
	my $Chrom = $ROI_SNP[$size];

	$Chrom =~ s/chr//g;
	$Chrom =~ s/MITOCHONDRIAL/MT/g;

	my $ROI_set_name = join(' ', @ROI_name);
	print SNP_SQL_OUT "$Chrom\t$Position\t$Position\n";
#	print SNP_SQL_OUT "$Chrom\t$Position\t$Position\t$RT\n";
} 
