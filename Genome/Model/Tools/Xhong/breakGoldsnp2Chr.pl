#!/usr/local/bin/perl

use strict;
use warnings;

# Goal to intersect wu and SJ snps calls
# perl intersect_wu_sj_snp.pl SJ WU SJonly WUonly both
if ($#ARGV<1){
    print "perl brealGoldsnp2Chr.pl Goldsnp chr\n";
    exit;
}


open (O, ">$ARGV[0].$ARGV[1]");
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my($chr, $start,$stop,$allel1,$allel2,$s1,$s2, $s3, $s4)=split/\t/, $line;
    print O $line if $chr eq $ARGV[1];
}
close I;
close O;




