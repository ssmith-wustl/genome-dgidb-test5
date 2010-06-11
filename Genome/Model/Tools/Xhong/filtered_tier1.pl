#!/usr/local/bin/perl

use strict;
use warnings;

# Goal to intersect old and new wu snp calls
# perl intersect_old_new_snp.pl old new Oldonly NEWonly both
if ($#ARGV<4){
    print "perl intersect_wu_sj_snp.pl old WU SJonly WUonly both\n";
    exit;
}

my (%old,%new)=({},{});
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my($sample, $class, $chr, $start, $stop,$ref, $var) =split/\t/, $line;
    my $key = "$chr.$start";
    $old{$key}=$line;
}
close I;

open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(OLD, ">$ARGV[2]") or die "cannot creat $ARGV[2]";
open(NEW, ">$ARGV[3]") or die "cannot creat $ARGV[3]";
open(BOTH, ">$ARGV[4]") or die  "cannot creat $ARGV[4]";
while(<I>){
    my $line = $_;
    my($sample, $class, $chr, $start, $stop, $ref, $var, $s5,$s6, $s7, $s8, $s9, $s10) = split/\t/, $line;
    my $key = "$chr.$start";
    if (! exists  $old{$key}){
	print NEW $line;
	delete $old{$key};
    }else{
	print BOTH $old{$key};
	print BOTH $line;
	delete $old{$key};
    }
}
while (my ($k, $v) = each %old){
    print OLD $old{$k};
}
close I;
close OLD;
close NEW;
close BOTH;



