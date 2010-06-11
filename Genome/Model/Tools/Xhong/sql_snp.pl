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
print SNP_SQL_OUT "Chr\tStart\tStop\n";


my $cue = 0;
my $RT="";
my ($first, $second, $line) = ("","","");;
while( $line = <SNP_SQL_IN> ) {
    if ($line =~ /Variation/){
	($first,$second) = split (/\sVariation\s/, $line);
	my ($pos, $start,$stop, $chr, $amplicon,$tmp) =("","","","","","");
	if($second !~ /\:/){
	    ($pos, $chr, $amplicon) = split(/\s+/, $second);
	    $start=$stop=$pos;
	}else{
	    if ($line !~ /UNKNOWN/){
		($pos, $chr, $amplicon) = split(/\s+/, $second);
		($start,$stop)=split (/\:/, $pos);
	    }else{ # if line contains "8547499 (NT_113885:75643) chrUNKNOWN 2851551033"
		($pos, $chr, $amplicon) = split(/\s+/, $second);
		$chr=~s/\(//;
		$chr=~s/\)//;
		($chr,$pos)= split/\:/,$chr;
		$start=$stop=$pos;
		print "$line\n$second\n$chr\n";
		print"$chr, $start,$stop\n";
	    }
	}
	chomp $amplicon;
#	print $line;
	$chr =~ s/chr//g;
	$chr =~ s/MITOCHONDRIAL/MT/g;
	if (length($amplicon) > 4){
	    print SNP_SQL_OUT "$chr\t$start\t$stop\n";
	}else{
	    print SNP_SQL_FAIL_OUT "$chr\t$start\t$stop\n";
	}
#	print SNP_SQL_OUT "$Chrom\t$Position\t$Position\t$RT\n";
    }
} 

close SNP_SQL_IN;
close SNP_SQL_FAIL_OUT;
close SNP_SQL_OUT;
