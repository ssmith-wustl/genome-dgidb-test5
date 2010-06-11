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

unless (open(SNP_SQL_FAIL_OUT,">$sql_snp_site_output.fail")) {
	die "Could not open output file '$sql_snp_site_output' for writing";
  }


#HEADER ON OUTPUT FILE
print SNP_SQL_OUT "CHR1\tPos1\tCHR2\tPos2\tOrientation\tType\tOthers\n";


my $cue = 0;
my $RT="";
my ($first, $second, $line) = ("","","");;
while( $line = <SNP_SQL_IN> ) {
    if ($line =~ /SV/){
	($first,$second) = split (/\sSEQUENCE\sSV\s/, $line);
	my ($t,$chr1,$pos1,$chr2,$pos2,$type,$ori,$score,$amplicon) =("","","","","","","","","");
	($first, $amplicon) = split(/\s+/, $second);
#	print "$amplicon\n";
	chomp $amplicon;
#	print $line;
	if ($line !~ /CTX/){
	    my @each = split(/\:/, $first);
	    if ($#each == 4){
		($pos1,$pos2,$type,$t,$chr1) = split(/\:/, $first);
	    }else{
		($pos1,$pos2,$type,$chr1) = split(/\:/, $first);
	    }
	    $chr2=$chr1;
	    $ori="\t";
	}else{
	    ($chr1,$pos1,$chr2,$pos2,$type,$ori) = split(/\:/, $first);
	}
	$chr1 =~ s/chr//g;
#	$chr1 =~ s/MITOCHONDRIAL/MT/g;
	$chr2 =~ s/chr//g;
#	$chr2 =~ s/MITOCHONDRIAL/MT/g;
	print "$chr1\t$pos1\t$chr2\t$pos2\t$type\t$ori\t\n";
	if (length($amplicon) > 4){
	    print SNP_SQL_OUT "$chr1\t$pos1\t$chr2\t$pos2\t$type\t$ori\t\n";
	}else{
	    print SNP_SQL_FAIL_OUT "$chr1\t$pos1\t$chr2\t$pos2\t$type\t$ori\t\n";
	}
#	print SNP_SQL_OUT "$Chrom\t$Position\t$Position\t$RT\n";
    }
} 

close SNP_SQL_IN;
close SNP_SQL_FAIL_OUT;
close SNP_SQL_OUT;
