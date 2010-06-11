#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# Useage: perl Make_MMRlist.pl <Originallist> <newlist>

# perl Make_MMRlist.pl 
 
use strict;
use warnings;

my (%normal, %tumor, %tumor_only, %normal_only)= ({},{},{},{});

open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
open (O, ">$ARGV[1]") or die "cannot open $ARGV[1]";
while(<I>){
    my $line = $_;
    my ($hugo, $EntrezGeneID, $list, $BER_W, $BER_TCGA, $DSB_TCGA, $HR_W, $MMR_W, $MMR_TCGA, $NER_W, $NER_TCGA, $NHEJ_W, $Other_W, $Other_DNA_rep_TCGA, $Other_GenStab_TCGA, $RAD6_dep_TCGA, $TLS_W, $Tel_Mnt_TCGA)= split /\t/, $line;
    if ($MMR_TCGA ne "" || $MMR_W ne "") {
	print O $line;

    }

}
close I;
close O;
