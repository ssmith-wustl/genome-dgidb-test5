#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# USEAGE: perl ManualREview_and_cosmic.pl <manualreview> <cosmic> <combine>
# Eg:  perl /gscuser/xhong/svn/perl_modules/Genome/Model/Tools/Xhong/ManualReview_and_cosmic.pl /gscmnt/200/medseq/biodb/shared/production/St_Jude_Pediatric_Cancer/SJC10/SJC10_RT54074_SNV/SJC10_tier_1_low_confidence_SNV.csv SJC10-tier1-lc-annotate-cosmic.txt SJC10-combine-lc.txt

use strict;
use warnings;


my (%MR, %cosmic)= ({},{});
my $n=0;
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    $line=~ s/\n$//;
    my ( $chr, $start, $stop, $ref, $var, $s1,$s2,$s3,$s4,$s5,$s6,$s7,$MR)=split/\t/, $line;

# for SJ project
#    my ( $chr, $start, $stop, $ref, $var, $type,$s2,$s3,$s4,$s5,$s6,$s7, $MR, $comments) = split /\t/, $line;
#    $MR =~ s/\"//gi;
#    $comments=~ s/\"//gi;
    my $key="$chr:$start:$stop";
#    if ($MR eq "S"){
	 $n ++;
	 $MR{$key}="$MR\t";
#   }
}
close I;

print "$n\n";
exit if $n==0;
open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(O, ">$ARGV[2]") or die "cannot open $ARGV[2]";
while(<I>){
    my $line=$_;
    my ($ln, $chr, $start, $stop, $ref, $var, $gene, $transcript, $species, $source, $version, $strand, $status, $trv, $c, $aa, $ucsc, $domain, $all_domains, $deletion, $cosmic, $OMIN)= split /\t/, $line;
    my $key="$chr:$start:$stop";
    $cosmic{$key}=$line;
    if (exists $MR{$key}){
	my $tmp = $MR{$key};
	print O "$tmp$line";
    }

}
close I;
close O;

