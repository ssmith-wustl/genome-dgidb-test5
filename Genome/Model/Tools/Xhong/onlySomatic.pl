#!/gsc/bin/perl

# Goal: intersect the assembly result of tumor and normal files and find the tumor only insertion/deletion and so on

# USEAGE: perl onlySomatic.pl <input> <output>
# Eg:  perl /gscuser/xhong/svn/perl_modules/Genome/Model/Tools/Xhong/onlySomatic.pl 

use strict;
use warnings;


my (%MR, %cosmic)= ({},{});
my $newline="";
open(O, ">$ARGV[1]") or die "cannot creat $ARGV[1]";
open(I, "<$ARGV[0]") or die "cannot open $ARGV[0]";
my ($n, $a) =(0,0);
while(<I>){
    my $line = $_;
    $line=~ s/\n$//;
    my @each = split/\t/, $line;
    print "$each[1]";
    $each[1] =~ s/\s+//;
    if ($each[1] eq "S"){
	print O "$line\n";
	print ".";
    }
}
close I;
close O;


