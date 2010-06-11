#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# Useage: perl Germline_PubMedlist.pl <Germline> <PUBMED> <Germline_PUBMED>

# perl Germline_MMRlist.pl 
 
use strict;
use warnings;

my (%PUB, %tumor, %tumor_only, %normal_only)= ({},{},{},{});

open(I, "<$ARGV[1]") or die "cannot open $ARGV[1]";
while(<I>){
    my $line = $_;
    my @each = split /\t/, $line;
    my $EGE_symbol = $each[25];
    $PUB{$EGE_symbol}=$line;
}
close I;


open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
open (O, ">$ARGV[2]") or die "cannot open $ARGV[2]";
while (<I>){
    my $line = $_;
    my ($chr, $start, $stop, $ref, $var, $type, $gene, $transcript, $S1, $s2)= split/\t/, $line;
    if (exists $PUB{$gene}){
	print O $line;
    }
}
close O;
close I;
