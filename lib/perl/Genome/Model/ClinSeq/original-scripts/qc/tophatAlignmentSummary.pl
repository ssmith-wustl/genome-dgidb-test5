#!/usr/bin/perl
#Written by Malachi Griffith

#This script will examine a tophat alignment results directory and generate basic statistics on the alignmnents
#As a tool it should take in input files and produce output files

#Main inputs:
#RNA-seq Build Dir (e.g. /gscmnt/gc8001/info/model_data/2881643231/build117377906/)
#Annotation Build Dir (e.g. /gscmnt/ams1102/info/model_data/2771411739/build106409619/)

#Example code for getting annotation reference transcript build object (including directory)
##!/usr/bin/perl
#use lib '/gscuser/ssmith/git/rnaseq/lib/perl';
#use Genome; 
#my $m = Genome::Model->get(2880794563); 
#my $b = $m->last_succeeded_build;
#my $a = $b->annotation_reference_transcripts_build;
#print $a->data_directory,"\n";


#Load modules
use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

my $script_dir;
use Cwd 'abs_path';
BEGIN{
  if (abs_path($0) =~ /(.*\/).*\/.*\.pl/){
    $script_dir = $1;
  }
}
use lib $script_dir;
use ClinSeq qw(:all);

#Input parameters
my $reference_fasta_file = '';
my $tophat_alignment_dir = '';
my $reference_annotations_dir = '';
my $working_dir = '';
my $verbose = 0;
my $clean = 0;

GetOptions ('reference_fasta_file=s'=>\$reference_fasta_file, 'tophat_alignment_dir=s'=>\$tophat_alignment_dir, 'reference_annotations_dir=s'=>\$reference_annotations_dir, 
 	    'working_dir=s'=>\$working_dir, 'verbose=i'=>\$verbose, 'clean=i'=>\$clean);


my $usage=<<INFO;

  Example usage: 
  
  tophatAlignmentStats.pl  --reference_fasta_file='/gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa'  --tophat_alignment_dir='/gscmnt/gc2014/info/model_data/2880794541/build115909743/alignments/'  --reference_annotations_dir='/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/'  --working_dir='/gscmnt/sata132/techd/mgriffit/hgs/hg1/qc/tophat/'
  
  Intro:
  This script summarizes results from a tophat alignment directory and writes resulting stats and figures to a working directory

  Details:
  --reference_fasta_file          Reference fasta file that was used for Tophat mapping
  --tophat_alignment_dir          The 'alignment' dir created by a Tophat run
  --reference_annotations_dir     Directory containing the reference junctions to be compared against
                                  For example: /gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ALL.Genes.junc                                
  --working_dir                   Directory where results will be stored
  --verbose                       To display more output, set to 1
  --clean                         To clobber the top dir and create everything from scratch, set to 1

INFO

unless ($reference_fasta_file && $tophat_alignment_dir && $reference_annotations_dir && $working_dir){
  print GREEN, "$usage", RESET;
  exit(1);
}

#Check input directories and files
$tophat_alignment_dir = &checkDir('-dir'=>$tophat_alignment_dir, '-clear'=>"no");
if ($clean){
  $working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"yes");
}else{
  $working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"no");
}

unless (-e $reference_annotations_dir){
  print RED, "\n\nCould not find reference junctions file: $reference_annotations_dir\n\n", RESET;
  exit(1);
}

my $tophat_stats_file = $tophat_alignment_dir . "alignment_stats.txt";
my $tophat_junctions_bed_file = $tophat_alignment_dir . "junctions.bed";
my $new_tophat_junctions_bed_file = $working_dir . "junctions.bed";
my $tophat_junctions_junc_file = $working_dir . "junctions.junc";
my $tophat_junctions_anno_file = $working_dir . "junctions.strand.junc";

#Make a copy of the junctions file and alignment stats file
my $cp_cmd1 = "cp $tophat_junctions_bed_file $new_tophat_junctions_bed_file";
if ($verbose){ print YELLOW, "\n\n$cp_cmd1", RESET; }
system($cp_cmd1);

