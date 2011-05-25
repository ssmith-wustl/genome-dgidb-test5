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

package maprdtocontig;

my %HH;
my $Rdnum=0;
my $K;
my @Contigs;
my @Contiglens;
my @Contigcovs;
my @Contigtypes;
my $Contignum=0;
my %Contigtips;
my $DefaultTip=1000;

my @Contigtags;
my @Contigs2;
my @Contiglens2;
my @Contigcovs2;
my @Contigtypes2;
my $Contignum2=0;
my $Smalltip=100;
my $Thin=2; # 4 for trep; tricky here
my $Ratiocutoff=0.3;
my $Walkcutoff=$Thin*3+1; # 10 for trep
my $Convergestepwall=12;
my $Convergelengthwall=150;

my %Interest2_rd;
my %Interest2;
my %Interest;
my $Insertwall=35;
my $Interestlength=100;
my $Scaffold_factor=1.2;
my @Contigtags2=(0);
my @Reads;

sub new{
  my ($class, %arg) = @_;
  my $self={
	   };
  $K=$arg{k};
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
  undef %Interest2_rd;
  undef %Interest2;
  undef %Interest;
}

sub doit{
  my ($self,%arg)=@_;


  @Reads=@{$arg{reads}};
  %HH=%{$arg{HH}};
  %Contigtips=%{$arg{tips}};
  my @in_contigs=@{$arg{contig}};
  my @in_contigs2=@{$arg{contig2}};

  for my $i(1..$#in_contigs){
    $Contiglens[$i]=$in_contigs[$i]->{lens};
    $Contigcovs[$i]=$in_contigs[$i]->{covs};
    $Contigtypes[$i]=$in_contigs[$i]->{types};
    $Contigtags[$i]=$in_contigs[$i]->{tags};
    $Contigs[$i]=$in_contigs[$i]->{seq};
  }


  for my $i(1..$#in_contigs2){
    $Contiglens2[$i]=$in_contigs2[$i]->{lens};
    $Contigcovs2[$i]=$in_contigs2[$i]->{covs};
    $Contigtypes2[$i]=$in_contigs2[$i]->{types};
    $Contigs2[$i]=$in_contigs2[$i]->{seq};
  }

  for (1..$#Contigs2) {
    $Contigtags2[$_]=$_;
  }

  &interestgen();
  &mapreads();
  &scaffold1();
}

