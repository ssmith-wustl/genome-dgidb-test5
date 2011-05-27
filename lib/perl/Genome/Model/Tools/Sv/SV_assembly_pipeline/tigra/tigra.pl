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
use Getopt::Std;
use IO::File;
#use Devel::Size qw(size total_size);
use FindBin qw($Bin);
use lib "$FindBin::Bin/lib";
use kmergen;
use graphgen;
use walknodes;
use addbridgekmer;
use walkcontig;
use processtips;
use maprdtocontig;
use allpaths;
use Bio::SeqIO;

my $version="TIGRA-0.0.2";
my %opts = (k=>15,m=>2,M=>2e9,t=>1000,c=>3,n=>100,N=>2);
getopts('o:k:m:M:dh:g:p:r:n:N:', \%opts);
die("
Usage:   tigra.pl <fasta files>
Options:
         -k INT   Specify Kmer sizes, Use comma to delimit multiple kmers [$opts{k}]
         -c FLOAT Minimal average kmer coverage [$opts{c}] for a contig to be considered in the alternative haplotypes
         -m INT   Lowest Kmer frequency in initial hashing [$opts{m}]
         -M INT   Highest Kmer frequency in initial hashing [$opts{M}]
         -o FILE  Save primary assembly contigs to FILE [stdout]
         -p STR   Estimate the utility of the subset of reads containing STR in header
         -r FILE  Provide a reference to screen for non-reference kmers
         -t INT   Set default tip number [$opts{t}]
         -h FILE  Save alternative haplotypes to FILE
         -n INT   Maxmimal number of nodes allowed for constructing alternative haplotypes [$opts{n}]
         -N INT   Minimal number of degrees for a node to consider as start of alternative haplotype [$opts{N}]
         -g FILE  Save assembly graph(png) in FILE
         -d       Turn on debug mode, generate intermediate files
Version: $version\n
") unless (@ARGV);

my ($Reads,$pReads)=&getReads(fastas=>\@ARGV);
my @kmersizes=split /\,/,$opts{k};
my $kmersize=shift @kmersizes;
my $contigs=&initial_iteration($kmersize);

while(@kmersizes){
  $kmersize=shift @kmersizes;
  $contigs=&iteration($kmersize,$contigs);
}

my $refseq;
if($opts{r}){
  $refseq='';
  my $refseq_stream = Bio::SeqIO->newFh(-file =>$opts{r}, -format => 'Fasta');
  while(my $refseq_obj = <$refseq_stream>){
    $refseq.=$refseq_obj->seq;
  }
}

my ($phh,$total);
if($#$pReads>=0){
  my $pkg=new kmergen(k=>$kmersize,c=>$opts{m},C=>$opts{M});
  ($phh,$total)=$pkg->doit($pReads,$refseq);
  $pkg->printMer("MerP",$phh) if($opts{d});  
}

#Output assembled contigs
&outputcontigs($opts{o},contig=>$contigs,format=>4,kmer=>$phh,total=>$total,kmersize=>$kmersize);

if($opts{h} || $opts{g}){  #Output all alternative paths or contig graph
  my $ap=new allpaths(k=>$kmersize,cov=>$opts{c},n=>$opts{n});
  $contigs=$ap->doit(contig=>$contigs,filename=>$ARGV[0],graph=>$opts{g},degree=>$opts{N});
  &outputcontigs($opts{h},contig=>$contigs,format=>5,kmer=>$phh,total=>$total,kmersize=>$kmersize) if($opts{h});
}

sub initial_iteration{
  my ($kmersize)=@_;
  ########################################## asm_1_kmergen2.pl
  my $kg=new kmergen(k=>$kmersize,c=>$opts{m},C=>$opts{M});
  my ($hh,$total)=$kg->doit($Reads);
  $kg->printMer("Mer",$hh) if($opts{d});

  my $gg=new graphgen(k=>$kmersize,kmers=>$hh);
  my ($RDnum,$PR,$HH)=$gg->doit($Reads);
  if($opts{d}){printnodes("Mynodes",$HH); $gg->printPR("MyREADnum",$PR);}

  #from de bruigin graph to proto-contig graph
  my $wn=new walknodes(k=>$kmersize);
  $wn->strictwalk($HH);
&printnodes("Mynodes_", $HH);
  my $contigtips;
  my $protocontigs=$wn->dump_protocontigs();
  if($opts{d}){&printnodes("Mynodes.strwlk1",$HH);&outputcontigs("Mycontigs.strwlk1",contig=>$protocontigs,tips=>$contigtips,format=>1);}

  #compute tip value: max{nucleotide distances to leaves} for all proto-contigs and the anti-proto-contigs, start from the leaves
  my $pt=new processtips(k=>$kmersize);
  $contigtips=$pt->tipwrap(1000,$protocontigs,$HH);
  if($opts{d}){&outputcontigs("Mycontigs.tiplabel1",contig=>$protocontigs,tips=>$contigtips);}

  #recover low frequency kmers in high quality reads that bridge separated non-tip proto-contig graphs
  my $ab=new addbridgekmer(k=>$kmersize);
  my $newkmers;
  ($HH,$newkmers)=$ab->doit($HH,$protocontigs,$contigtips,$PR,$Reads);
  if($opts{d}){
    &printnodes("Mynodes.add",$HH);
    open(FOUT,">Newmer") || die "unable to open Newmer\n";
    foreach (@{$newkmers}){
      print FOUT $_ . "\n";
    }
    close(FOUT);
  }

  undef $contigtips;
  $wn->strictwalk($HH);
printnodes("Mynodes_",$HH);  
  $protocontigs=$wn->dump_protocontigs();
  if($opts{d}){&printnodes("Mynodes.strwlk2",$HH);&outputcontigs("Mycontigs.strwlk2",contig=>$protocontigs,tips=>$contigtips,format=>1);}
  #updated the set of proto-contigs with the expanded hash
  undef $pt;
  $pt=new processtips(k=>$kmersize);
  $contigtips=$pt->tipwrap(1000,$protocontigs,$HH);
  if($opts{d}){&outputcontigs("Mycontigs.tiplabel2",contig=>$protocontigs,tips=>$contigtips);}

  #extend proto-contigs to contigs by removing tips and collapse bubbles with heuristic cut-offs
  my $wc=new walkcontig(k=>$kmersize);
  my $contigs=$wc->walkcontigwrap(cutoff=>3,ratiocutoff=>0.3,HH=>$HH,contig=>$protocontigs,tips=>$contigtips);
  my $contigs2=$wc->dump_contigs2();
  if($opts{d}){&printnodes("Mynodes.wlkcon",$HH); &outputcontigs("Mycontigs.wlkcon",contig=>$contigs,tips=>$contigtips,format=>3); &outputcontigs("Mycontigs2.wlkcon",contig=>$contigs2,format=>2);}

  #relabel tips on proto-contigs connected to the middle of a contig
  $contigtips=$pt->breaktip(1000,$HH,$contigtips,$contigs,$contigs2);
  if($opts{d}){&printnodes("Mynodes.btip",$HH);&outputcontigs("Mycontigs.btip",contig=>$contigs,tips=>$contigtips,format=>3);
  }

  #similar to 6, different param, more sensitive to weak branches
  undef $wc;
  $wc=new walkcontig(k=>$kmersize);
  $contigs=$wc->walkcontigwrap(cutoff=>3,ratiocutoff=>0.2,HH=>$HH,contig=>$protocontigs,tips=>$contigtips);
  if($opts{d}){&printnodes("Mynodes.wlkcon2",$HH);&outputcontigs("Mycontigs.wlkcon2",contig=>$contigs,tips=>$contigtips,format=>1);&outputcontigs("Mycontigs2.wlkcon2",contig=>$contigs2,format=>2);
  }

  #use entire read length to resolve small repeats
  my $mr=new maprdtocontig(k=>$kmersize);
  $mr->doit(reads=>$Reads,HH=>$HH,contig=>$contigs,contig2=>$contigs2,tips=>$contigtips);
  $contigs=$mr->dump_contigs2_m();
  if($opts{d}){$mr->printmapping("Mapfile");&outputcontigs("Mycontigs2.scaf",contig=>$contigs,format=>4);
  }

  return $contigs;
}

sub iteration{
  my ($kmersize,$fakereads)=@_;

  my ($fakeReads,$pfakeReads)=&getReads(contigs=>$fakereads,K=>$kmersize);
  my $kg=new kmergen(k=>$kmersize,c=>$opts{m},C=>$opts{M});
  my @totalReads=(@{$Reads},@{$fakeReads},@{$fakeReads});
  my ($hh,$total)=$kg->doit(\@totalReads);
  $kg->printMer("Mer",$hh) if($opts{d});

  @totalReads=(@{$Reads},@{$fakeReads});
  my $gg=new graphgen(k=>$kmersize,kmers=>$hh);
  my ($RDnum,$PR,$HH)=$gg->doit(\@totalReads);
  if($opts{d}){printnodes("Mynodes",$HH); $gg->printPR("MyREADnum",$PR);}

  #from de bruigin graph to proto-contig graph
  my $wn=new walknodes(k=>$kmersize);
  $wn->strictwalk($HH);
  my $contigtips;
  my $protocontigs=$wn->dump_protocontigs();
  if($opts{d}){&printnodes("Mynodes.strwlk1",$HH);&outputcontigs("Mycontigs.strwlk1",contig=>$protocontigs,tips=>$contigtips,format=>1);}

  #compute tip value: max{nucleotide distances to leaves} for all proto-contigs and the anti-proto-contigs, start from the leaves
  my $pt=new processtips(k=>$kmersize);
  $contigtips=$pt->tipwrap(1000,$protocontigs,$HH);
  if($opts{d}){&outputcontigs("Mycontigs.tiplabel1",contig=>$protocontigs,tips=>$contigtips);}

  #recover low frequency kmers in high quality reads that bridge separated non-tip proto-contig graphs
  my $ab=new addbridgekmer(k=>$kmersize);
  my $newkmers;
  ($HH,$newkmers)=$ab->doit($HH,$protocontigs,$contigtips,$PR,$Reads);
  if($opts{d}){
    &printnodes("Mynodes.add",$HH);
    open(FOUT,">Newmer") || die "unable to open Newmer\n";
    foreach (@{$newkmers}){
      print FOUT $_ . "\n";
    }
    close(FOUT);
  }

  undef $contigtips;
  $wn->strictwalk($HH);
  $protocontigs=$wn->dump_protocontigs();
  if($opts{d}){&printnodes("Mynodes.strwlk2",$HH);&outputcontigs("Mycontigs.strwlk2",contig=>$protocontigs,tips=>$contigtips,format=>1);
  }
  #updated the set of proto-contigs with the expanded hash
  undef $pt;
  $pt=new processtips(k=>$kmersize,Thin=>2);
  $contigtips=$pt->tipwrap(1000,$protocontigs,$HH);
  if($opts{d}){&outputcontigs("Mycontigs.tiplabel2",contig=>$protocontigs,tips=>$contigtips);
  }

  #extend proto-contigs to contigs by removing tips and collapse bubbles with heuristic cut-offs
  my $wc=new walkcontig(k=>$kmersize);
  my $contigs=$wc->walkcontigwrap(cutoff=>3,ratiocutoff=>0.3,HH=>$HH,contig=>$protocontigs,tips=>$contigtips);
  my $contigs2=$wc->dump_contigs2();
  if($opts{d}){&printnodes("Mynodes.wlkcon",$HH);&outputcontigs("Mycontigs.wlkcon",contig=>$contigs,tips=>$contigtips,format=>3);&outputcontigs("Mycontigs2.wlkcon",contig=>$contigs2,format=>2);
  }

  #relabel tips on proto-contigs connected to the middle of a contig
  $HH=$pt->thicken(2.5,$HH,$contigtips,$contigs,$contigs2);
  if($opts{d}){&printnodes("Mynodes.btip",$HH);&outputcontigs("Mycontigs.btip",contig=>$contigs,tips=>$contigtips,format=>3);
  }

  #similar to 6, different param, more sensitive to weak branches
  undef $wc;
  $wc=new walkcontig(k=>$kmersize);
  $contigs=$wc->walkcontigwrap(cutoff=>3,ratiocutoff=>0.2,HH=>$HH,contig=>$protocontigs,tips=>$contigtips);
  if($opts{d}){&printnodes("Mynodes.wlkcon2",$HH);&outputcontigs("Mycontigs.wlkcon2",contig=>$contigs,tips=>$contigtips,format=>1);&outputcontigs("Mycontigs2.wlkcon2",contig=>$contigs2,format=>2);
  }

  #use entire read length to resolve small repeats
  my $mr=new maprdtocontig(k=>$kmersize);
  $mr->doit(reads=>$Reads,HH=>$HH,contig=>$contigs,contig2=>$contigs2,tips=>$contigtips);
  $contigs=$mr->dump_contigs2_m();
  if($opts{d}){$mr->printmapping("Mapfile");&outputcontigs("Mycontigs2.scaf",contig=>$contigs,format=>4);
  }

  return $contigs;
}

sub getReads{
  my (%arg)=@_;
  my @fastas=@{$arg{fastas}} if($arg{fastas});
  my @contigs=@{$arg{contigs}} if($arg{contigs});
  my $K=$arg{K};

  push @fastas,$arg{fasta} if($arg{fasta});
  my @Reads;
  my @pReads;
  foreach my $fasta (@fastas){
    open(FASTAS,"<$fasta") || die "unable to open $fasta\n";
    my $header;
    while(<FASTAS>){
      chomp;
      my $header=$_ if($_=~/^\>/);
      $_=<FASTAS>; chomp;
      push @Reads,$_;
      push @pReads,$_ if($opts{p} && $header=~/$opts{p}/);
    }
    close(FASTAS);
  }

  foreach my $contig(@contigs){
    next unless ($contig->{lens}>$K+5);
    push @Reads,$contig->{seq};
  }
  return (\@Reads,\@pReads);
}

sub printnodes {
  my ($filename,$HH)=@_;
  open(MYFILE,">$filename") || die "unable to write to $filename\n";
  #while (my $key= each %{$HH}) {
  foreach my $key ( sort keys %{$HH}){
    print MYFILE $key." ".$$HH{$key}{n}." ".$$HH{$key}{AI}." ".$$HH{$key}{TI}." ".$$HH{$key}{GI}." ".$$HH{$key}{CI}." ".$$HH{$key}{AO}." ".$$HH{$key}{TO}." ".$$HH{$key}{GO}." ".$$HH{$key}{CO}." ".$$HH{$key}{tag}." ".$$HH{$key}{tag2}."\n";
  }
  close(MYFILE);
}

sub outputcontigs{
  my ($filename,%arg)=@_;
  my ($contigs,$contigtips,$format,$rhh,$total,$kmersize)=($arg{contig},$arg{tips},$arg{format}||0,$arg{kmer},$arg{total},$arg{kmersize});
  my $fh;
  if($filename){
    open(MYFILE,">$filename") || die "unable to write to $filename\n";
    $fh=\*MYFILE;
  }
  else{
    $fh=\*STDOUT;
  }

  foreach my $contig(@{$contigs}){
    next unless(defined $contig);
    my $contig_kmerUtil=0; 
    my $case_seq;

    if(defined $rhh){
      ($contig_kmerUtil,$case_seq)=&KmerUtility($kmersize,$contig->{seq},$rhh,$total);
    }
    else{
      $case_seq=lc($contig->{seq});
    }

    if($format==1){
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig->{types},$$contigtips{$contig->{id}}||$opts{t},$$contigtips{-$contig->{id}}||$opts{t},$contig->{tags},'I'.$contig->{I},'O'.$contig->{O},$contig_kmerUtil);
    }
    elsif($format==2){
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig->{types},'I'.$contig->{I},'O'.$contig->{O},$contig_kmerUtil);
    }
    elsif($format==3){
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig->{types},$$contigtips{$contig->{id}}||$opts{t},$$contigtips{-$contig->{id}}||$opts{t},$contig->{tags},$contig_kmerUtil);
    }
    elsif($format==4){
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig->{types},'I'.$contig->{I},'O'.$contig->{O},$contig->{tags},$contig_kmerUtil);
    }
    elsif($format==5){
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig_kmerUtil);
    }
    else{
      print $fh '>Contig'. join(" ",$contig->{id},$contig->{lens},$contig->{covs},$contig->{types},$$contigtips{$contig->{id}}||$opts{t},$$contigtips{-$contig->{id}}||$opts{t},$contig_kmerUtil);
    }
    print $fh "\n";
    #print $fh $contig->{seq}."\n";
    print $fh ($case_seq || $contig->{seq}) ."\n";
  }
  close($fh);
}


sub KmerUtility{
  my ($kmersize,$seq,$rhh,$total,@bkpos)=@_;
  my $occur=0;
  my @uniqpos;
  for (my $i=$kmersize; $i<=length($seq); $i++) {
    my $w=substr $seq, $i-$kmersize, $kmersize;
    my $rw=reverse $w; $rw=~tr/ATGC/TACG/;

    if($$rhh{$w}) {
      $occur+=$$rhh{$w};
      push @uniqpos,$i;
    }
    elsif($$rhh{$rw}){
      $occur+=$$rhh{$rw};
      push @uniqpos,$i;
    }

  }

  $seq=lc $seq;
  if(@uniqpos){
    my @bases=split //,$seq;
    foreach my $pos(@uniqpos){
      for(my $i=$pos-$kmersize;$i<$pos;$i++){
	$bases[$i]=uc($bases[$i]);
      }
    }
    $seq=join('',@bases);
  }
  my $utility=($total>0)?int($occur*100/$total):0;
  #my $utility=$occur;
  return ($utility,$seq);
}
