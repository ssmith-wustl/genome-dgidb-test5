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

package graphgen;
my %HH;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	   };
  if($arg{kmers}){
    while(my ($key,$value)=each %{$arg{kmers}}){
      $HH{$key}={n=>$value,AI=>0,CI=>0,GI=>0,TI=>0,AO=>0,CO=>0,GO=>0,TO=>0,tag=>0,tag2=>0};
      #   n:  occurence
      #  AI:  incoming edges from A/C/G/T
      #  AO:  outgoing edges from A/C/G/T
      # tag:  intermediate proto-contig (integer contig index)
      #tag2:  contig index
    }
  }
  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %HH;
}

sub doit{
  my ($self,$rReads)=@_;
  ################################################ asm_2_graphgen_1.pl
  my $RDnum=0;
  my @PR;
  foreach (@{$rReads}){
    my $rd=$_;
    my $PRstr="";
    my $l=length $rd;
    for (my $i=$self->{k}; $i<=$l-1; $i++) {
      my $w=substr $rd, $i-$self->{k}, $self->{k};
      my $rw=reverse $w;
      $rw=~tr/ATGC/TACG/;
      my $occur=0;
      my $tag=0;  #skip bases when kmer do not exist
      if($HH{$w}) {
	$occur=$HH{$w}{n};
	my $u=substr $rd, $i-$self->{k}+1,$self->{k};
	my $ru=reverse $u;
	$ru=~tr/ATGC/TACG/;
	if($HH{$u}) {                    # $w $u
	  my $next=substr $u, $self->{k}-1,1;
	  $HH{$w}{$next."O"}+=1;
	  $next=substr $w,0,1;
	  $HH{$u}{$next."I"}+=1;
	}
	elsif($HH{$ru}) {               # $w $ru  
	  my $next=substr $u, $self->{k}-1,1;
	  $HH{$w}{$next."O"}+=1;
	  $next=substr $rw,$self->{k}-1,1;
	  $HH{$ru}{$next."O"}+=1;
	}
	else {$i+=1; $tag=1;}
      }
      elsif($HH{$rw}){
	$occur=$HH{$rw}{n};
	my $u=substr $rd, $i-$self->{k}+1,$self->{k};
	my $ru=reverse $u;
	$ru=~tr/ATGC/TACG/;
	if($HH{$u}) {                    # $rw $u
	  my $next=substr $ru, 0,1;
	  $HH{$rw}{$next."I"}+=1;
	  $next=substr $w,0,1;
	  $HH{$u}{$next."I"}+=1;
	}
	elsif($HH{$ru}) {               # $rw $ru
	  my $next=substr $ru, 0,1;
	  $HH{$rw}{$next."I"}+=1;
	  $next=substr $rw, $self->{k}-1,1;
	  $HH{$ru}{$next."O"}+=1;
	}
	else {$i+=1; $tag=1;}
      }
      else {$occur=1;}
      $PRstr.= $occur." ";
      $PRstr.= "1 " if ($tag==1 && $i<$l);
    }

    my $w=substr $rd, $l-$self->{k}, $self->{k};
    my $rw=reverse $w;
    $rw=~tr/ATGC/TACG/;

    if ($HH{$w}) {$PRstr.=$HH{$w}{n};}
    elsif ($HH{$rw}) {$PRstr.=$HH{$rw}{n};}
    else {$PRstr.='1';}
    push @PR,$PRstr;

    $RDnum+=1;
    if ($RDnum % 100000 ==0) {
      #print STDERR "Added $RDnum reads\n";
    }
  }
  return($RDnum,\@PR,\%HH);
}

sub printPR{
  my ($self,$file,$rPR)=@_;
  open(FOUT,">$file") || die "unable to write to $file\n";
  foreach my $PRstr(@{$rPR}){
    print FOUT "$PRstr\n";
  }
  close(FOUT);
}

1;