sub scaffold1{
  #print STDERR "Scaffold1ing ..\n";
  my %contig2check;
  for (keys %Interest2_rd) {$contig2check{$_}=0;}
  for (keys %Interest2_rd) {
    next if ($contig2check{$_}==1);
    #     $_=&realcontig2($_);
    my ($xcontig2,$path)=&checkIcontig($_);
    $contig2check{$_}=1;
    next if ($xcontig2==0);
    my ($xxcontig2,)=&checkIcontig(-$xcontig2);
    if ($_==(-$xxcontig2)){
      $contig2check{-$xcontig2}=1;
      my @p=split / /, $path;
      my @sort= sort ($Contigcovs[abs $p[0]],$Contigcovs[abs $p[-1]]);        
        #print STDERR "bingo $_\t$xcontig2\t$path\tsort $sort[0] $sort[1] ".($sort[1]-$sort[0])." ".$Walkcutoff*$Scaffold_factor." ".$Ratiocutoff*$Scaffold_factor*$sort[1]."\n";
      if (($sort[1]-$sort[0]) < $Walkcutoff*$Scaffold_factor && ($sort[1]-$sort[0])<$Ratiocutoff*$Scaffold_factor*$sort[1]) {
	#print STDERR "Bingo $_\t$xcontig2\t$path\n";
	
	#          print STDERR "BINGO $_\t$xcontig2\t$path\n" if ($p[0]==$Interest2{$_}[0] && $p[-1]==-$Interest2{-$xcontig2}[0]);    
	if ($p[0]==$Interest2{$_}[0] && $p[-1]==-$Interest2{-$xcontig2}[0]) {  #merge go here
	  #print STDERR "BINGO $_\t$xcontig2\t$path\n";
	  my $pathseq=($p[0]>0)?$Contigs[abs $p[0]]:&revcom($Contigs[abs $p[0]]);
	  $pathseq=substr $pathseq, length($pathseq)-$K+1,$K-1;
	  for my $i (1..($#p-1)) {
	    my $tmp=($p[$i]>0)?$Contigs[abs $p[$i]]:&revcom($Contigs[abs $p[$i]]);
	    $pathseq.= substr $tmp, $K-1,length($tmp)-$K+1;
	  }
	  &merge($_,$xcontig2,$pathseq);
	}
	
      }
    }
  }
}

sub merge {
  my ($contigx, $contigy, $path)=@_;
  my $contigxreal=&realcontig2($contigx);
  my $contigyreal=&realcontig2($contigy);  
  if (abs $contigxreal==abs $contigyreal) {return;}
  if ($contigxreal>0) {
    my $seqy=$Contigs2[abs $contigyreal];
    $seqy=&revcom($seqy) if ($contigyreal<0);
    $Contigs2[$contigxreal]=(substr $Contigs2[$contigxreal],0,$Contiglens2[$contigxreal]-$K+1).$path.(substr $seqy,$K-1,$Contiglens2[abs $contigyreal]-$K+1);
    $Contigcovs2[$contigxreal]=($Contigcovs2[$contigxreal]*$Contiglens2[$contigxreal]+$Contigcovs2[abs $contigyreal]*$Contiglens2[abs $contigyreal])/($Contiglens2[$contigxreal]+$Contiglens2[abs $contigyreal]);
    $Contiglens2[$contigxreal]=length $Contigs2[$contigxreal];
    my $x=$Contigtypes2[abs $contigyreal];
    $x=reverse $x if ($contigyreal < 0);
    my @tmp=split //, $Contigtypes2[$contigxreal].$x;
    $Contigtypes2[$contigxreal]=$tmp[0].$tmp[-1];
    $Contigs2[abs $contigyreal]="";
  }
  elsif ($contigxreal<0){
    my $seqy=$Contigs2[abs $contigyreal];
    $seqy=&revcom($seqy) if ($contigyreal>0);
    $Contigs2[-$contigxreal]=(substr $seqy,0,$Contiglens2[abs $contigyreal]-$K+1).(&revcom($path)).(substr $Contigs2[-$contigxreal],$K-1,$Contiglens2[-$contigxreal]-$K+1);
    $Contigcovs2[-$contigxreal]=($Contigcovs2[-$contigxreal]*$Contiglens2[-$contigxreal]+$Contigcovs2[abs $contigyreal]*$Contiglens2[abs $contigyreal])/($Contiglens2[-$contigxreal]+$Contiglens2[abs $contigyreal]);
    $Contiglens2[-$contigxreal]=length $Contigs2[-$contigxreal];
    my $x=$Contigtypes2[abs $contigyreal];
    $x=reverse $x if ($contigyreal > 0);
    my @tmp=split //, $x.$Contigtypes2[-$contigxreal];
    $Contigtypes2[-$contigxreal]=$tmp[0].$tmp[-1];
    $Contigs2[abs $contigyreal]=""; 
  }
#  $Interest2{$contigxreal}=$Interest2{$contigyreal};
#  $Interest2_rd{$contigxreal}=$Interest2_rd{$contigyreal};
    $Contigtags2[abs $contigyreal]=$contigxreal*$contigyreal/(abs $contigyreal);   
}

sub realcontig2 {
  my ($contig2)=@_;
  return 0 if ($contig2==0);
  if ($Contigtags2[abs $contig2]==abs $contig2) {
    return $contig2;
  }
  else {
    return &realcontig2($Contigtags2[abs $contig2]*$contig2/(abs $contig2));
  }
}

sub checkIcontig{
  my ($contig2)=@_;
  my %h;
  my %ha;
  my $n=0;
  for my $i (@{$Interest2_rd{$contig2}}){
    my $rd=$Reads[(abs $i)-1];
    $rd=&revcom($rd) if ($i<0);
    my ($xcontig2, $path)=&walkrd($rd,$contig2);
#    my ($test1,$test2)=&walkrd($rd,$contig2);
#    print "debugx contig2 $contig2 xcontig2 $xcontig2 path $path\n" ;
#    print "debugx contig2 $contig2 test1 $test1 test2 $test2\n";
   next if ($xcontig2==0);         
    $h{$xcontig2}+=1;
    $ha{$xcontig2}={} if (!$ha{$xcontig2});
    $ha{$xcontig2}{$path}+=1;
    $n+=1; 
  }
  my @sorted=(sort {$h{$b}<=>$h{$a}} (keys %h));
#  my @test=(keys %h); 
  if ($h{$sorted[1]}<$Walkcutoff && $h{$sorted[0]}*$Ratiocutoff>$h{$sorted[1]}&& $h{$sorted[0]}>=$Thin){
    my @sortedpath=sort {$ha{$sorted[0]}{$b}<=>$ha{$sorted[0]}{$a}} (keys %{$ha{$sorted[0]}});
    if ($ha{$sorted[0]}{$sortedpath[0]}>0.5*$h{$sorted[0]}) {
      return ($sorted[0],$sortedpath[0]);
    }
  }
  return (0,"0");
}

sub walkrd {
  my ($rd,$contig2)=@_;
  my @s;
  my @s2;
  my @p;
  my $tag=0;
  my $end="";
  my $endtag=0;
  for (my $i=0; $i<=(length $rd)-$K;$i++) {
    my $w=substr $rd, $i,$K;
    if ($HH{$w}||$HH{&revcom($w)}) {
	my ($truew, $dir)=&true($w);
	if ( $dir*$HH{$truew}{tag} != $s[-1] || $endtag==1) {
	    $endtag=0;
	    my $x=$Contigtags[abs $HH{$truew}{tag}]*$HH{$truew}{tag}/(abs $HH{$truew}{tag})*$dir;
	    push @s, $dir*$HH{$truew}{tag};
	    if ($Interest2_rd{$x}){
	      if ($x!=$s2[-1]){
	        push @s2, $x;
	        $tag=2 if ($tag==1.5);
	         
	      }
	      if ($x==$contig2){
	        $tag=1;
	      }
	      elsif ($tag==1) {
	        @p=();
		push @p, $s[-2];
	        push @p, $s[-1];
	        $tag=1.5;
	      }
	      elsif ($tag==1.5) {
	        push @p, $s[-1];
	      }
	      elsif ($tag==2) {
	        push @p, $s[-1];
	        $tag=3;
	        last;
	      }
	    }
	    else {
	      if ($tag==1) {
	        @p=();
	        push @p, $s[-2];
	        push @p, $s[-1];
	        $tag=2;
	      }
	      elsif ($tag==2 || $tag==1.5) {
	        push @p, $s[-1];
	        $tag=2 if ($tag==1.5);
	      }
	      $end=$Contigs[abs $s[-1]];
	      $end=&revcom($end) if ($s[-1]<0);
	    }
	}
        $endtag=1 if ($w eq (substr $end, length($end)-$K, $K));
    }
    else {
#      if ($s[-1]!=0){
#        push(@s, 0);
#        if ($tag==1) {
#          @p=();
#	  push @p, $s[-2];
#	  push @p, $s[-1];
#	  $tag=2;
#	}
#	elsif ($tag==2 || $tag==1.5) {
#	  push @p, $s[-1];
#	  $tag=2 if ($tag==1.5);
#	} 
      
#      }
      $tag=0;
    
    }
  }
  my @tmp=@{$Interest2{$contig2}};
  #print STDERR "debugx contig2 $contig2 tmp @tmp s @s s2 @s2 p @p\n" ;
  if ($tag==3) {
    return ($s2[-1], "@p");
  }
  return (0,"0");  
}

sub mapreads {
  #print STDERR "Mapping reads to contigs ..\n";
  my $index=0;  # reads start from 1,  negative mean revcom
  for my $rd (@Reads){
    chomp $rd;
    $index+=1;
    if ($index % 100000 ==0) {
      #print STDERR "Mapped $index reads\n";
    }
    my %a;
    for (my $i=0;$i<=length($rd)-$K;$i+=2) {
      my $w=substr $rd,$i,$K;
      next unless($HH{$w}||$HH{&revcom($w)});
      my ($truew,$dir)=&true($w);
      next if ($HH{$truew}{n}<=1);
      my $contig=$dir*$HH{$truew}{tag};
      next if (! $Interest{abs $contig});
      unless ($a{$contig}){
	push @{$Interest{abs $contig}},$contig/(abs $contig)*$index;
	$a{$contig}=1;
      }
    }
  }
}

sub printmapping {
    my ($self,$myfile)=@_;
    open(MYF,">$myfile");
    #print STDERR "Print reads mapping to file $myfile .. \n";
    for my $k (sort {$a <=> $b} keys %Interest2) {
        my %a;
	my @temp=@{$Interest2{$k}};
	print MYF "BC\t$k\t@temp\n";   #Big Contig
	$Interest2_rd{$k}=[];
	for my $i (@temp) {
	  my $dir=$i/(abs $i);
	  my @tmp=@{$Interest{abs $i}};
	  for my $j (@tmp) {
	    my $rd=$j*$dir;
	    unless ($a{$rd}){
	    push @{$Interest2_rd{$k}}, $rd;
	    $a{$rd}=1; 
	    }
	  }
	  print MYF "SC\t".(abs $i)."\t@tmp\n";   #Small (proto) Contig
	}
	
	my @t=@{$Interest2_rd{$k}};
	print MYF "AC\t$k\t@t\n";   #
    }
    close(MYF);
}

sub interestgen {
  my ($cutoff)=@_;
  #print STDERR "Generating contigs list ..\n";
  #    print STDERR $i."\n";
  for my $i (1..($#Contigs2)) {
    next if ($Contiglens2[$i]<$Interestlength);
    $Interest2{$i}=[];
    $Interest2{-$i}=[];
    my $wall=$Insertwall;
    $wall=$Contiglens2[$i]/2 if ($Contiglens2[$i]/2<$wall);
    my $length=$K-1;
    while (1) {
      my $node=substr $Contigs2[$i],$length-$K+1,$K;
      my ($truenode,$dir)=&true($node);
      my $contig=$HH{$truenode}{tag};
      push @{$Interest2{-$i}},$contig*(-$dir);
      $Interest{abs $contig}=[] if (!$Interest{abs $contig});
      $length+=$Contiglens[abs $contig]-$K+1;
      last if ($length>=$wall);
    }

    #	next if ($length==$Contiglens2[$i]);
    $length=$K-1;
    while (1) {
      my $node=substr $Contigs2[$i],$Contiglens2[$i]-$length-1,$K;
      my ($truenode,$dir)=&true($node);
      my $contig=$HH{$truenode}{tag};
      push @{$Interest2{$i}},$contig*$dir;
      $Interest{abs $contig}=[] if (!$Interest{abs $contig});
      $length+=$Contiglens[abs $contig]-$K+1;
      last if ($length>=$wall);
    }
  }
  my $temp=(keys %Interest);
  #print STDERR "$temp interesting contigs found.\n";
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
sub nextcontigs {
    my ($contignum)=@_;
    my $node;
    if ($contignum>0){
        $node=substr $Contigs[$contignum], $Contiglens[$contignum]-$K, $K;

    }
    else {
        $node=substr $Contigs[-$contignum], 0, $K;
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


sub nextbase{
    my ($node)=@_;
    my ($truenode,$dir)=&true($node);
    if ($dir==1){
	return("A",$HH{$truenode}{AO},"T",$HH{$truenode}{TO},"G",$HH{$truenode}{GO},"C",$HH{$truenode}{CO});
    }
    else {return("A",$HH{$truenode}{TI},"T",$HH{$truenode}{AI},"G",$HH{$truenode}{CI},"C",$HH{$truenode}{GI});}
}

sub dump_contigs2_m {
  my ($self)=@_;
  my @dContigs2;
  #open(MYFILE,">$filename");
  for (1..$#Contigs2) {
    # next if ($Contigtags2[$_]!=$_);
    my $contig2;
    if ($Contigtags2[$_]==$_){
      my $node=substr $Contigs2[$_], 0, $K;
      my ($truenode,$dir)=&true($node);
      my $contig=$HH{$truenode}{tag}*$dir*(-1);
      my %a=&nextcontigs_warc($contig);
      my $i="";
      my $o="";
      foreach my $con (sort keys %a) {
	my $tmp=&realcontig2($Contigtags[abs $con]*$con/(abs $con));
	my $conhead=($con>0)?(substr $Contigs[$con],0, $K):(&revcom(substr $Contigs[-$con],$Contiglens[-$con]-$K,$K));
	my $tmphead=($tmp>0)?(substr $Contigs2[$tmp],0, $K):(&revcom(substr $Contigs2[-$tmp],$Contiglens2[-$tmp]-$K,$K));
	$tmp.="M" if ($tmphead ne $conhead);
	$i.=$tmp;
	$i.=":".$a{$con}.",";
      }
      $node=substr $Contigs2[$_], $Contiglens2[$_]-$K, $K;
      ($truenode,$dir)=&true($node);
      $contig=$HH{$truenode}{tag}*$dir;
      %a=&nextcontigs_warc($contig);
      foreach my $con (sort keys %a) {
	my $tmp=&realcontig2($Contigtags[abs $con]*$con/(abs $con));
	my $conhead=($con>0)?(substr $Contigs[$con],0, $K):(&revcom(substr $Contigs[-$con],$Contiglens[-$con]-$K,$K));
	my $tmphead=($tmp>0)?(substr $Contigs2[$tmp],0, $K):(&revcom(substr $Contigs2[-$tmp],$Contiglens2[-$tmp]-$K,$K));
	$tmp.="M" if ($tmphead ne $conhead);
	$o.=$tmp;
	$o.=":".$a{$con}.",";
      }

      ($contig2->{id},$contig2->{lens},$contig2->{covs},$contig2->{types},$contig2->{I},$contig2->{O},$contig2->{tags})=($_,$Contiglens2[$_], $Contigcovs2[$_], $Contigtypes2[$_], "$i", "$o", $Contigtags2[$_]);
      #print MYFILE ">Contig$_ $Contiglens2[$_] $Contigcovs2[$_] $Contigtypes2[$_] I$i O$o $Contigtags2[$_]\n";
    }
    else {
      ($contig2->{id},$contig2->{lens},$contig2->{covs},$contig2->{types},$contig2->{I},$contig2->{O},$contig2->{tags})=($_,$Contiglens2[$_], $Contigcovs2[$_], $Contigtypes2[$_], "", "",$Contigtags2[$_].' *');
      #print MYFILE ">Contig$_ $Contiglens2[$_] $Contigcovs2[$_] $Contigtypes2[$_] I O $Contigtags2[$_] *\n";
    }
    $contig2->{seq}=$Contigs2[$_];
    #print MYFILE $Contigs2[$_]."\n";

    push @dContigs2,$contig2;
  }
  close(MYFILE);
  return \@dContigs2;
}

sub nextcontigs_warc {
    my ($contignum)=@_;
    my $node;
    if ($contignum>0){
	$node=substr $Contigs[$contignum], $Contiglens[$contignum]-$K, $K;

    }
    else { 
	$node=substr $Contigs[-$contignum], 0, $K;
	$node=&revcom($node);
    }
    my %a;
    if ($HH{$node}){
	for ("A", "C", "G", "T") {
	    next if ($HH{$node}{$_."O"}==0);
	    my $vnode=(substr $node, 1, $K-1).$_;
	    my ($truenode, $dir)=&true($vnode);
	    $a{$dir*$HH{$truenode}{tag}}=$HH{$node}{$_."O"};
	}
    }
    else {
	my $rnode=&revcom($node);
        for ("A", "C", "G", "T") {
            next if ($HH{$rnode}{$_."I"}==0);
            my $vnode=$_.(substr $rnode, 0, $K-1);
            my ($truenode, $dir)=&true($vnode);
            $a{-$dir*$HH{$truenode}{tag}}=$HH{$rnode}{$_."I"};
	}
    }
    return(%a);
}

1;
