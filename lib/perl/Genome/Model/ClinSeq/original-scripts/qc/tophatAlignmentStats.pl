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
my $reference_junctions_file = '';
my $working_dir = '';
my $verbose = 0;
my $clean = 0;

GetOptions ('reference_fasta_file=s'=>\$reference_fasta_file, 'tophat_alignment_dir=s'=>\$tophat_alignment_dir, 'reference_junctions_file=s'=>\$reference_junctions_file, 
 	    'working_dir=s'=>\$working_dir, 'verbose=i'=>\$verbose, 'clean=i'=>\$clean);


my $usage=<<INFO;

  Example usage: 
  
  tophatAlignmentStats.pl  --reference_fasta_file='/gscmnt/sata420/info/model_data/2857786885/build102671028/all_sequences.fa'  --tophat_alignment_dir='/gscmnt/gc2014/info/model_data/2880794541/build115909743/alignments/'  --reference_junctions_file='/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ALL.Genes.junc'  --working_dir='/gscmnt/sata132/techd/mgriffit/hgs/hg1/qc/tophat/'
  
  Intro:
  This script summarizes results from a tophat alignment directory and writes resulting stats and figures to a working directory

  Details:
  --reference_fasta_file          Reference fasta file that was used for Tophat mapping
  --tophat_alignment_dir          The 'alignment' dir created by a Tophat run
  --reference_junctions_file      The reference junctions to be compared against
                                  For example: /gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ALL.Genes.junc                                
  --working_dir                   Directory where results will be stored
  --verbose                       To display more output, set to 1
  --clean                         To clobber the top dir and create everything from scratch, set to 1

INFO

unless ($reference_fasta_file && $tophat_alignment_dir && $reference_junctions_file && $working_dir){
  print GREEN, "$usage", RESET;
  exit(1);
}

#Check input directories and files
$tophat_alignment_dir = &checkDir('-dir'=>$tophat_alignment_dir, '-clear'=>"no");
$working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"no");

unless (-e $reference_junctions_file){
  print RED, "\n\nCould not find reference junctions file: $reference_junctions_file\n\n", RESET;
  exit(1);
}

my $tophat_junctions_bed_file = $tophat_alignment_dir . "junctions.bed";
my $new_tophat_junctions_bed_file = $working_dir . "junctions.bed";
my $tophat_junctions_junc_file = $working_dir . "junctions.junc";
my $tophat_junctions_anno_file = $working_dir . "junctions.strand.junc";

#Make a copy of the junctions file
my $cp_cmd = "cp $tophat_junctions_bed_file $new_tophat_junctions_bed_file";
if ($verbose){
  print YELLOW, "\n\n$cp_cmd", RESET;
}
system($cp_cmd);


#Convert junctions.bed to a .junc file
my $bed_to_junc_cmd = "cat $new_tophat_junctions_bed_file | "."$script_dir"."misc/bed2junc.pl > $tophat_junctions_junc_file";
if ($verbose){
  print YELLOW, "\n\n$bed_to_junc_cmd", RESET;
}
system($bed_to_junc_cmd);


#Go through the .junc file and infer the strand of each observed junction
&inferStrand('-infile'=>$tophat_junctions_junc_file, '-outfile'=>$tophat_junctions_anno_file, '-reference_fasta_file'=>$reference_fasta_file);




if ($verbose){print "\n\n"};

exit();



############################################################################################################################
#Infer strand from alignment to reference genome                                                                           #
############################################################################################################################
sub inferStrand{
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
  print BLUE, "\n\nAttempting to determine correct strand for each junction", RESET;
  open (REF, "$reference_fasta_file") || die "\n\nCould not open fasta file: $reference_fasta_file";
  my $tmp = $/;
  $/ = "\n>";  # read by FASTA record

  while (<REF>){
    chomp $_;
    my $chr_seq = $_;
    my ($chr) = $chr_seq =~ /^>*(\S+)/;  # parse ID as first word in FASTA header
    $chr_seq =~ s/^>*.+\n//;  # remove FASTA header
    $chr_seq =~ s/\n//g;  # remove endlines

    my $chr_length = length($_);
    print BLUE, "\n\tFound $chr sequence (length = $chr_length)", RESET;

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
        #Assign strand...
        if ($left_dn eq "GT" && $right_dn eq "AG"){
          $junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "GT-AG";
        }elsif($left_dn eq "CT" && $right_dn eq "AC"){
          $junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "GT-AG";
        }elsif($left_dn eq "GC" && $right_dn eq "AG"){
          $junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "GC-AG";
        }elsif($left_dn eq "CT" && $right_dn eq "GC"){
          $junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "GC-AG";
        }elsif($left_dn eq "AT" && $right_dn eq "AC"){
          $junctions{$j}{strand} = "+";
          $junctions{$j}{splice_site} = "AT-AC";     
        }elsif($left_dn eq "GT" && $right_dn eq "AT"){
          $junctions{$j}{strand} = "-";
          $junctions{$j}{splice_site} = "AT-AC";
        }else{
          $junctions{$j}{strand} = ".";
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
    my $jid = $j."($junctions{$j}{strand})";
    print OUT "$jid\t$junctions{$j}{read_count}\t$junctions{$j}{splice_site}\n";

  }
  close(OUT);

  return();
}



