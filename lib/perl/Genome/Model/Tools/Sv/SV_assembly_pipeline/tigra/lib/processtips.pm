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

package processtips;

my $K;
my %HH;
my @Contigs;
my @Contiglens;
my @Contigcovs;
my @Contigtypes;
my $Contignum=0;
my %Contigtips;
my @Contigs2;
my $Tipcount;
my $Thin;
my $DefaultTip;

sub new{
  my ($class, %arg) = @_;
  my $self={
	   };
  $K=$arg{k} || 25;
  $Tipcount=0;
  $DefaultTip=$arg{Tip} || 1000;
  $Thin=$arg{Thin}||4;
  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %HH;
  undef %Contigtips;
  undef @Contigs;
  undef @Contigs2;
  undef $K;
  undef $Contignum;
  undef $Tipcount;
  undef $Thin;
}

sub tipwrap {
  my ($self,$cutoff,$rContigs,$HH)=@_;
  %HH=%{$HH} if(defined $HH);
  @Contigs=@{$rContigs};

  #print STDERR "Labeling tips upto $cutoff ..\n";
  for my $i (1..$#Contigs) {
    my $contig=$Contigs[$i];
    my ($left, $right)=split //, $contig->{types};
    if ($left==0) {
      &labeltip(-$i, $K-1, $cutoff);
    }
    if ($right==0) {
      &labeltip($i, $K-1, $cutoff);
    }
  }
  return \%Contigtips;
}

sub labeltip {
  my ($contignum, $dist, $tipcutoff)=@_;
  $dist+=$Contigs[abs($contignum)]->{lens}-$K+1;
  $Contigtips{$contignum}=$DefaultTip if(!defined $Contigtips{$contignum});
  return if ($dist >= $tipcutoff ||  $Contigtips{$contignum}<=$dist);

  $Contigtips{$contignum}=$dist;
  $Tipcount+=1;
  my @nextcontigs=&nextcontigs(-$contignum);
  for (@nextcontigs) {
    my @ncon=&nextcontigs(-$_);
    my $indist=$dist;
    for my $i (@ncon) {
      $Contigtips{$i}=$DefaultTip if(!defined $Contigtips{$i});
      $indist=$Contigtips{$i} if ($Contigtips{$i}> $indist);
    }
    &labeltip(-$_, $indist, $tipcutoff) if ($indist<$tipcutoff-1);
  }
}

