#!/usr/bin/perl
#Written by Malachi Griffith


#This script takes an input gene list and annotates it against various lists of gene setting values as 0/1
#e.g. I have a list of 1000 genes, and I want to know which is a kinase, transcription factor, etc.

#Input parameters / options
#Input file (containing gene names)
#Gene name column.  Column number containing gene symbols
#Symbol lists to annotate with (display a list of gene symbol lists to select from and the location being queried)
#Output file

#1.) Take an input file with gene names in it
#2.) Get the gene name column from input
#3.) 'fix' gene names to Entrez official gene symbols
#4.) Load the symbols lists (fixing gene names on each)
#5.) Intersect the gene names in the input list with each symbol list
#6.) Print output file with annotations and new column headers appended

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

my $lib_dir;
my $script_dir;
use Cwd 'abs_path';
BEGIN{
  if (abs_path($0) =~ /(.*\/)(.*\/).*\.pl/){
    $lib_dir = $1;
    $script_dir = $1.$2;
  }
}
use lib $lib_dir;
use ClinSeq qw(:all);

#Required parameters. 
my $infile = '';
my $name_column = '';
my $gene_category_names = '';
my $outfile = '';

GetOptions ('infile=s'=>\$infile, 'name_column=i'=>\$name_column, 'gene_category_names=s'=>\$gene_category_names, 'outfile=s'=>\$outfile);

my $usage=<<INFO;

  Example usage: 
  
  geneToGeneCategories.pl  --infile=Genes.txt  --name_column=1  --gene_category_names='CancerGeneCensus_Sanger,Kinase_GO0016301'  --outfile=GenesAnnotated.txt
  
  Notes:
  This script will take an input TSV file containing a gene name column and will append columns indicating whether each gene belongs to a list of categories
  e.g. Kinases, transcription factors, etc.  These lists are pre-defined as reported below.
  Whether each gene belongs to each category will be indicated with a 1 or 0.
  The order and content of lines in the input file will be maintained (including duplicate gene records)
  The order of the gene categories in your list will also be used

  Inputs:
  --infile               PATH. Any tab delimited file to be annotated containing a gene name column. Assumed to contain a header line.
  --name_column          INT. Number of column containing gene names (Entrez gene symbols ideally - gene name translation will be attempted).
  --gene_category_names  STRING.  Comma separated list of gene categories to be used for annotation.
  --outfile              PATH.  New file with annotation columns appended.

INFO

#Location of gene category files (any .txt file in this directory)
my $gene_symbol_lists_dir = "/gscmnt/sata132/techd/mgriffit/reference_annotations/GeneSymbolLists/";
$gene_symbol_lists_dir = &checkDir('-dir'=>$gene_symbol_lists_dir, '-clear'=>"no");

#List the possible gene symbol categories from this directory and their counts.
my $gene_categories = &listGeneCategories('-category_dir'=>$gene_symbol_lists_dir, '-verbose'=>1);

unless ($infile && $name_column && $gene_category_names && $outfile){
  print GREEN, "$usage", RESET;
  exit();
}

#Check symbol list supplied by user
my @gene_category_names = split(",", $gene_category_names);
my $list_count = scalar(@gene_category_names);
unless($list_count){
  print RED, "\n\nMust supply at least one category name (or multiple names as a comma separated list)\n\n", RESET;
  exit();
}

#Make sure all category names are valid
foreach my $cat (@gene_category_names){
  unless(defined($gene_categories->{$cat})){
    print RED, "\n\nGene category name: $cat does not appear to be valid, check list\n\n", RESET;
    exit();
  }
}

#Get Entrez and Ensembl data for gene name mappings
my $entrez_ensembl_data = &loadEntrezEnsemblData();

#Import gene names from input file:
my %lines;
open (IN, "$infile") || die "\n\nCould not open input file: $infile\n\n";
my $header = 1;
my $header_line = "";
my $l = 0;
while(<IN>){
  chomp($_);
  my @line = split("\t", $_);
  if ($header){
    $header = 0;
    $header_line = $_;
    next();
  }
  $l++;
  my $gene_name = $line[$name_column-1];
  $lines{$l}{record} = $_;
  $lines{$l}{gene_name} = $gene_name;

  #Fix gene names
  my $mapped_gene_name = &fixGeneName('-gene'=>$gene_name, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);
  $lines{$l}{mapped_gene_name} = $mapped_gene_name;
}
close(IN);

#Import the specified gene symbol lists
my $gene_symbol_lists = &importGeneSymbolLists('-gene_symbol_lists_dir'=>$gene_symbol_lists_dir, '-symbol_list_names'=>\@gene_category_names, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);

#Intersect the gene names in the input list with each symbol list
foreach my $l (keys %lines){
  my $mapped_gene_name = $lines{$l}{mapped_gene_name};
  foreach my $cat (@gene_category_names){
    if ($gene_symbol_lists->{$cat}->{symbols}->{$mapped_gene_name}){
      $lines{$l}{$cat} = 1;
    }else{
      $lines{$l}{$cat} = 0;
    }
  }
}

#Print output file with annotations and new column headers appended
open (OUT, ">$outfile") || die "\n\nCould not open output file for writing: $outfile\n\n";
my $append_header = join("\t", @gene_category_names);
print OUT "$header_line\tMappedGeneName\t$append_header\n";

foreach my $l (sort {$a <=> $b} keys %lines){
  my $mapped_gene_name = $lines{$l}{mapped_gene_name};
  my @append;
  foreach my $cat (@gene_category_names){
    push(@append, $lines{$l}{$cat});
  }
  my $append_string = join("\t", @append);
  print OUT "$lines{$l}{record}\t$mapped_gene_name\t$append_string\n";
}
close (OUT);
print "\n\n";


exit();

