#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# Useage: perl intersect-normal-tumor.pl <normal-assembly> <tumor-assembly> <tumor-only> <both> <normal-only>
 
use strict;
use warnings;

my (%normal, %tumor, %tumor_only, %normal_only)= ({},{},{},{});

open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my ($chr1, $start, $stop)=split/\,/, $line;
# $strand, $match, $length, $mismatch, $insdel, $contig, $unknown1, $unknown2) = split /\t/, $line;
    my $key="$chr1:$start";
    $normal{$key}=$line;

}
close I;


open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(O, ">$ARGV[2]") or die "cannot open $ARGV[2]";
open(B, ">$ARGV[3]") or die "cannot open $ARGV[3]";
while(<I>){
    my $line=$_;
    my ($chr1, $start, $stop, $ref, $var, $type, $s1, $s2, $s3,$s4, $s5, $s6, $s7)= split/\,/, $line;
    my $key="$chr1:$start";
    $tumor{$key}=$line;
    if (!exists $normal{$key}){
	print O $line;
	delete $normal{$key};
	delete $tumor{$key};
    }else{
	print B $line;
#	print B $normal{$key};
    }

}
close I;
close O;
close B; 

open(N,">$ARGV[4]") or die "cannot open $ARGV[4]";
while( my ($key, $value) =each %normal){
    print N $value;

}
close N;
