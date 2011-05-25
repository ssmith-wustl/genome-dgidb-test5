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
no warnings 'recursion';

package walkcontig;

my %HH;
my %Contigtips;
my @Contigs;
my @Contiglens;
my @Contigcovs;
my @Contigtypes;
my $Contignum;
my @Contigtags;

my @Contigs2;
my @Contiglens2;
my @Contigcovs2;
my @Contigtypes2;
my $Contignum2;
my $Ratiocutoff=0.3;
my $Convergestepwall=12;
my $Convergelengthwall=150;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	    Thin=>$arg{Thin} || 2,
	    Smalltip=>$arg{Smalltip} || 100,
	    Walkcutoff=>$arg{Walkcutoff} || 3,
	    Tipcount=>0,
	    DefaultTip=>$arg{Tip} || 1000
	   };
  $Ratiocutoff=0.3;
  $Convergestepwall=12;
  $Convergelengthwall=150;
  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %HH;
  undef %Contigtips;
  undef @Contigs;
  undef @Contiglens;
  undef @Contigcovs;
  undef @Contigtypes;
  undef @Contigtags;
  undef @Contigs2;
  undef @Contiglens2;
  undef @Contigcovs2;
  undef @Contigtypes2;
  undef $Contignum;
  undef $Contignum2;
  undef $Ratiocutoff;
  undef $Convergestepwall;
  undef $Convergelengthwall;
}


