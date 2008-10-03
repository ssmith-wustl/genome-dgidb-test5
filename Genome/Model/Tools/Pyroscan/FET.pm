#!/gsc/bin/perl

########################################################################################
# Author: Ken Chen (kchen@genome.wustl.edu)
# Date: July, 2008
# This module conduct Fisher Exact Test on 2x2 table
# Right and two-tailed test are implemented
# http://mathworld.wolfram.com/FishersExactTest.html
########################################################################################

package FET;

use Inline C => <<'END';

double LogFact(int x){
  //compute log of factorial
  int i;
  double sum=0;
  if(x>0){
    for(i=2;i<=x;i++){
      sum+=log(i);
    }
  }
  return sum;
}

double LAdd(double x, double y){

  double temp, diff, z;
  if (x<y) {
    temp = x; x = y; y = temp;
  }
  diff = y-x;
  if (diff<-23.02585){
    return  (x<-5000000000.0)?-10000000000.0:x;
  }
  else {
    z = exp(diff);
    return x+log(1.0+z);
  }
  return z;
}
END

use strict;
use warnings;

my $LZERO=-10000000000;
my $LSMALL=$LZERO/2;
my $minLogExp = -log(-$LZERO);

sub new{
  my ($class, %arg) = @_;
  my $self={
	   };
  bless($self, $class || ref($class));
  return $self;
}

sub Right_Test{

#  a   b   R0
#  c   d   R1

#  C0  C1  N

  my ($self,$a,$b,$c,$d,$cutoff)=@_;
  my @R=($a+$b, $c+$d);
  my @C=($a+$c, $b+$d);
  my $LPvalue=$LZERO;
  my $Lcutoff=log($cutoff) if(defined $cutoff && $cutoff>0);
  for(my $i=$a;$i<=$R[0];$i++){
    my $j=$R[0]-$i;
    my $k=$C[0]-$i;
    my $l=$R[1]-$k;
    my $LP=&LogHyge($i,$j,$k,$l);
    $LPvalue=&LAdd($LPvalue,$LP);
    last if(defined $Lcutoff && $LPvalue>$Lcutoff);  #no need to continue if exceeds Pcutoff
  }
  return exp($LPvalue);
}

sub Test{

#  a   b   R0
#  c   d   R1

#  C0  C1  N

  my ($self,$a,$b,$c,$d,$cutoff)=@_;
  my $Lcutoff=log($cutoff) if(defined $cutoff && $cutoff>0);
  my @R=($a+$b, $c+$d);
  my @C=($a+$c, $b+$d);

  my $LPcut=&LogHyge($a,$b,$c,$d);
  my @LProbs;
  for(my $i=0;$i<=$R[0];$i++){
    my $j=$R[0]-$i;
    my $k=$C[0]-$i;
    my $l=$R[1]-$k;
    my $LP=&LogHyge($i,$j,$k,$l);
    push @LProbs,$LP if($LP<=$LPcut);
  }
  my $LPvalue=$LZERO;
  foreach my $LP(@LProbs){
    $LPvalue=LAdd($LPvalue,$LP);
    last if(defined $Lcutoff && $LPvalue>$Lcutoff);  #no need to continue if exceeds Pcutoff
  }
  return exp($LPvalue);
}


sub LogHyge{
  my ($a,$b,$c,$d)=@_;
  my $N=$a+$b+$c+$d;
  my @R=($a+$b, $c+$d);
  my @C=($a+$c, $b+$d);
  my $LHyge=&LogFact($R[0])+&LogFact($R[1])+&LogFact($C[0])+&LogFact($C[1])
    -&LogFact($N)-&LogFact($a)-&LogFact($b)-&LogFact($c)-&LogFact($d);
  return $LHyge;
}

1;