my $cp_cmd2 = "cp $tophat_stats_file $working_dir";
if ($verbose){ print YELLOW, "\n\n$cp_cmd2", RESET; }
system($cp_cmd2);


#Convert junctions.bed to a .junc file
my $bed_to_junc_cmd = "cat $new_tophat_junctions_bed_file | "."$script_dir"."misc/bed2junc.pl > $tophat_junctions_junc_file";
if ($verbose){ print YELLOW, "\n\n$bed_to_junc_cmd", RESET; }
system($bed_to_junc_cmd);


#Go through the .junc file and infer the strand of each observed junction
&inferSpliceSite('-infile'=>$tophat_junctions_junc_file, '-outfile'=>$tophat_junctions_anno_file, '-reference_fasta_file'=>$reference_fasta_file);


#Now annotate observed exon-exon junctions against databases of known junctions
#annotateObservedJunctions.pl  --obs_junction_file='/gscmnt/sata132/techd/mgriffit/hgs/hg1/qc/tophat/junctions.strand.junc'  --bedtools_bin_dir='/gsc/bin/'  --working_dir='/gscmnt/sata132/techd/mgriffit/hgs/hg1/qc/tophat/'  --gene_annotation_dir='/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/'  --gene_annotation_set='Ensembl'  --gene_name_type='id'
my @gene_name_type = qw ( symbol id );
my @gene_annotation_sets = qw (ALL Ensembl);
foreach my $gene_name_type (@gene_name_type){
  foreach my $gene_annotation_set (@gene_annotation_sets){
    my $cmd = "$script_dir/rnaseq/annotateObservedJunctions.pl  --obs_junction_file=$tophat_junctions_anno_file  --bedtools_bin_dir='/gsc/bin/'  --working_dir=$working_dir  --gene_annotation_dir=$reference_annotations_dir  --gene_annotation_set='$gene_annotation_set'  --gene_name_type='$gene_name_type'  --verbose=$verbose";
    if ($verbose){ print YELLOW, "\n\n$cmd", RESET };
    system($cmd);
  }
}


#Calculate gene level read counts and expression estimates from exon-exon junction counts
#Gene level expression = sum of exon junction read counts for a gene / number of exon-exon junctions of that gene
#Only known junctions 'DA' will be used for these calculations
#Store the proportion of junctions of the gene that were observed at least 1X, 5X, 10X, etc.
#Make sure the output file has both ENSG ID, Gene Symbol, and Mapped Gene Symbol


#Summarize the alignment stats file using an R script


#Feed resulting files into R and generate statistics (also supply known junctions file used for the analysis)
#- Basic stats: 
#  - Total junctions observed, 
#  - Total known junctions observed
#  - Proportion of all known junctions observed
#  - Total exon skipping junctions observed (and proportion of the library)
#  - Total novel exon skipping junctions observed (and proportion of the library)
#- Pie chart of splice sites observed (GC-AG, GC-AG, etc.)
#- Pie chart of anchor types (DA, NDA, D, A, N) - Number and Percentage of reads corresponding to each type
#- Percentage of all junction mapping reads with corresponding to known junctions
#- Distribution of exon-exon junction read counts
#- Expression distribution bias.  Percentage of all reads consumed by top N .. M % of junctions/genes
#- Display read count distribution at both the gene and junction level
#- For known exon-skipping events, display the proportion that are 1S, 2S, 3S, etc. - repeat for novel exon skipping
#- How many genes are covered over the majority of their junctions (25%, 50%, 75%, 90%, 95%, 100%)?
#- Produce ranked gene expression lists based on exon-junction values
#- Produce a Top N% expressed file


if ($verbose){print "\n\n"};

exit();



