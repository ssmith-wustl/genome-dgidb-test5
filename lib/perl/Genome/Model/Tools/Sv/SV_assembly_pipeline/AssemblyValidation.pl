#!/gsc/bin/perl
#extract reads from a set of bams in breakdancer predicted regions

use strict;
use warnings;
use Getopt::Std;
use Bio::SeqIO;
use Bio::Seq;
use File::Temp;
use FindBin qw($Bin);
use lib "$FindBin::Bin/lib";

my $version='0.0.1-r141';

my %opts = (l=>500,p=>1000,s=>0,q=>1,n=>0,m=>10,x=>3,P=>-10,G=>-10,S=>0.02,A=>500,Q=>0,w=>200,C=>0.5,N=>5,J=>1);
getopts('l:d:c:p:r:e:s:Q:q:t:n:a:b:f:km:MRzv:hD:x:i:P:G:I:A:S:L:w:C:N:HJ:y',\%opts);
die("
Usage:   AssemblyValidation.pl <SV file, default in BreakDancer format> <bam files ... >
Options:
         -d DIR     Directory where all intermediate files are saved
         -I DIR     Read intermediate files from DIR instead of creating them
         -f FILE    Save Breakpoint sequences in file
         -r FILE    Save relevant cross_match alignment results to file
         -z         Customized SV format, interpret column from header that must start with # and contain chr1, start, chr2, end, type, size
         -H         Assemble high coverage data (such as capture)
         -y         Highest sensitivity assembly (1 read)
         -e INT     Exhaustively search combinations of $opts{l} bp blocks at the predicted breakpoints from -INT bp to +INT bp
         -v FILE    Save unconfirmed predictions in FILE
         -h         Make homo variants het by adding same amount of randomly selected wiletype reads
         -l INT     Flanking size [$opts{l}]
         -A INT     Esimated maximal insert size [$opts{A}]
         -q INT     Only assemble reads with mapping quality >= [$opts{q}]
         -m INT     Minimal size (bp) for an assembled SV to be called confirmed [$opts{m}]
         -i INT     invalidate indels are -i bp bigger or smaller than the predicted size, usually 1 std insert size
         -a INT     Get reads with start position bp into the left breakpoint, default [50,100,150]
         -b INT     Get reads with start position bp into the right breakpoint, default [50,100,150]
         -w INT     Pad local reference by additional [$opts{w}] bp on both ends
         -S FLOAT   Maximally allowed polymorphism rate in the flanking region [$opts{S}]
         -P INT     Substitution penalty in cross_match alignment [$opts{P}]
         -G INT     Gap Initialization penalty in cross_match alignment [$opts{G}]
         -N INT     Number of mismatches required to be tagged as poorly mapped [$opts{N}]
         -M         Prefix reference name with \'chr\' when fetching reads using samtools view
         -R         Assemble Mouse calls, NCBI reference build 37
         -J INT     Sleep [$opts{J}] second between the assembly iterations

Filtering:
         -p INT     Ignore cases that have average read depth greater than [$opts{p}]
         -c STRING  Specify a single chromosome
         -s INT     Minimal size of the region to analysis [$opts{s}]
         -Q INT     minimal BreakDancer score required for analysis [$opts{Q}]
         -t STRING  type of SV
         -n INT     minimal number of supporting reads [$opts{n}]
         -C FLOAT   Examine [$opts{C}] copy number altered events in the non-normal tissue, specific to BreakDancer
         -L STRING  Ingore calls supported by libraries that contains (comma separated) STRING
         -k         Attach assembly results as additional columns in the input file
         -D DIR     A directory that contains a set of supplementary reads (when they are missing from the main data stream)
         -x INT     Duplicate supplementary reads [$opts{x}] times
\n") unless ($#ARGV>=1);

my $fout;
if($opts{f}){
  if( -s $opts{f}){
    `rm -f $opts{f}`;
  }
  $fout = Bio::SeqIO->new(-file => ">>$opts{f}" , '-format' => 'Fasta');
}

my @SVs;
if($opts{z}){
  @SVs=&ReadCustomized(shift @ARGV);
}
else{
  @SVs=&ReadBDCoor(shift @ARGV);
}

printf "#%d SVs to be assembled from\n#Bams: ", $#SVs+1;
my @FBAMS;
foreach my $bam(@ARGV){
  my $fbam=`readlink $bam`; chomp $fbam;
  $fbam = $bam if($fbam eq "");
  push @FBAMS,$fbam;
}
print join(",",@FBAMS) . "\n";

printf "#Version-%s\tParameters: ", $version;
foreach my $opt(keys %opts){printf "\t%s",join(':',$opt,$opts{$opt});} print "\n";
if($opts{k}){
  print "#Chr1\tPos1\tOrientation1\tChr2\tPos2\tOrientation2\tType\tSize\tScore\tnum_Reads\tnum_Reads_lib\tAllele_frequency\tVersion\tRun_Param\tAsmChr1\tAsmStart1\tAsmChr2\tAsmStart2\tAsmOri\tAsmSize\tAsmHet\tAsmScore\tAlnScore\twAsmScore\n";
}
else{
#printf "%s\t%d(%d)\t%s\t%d(%d)\t%s\t%d(%d)\t%s(%s)\t%s\t%d\t%d\t%d\%\t%d\t%d\t%d\t%d\t%d\t%d\t%s\ta%d.b%d\n",$maxSV->{chr1},$maxSV->{start1},$start,$maxSV->{chr2},$maxSV->{start2},$end,$maxSV->{ori},$maxSV->{size},$size,$maxSV->{type},$type,$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$maxSV->{scarsize},$prefix,$maxSV->{a},$maxSV->{b};
  print "\#CHR1\tPOS1\tCHR2\tPOS2\tORI\tSIZE\tTYPE\tHET\twASMSCORE\tTRIMMED_CONTIG_SIZE\tALIGNED\%\tNUM_SEG\tNUM_FSUB\tNUM_FINDEL\tBP_FINDEL\tMicroHomology\tMicroInsertion\tPREFIX\tASMPARM\tCopyNumber\tGene\tKnown\n";
}

if($opts{v}){open(FN,">$opts{v}") || die "unable to open $opts{v}\n";}
if($opts{r}){open(ALNOUT,">$opts{r}") || die "unable to open $opts{r}\n";}

my @as; my @bs;
@as=(defined $opts{a})?($opts{a}):(50,100,150);
@bs=(defined $opts{b})?($opts{b}):(50,100,150);
if($opts{H}){@as=(50); @bs=(100);$opts{p}=10000;}  #parameteres for capture data
if($opts{e}){my $stepsize=int($opts{l}/2); @as=($stepsize); @bs=($stepsize);}
srand(time ^ $$);

my $prefix;
foreach my $SV(@SVs){
  my ($chr1,$start,$chr2,$end,$type,$size)=($SV->{chr1},$SV->{pos1},$SV->{chr2},$SV->{pos2},$SV->{type},$SV->{size});
  $chr1=~s/chr//; $chr2=~s/chr//;
  next unless ($start=~/^\d/ && $end=~/^\d/ && $size=~/^\d/);

  my $datadir = $opts{d};

  if(!defined $opts{I}){
    if(defined $opts{d}){
      $datadir="/tmp/chr$chr1.$start.$end.$type.$size";
      mkdir $datadir;
    }
    else{
      $datadir=File::Temp::tempdir("SV_Assembly_XXXXXX", DIR => '/tmp', CLEANUP => 1);
    }
  }
  else{
    $datadir=$opts{I};
  }

  print STDERR "Data directory: $datadir\n";

  if($chr1 eq $chr2 && $start>$end){my $tmp=$start;$start=$end;$end=$tmp;}
  my @start_ends;
  if($opts{e}){
    for(my $s=$start-$opts{e};$s<=$start+$opts{e};$s+=$opts{l}){
      for(my $e=$end-$opts{e}; $e<=$end+$opts{e};$e+=$opts{l}){
	push @start_ends,join(',',$s,$e);
      }
    }
  }
  else{
    @start_ends=join(',',$start,$end);
  }

  foreach (@start_ends){
    ($start,$end)=split /\,/;
    $prefix=join('.',$chr1,$start,$chr2,$end,$type,$size,'+-');
    &AssembleBestSV($datadir,$SV);
    if($chr1 ne $chr2){   #reciprocal translocations
      foreach my $ori('++','--','-+'){
	$prefix=join('.',$chr1,$start,$chr2,$end,$type,$size,$ori);
	&AssembleBestSV($datadir,$SV);
      }
    }
  }

  #keep
  if(!defined $opts{I} && defined $opts{d}){
    `mv $datadir/* $opts{d}/`;
  }
  elsif(!defined $opts{I}){
    File::Temp::cleanup();
  }
}
close(FN) if($opts{v});
close(ALNOUT) if($opts{r});
print STDERR "AllDone\n";

sub AssembleBestSV{
  my ($datadir,$SV)=@_;
  my $maxSV;
  my ($chr1,$start,$chr2,$end,$type,$size,$ori)=split /\./,$prefix;
  if(defined $opts{M}){$chr1="chr$chr1";$chr2="chr$chr2";}
  if($start-$opts{l}-$opts{w}<1){
    print STDERR "$prefix: negative reference start coordinates, skip ...\n";
    return;
  }

  foreach my $a(@as){
    foreach my $b(@bs){
      sleep $opts{J};
      my $seqlen=0;
      my $nreads=0;
      my $nSVreads=0;
      my %readhash;
      my ($start1,$end1,$start2,$end2,$regionsize,$refsize);
      my @refs;
      my @samtools;
      my $posstr;
      print STDERR "$prefix\ta:$a\tb:$b\n";
      my $makeup_size=0;
      my $concatenated_pos=0;
      foreach my $fbam(@ARGV){
	if($type eq 'ITX'){
	  $start1=$start-$b;
	  $end1=$start+$opts{A};
	  $start2=$end-$opts{A};
	  $end2=$end+$a;
	}
	elsif($type eq 'INV'){
	  $start1=$start-$opts{l};
	  $end1=$start+$opts{l};
	  $start2=$end-$opts{l};
	  $end2=$end+$opts{l};
	}
	else{
	  $start1=$start-$opts{l};
	  $end1=$start+$a;
	  $start2=$end-$b;
	  $end2=$end+$opts{l};
	}

	if($ori eq '+-' && ($chr1 eq $chr2 && $start2<$end1)){
	  push @refs, join(':',$chr1,$start-$opts{l}-$opts{w},$end+$opts{l}+$opts{w});
	  $refsize=$end-$start+1+2*$opts{l}+2*$opts{w};
	  $posstr=join("_",$chr1,$start1-$opts{w},$chr1,$start1-$opts{w},$type,$size,$ori);
	  push @samtools,"samtools view $fbam $chr1:$start1\-$end2";
	  $regionsize=$end2-$start1+1;
	}
	else{
	  if($type eq 'CTX'){
	    push @refs, join(':',$chr1,$start-$opts{l}-$opts{w},$start+$opts{l}+$opts{w});
	    push @refs, join(':',$chr2,$end-$opts{l}-$opts{w},$end+$opts{l}+$opts{w});
	    $refsize=2*($opts{l}+$opts{w})+1;
	    $posstr=join("_",$chr1,$start-$opts{l}-$opts{w},$chr2,$end-$opts{l}-$opts{w},$type,$size,$ori);
	  }
	  elsif($size>99999){
	    push @refs, join(':',$chr1,$start-$opts{l}-$opts{w},$start+$opts{l});
	    push @refs, join(':',$chr2,$end-$opts{l},$end+$opts{l}+$opts{w});
	    $refsize=2*$opts{l}+$opts{w}+1;
	    $makeup_size=($end-$opts{l})-($start+$opts{l})-1;
	    $concatenated_pos=2*$opts{l}+$opts{w};
	    $posstr=join("_",$chr1,$start-$opts{l}-$opts{w},$chr2,$end-$opts{l}-$opts{w},$type,$size,$ori);
	  }
	  else{
	    push @refs, join(':',$chr1,$start-$opts{l}-$opts{w},$end+$opts{l}+$opts{w});
	    $refsize=$end-$start+1+2*($opts{l}+$opts{w});
	    $posstr=join("_",$chr1,$start1-$opts{w},$chr1,$start1-$opts{w},$type,$size,$ori);
	  }
	
	  my ($reg1,$reg2);
	  if($ori eq '+-'){
	    $reg1=$chr1 .':'.$start1.'-'.$end1;
	    $reg2=$chr2 .':'.$start2.'-'.$end2;
	  }
	  elsif($ori eq '-+'){
	    $reg1=$chr2 .':'.($end-$opts{l}).'-'.($end+$a);
	    $reg2=$chr1 .':'.($start-$b).'-'.($start+$opts{l});
	  }
	  elsif($ori eq '++'){
	    $reg1=$chr1 .':'.($start-$opts{l}).'-'.($start+$a);
	    $reg2=$chr2 .':'.($end-$opts{l}).'-'.($end+$b);
	  }
	  elsif($ori eq '--'){
	    $reg1=$chr1 .':'.($start-$a).'-'.($start+$opts{l});
	    $reg2=$chr2 .':'.($end-$b).'-'.($end+$opts{l});
	  }
	  else{}
	  $regionsize=$a+$b+2*$opts{l}+1;
	  push @samtools,"samtools view $fbam $reg1";	
	  push @samtools,"samtools view $fbam $reg2";
	}
      }

      if($refsize>1e6){printf STDERR "reference size %d too large, skip ...",$refsize; return;}
      my $cmd;
      #if((!defined $opts{I}) || (!-s "$datadir/$prefix.a$a.b$b.stat")){
      if(!-s "$datadir/$prefix.a$a.b$b.stat"){
	#create reference
	if(-s "$datadir/$prefix.ref.fa" && !defined $opts{I}){
	  `rm $datadir/$prefix.ref.fa`;
	}
	foreach my $ref(@refs){
	  my ($chr_ref,$start_ref,$end_ref)=split /\:/,$ref;
	  if(defined $opts{R}){  #Mice
	    $cmd="expiece $start_ref $end_ref /gscmnt/839/info/medseq/reference_sequences/NCBI-mouse-build37/${chr_ref}.fasta >> $datadir/$prefix.ref.fa";
	  }
	  else{
	    $cmd="expiece $start_ref $end_ref /gscuser/kchen/sata114/kchen/Hs_build36/all_fragments/Homo_sapiens.NCBI36.45.dna.chromosome.${chr_ref}.fa >> $datadir/$prefix.ref.fa";
            #  $cmd="expiece $start_ref $end_ref /gscmnt/839/info/medseq/reference_sequences/NCBI-mouse-build37/${chr_ref}.fasta >> /gscmnt/sata872/info/medseq/xfan/test1";
            #my $test = `expiece $start_ref $end_ref /gscuser/kchen/sata114/kchen/Hs_build36/all_fragments/Homo_sapiens.NCBI36.45.dna.chromosome.${chr_ref}.fa`;
            #print "Test::$test\n";
	  }

          #if(!defined $opts{I}){
	    system($cmd);
	    print STDERR "$cmd\n";
            #}
	}

	if($makeup_size>0){  #piece together 2 refs as one
	  `head -n 1 $datadir/$prefix.ref.fa > $datadir/$prefix.ref.fa.tmp`;
	  `grep -v fa $datadir/$prefix.ref.fa >> $datadir/$prefix.ref.fa.tmp`;
	  `mv $datadir/$prefix.ref.fa.tmp $datadir/$prefix.ref.fa`;
	}
	my $freads="$datadir/$prefix.a$a.b$b.fa";
	my $avgdepth=0;
	if((!-s $freads) || (!defined $opts{I})){
	  my @buffer;
	  my %uniqreadnames;
	  foreach my $scmd(@samtools){
	    my @reads;
	    my %max_mapqual;
	    my %min_NM;
	    open(SAM,"$scmd |");
	    print STDERR "$scmd\n";
	    while(<SAM>){
	      chomp;
	      my @fields=split;
	      my $read;
	      ($read->{NM})=($_=~/NM\:i\:(\d+)/);
              $read->{NM}=0 if(!defined $read->{NM});
	      ($read->{MF})=($_=~/MF\:i\:(\d+)/);
	      my $NBaseMapped=0;
	      foreach my $mstr(split /M/,$fields[5]){
		my ($nbasem)=($mstr=~/(\d+)$/);
		$NBaseMapped+=$nbasem || 0;
	      }
	      ($read->{name},$read->{flag},$read->{mqual},$read->{seq})=($fields[0],$fields[1],$fields[4],$fields[9]);
	      my $readlen=length($read->{seq});
	      $read->{PercMapped}=($readlen>0)?$NBaseMapped/$readlen:0;

	      $seqlen+=$readlen;
	      $read->{name}=~s/\/[12]//;
	      $max_mapqual{$read->{name}}=$read->{mqual} if(!defined $max_mapqual{$read->{name}} || $max_mapqual{$read->{name}}<$read->{mqual});
	      $min_NM{$read->{name}}=$read->{NM} if(!defined $min_NM{$read->{name}} || $min_NM{$read->{name}}>$read->{NM});
	      push @reads,$read;
	    }
	    close(SAM);
	    foreach my $read(@reads){
	      next if($read->{flag} & 0x0200 || $read->{flag} & 0x0400);  #duplicates or failed vendor QC
              next if(!defined $max_mapqual{$read->{name}} || $max_mapqual{$read->{name}}<$opts{q});
	      if($max_mapqual{$read->{name}}>=40 && $read->{flag} & 0x0001 && 
		 ($read->{flag} & 0x0004 ) ||  #one-end unmapped reads
		 ($read->{NM}>$opts{N} && $min_NM{$read->{name}}<3) ||  #one-end poorly mapped
		 (defined $read->{MF} && $read->{MF}==130)  ||    #Maq Smith-Waterman aligned
		 ($read->{PercMapped}<.9)  # more than 10% of bases are not mapped
		){
		$read->{name}.=',SV';
		$nSVreads++;
	      }
	      next if(defined $uniqreadnames{$read->{name}.$read->{flag}});
	      push @buffer,$read->{name};
	      push @buffer,$read->{seq};
	      $uniqreadnames{$read->{name}.$read->{flag}}++;
	    }
	    $nreads+=$#reads+1;
	  }
	  if($nreads<=0){print STDERR "no coverage from bam, skip ... \n";return}
	  my $avgseqlen=$seqlen/$nreads;
	  open(OUT,">$datadir/$prefix.a$a.b$b.fa") || die "unable to open $datadir/$prefix.a$a.b$b.fa\n";
	  while(@buffer){
	    printf OUT ">%s\n",shift @buffer;
	    my $sequence=shift @buffer;
	    printf OUT "%s\n",$sequence;
	    $readhash{uc($sequence)}=1 if(defined $opts{D});
	  }
	  if($opts{h}){  # add synthetic wildtype reads, making homo to het
	    my $reflen=$end2-$start1+1;
	    my $nr=0;
	    my $in  = Bio::SeqIO->newFh(-file => "$datadir/$prefix.ref.fa" , '-format' => 'Fasta');
	    my $seq = <$in>;
	    # do something with $seq
	    my $refseq=$seq->seq();
	    while($nr<$nreads){
	      my $rpos=rand()*$reflen;
	      my $refpos=$start1+$rpos;
	      next if($refpos>$end1 && $refpos<$start2);
	      $nr++;
	      my $readseq=substr($refseq,$rpos,$avgseqlen);
	      printf OUT ">Synthetic%dWildtype%d\n",$refpos,$nr;
	      printf OUT "%s\n",$readseq;
	    }
	  }
	  if(defined $opts{D} && ( -s "$opts{D}/$prefix.fa") ){  # the makeup reads
	    my $idx=0;
	    open(FIN,"<$opts{D}/$prefix.fa");
	    while(<FIN>){
	      chomp;
	      my $header=$_;
	      my $sequence=<FIN>; chomp $sequence;
	      next if(defined $readhash{uc($sequence)});
	      for(my $ii=0;$ii<$opts{x};$ii++){
		print OUT "$header.$idx\n";
		print OUT "$sequence\n";
		$idx++;
	      }
	    }
	  }
	  close(OUT);
	  if($regionsize<=0){
	    print STDERR "region size <=0, skip ...\n";
	    return;
	  }
	  $regionsize+=2*$avgseqlen;
	  $avgdepth=($regionsize>0)?$seqlen/$regionsize:0;
	  if($avgdepth<=0 || $avgdepth>$opts{p}){  #skip high depth region
	    print STDERR "no coverage, skip ...\n" if($avgdepth<=0);
	    print STDERR "coverage > $opts{p}, skip ...\n" if($avgdepth>$opts{p});
	    return;
	  }
	}
	printf STDERR "#Reads:%d\t#SVReads:%d\tRegionSize:%d\tAvgCoverage:%.2f\n",$nreads,$nSVreads,$regionsize,$avgdepth;

	#Assemble
	$cmd="time $FindBin::Bin/tigra/tigra.pl ";
#	$cmd="time /gscuser/xfan/kdevelop/tigra/debug/TIGRA_new/tigra.pl ";
	if($type=~/ITX/i || $type=~/INS/i){  #Tandem duplication
	  $cmd.="-N 1 ";
	}
	if($opts{y}){
	  $cmd.='-m 1 ';
	}
	if($opts{H}){
	  $cmd.="-h $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -o $datadir/$prefix.a$a.b$b.fa.contigs.fa -k25 -p SV -r $datadir/$prefix.ref.fa $datadir/$prefix.a$a.b$b.fa";
	}
	else{
	  $cmd.="-h $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -o $datadir/$prefix.a$a.b$b.fa.contigs.fa -k 15,25 -p SV -r $datadir/$prefix.ref.fa $datadir/$prefix.a$a.b$b.fa";
	}
	if((!defined $opts{I}) || (!-s "$datadir/$prefix.a$a.b$b.fa.contigs.fa") || (!-s "$datadir/$prefix.a$a.b$b.fa.contigs.het.fa")){
	  print STDERR "$cmd\n";
	  system($cmd);
	}
	#test homo contigs
	$cmd="cross_match $datadir/$prefix.a$a.b$b.fa.contigs.fa $datadir/$prefix.ref.fa -bandwidth 20 -minmatch 20 -minscore 25 -penalty $opts{P} -discrep_lists -tags -gap_init $opts{G} -gap_ext -1 > $datadir/$prefix.a$a.b$b.stat 2>/dev/null";
	system($cmd);
	print STDERR "$cmd\n";
      }
      $cmd="$FindBin::Bin/getCrossMatchIndel_ctx.pl -c $datadir/$prefix.a$a.b$b.fa.contigs.fa -r $datadir/$prefix.ref.fa -m $opts{S} -x $posstr -b $concatenated_pos -z $makeup_size $datadir/$prefix.a$a.b$b.stat";
      print STDERR "$cmd\n";
      my ($result)=`$cmd`;
      my $N50size=&ComputeTigraN50("$datadir/$prefix.a$a.b$b.fa.contigs.fa");
      my $DepthWeightedAvgSize=&ComputeTigraWeightedAvgSize("$datadir/$prefix.a$a.b$b.fa.contigs.fa");
      if(defined $result && $result=~/\S+/){
	$maxSV=&UpdateSVs($datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$DepthWeightedAvgSize,$regionsize);
      }

      if((!defined $opts{I}) || (!-s "$datadir/$prefix.a$a.b$b.het.stat")){
	#produce het contigs
	#`/gscuser/kchen/1000genomes/analysis/scripts/hetAtlas.pl -n 100 $datadir/$prefix.a$a.b$b.fa.contigs.fa > $datadir/$prefix.a$a.b$b.fa.contigs.fa.het` if((!defined $opts{I}) || (!-s "$datadir/$prefix.a$a.b$b.fa.contigs.fa.het"));
	#test het contigs
	$cmd="cross_match $datadir/$prefix.a$a.b$b.fa.contigs.het.fa $datadir/$prefix.ref.fa -bandwidth 20 -minmatch 20 -minscore 25 -penalty $opts{P} -discrep_lists -tags -gap_init $opts{G} -gap_ext -1 > $datadir/$prefix.a$a.b$b.het.stat 2>/dev/null";
	print STDERR "$cmd\n";
	system($cmd);
      }
      $cmd="$FindBin::Bin/getCrossMatchIndel_ctx.pl -c $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -r $datadir/$prefix.ref.fa -m $opts{S} -x $posstr -b $concatenated_pos -z $makeup_size $datadir/$prefix.a$a.b$b.het.stat";
      print STDERR "$cmd\n";
      $result=`$cmd`;
      if(defined $result && $result=~/\S+/){
	$maxSV=&UpdateSVs($datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$DepthWeightedAvgSize,$regionsize,1);
      }
    }
  }

  if(defined $maxSV && ($type eq 'CTX' && $maxSV->{type} eq $type ||
			$type eq 'INV' && $maxSV->{type} eq $type ||
			(($type eq $maxSV->{type} && $type eq 'DEL') ||
			 ($type eq 'ITX' && ($maxSV->{type} eq 'ITX' || $maxSV->{type} eq 'INS')) ||
			 ($type eq 'INS' && ($maxSV->{type} eq 'ITX' || $maxSV->{type} eq 'INS'))) &&
			$maxSV->{size}>=$opts{m} && (!defined $opts{i} || abs($maxSV->{size}-$size)<=$opts{i})
		       )
    ){
    my $scarstr;
    $scarstr=($maxSV->{scarsize}>0)?substr($maxSV->{contig},$maxSV->{bkstart}-1,$maxSV->{bkend}-$maxSV->{bkstart}+1):'-';

    if($opts{k}){
      printf "%s\t%s\t%d\t%s\t%d\t%s\t%d\t%s\t%d\t%d\t%d%%\t%d\t%d\t%d\t%d\t%d\t%s\ta%d.b%d\t%s\t%s\t%s\n",$SV->{line},$maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{ori},$maxSV->{size},$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$maxSV->{a},$maxSV->{b},$SV->{cnstr}||'NA',$SV->{gene}||'NA',$SV->{database}||'NA';
    }
    else{
      printf "%s\t%d(%d)\t%s\t%d(%d)\t%s\t%d(%d)\t%s(%s)\t%s\t%d\t%d\t%d\%\t%d\t%d\t%d\t%d\t%d\t%s\t%s\ta%d.b%d\t%s\t%s\t%s\n",$maxSV->{chr1},$maxSV->{start1},$start,$maxSV->{chr2},$maxSV->{start2},$end,$maxSV->{ori},$maxSV->{size},$size,$maxSV->{type},$type,$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$prefix,$maxSV->{a},$maxSV->{b},$SV->{cnstr}||'NA',$SV->{gene}||'NA',$SV->{database}||'NA';
    }
    if(defined $opts{f}){  #save breakpoint sequence
      my $coord=join(".",$maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{type},$maxSV->{size},$maxSV->{ori});
      my $contigsize=$maxSV->{contiglens};
      my $seqobj = Bio::Seq->new( -display_id => "ID:$prefix,Var:$coord,Ins:$maxSV->{bkstart}\-$maxSV->{bkend},Length:$maxSV->{contiglens},KmerCoverage:$maxSV->{contigcovs},Strand:$maxSV->{strand},Assembly_Score:$maxSV->{weightedsize},PercNonRefKmerUtil:$maxSV->{kmerutil},TIGRA",
				  -seq => $maxSV->{contig} );
      $fout->write_seq($seqobj);
    }
    if(defined $opts{r}){
      printf ALNOUT "%s\t%d(%d)\t%s\t%d(%d)\t%s\t%d(%d)\t%s(%s)\t%s\t%d\t%d\t%d\%\t%d\t%d\t%d\t%d\t%d\t%s\t%s\ta%d.b%d\n",$maxSV->{chr1},$maxSV->{start1},$start,$maxSV->{chr2},$maxSV->{start2},$end,$maxSV->{ori},$maxSV->{size},$size,$maxSV->{type},$type,$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$prefix,$maxSV->{a},$maxSV->{b};
      foreach my $aln(split /\,/,$maxSV->{alnstrs}){
	printf ALNOUT "%s\n",join("\t", split /\|/, $aln);
      }
      print ALNOUT "\n";
    }
  }
  elsif($opts{v}){
    printf FN "%s\t%d\t%s\t%d\t%s\t%d\t%s\n",$chr1,$start,$chr2,$end,$type,$size,$ori;
  }
}

sub UpdateSVs{
  my ($datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$depthWeightedAvgSize,$regionsize,$het)=@_;
  if(defined $result){
    my ($pre_chr1,$pre_start1,$pre_chr2,$pre_start2,$ori,$pre_bkstart,$pre_bkend,$pre_size,$pre_type,$pre_contigid,$alnscore,$scar_size,$read_len,$fraction_aligned,$n_seg,$n_sub,$n_indel,$nbp_indel,$strand,$microhomology,$alnstrs)=split /\s+/,$result;
    #$pre_size+=$makeup_size if($n_seg>=2 && $pre_bkstart<$opts{l}+$opts{w} && $pre_bkend>$opts{l}+$opts{w});
    if(defined $pre_size && defined $pre_start1 && defined $pre_start2){
      my $fcontig=($het)?"$datadir/$prefix.a$a.b$b.fa.contigs.het.fa":"$datadir/$prefix.a$a.b$b.fa.contigs.fa";
      my ($contigseq,$contiglens,$contigcovs,$kmerutil)=&GetContig($fcontig,$pre_contigid,$prefix);
      $alnscore=int($alnscore*100/$regionsize); $alnscore=($alnscore>100)?100:$alnscore;
      if(! defined $maxSV ||
	 $maxSV->{size}<$pre_size ||
	 $maxSV->{alnscore} <$alnscore){
	my $N50score=int($N50size*100/$regionsize); $N50score=($N50score>100)?100:$N50score;
	if(defined $opts{R}){  #Mouse
	  $pre_chr1=~s/.*\///; $pre_chr1=~s/\.fasta//;
	  $pre_chr2=~s/.*\///; $pre_chr2=~s/\.fasta//;
	}
	($maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{bkstart},$maxSV->{bkend},$maxSV->{size},$maxSV->{type},$maxSV->{contigid},$maxSV->{contig},$maxSV->{contiglens},$maxSV->{contigcovs},$maxSV->{kmerutil},$maxSV->{N50},$maxSV->{weightedsize},$maxSV->{alnscore},$maxSV->{scarsize},$maxSV->{a},$maxSV->{b},$maxSV->{read_len},$maxSV->{fraction_aligned},$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{strand},$maxSV->{microhomology})=($pre_chr1,$pre_start1,$pre_chr2,$pre_start2,$pre_bkstart,$pre_bkend,$pre_size,$pre_type,$pre_contigid,$contigseq,$contiglens,$contigcovs,$kmerutil,$N50score,$depthWeightedAvgSize,$alnscore,$scar_size,$a,$b,$read_len,$fraction_aligned,$n_seg,$n_sub,$n_indel,$nbp_indel,$strand,$microhomology);
	$maxSV->{het}=($het)?'het':'homo';
	$maxSV->{ori}=$ori;
	$maxSV->{alnstrs}=$alnstrs;
      }
    }
  }
  return $maxSV;
}

sub GetContig{
  my ($fin,$contigid,$prefix)=@_;
  my $in  = Bio::SeqIO->newFh(-file => "$fin" , '-format' => 'Fasta');
  my $sequence; 
  my @info;
  while ( my $seq = <$in> ) {
    # do something with $seq
    next unless($seq->id eq $contigid);
    @info=split /\s+/,$seq->desc;
    $sequence=$seq->seq();
    last;
  }
  return ($sequence,$info[0],$info[1],$info[$#info]);
}

sub ReadBDCoor{
  my ($f)=@_;
  open(IN,"<$f") || die "unable to open $f\n";
  my @coor;
  my @col_cn;
  my ($col_gene,$col_database);
  my @headfields;
  my @nlibs=split /\,/,$opts{L} if(defined $opts{L});
  while(<IN>){
    chomp;
    if(/^\#/){
      next unless(/Chr1\s/);
      #Parse the header line
      @headfields=split /\t/;
      my $col_normalcn;
      for(my $i=0; $i<=$#headfields; $i++){
	if($headfields[$i]=~/\.bam/){
	  if($headfields[$i]=~/normal/i){
	    $col_normalcn=$i;
	  }
	  else{
	    push @col_cn,$i;
	  }
	}
	elsif($headfields[$i]=~/Gene/i){
	  $col_gene=$i;
	}
	elsif($headfields[$i]=~/databases/i){
	  $col_database=$i;
	}
      }
      if(defined $col_normalcn){
	unshift @col_cn, $col_normalcn;
      }
    }
    chomp;
    my $cr;
    my @fields=split;
    my @extra;
    (
     $cr->{chr1},
     $cr->{pos1},
     $cr->{ori1},
     $cr->{chr2},
     $cr->{pos2},
     $cr->{ori2},
     $cr->{type},
     $cr->{size},
     $cr->{score},
     $cr->{nreads},
     $cr->{nreads_lib},
     @extra
    )=@fields;
    $cr->{line}=$_;
    $cr->{size}=abs($cr->{size});

    next if($cr->{chr1}=~/NT/ || $cr->{chr1}=~/RIB/);
    next if($cr->{chr2}=~/NT/ || $cr->{chr2}=~/RIB/);

    next unless(defined $cr->{pos1} && defined $cr->{pos2} && $cr->{pos1}=~/^\d+$/ && $cr->{pos2}=~/^\d+$/);
    next if(defined $opts{t} && $opts{t} ne $cr->{type} ||
	    defined $opts{s} && abs($cr->{size})<$opts{s} ||
	    defined $opts{n} && $cr->{nreads}<$opts{n} ||
	    defined $opts{Q} && $cr->{score}<$opts{Q} ||
	    defined $opts{c} && $cr->{chr1} ne $opts{c} || 
            defined $opts{M} && abs($cr->{size})<$opts{M} # also apply M to the predicted size as in the new version
	   );

    #Ignore events detected in a library
    my $ignore=0;
    foreach my $nlib(@nlibs){
      $ignore=1 if($cr->{nreads_lib}=~/$nlib/);
    }
    next if($ignore == 1);

    #Include Copy Number Altered events if available
    if(@col_cn){
      for(my $i=1;$i<=$#col_cn;$i++){
	next if($fields[$col_cn[$i]]=~/NA/ || $fields[$col_cn[0]]=~/NA/);
	my $diff_cn=abs($fields[$col_cn[$i]]-$fields[$col_cn[0]]);
	$ignore=0 if($diff_cn>$opts{C});
      }
      my @cns;
      for(my $i=0;$i<=$#col_cn;$i++){
	push @cns,join(':',$headfields[$col_cn[$i]],$fields[$col_cn[$i]]);
      }
      $cr->{cnstr}=join(',',@cns);
    }

    $cr->{gene}=$fields[$col_gene] if($col_gene);
    $cr->{database}=$fields[$col_database] if($col_database);

    $ignore=0 if($cr->{line}=~/cancer/i || $cr->{line}=~/coding/i);
    $ignore=0 if($cr->{line}=~/gene/i && $cr->{type}=~/ctx/i);  #assemble all translocation overlapping gene
    next if($ignore>0);

    push @coor, $cr;
  }
  close(IN);
  return @coor;
}

sub ReadCustomized{
  my ($f)=@_;
  open(IN,"<$f") || die "unable to open $f\n";
  my @coor;
  my %hc;
  while(<IN>){
    chomp;
    my @cols=split /\t+/;
    if(/^\#/){
      for(my $i=0;$i<=$#cols;$i++){
	$hc{chr1}=$i if(!defined $hc{chr1} && $cols[$i]=~/chr/i);
	$hc{pos1}=$i if(!defined $hc{pos1} && $cols[$i]=~/start/i);
	$hc{chr2}=$i if(!defined $hc{chr2} && $cols[$i]=~/chr2/i);
	$hc{pos2}=$i if(!defined $hc{pos2} && $cols[$i]=~/end/i);
	$hc{type}=$i if(!defined $hc{type} && $cols[$i]=~/type/i);
	$hc{size}=$i if(!defined $hc{size} && $cols[$i]=~/size/i);
      }
      $hc{chr2}=$hc{chr1} if(!defined $hc{chr2} && defined $hc{chr1});
      next;
    }
    die "file header in correctly formated.  Must have \#, chr, start, end, type, size.\n" if(!defined $hc{chr1} || !defined $hc{pos1} || !defined $hc{pos2} || !defined $hc{type} || !defined $hc{size});
    my $cr;
    $cr->{line}=$_;
    foreach my $k('chr1','pos1','chr2','pos2','type','size'){
      $cr->{$k}=$cols[$hc{$k}];
    }

    next unless(defined $cr->{pos1} && defined $cr->{pos2} && $cr->{pos1}=~/^\d+$/ && $cr->{pos2}=~/^\d+$/);
    next if(defined $opts{t} && $opts{t} ne $cr->{type} ||
	    defined $opts{s} && abs($cr->{size})<$opts{s} ||
	    defined $opts{c} && $cr->{chr1} ne $opts{c}
	   );
    $cr->{size}=abs($cr->{size});
    push @coor, $cr;
  }
  close(IN);
  return @coor;
}

sub ComputeTigraN50{
  my ($contigfile)=@_;
  my @sizes;
  my $totalsize=0;
  open(CF,"<$contigfile") || die "unable to open $contigfile\n";
  while(<CF>){
    chomp;
    next unless(/^\>/);
    next if(/\*/);
    my ($id,$size,$depth,$ioc,@extra)=split /\s+/;
    next if($size<=50 && $depth<3 && $ioc=~/0/);
    push @sizes,$size;
    $totalsize+=$size;
  }
  close(CF);
  my $cum_size=0;
  my $halfnuc_size=$totalsize/2;
  my $N50size;
  @sizes=sort {$a<=>$b} @sizes;
  while($cum_size<$halfnuc_size){
    $N50size=pop @sizes;
    $cum_size+=$N50size;
  }
  return $N50size;
}


sub ComputeTigraWeightedAvgSize{
  my ($contigfile)=@_;
  my $totalsize=0;
  my $totaldepth=0;
  open(CF,"<$contigfile") || die "unable to open $contigfile\n";
  while(<CF>){
    chomp;
    next unless(/^\>/);
    next if(/\*/);
    my ($id,$size,$depth,$ioc,@extra)=split /\s+/;
    next if($size<=50 && (($depth<3 && $ioc=~/0/) || $depth>500));  #skip error tips or extremely short and repetitive contigs
    $_=<CF>; chomp;
    next if($size<=50 && (/A{10}/ || /T{10}/ || /C{10}/ || /G{10}/));  #ignore homopolymer contig
    $totalsize+=$size*$depth;
    $totaldepth+=$depth;
  }
  close(CF);
  my $WeightedAvgSize=($totaldepth>0)?int($totalsize*100/$totaldepth)/100:0;
  return $WeightedAvgSize;
}
