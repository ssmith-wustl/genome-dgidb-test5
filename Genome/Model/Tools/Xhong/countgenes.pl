#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# USEAGE: perl countgenes.pl <combine> <freq>
# Eg:  perl /gscuser/xhong/svn/perl_modules/Genome/Model/Tools/Xhong/countgenes.pl ~xhong/SJC/SJMB-lc-annotate-cosmic-somatic.txt SJMB-lc-snps-gene-freq.txt

use strict;
use warnings;


my (%freq, %cosmic, %OMIM)= ({},{},{});
my $n="Novel:";
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
while(<I>){
    my $line = $_;
    $line=~ s/\n$//;
    my ($sample, $newname, $chr, $start, $stop, $ref, $var, $type,$MR, $comments, $gene, $transcript, $species, $source, $version, $strand, $trv_type, $c, $aa, $ucsc, $domain, $all_domain, $deletion, $cosmic, $OMIM) = split/\t/, $line;
    print "$gene\t";

   
    if (exists $freq{$gene}){
	$freq{$gene}=$freq{$gene}+1;
    }else{
	$freq{$gene}=1;
    }

    if ($cosmic =~ m/$n/){
	print ".";
	if (exists $cosmic{$gene}){
	    $cosmic{$gene}=$cosmic{$gene}+1;
	}else{
	    $cosmic{$gene}=1;
	}
    }
    if ($OMIM =~ m/$n/){
	print ",";
	if (exists $OMIM{$gene}){
	    $OMIM{$gene}=$OMIM{$gene}+1;
	}else{
	    $OMIM{$gene}=1;
	}
    }

}
close I;

my($n1, $n2, $n3)= (0,0,0);

open(I, ">$ARGV[1]") or die "cannot open $ARGV[1]";
open(O, ">test") or die "cannot open test";
foreach my $key (keys %freq){
    my ($v1, $v2, $v3)=(0,0,0);
    $v1= $freq{$key} if exists $freq{$key} ;
    $v2=$cosmic{$key} if exists $cosmic{$key};
    $v3=$OMIM{$key}if exists $OMIM{$key};
    print I "$key\t$v1\t$v2\t$v3\n";
    if ($v1 > 0 ){
	$n1++;
	if( $v2>0 && $v3 > 0){
	    $n2++ if ($v2 > 0);
	    $n3++ if ($v3 > 0);
	    print O "$key\t$freq{$key}\t$cosmic{$key}\t$OMIM{$key}\n";
	}
    }
}
close I;
close O;

print "$n1, $n2, $n3\n";