############################################################################################################################
#Infer strand from alignment to reference genome                                                                           #
############################################################################################################################
sub inferSpliceSite{
  my %args = @_; 
  my $infile = $args{'-infile'};
  my $outfile = $args{'-outfile'};
  my $reference_fasta_file = $args{'-reference_fasta_file'};

  #Load in the junctions from the input file
  my %junctions;
  open(JUNC, "$infile") || die "\n\nCould not open input file: $infile\n\n";
  my $header = 1;
  my $header_line;
  my %columns;
  my $o = 0;
  while(<JUNC>){
    chomp($_);
    my @line = split("\t", $_);
    if ($header){
      $header_line = $_;
      my $p = 0;
      foreach my $col (@line){
        $columns{$col}{position} = $p;
        $p++;
      }
      $header = 0;
      next();
    }
    $o++;
    my $jid = $line[$columns{'chr:start-end'}{position}];
    my $read_count = $line[$columns{'read_count'}{position}];
    $junctions{$jid}{read_count} = $read_count;
    $junctions{$jid}{order} = $o;
  }
  close(JUNC);

  #Determine strand by comparison back to the reference genome...
  if ($verbose){print BLUE, "\n\nAttempting to determine splice site and strand for each junction", RESET;}

  open (REF, "$reference_fasta_file") || die "\n\nCould not open fasta file: $reference_fasta_file";
  my $tmp = $/;
  $/ = "\n>";  # read by FASTA record

  while (<REF>){
    chomp $_;
    my $chr_seq = $_;
    my ($chr) = $chr_seq =~ /^>*(\S+)/;  # p  arse ID as first word in FASTA header
    $chr = "chr".$chr;
    $chr_seq =~ s/^>*.+\n//;  # remove FASTA header
    $chr_seq =~ s/\n//g;  # remove endlines

    my $chr_length = length($_);
    if ($verbose){print BLUE, "\n\tFound $chr sequence (length = $chr_length)", RESET;}

    #Now go through the junctions found for this chromosome and look for donor/acceptor splice sites at the coordinates reported
    #SPLICE_SITES = ["GT-AG", "CT-AC", "GC-AG", "CT-GC", "AT-AC", "GT-AT"]

    foreach my $j (sort keys %junctions){
      if ($j =~ /(.*)\:(\d+)\-(\d+)/){
        my $j_chr = $1;
        my $left = $2;
        my $right = $3;
        unless($chr eq $j_chr){
          next();
        }
        my $intron_size = ($right - $left)+1;
        $junctions{$j}{intron_size} = $intron_size;
        my $left_dn = uc(substr($chr_seq, $left, 2));
        my $right_dn = uc(substr($chr_seq, $right-3, 2));

        #print "\n\t\tDEBUG: $left_dn ... $right_dn";
        #Strand is assigned by Tophat...
        if ($left_dn eq "GT" && $right_dn eq "AG"){
          #$junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "GT-AG";
        }elsif($left_dn eq "CT" && $right_dn eq "AC"){
          #$junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "GT-AG";
        }elsif($left_dn eq "GC" && $right_dn eq "AG"){
          #$junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "GC-AG";
        }elsif($left_dn eq "CT" && $right_dn eq "GC"){
          #$junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "GC-AG";
        }elsif($left_dn eq "AT" && $right_dn eq "AC"){
          #$junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "AT-AC";     
        }elsif($left_dn eq "GT" && $right_dn eq "AT"){
          #$junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "AT-AC";
        }else{
          #$junctions{$j}{strand} = ".";
          $junctions{$j}{splice_site} = "NA";
        }
      }else{
        print RED, "\n\nObserved junction not understood\n\n", RESET;
        exit();
      }
      #print YELLOW, "\n\t$junctions{$j}{strand}\t$junctions{$j}{splice_site}", RESET;
    }
  }
  close(REF);
  $/ = $tmp;

  #Print out the strand inferred junctions to a new file
  open (OUT, ">$outfile") || die "\n\nCould not open output file: $outfile\n\n";
  print OUT "$header_line\tintron_size\tsplice_site\n";
  foreach my $j (sort {$junctions{$a}{order} <=> $junctions{$b}{order}} keys %junctions){
    print OUT "$j\t$junctions{$j}{read_count}\t$junctions{$j}{intron_size}\t$junctions{$j}{splice_site}\n";

  }
  close(OUT);

  return();
}



