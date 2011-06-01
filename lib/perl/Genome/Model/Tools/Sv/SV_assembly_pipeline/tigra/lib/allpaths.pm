#!/usr/bin/env perl
#construct heterozygous alleles

use strict;
use warnings;
use Getopt::Std;
use GraphViz;

package allpaths;
my %nodes;
my @bnodes;
my %opts;  #this is not activated at this moment

sub new{
  my ($class, %arg) = @_;
  my $self={
	    k=>$arg{k} || 25,
	    n=>$arg{n} || 100,
	    cov=>$arg{cov} || 3
	   };
  bless($self, $class || ref($class));
  return $self;
}

sub DESTROY{
  undef %nodes;
  undef @bnodes;
}

sub doit{
  my ($self,%arg)=@_;
  my $rcontigs=$arg{contig} if($arg{contig});
  my $f_contig=$arg{filename} if($arg{filename});
  my $min_degree=$arg{degree} || 2;
  my @Contigs;

  foreach my $contig(@{$rcontigs}){
    $nodes{$contig->{id}}=$contig;
    if($contig->{types} && $contig->{covs}>$self->{cov}){
      my @degree=split //,$contig->{types};
      push @bnodes,-($contig->{id}) if($degree[0]>=$min_degree);
      push @bnodes,$contig->{id} if($degree[1]>=$min_degree);
    }
  }

  if($#bnodes>=$self->{n}){
    print STDERR "Skip Graph size too large!\n";
    return;
  }

  my @longest_uniq_paths;
  my @allpaths;
  my $pathstr='';
  foreach my $id(@bnodes){
    my $edges=&CreateGraph($id, $f_contig,$arg{graph});
    my %visited;
    my @paths=&getPath($id,$edges,\%visited);
    foreach my $p(@paths){push @allpaths,$p;};
  }

  foreach my $p(sort byLongestLength @allpaths){
    #Mirror path
    my @rpns=split /\./, $p;
    for(my $i=0;$i<=$#rpns;$i++){
      $rpns[$i]=($rpns[$i]>0)?-$rpns[$i]:abs($rpns[$i]);
    }
    my $ap=join('.',reverse(@rpns));
    my $rindex1=rindex $pathstr,$p;
    my $rindex2=rindex $pathstr,$ap;
    if($rindex1>=0){
      my $char=substr $pathstr,$rindex1+length($p),1;
      next if($char !~ /\d/);
    }
    if($rindex2>=0){
      my $char=substr $pathstr,$rindex2+length($ap),1;
      next if($char !~ /\d/);
    }
    $pathstr.='|'.$p;
    push @longest_uniq_paths,$p;
  }

  foreach my $p(sort byLongestLength @longest_uniq_paths){
    #edit fasta
    my @pns=split /\./, $p;
    my $fasta;
    my $kmercovsum=0;
    foreach my $nid(@pns){
      my $fa=$nodes{abs($nid)}->{seq};
      if($nid<0){
	$fa=~ tr/ACGT/TGCA/; $fa=reverse $fa;
      }
      if(!defined $fasta){
	$fasta=$fa;
      }
      else{
	$fa=substr($fa,$self->{k}-1);
	$fasta.=$fa||'';
      }
      $kmercovsum+=$nodes{abs($nid)}->{covs}*($nodes{abs($nid)}->{lens}-$self->{k}+1);
    }
    my $contig;
    my $lens=length($fasta);
    my $avgkmercov=($lens>0)?int($kmercovsum*100/$lens)/100:0;
    ($contig->{id},$contig->{seq},$contig->{lens},$contig->{covs})=($p,$fasta,$lens,$avgkmercov);
    push @Contigs,$contig;
  }
  return \@Contigs;
}

