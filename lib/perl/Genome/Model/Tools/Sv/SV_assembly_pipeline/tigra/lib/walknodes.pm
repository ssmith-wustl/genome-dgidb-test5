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

package walknodes;

my %HH;
my @Contigs;
my @Contiglens;
my @Contigcovs;
my @Contigtypes;
my $Contignum;
my @Contigtags;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	    Thin=>$arg{Thin} || 2,
	    Walkcutoff=>$arg{Walkcutoff} || 4
	   };

  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %HH;
  undef @Contigs;
  undef @Contiglens;
  undef @Contigcovs;
  undef @Contigtypes;
  undef @Contigtags;
}


sub strictwalk{  #generate proto-contigs
  my ($self,$rHH)=@_;
  $Contignum=0;
  %HH=%{$rHH};
  for (keys %HH) {
    $HH{$_}{tag}=0;
  }
  #print STDERR "Strictwalk nodes ..   \n";
  foreach my $key (sort keys %HH){
    next if ($HH{$key}{tag}!=0);
    $Contignum+=1;
    $HH{$key}{tag}=$Contignum;
    my ($right, $rightsum, $righttype, $left, $leftsum, $lefttype);
    ($right, $rightsum, $righttype)=$self->walk($key,"O",$Contignum);  # sequence, sum of merged kmer frequency, out degree
    ($left, $leftsum, $lefttype)=$self->walk($key,"I",$Contignum);
    $left=reverse $left;
    $Contigs[$Contignum]=$left.$key.$right;
    $Contiglens[$Contignum]=(length $Contigs[$Contignum]);
    $Contigcovs[$Contignum]=(int 100*($rightsum+$leftsum+$HH{$key}{n})/($Contiglens[$Contignum]-$self->{k}+1))/100;
    $Contigtypes[$Contignum]=$lefttype.$righttype;
  }
  #print STDERR "  Num of Contigs: $Contignum\n";
}

sub walk {                 # do not check existance of nodes, always use solid nodes
  #break when out-degree != 1 or the in-degree of the next node > 1

  my ($self,$node, $dir,$contignum)=@_;
  my $antidir="I";
  $antidir="O" if ($dir eq "I");
  my $nbase="";
  my $count=0;
  for ("A","C","G","T") {
    if ($HH{$node}{$_.$dir}>0){
      $nbase=$_;
      $count+=1;
    }
  }
  return ("",0,$count) if ($count==0 || $count>1);
  my ($nnode,$vnnode);
  if ($dir eq "O"){
    $nnode=(substr $node, 1, $self->{k}-1).$nbase;
  }
  else {
    $nnode=$nbase.(substr $node, 0, $self->{k}-1);
  }
  $vnnode=reverse $nnode;
  $vnnode=~tr/ATGC/TACG/;
  if ($HH{$nnode}) {
    return ("",0,$count) if ($HH{$nnode}{tag}!=0);
    my $vcount=0;
    for ("A","C","G","T") {
      if ($HH{$nnode}{$_.$antidir}>0){
	$vcount+=1;
      }
    }
    return ("",0,$count) if ($vcount!=1); ## or >1 ??
    $HH{$nnode}{tag}=$contignum;
    my ($rnext, $sumnext, $endtype)=$self->walk($nnode, $dir,$contignum);
    return ($nbase.$rnext, $HH{$nnode}{n}+$sumnext,$endtype);
  }
  elsif ($HH{$vnnode}) {
    return ("",0,$count) if ($HH{$vnnode}{tag}!=0);
    my $vcount=0;
    for ("A","C","G","T") {
      if ($HH{$vnnode}{$_.$dir}>0){
	$vcount+=1;
      }
    }
    return ("",0,$count) if ($vcount!=1); ## or >1 ?? 
    $HH{$vnnode}{tag}=-$contignum;
    my ($rnext, $sumnext, $endtype)=$self->walk($vnnode, $antidir,-$contignum);
    $rnext=~tr/ATGC/TACG/;
    return ($nbase.$rnext, $HH{$vnnode}{n}+$sumnext,$endtype);
  }
}

sub dump_protocontigs {
  my ($self)=@_;
  my @protocontigs;
  #print STDERR "Printing contigs to $filename.. \n";

  for (1..$#Contigs) {
    my $node=substr $Contigs[$_], 0, $self->{k};
    my ($truenode,$dir)=&true($node);
    my $contig=$HH{$truenode}{tag}*$dir*(-1);
    my %a=$self->nextcontigs_warc($contig);
    my $i="";
    my $o="";
    foreach my $con (keys %a) {
      $i.=$con;
      $i.=":".$a{$con}.",";
    }
    $node=substr $Contigs[$_], $Contiglens[$_]-$self->{k}, $self->{k};
    ($truenode,$dir)=&true($node);
    $contig=$HH{$truenode}{tag}*$dir;
    %a=$self->nextcontigs_warc($contig);
    foreach my $con (keys %a) {
      $o.=$con;
      $o.=":".$a{$con}.",";
    }
    $Contigtags[$_]=0 if (! $Contigtags[$_]);
    my $protocontig;
    ($protocontig->{id},$protocontig->{lens},$protocontig->{covs},$protocontig->{types},$protocontig->{tags},$protocontig->{I},$protocontig->{O})=($_, $Contiglens[$_], $Contigcovs[$_], $Contigtypes[$_], $Contigtags[$_], "I$i", "O$o") ;
    $protocontig->{seq}=$Contigs[$_];
    $protocontigs[$_]=$protocontig;
  }
  return \@protocontigs;
}


sub nextcontigs_warc {
  #return a hash containing the connections between the query proto-contig and its connected proto-contigs with the thickness of the edges
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

1;

