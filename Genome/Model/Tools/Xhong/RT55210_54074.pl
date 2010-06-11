#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# Useage: perl intersect-assembly.pl <normal-assembly> <tumor-assembly> <tumor-only> <both> <normal-only>

# perl intersect-assembly.pl /gscmnt/sata843/info/medseq/xhong/LUC-assembly/LUC2/LUC2_assembly_tier1_indel_normal_list /gscmnt/sata843/info/medseq/xhong/LUC-assembly/LUC2/LUC2_assembly_tier1_indel_tumor_list  /gscmnt/sata843/info/medseq/xhong/LUC-assembly/LUC2/tumor_only  /gscmnt/sata843/info/medseq/xhong/LUC-assembly/LUC2/both /gscmnt/sata843/info/medseq/xhong/LUC-assembly/LUC2/normal_only
 
use strict;
use warnings;


my (%normal, %tumor, %tumor_only, %normal_only)= ({},{},{},{});

open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    my ($chr1, $start, $chr2, $stop, $strand, $match, $length, $mismatch, $insdel, $contig, $unknown1, $unknown2) = split /\t/, $line;
    my $key="$chr1:$start";
    $normal{$key}=$line;

}
close I;


open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
open(O, ">$ARGV[2]") or die "cannot open $ARGV[2]";
open(B, ">$ARGV[3]") or die "cannot open $ARGV[3]";
while(<I>){
    my $line=$_;
    my ($chr1, $start, $chr2, $stop, $strand, $match, $length, $mismatch, $insdel, $contig, $unknown1, $unknown2) = split /\t/, $line;
    my $key="$chr1:$start";
    $tumor{$key}=$line;
    if (!exists $normal{$key}){
	print O $line;
	delete $normal{$key};
	delete $tumor{$key};
    }else{
	print B $line;
	print B $normal{$key};
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
