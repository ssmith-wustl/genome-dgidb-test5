#!/usr/bin/env perl
#*****************************************************************************/
# This software is part of a beta-test version of the TIGRA package,
# a local de novo assembler that constructs all the alleles in the input reads
# Copyright (C) 2010 Washington University in St. Louis

# Input:  a set of reads (fasta) mapped to a ROI, included one end unmapped pair end reads
# Output: a set of haplotype contigs (fasta)

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 
# as published by the Free Software Foundation;
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#*****************************************************************************/

use strict;
use warnings;

package addbridgekmer;

my %HH;
my $Rdnum=0;
my @Contigs;
my $Contignum=0;
my %Contigtips;
my @newKmers;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	    Bridgeanchor=>$arg{Bridgeanchor} || 1,
	    DefaultTip=>$arg{Tip} || 1000
	   };
  %HH=%{$arg{graph}} if($arg{graph});
  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %HH;
  undef @Contigs;
  undef %Contigtips;
  undef @newKmers;
}

sub doit{
  my ($self,$rHH,$rContigs,$rContigtips,$rPR,$rReads)=@_;
  %HH=%{$rHH};
  @Contigs=@{$rContigs};
  %Contigtips=%{$rContigtips};
  my @PR=@{$rPR};
  foreach(@{$rReads}){
    my $nums=shift @PR;
    $self->addbridge($_,$nums);
  }
  return (\%HH, \@newKmers);
}

sub addbridge{
  my ($self,$rd, $nums)=@_;

  my @aqual=split / /, $nums;
  my $lefts=-1;
  my $lefte=0;
  my $leftsum=0;
  my $leftbig=0;
  my $leftbigpos=0;
  for (0..$#aqual) {
    if  ($aqual[$_]>1){
      $lefts=$_ if ($lefts==-1);
      $leftsum+=$aqual[$_];
      if ($leftbig<$aqual[$_]) {
	$leftbig=$aqual[$_];
	$leftbigpos=$_;
      }
    }
    elsif($lefts>-1) {
      if ($leftsum>$self->{Bridgeanchor}){
	$lefte=$_;
	last;
      }
      else {
	$lefts=-1;
	$lefte=0;
	$leftsum=0;
	$leftbig=0;
	$leftbigpos=0;
      }
    }
  }
  if ($lefte==0){
    #    	print NREAD "$rd\n";
    return;
  }

  my $rights=-1;
  my $righte=0;
  my $rightsum=0;
  my $rightbig=0;
  my $rightbigpos=0;
  for (reverse ($lefte..$#aqual)) {
    if  ($aqual[$_]>1){
      $rights=$_ if ($rights==-1);
      $rightsum+=$aqual[$_];
      if ($rightbig<$aqual[$_]) {
	$rightbig=$aqual[$_];
	$rightbigpos=$_;
      }
    }
    elsif($rights>-1) {
      if ($rightsum>$self->{Bridgeanchor}){
	$righte=$_;
	last;
      }
      else{
	$rights=-1;
	$righte=0;
	$rightsum=0;
	$rightbig=0;
	$rightbigpos=0;
      }
    }
  }
  if ($righte==0){
    #	print NREAD "$rd\n";
    return;
  }

  return if ($righte-$lefte>$self->{k}-2);   # do not allow real single cov bridge
  my $node=substr $rd, $leftbigpos,$self->{k};
  my ($truenode,$dir)=&true($node);
  my $contigl=$dir*$HH{$truenode}{tag};
  $node=substr $rd, $rightbigpos,$self->{k};
  $node=&revcom($node);
  ($truenode,$dir)=&true($node);
  my $contigr=$dir*$HH{$truenode}{tag};
  $Contigtips{$contigl}=$self->{DefaultTip} if(!defined $Contigtips{$contigl});
  $Contigtips{$contigr}=$self->{DefaultTip} if(!defined $Contigtips{$contigr});
  if ($Contigtips{$contigl}-$Contigs[abs $contigl]->{lens}<100 || $Contigtips{$contigr}-$Contigs[abs $contigr]->{lens}<100) {
    $self->addback($rd,$lefte,$righte);
    #	print NREAD "$rd\n";
  }
  else {
    #	print NREAD "$rd\n";
  }
}

sub addback {
  my ($self,$rd, $le, $re)=@_;
  my $u=substr $rd, $le-1,$self->{k};
  my $w;
  for ($le..($re+1)){
    $w=$u;
    $u=substr $rd, $_,$self->{k};
    next if ($u=~m/N/||$w=~m/N/);
    unless ($HH{$u} ||$HH{&revcom($u)}){
      $HH{$u}={n=>1,AI=>0,CI=>0,GI=>0,TI=>0,AO=>0,CO=>0,GO=>0,TO=>0,tag=>0,tag2=>0};
      push @newKmers,$u;
    }

    $self->addedge($w,$u);
  }
}

sub addedge {       # a always exist
  my ($self,$a,$b)=@_;
  my ($truea,$dira)=&true($a);
  my ($trueb,$dirb)=&true($b);
  
  if ($dira==1){
    if ($dirb==1){
      my $next=substr $b, $self->{k}-1,1;
      $HH{$a}{$next."O"}+=1;
      $next=substr $a,0,1;
      $HH{$b}{$next."I"}+=1;
    }
    else {
      my $next=substr $b, $self->{k}-1,1;
      $HH{$a}{$next."O"}+=1;
      $next=substr &revcom($a),$self->{k}-1,1;
      $HH{$trueb}{$next."O"}+=1;
    }
  }
  else {
    if ($dirb==1){
      my $next=substr &revcom($b),0,1;
      $HH{$truea}{$next."I"}+=1;
      $next=substr $a,0,1;
      $HH{$b}{$next."I"}+=1;
    }
    else {
      my $next=substr &revcom($b),0,1;
      $HH{$truea}{$next."I"}+=1;
      $next=substr &revcom($a),$self->{k}-1,1;
      $HH{$trueb}{$next."O"}+=1;
    }
  }
}

sub revcom {
  my ($seq)=@_;
  $seq=reverse $seq;
  $seq=~tr/ATGC/TACG/;
  return($seq);
}

sub true {
  my ($node)=@_;
  if ($HH{$node}) {return ($node, 1);}
  else {
    my $rnode=&revcom($node); 
    return ($rnode, -1) if ($HH{$rnode});
    return (0,0);
  }
}


sub nextbase{
  my ($node)=@_;
  my ($truenode,$dir)=&true($node);
  if ($dir==1){
    return("A",$HH{$truenode}{AO},"T",$HH{$truenode}{TO},"G",$HH{$truenode}{GO},"C",$HH{$truenode}{CO});
  }
  else {return("A",$HH{$truenode}{TI},"T",$HH{$truenode}{AI},"G",$HH{$truenode}{CI},"C",$HH{$truenode}{GI});}
}

sub min {
  my @list=@_;
  my $min= pop @list;
  foreach my $i (@list){
    $min = $i if ($i < $min);
  }
  return $min;
}

1;
