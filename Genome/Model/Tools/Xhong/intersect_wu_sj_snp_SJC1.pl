#!/usr/local/bin/perl

use strict;
use warnings;

# Goal to intersect wu and SJ snps calls
# perl intersect_wu_sj_snp_SJC1.pl SJ WU SJonly WUonly both
if ($#ARGV<4){
    print "perl intersect_wu_sj_snp.pl SJ WU SJonly WUonly both\n";
    exit;
}

my (%sj,%wu)=({},{});
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my($gene, $Quality, $sample, $chr, $pos,$region,$AAchange, $nTumor,$tTormal, $nNormal, $nTotal, $var, $ref, $flanks) = split/\t/, $line;
    $chr=~s/chr//;
    my $key = "$chr.$pos";
    $sj{$key}=$line;
}
close I;

open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(SJ, ">$ARGV[2]") or die "cannot creat $ARGV[2]";
open(WU, ">$ARGV[3]") or die "cannot creat $ARGV[3]";
open(BOTH, ">$ARGV[4]") or die  "cannot creat $ARGV[4]";
while(<I>){
    my $line = $_;
    my($name, $class, $chr, $start, $stop, $ref, $var, $s5,$s6, $s7, $s8, $s9, $s10) = split/\t/, $line;
    my $key = "$chr.$start";
    if (! exists  $sj{$key}){
	print WU $line;
	delete $sj{$key};
    }else{
	print BOTH $sj{$key};
	print BOTH $line;
	delete $sj{$key};
    }
}
while (my ($k, $v) = each %sj){
    print SJ $sj{$k};
}
close I;
close SJ;
close WU;
close BOTH;



