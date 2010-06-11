#!/usr/local/bin/perl

use strict;
use warnings;

# Goal to separate high and low confidence snps
# perl low_confidence_tier1_snp.pl high all low

my (%hc,%lc)=({},{});
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my($chr, $start, $stop, $ref, $var, $s5,$s6, $s7, $s8, $s9, $s10) = split/\t/, $line;
    my $key = "$chr.$start.$stop";
    $hc{$key}=$line;
}
close I;

open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(O, ">$ARGV[2]") or die "cannot creat $ARGV[2]";
while(<I>){
    my $line = $_;
    my($chr, $start, $stop, $ref, $var, $s5,$s6, $s7, $s8, $s9, $s10) = split/\t/, $line;
    my $key = "$chr.$start.$stop";
    if (! exists  $hc{$key}){
	print O $line;
    }
}
close I;
close O;