sub walkcontigwrap {
  my ($self,%arg)=@_;
  my ($cutoff, $ratiocutoff)=($arg{cutoff}||$self->{Walkcutoff},$arg{ratiocutoff}||$Ratiocutoff);
  #print STDERR "Walking contigs with cutoff $cutoff, ratio_cutoff $ratiocutoff ..\n";
  %HH=%{$arg{HH}};
  %Contigtips=%{$arg{tips}};
  my @in_contigs=@{$arg{contig}};
  for my $i(1..$#in_contigs){
    $Contiglens[$i]=$in_contigs[$i]->{lens};
    $Contigcovs[$i]=$in_contigs[$i]->{covs};
    $Contigtypes[$i]=$in_contigs[$i]->{types};
    $Contigtags[$i]=$in_contigs[$i]->{tags};
    $Contigs[$i]=$in_contigs[$i]->{seq};
  }

  $Contignum2=0;
  for my $i (sort {$Contigcovs[$b]<=>$Contigcovs[$a]} (1..($#Contigs))) {
    next if ($Contigtags[$i]!=0);
    $Contignum2+=1;
if($Contignum2 == 37){
my $j = 0;
}
    $Contigtags[$i]=$Contignum2;
    my ($right, $rightsum, $righttype)=$self->walkcontig($i,$Contignum2, $cutoff, $ratiocutoff);
    my ($left, $leftsum, $lefttype)=$self->walkcontig(-$i,-$Contignum2, $cutoff, $ratiocutoff);
    $left=&revcom($left);
    $Contigs2[$Contignum2]=$left.$Contigs[$i].$right;
    $Contiglens2[$Contignum2]=(length $Contigs2[$Contignum2]);
    $Contigcovs2[$Contignum2]=(int 100*($rightsum+$leftsum+($Contiglens[$i]-$self->{k}+1)*$Contigcovs[$i])/($Contiglens2[$Contignum2]-$self->{k}+1))/100;
    $Contigtypes2[$Contignum2]=$lefttype.$righttype;
    for my $i ($self->{k}..$Contiglens2[$Contignum2]){
      my $node=substr $Contigs2[$Contignum2],$i-$self->{k},$self->{k};
      my ($truenode, $dir)=&true($node);
      $HH{$truenode}{tag2}=$dir*$Contignum2;
    }
  }

  for my $i(1..$#Contigs){
    $in_contigs[$i]->{tags}=$Contigtags[$i];
  }
  #print STDERR "Done walking contigs, number of contigs2: $Contignum2\n";
  return \@in_contigs;
}

sub walkcontig {
  my ($self,$contig,$contiglab,$cutoff,$ratiocutoff)=@_;
  my @ncontigs=$self->step($contig,$cutoff,$ratiocutoff);
  my $nx=pop @ncontigs;
  return ("",0,$nx) if ($nx==0 || $Contigtags[abs $ncontigs[0]]!=0);
  my $ncontig=0;
  if (@ncontigs>1){
    for $ncontig (@ncontigs) {
      my @vcontigs=$self->step(-$ncontig,$cutoff,$ratiocutoff);
      pop @vcontigs;
      if (@vcontigs!=1 || $vcontigs[0]!=-$contig){
	return ("",0,$nx);
      }
    }
    ($ncontig,)=$self->converge(@ncontigs);
  }
  else {
    my ($pseudo, $convergeon)=$self->pseudowalkcontig(-$ncontigs[0],$cutoff,$ratiocutoff);
    $ncontig=$ncontigs[0] if ($pseudo==-$contig ||($convergeon!=0 && (abs $convergeon)/$convergeon*$Contigtags[abs $convergeon]==-$contiglab));
  }
  return("",0,$nx)  if ($ncontig==0);
  my $seq;
  if ($ncontig>0) {
    $Contigtags[$ncontig]=$contiglab;
    $seq=substr $Contigs[$ncontig], $self->{k}-1, $Contiglens[$ncontig]-$self->{k}+1;
  }
  else {
    $Contigtags[-$ncontig]=-$contiglab;
    $seq=substr $Contigs[-$ncontig], 0, $Contiglens[-$ncontig]-$self->{k}+1;
    $seq=&revcom($seq);
  }
  my ($rnext, $sumnext, $endtype)=$self->walkcontig($ncontig, $contiglab, $cutoff, $ratiocutoff);
  return ($seq.$rnext, ($Contiglens[abs $ncontig]-$self->{k}+1)*$Contigcovs[abs $ncontig]+$sumnext, $endtype);
}

sub pseudowalkcontig {
    my ($self,$contig,$cutoff,$ratiocutoff)=@_;
    my @ncontigs=$self->step($contig,$cutoff,$ratiocutoff);
    my $nx=pop @ncontigs;
    return (0,0) if ($nx==0);
    my $ncontig;
    for $ncontig (@ncontigs) {
	my @vcontigs=$self->step(-$ncontig,$cutoff,$ratiocutoff);
	pop @vcontigs;
	if (@vcontigs!=1 || $vcontigs[0]!=-$contig){
	    return (0,0);
	}
    }
    my $convergeon;
    ($ncontig,$convergeon)=$self->converge(@ncontigs);
    return($ncontig,$convergeon);
}

sub converge{
  my ($self,@contigs)=@_;
  my $stepcutoff=$self->{Walkcutoff};
  my $stepratiocutoff=$Ratiocutoff;
  return(0,0) if (@contigs==0 || $contigs[0]==0);
  return($contigs[0],$contigs[0]) if (@contigs==1);
  if (@contigs>2){
    my $a=shift @contigs;
    my $b=shift @contigs;
    my ($x,)=$self->converge($a,$b);
    unshift @contigs, $x;
    return($self->converge(@contigs));
  }
  else {
    my @a=($contigs[0]);
    my @b=($contigs[1]);
    my $lengtha=$Contiglens[abs $a[0]]-$self->{k}+1;
    my $lengthb=$Contiglens[abs $b[0]]-$self->{k}+1;
    my $length=($lengtha<$lengthb)?$lengtha:$lengthb;
    my $step=0;

    while($length<=$Convergelengthwall && $step<=$Convergestepwall){
      $step+=1;
      if ($a[-1]!=0){
	my @temp=$self->step($a[-1],$stepcutoff,$stepratiocutoff);
	my $x=$temp[0];
	if ($x!=0){
	  @temp=$self->step(-$x,$stepcutoff,$stepratiocutoff);
	  if ($temp[0]!=-$a[-1]) {
	    $x=0;
	  }
	  else {
	    if ((grep /^$x$/, @b)>0){
	      $lengthb=0;
	      for(@b) {last if ($_==$x);$lengthb+=$Contiglens[abs $_]-$self->{k}+1;}
	      my $xx=abs ($lengtha-$lengthb);
	      return(0,0) if ($xx>3 || $lengthb==0); #make sure the other branch not 0
	      return($a[0],$x);
	    }
	    $lengtha+=$Contiglens[abs $x]-$self->{k}+1;
	    push @a, $x;
	  }
	}
      }
      if ($b[-1]!=0){
	my @temp=$self->step($b[-1],$stepcutoff,$stepratiocutoff);
	my $x=$temp[0];
	if ($x!=0){
	  if ((grep /^$x$/, @a)>0) {
	    $lengtha=0;
	    for(@a) {
	      last if ($_==$x);
	      $lengtha+=$Contiglens[abs $_]-$self->{k}+1;
	    }
	    my $xx=abs ($lengtha-$lengthb);
	    return(0,0) if ($xx>3 || $lengtha==0);
	    return($a[0],$x);
	  }
	  $lengthb+=$Contiglens[abs $x]-$self->{k}+1;
	}
	push @b, $x;
      }
      $length=($lengtha<$lengthb)?$lengtha:$lengthb;
    }
    return(0,0);
  }
}

sub step {
  my ($self,$contig,$cutoff,$ratiocutoff)=@_;
  my %n=$self->nextcontigs_warc($contig);
  my $nx=keys %n;
  return ($nx) if ($nx==0);
  my %long;
  my $bigpro=0;
  my $bigprocontig=0;
  my $biglong=0;
  my $biglongcontig=0;
  my %ncontigh;
  for (sort {$a <=> $b} keys %n) {
    $Contigtips{$_}=$self->{DefaultTip} if(!defined $Contigtips{$_});
    if ($n{$_}*$Contigtips{$_}>$bigpro) {
      $bigpro=$n{$_}*$Contigtips{$_};
      $bigprocontig=$_;
    }
    if ($Contigtips{$_}>$self->{Smalltip} && $n{$_}>$self->{Thin}) {     # long path must also be thick
      $long{$_}=$n{$_};
      if ($long{$_ }>$biglong) {
	$biglong=$long{$_};
	$biglongcontig=$_;
      }
    }
  }
  if ((keys %long)==0) {
    $ncontigh{$bigprocontig}=$n{$bigprocontig};
  }
  else {
    for my $i (sort keys %long) {
      if ($long{$i}>$ratiocutoff*$biglong || $long{$i}>$cutoff) {$ncontigh{$i}=$long{$i};}
    }
  }
  my @aa=sort {$ncontigh{$b}<=>$ncontigh{$a}} (sort keys %ncontigh);
  push @aa, $nx;
  return(@aa);
}

sub dump_contigs2 {
  my ($self)=@_;
  #  print STDERR "Printing contigs2 to $filename.. \n";
  #  open(MYFILE,">$filename");
  my @dContigs2;
  for (1..$#Contigs2) {
    my $node=substr $Contigs2[$_], 0, $self->{k};
    my ($truenode,$dir)=&true($node);
    my $contig=$HH{$truenode}{tag}*$dir*(-1);
    my %a=$self->nextcontigs_warc($contig);
    my $i="";
    my $o="";
    foreach my $con (sort keys %a) {
      $i.=$Contigtags[abs $con]*$con/(abs $con);
      $i.=":".$a{$con}.",";
    }
    $node=substr $Contigs2[$_], $Contiglens2[$_]-$self->{k}, $self->{k};
    ($truenode,$dir)=&true($node);
    $contig=$HH{$truenode}{tag}*$dir;
    %a=$self->nextcontigs_warc($contig);
    foreach my $con (sort keys %a) {
      $o.=$Contigtags[abs $con]*$con/(abs $con);
      $o.=":".$a{$con}.",";
    }
    #    print MYFILE ">Contig$_ $Contiglens2[$_] $Contigcovs2[$_] $Contigtypes2[$_] I$i O$o\n";
    #    print MYFILE $Contigs2[$_]."\n";

    my $contig2;
    ($contig2->{id},$contig2->{lens},$contig2->{covs},$contig2->{types},$contig2->{I},$contig2->{O})=($_,$Contiglens2[$_], $Contigcovs2[$_], $Contigtypes2[$_], "$i", "$o");
    $contig2->{seq}=$Contigs2[$_];
    $dContigs2[$_]=$contig2;
  }
  #  close(MYFILE);
  return \@dContigs2;
}

sub nextcontigs_warc {
  my ($self,$contignum)=@_;
  my $node;
  if ($contignum>0){
    $node=substr $Contigs[$contignum], $Contiglens[$contignum]-$self->{k}, $self->{k};
  }
  else {
    $node=substr $Contigs[-$contignum], 0, $self->{k};
    $node=&revcom($node);
  }
  my %a;
  if ($HH{$node}){
    for ("A", "C", "G", "T") {
      next if ($HH{$node}{$_."O"}==0);
      my $vnode=(substr $node, 1, $self->{k}-1).$_;
      my ($truenode, $dir)=&true($vnode);
      $a{$dir*$HH{$truenode}{tag}}=$HH{$node}{$_."O"};
    }
  }
  else {
    my $rnode=&revcom($node);
    for ("A", "C", "G", "T") {
      next if ($HH{$rnode}{$_."I"}==0);
      my $vnode=$_.(substr $rnode, 0, $self->{k}-1);
      my ($truenode, $dir)=&true($vnode);
      $a{-$dir*$HH{$truenode}{tag}}=$HH{$rnode}{$_."I"};
    }
  }
  return(%a);
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
    else {return (&revcom($node), -1);}
}
