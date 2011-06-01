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

use warnings;
use strict;

package kmergen;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	    c=>$arg{c} || 2,
	    C=>$arg{C} || 2e9
	   };
  bless($self, $class || ref($class));
  return $self;
}


sub doit{
  my ($self,$rReads,$filter)=@_;
  my %hh;
  my $totalcount=0;
my $p = -1;  
  foreach (@{$rReads}){
$p ++;  
    my @segments = split/N+/;
my $pp = -1;    
    foreach my $seg (@segments){
$pp ++;    
      my $kmers = length($seg)-$self->{k};
if($kmers eq "AAAAAGAGACAGGACAGATGGACAG"){
my $ppp = 0;
}
      next if($kmers<1);
      foreach my $i (0..$kmers){
	my $w = substr $seg, $i, $self->{k};
if(defined $filter){
	my $test = ($filter=~/$w/i);
	if($test != 0){
		my $test1 = 0;
	}
}
	next if(defined $filter && $filter=~/$w/i);
	if($hh{$w}){
	  $hh{$w} += 1;
	}else{
	  my $vw = reverse $w;
	  $vw =~ tr/ATGC/TACG/;
if(defined $filter){
	my $test = ($filter=~/$vw/i);
	if($test != 0){
		my $test1 = 0;
	}	
}	  
	  next if(defined $filter && $filter=~/$vw/i);
	  if($hh{$vw}){
	    $hh{$vw} += 1;
	  }else{
	    $hh{$w} = 1;
	  }
	}
	$totalcount++;
      }
    }
  }
  my @aa;
  foreach my $i (1..1000){
    $aa[$i] = 0;
  }

  foreach my $key (sort keys %hh){
    ($hh{$key} > 1000) ? ($aa[1000]+=1) : ($aa[$hh{$key}]+=1);
    if ( $hh{$key} < $self->{c} or $hh{$key} > $self->{C} ){
      $totalcount-=$hh{$key};
      delete $hh{$key};
    }
  }
  return (\%hh,$totalcount);
}

sub printMer{
  my ($self,$fout,$hh)=@_;
  open(FOUT,">$fout") || die "unable to open $fout\n";
  foreach my $key (sort keys %{$hh}){
    print FOUT "$key\t${$hh}{$key}\n";
  }
  close(FOUT);
}

1;
