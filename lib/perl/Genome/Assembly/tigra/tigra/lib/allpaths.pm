#!/gsc/bin/perl
#construct heterozygous alleles based on Atlas (Lei Chen's) local assembly output

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

  die "Skip Graph size too large!\n" if($#bnodes>=$self->{n});
  my %pathrec;
  foreach my $id(@bnodes){
    my $edges=&CreateGraph($id, $f_contig,$arg{graph});
    my %visited;
    my @paths=&getPath($id,$edges,\%visited);
    foreach my $p(@paths){
      #Mirror path
      my @pns=split /\./, $p;
      my @rpns=@pns;
      for(my $i=0;$i<=$#rpns;$i++){
	$rpns[$i]=($rpns[$i]>0)?-$rpns[$i]:abs($rpns[$i]);
      }

      my $ap=join('.',reverse(@rpns));
      if(!defined $pathrec{$p} && !defined $pathrec{$ap}){
	#edit fasta
	$pathrec{$p}=1;
	my $fasta;
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
	    $fasta.=$fa;
	  }
	}
	my $contig;
	($contig->{id},$contig->{seq})=($p,$fasta);
	push @Contigs,$contig;
      }
    }
  }
  return \@Contigs;
}

sub getPath{
  #recursion
  my ($id,$edges,$visited)=@_;
  my @path;

  my @nds=keys %{$$edges{$id}};
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
    my @newtails=();
    foreach my $t(@tails){  #breadth first search
      my %neighbor;
      &InNodes($t,\%neighbor);
      &OutNodes($t,\%neighbor);
      $snodes{$t}=1;
      foreach my $n(keys %neighbor){
	next if($t eq $n);   #skip looping back to itself
	next if(defined $edges{$t}{$n});
	$edges{$t}{$n}=$neighbor{$n};

	if(!defined $snodes{$n}){  # a new node
	  push @newtails,$n;
	}
      }
    }
    @tails=@newtails;
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
    my @newtails=();
    foreach my $t(@tails){  #breadth first search
      $visited{$t}=1;
      my %outnodes;
      &OutNodes($t,\%outnodes);
      foreach my $n(keys %{$edges{$t}}){	
	if(defined $edges{$n}{$t} && defined $outnodes{$n}){ #only care end to end connections
	  $g->add_edge($t => $n, label => $edges{$t}{$n}) if(defined $f_graph);
	  $dedges{$t}{$n}=$edges{$t}{$n};
	  push @newtails,$n if(! defined $visited{$n});
	  $nedges++;
	}
      }
    }
    @tails=@newtails;
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

1;