sub breaktip {
  my ($self,$cutoff,$rHH,$rcontigtips,$rcontigs,$rcontigs2)=@_;
  %HH=%{$rHH};
  %Contigtips=%{$rcontigtips};
  @Contigs=@{$rcontigs};
  @Contigs2=@{$rcontigs2};

  #print STDERR "Breaking tips upto $cutoff ..\n";
  $Tipcount=0;
  for my $i (1..($#Contigs2)) {
    my $end=&contigend2($i);
    my ($trueend, $dir)=&true($end);
    my $si=$dir*$HH{$trueend}{tag};
    my @n=&nextcontigs($si);
    my $dist=$K-1;
    my $tag=0;
    if (@n>0){
      for my $j (@n){
	$Contigtips{$j}=$DefaultTip if(!defined $Contigtips{$j});
	if (&contigend(-$j) eq &contigend2(-($j/(abs $j))*$Contigs[abs $j]->{tags})) {
	  $dist=$Contigtips{$j} if ($dist<$Contigtips{$j});
	}
	else {$tag=1;}
      }
      next if ($tag==0);
      &labeltip($si, $dist, $cutoff) if ($dist<$cutoff-1);
    }

    $end=&contigend2(-$i);
    ($trueend, $dir)=&true($end);
    $si=$dir*$HH{$trueend}{tag};
    @n=&nextcontigs($si);
    $dist=$K-1;
    $tag=0;
    if (@n>0){
      for my $j (@n){
	$Contigtips{$j}=$DefaultTip if(!defined $Contigtips{$j});
	if (&contigend(-$j) eq &contigend2(-($j/(abs $j))*$Contigs[abs $j]->{tags})) {
	  $dist=$Contigtips{$j} if ($dist<$Contigtips{$j});
	}
	else {$tag=1;}
      }
      next if ($tag==0);
      &labeltip($si, $dist, $cutoff) if ($dist<$cutoff-1);
    }
  }
  #print STDERR "Tip count: $Tipcount\n";
  return \%Contigtips;
}


sub thicken {
  my ($self,$cutoff,$rHH,$rcontigtips,$rcontigs,$rcontigs2)=@_;
  %HH=%{$rHH};
  %Contigtips=%{$rcontigtips};
  @Contigs=@{$rcontigs};
  @Contigs2=@{$rcontigs2};
  #print STDERR "Thicken with cutoff $cutoff ..\n";
  my $Smalltip=100;

  for my $i ((-$#Contigs2)..(-1),1..($#Contigs2)) {
    next if ($Contigs2[abs $i]->{covs} <$cutoff ||$Contigs2[abs $i]->{types} ne "11");
    my $end=&contigend2($i);
    my ($trueend, $dir)=&true($end);
    my $si=$dir*$HH{$trueend}{tag};
    $Contigtips{-$si}=$DefaultTip if(!defined $Contigtips{-$si});
    next if ($Contigtips{-$si}<$Smalltip);
    if ($dir==1) {
      my $big=0;
      my $base="";
      for ("A", "C", "G", "T") {
	if ($HH{$trueend}{$_."O"}>$big) {
	  $big=$HH{$trueend}{$_."O"};
	  $base=$_;
	}
      }
      for ($big..$Thin){
	&addstring($trueend.$base);
      }
    }
    else {
      my $big=0;
      my $base="";
      for ("A", "C", "G", "T") {
	if ($HH{$trueend}{$_."I"}>$big) {
	  $big=$HH{$trueend}{$_."I"};
	  $base=$_;
	}
      }
      for ($big..$Thin){
	&addstring($base.$trueend);
      }
    }
  }
  return \%HH;
}

sub addstring {
  my ($rd)= @_;
  my $l=length $rd;
  for (my $i=$K; $i<=$l-1; $i++) {
    my $w=substr $rd, $i-$K, $K;
        my $rw=reverse $w;
    $rw=~tr/ATGC/TACG/;
    if($HH{$w}) {
      my $u=substr $rd, $i-$K+1,$K;
      my $ru=reverse $u;
      $ru=~tr/ATGC/TACG/;
      if($HH{$u}) {
	my $next=substr $u, $K-1,1;
	$HH{$w}{$next."O"}+=1;
	$next=substr $w,0,1;
	$HH{$u}{$next."I"}+=1;
      }
      elsif($HH{$ru}) {
	my $next=substr $u, $K-1,1;
	$HH{$w}{$next."O"}+=1;
	$next=substr $rw,$K-1,1;
	$HH{$ru}{$next."O"}+=1;
      }
      else {$i+=1;} 
    }
    elsif($HH{$rw}){
      my $u=substr $rd, $i-$K+1,$K;
      my $ru=reverse $u;
      $ru=~tr/ATGC/TACG/;
      if($HH{$u}) {
	my $next=substr $ru, 0,1;
	$HH{$rw}{$next."I"}+=1;
	$next=substr $w,0,1;
	$HH{$u}{$next."I"}+=1;
      }
      elsif($HH{$ru}) {
	my $next=substr $ru, 0,1;
	$HH{$rw}{$next."I"}+=1;
	$next=substr $rw, $K-1,1;
	$HH{$ru}{$next."O"}+=1;
	
      }
      else {$i+=1;}
    }
  }
}

sub nextcontigs {
  my ($contignum)=@_;
  my $node;
  if ($contignum>0){
    $node=substr $Contigs[$contignum]->{seq}, $Contigs[$contignum]->{lens}-$K, $K;
  }
  else {
    $node=substr $Contigs[-$contignum]->{seq}, 0, $K;
    $node=&revcom($node);
  }
  my @a;
  if ($HH{$node}){
    for ("A", "C", "G", "T") {
      next if ($HH{$node}{$_."O"}==0);
      my $vnode=(substr $node, 1, $K-1).$_;
      my ($truenode, $dir)=&true($vnode);
      push @a, $dir*$HH{$truenode}{tag};
    }
  }
  else {
    my $rnode=&revcom($node);
    for ("A", "C", "G", "T") {
      next if ($HH{$rnode}{$_."I"}==0);
      my $vnode=$_.(substr $rnode, 0, $K-1);
      my ($truenode, $dir)=&true($vnode);
      push @a, -$dir*$HH{$truenode}{tag};
    }
  }
  return(@a);
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
sub contigend {
    my ($contig)=@_;
    if ($contig>0) {
	return (substr $Contigs[$contig]->{seq}, $Contigs[$contig]->{lens}-$K,$K);
    }
    else {
	return (&revcom(substr $Contigs[-$contig]->{seq}, 0,$K));
    }
}
sub contigend2 {
    my ($contig)=@_;
    if ($contig>0) {
        return (substr $Contigs2[$contig]->{seq}, $Contigs2[$contig]->{lens}-$K,$K);
    }
    else {
        return (&revcom(substr $Contigs2[-$contig]->{seq}, 0,$K));
    }
}


1;
