#!/gsc/bin/perl

use strict;
use warnings;

my ($dir,$lst)=@ARGV;
my @stats;
if(defined $lst){
  open(LST,"<$lst") || die "unable to open $lst\n";
  while(<LST>){
    chomp;
    $_=~s/\s+$//ig;
    my ($gene,@extra)=split /\s+/;
    push @stats,$gene . '.stat';
  }
  close(LST);
}
else{
  opendir(DIR,$dir);
  @stats=grep {/\.stat/} readdir(DIR);
}

my $ngene=0;
my ($nhit_total,$nmut_total,$npre_total)=(0,0,0);
my ($nhit_total_indel,$nmut_total_indel,$npre_total_indel)=(0,0,0);

foreach my $stat(@stats){
  my ($nhit,$nmut,$npre)=(0,0,0);
  open(STAT,"<$dir/$stat") || die "unable to open $dir/$stat\n";;
  while(<STAT>){
    chomp;
    next unless (/\bsomatic\b/i);
    my ($pos,$mut_type,$var_type,@extra)=split /\s+/;
    if($mut_type=~/somatic/i){
      #if($_=~/Somatic$/i || $_=~/dbsnp/i){
      if($_=~/Somatic$/i){
	$nhit++;
	$nmut++;
	$npre++;
	#print "HIT: $_\n";
      }
      #elsif($_=~/dbsnp/i){
      #}
      else{
	$npre++;
	#print "FP: $_\n";
      }
    }
    else{
      $nmut++ if(/Somatic$/i);
      #print "MISS: $_\n";
    }
  }
  close(STAT);

  my $sen=($nmut>0)?$nhit*100/$nmut:100;
  my $spe=($npre>0)?$nhit*100/$npre:100;
  $stat=~s/\.stat//;
  #printf "%s\t%d\/%d\t%.2f\t%d\/%d\t%.2f\n", $stat,$nhit,$nmut,$sen,$nhit,$npre,$spe;

  $nhit_total+=$nhit;
  $nmut_total+=$nmut;
  $npre_total+=$npre;

  $ngene++;
}

$dir=~s/.*\///;
#printf "%s, %d genes, sen: %d\/%d (%.2f%%), spe: %d\/%d (%.2f%%)\n", $dir,$ngene,$nhit_total,$nmut_total,$nhit_total*100/$nmut_total,$nhit_total,$npre_total,$nhit_total*100/$npre_total;

printf "%d\/%d\t%.2f\t%d\/%d\t%.2f\n", $nhit_total,$nmut_total,$nhit_total*100/$nmut_total,$nhit_total,$npre_total,$nhit_total*100/$npre_total;

#printf "%d\t%.2f\t%.2f\n", $ngene,$nhit_total*100/$nmut_total, $nhit_total*100/$npr_total;
#printf "%.2f\t%.2f\n", $nhit*100/$nmut, $nhit*100/$npre;