sub getPath{
  #recursion
  my ($id,$edges,$visited)=@_;
  my @path;

  my @nds=sort {$a <=> $b} keys %{$$edges{$id}};
  if(@nds){
    foreach my $nd(@nds){
      next if($$visited{$id}{$nd});  #avoid repeat
      $$visited{$id}{$nd}=1;
      my @spath=&getPath($nd,$edges,$visited);
      foreach my $p(@spath){
	push @path,$id . '.' . $p;
	#push @path, $p . '.' . $id;
      }
    }
  }
  else{
    push @path,$id;
  }
  return @path;
}


sub CreateGraph{
  my ($seed,$f_contig,$f_graph)=@_;
  my @tails;
  push @tails,$seed;
  my %cn;
  my %edges;
  my %snodes;
  while(@tails){
    my %newtails;
    foreach my $t(@tails){  #breadth first search
      my %neighbor;
      &InNodes($t,\%neighbor);
      &OutNodes($t,\%neighbor);
      $snodes{$t}=1;
      foreach my $n(sort {$a <=> $b} keys %neighbor){
	next if($t eq $n);   #skip looping back to itself
	next if(defined $edges{$t}{$n});
	$edges{$t}{$n}=$neighbor{$n};

	if(!defined $snodes{$n}){  # a new node
	  $newtails{$n}=1;
	}
      }
    }
    @tails=keys %newtails;
  }

  my $g;
  if(defined $f_graph){
    #Visualization
    $g = GraphViz->new(rankdir=>1, directed=>1);
    foreach my $n(keys %snodes){
      $g->add_node($n);
    }
  }

  my %visited;
  my %dedges;
  @tails=($seed);
  my $nedges=0;
  while(@tails){
    my %newtails;
    foreach my $t(@tails){  #breadth first search
      $visited{$t}=1;
      my %outnodes;
      &OutNodes($t,\%outnodes);
      foreach my $n(keys %{$edges{$t}}){	
	if(defined $edges{$n}{$t} && defined $outnodes{$n}){ #only care end to end connections
	  $g->add_edge($t => $n, label => $edges{$t}{$n}) if(defined $f_graph && !defined $dedges{$t}{$n});
	  $dedges{$t}{$n}=$edges{$t}{$n};
	  $newtails{$n}=1 if(! defined $visited{$n});
	  $nedges++;
	}
      }
    }
    @tails=keys %newtails;
  }

  if(defined $f_graph && $nedges>0){
    my $fimg=join('.',$f_contig,$seed,'png');
    $g->as_png($fimg); # save image
  }
  return \%dedges;
}

sub InNodes{
  my ($id,$neighbor)=@_;
  my $node=$nodes{abs($id)};
  if($id>0){
    if(defined $node->{I}){
      foreach my $ni(split /\,/, $node->{I}){
	my ($id,$nreads)=split /\:/,$ni;
	next if($id=~/M/);
	$id=($id<0)?abs($id):-abs($id);
	$$neighbor{$id}=$nreads;
      }
    }
  }
  else{
    if(defined $node->{O}){
      foreach my $ni(split /\,/, $node->{O}){
	my ($id,$nreads)=split /\:/,$ni;
	next if($id=~/M/);
	my $end=($id>0)?1:0;  #inbound reverse in-node orientation
	# 1: the start end of a contig, 0: the end of a contig
	$id=($id<0)?abs($id):-abs($id);
	$$neighbor{$id}=$nreads;
      }
    }
  }
}

sub OutNodes{
  my ($id,$neighbor)=@_;
  my $node=$nodes{abs($id)};
  if($id>0){
    foreach my $no(split /\,/, $node->{O}){
      my ($id,$nreads)=split /\:/,$no;
      next if($id=~/M/);
      $$neighbor{$id}=$nreads;
    }
  }
  else{
    foreach my $no(split /\,/, $node->{I}){
      my ($id,$nreads)=split /\:/,$no;
      next if($id=~/M/);
      $$neighbor{$id}=$nreads;
    }
  }
}

sub byLongestLength{
  my @na=split /\./,$a;
  my @nb=split /\./,$b;
  return $#nb <=> $#na;
}

1;
