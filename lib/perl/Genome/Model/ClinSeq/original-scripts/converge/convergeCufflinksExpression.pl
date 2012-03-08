#!/usr/bin/perl
#Written by Malachi Griffith
#For a group of ClinSeq models, converge various types of Cufflinks expression values together
#For example, allow for merging at the level of isoforms and genes
#Make it as generic as possible
#Deal with SampleType.  i.e. get both 'tumor' and 'normal' files if available

#Input:
#A list of Clinseq builds, models, or a Clinseq model-group

#Parameters:
#1.) the name of the file to be joined. e.g. 'isoforms.merged.fpkm.expsort.tsv'
#2.) the join column name (unique ID).  e.g. 'tracking_id'
#3.) the data column name containing the data to be used for the matrix.  e.g. 'FPKM'
#4.) a list of annotation column names.  Values from these will be taken from the first file only and appended to the end of the resulting matrix file

#Sanity checks:
#Make sure each file found has the neccessary columns specified by the user
#Make sure each file found has the same number of IDs, only unique IDs, and all the same IDs as every other file
#Make sure all values are defined.  If there are empty cells allow an option for these to be converted to NAs

#Output:
#A single expression matrix file
#In the output expression file, name the expression columns according to: CommonName_SampleType_BuildID
#Sort by primary ID

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;
use Genome;

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
use converge::Converge qw(:all);

my $build_ids = '';
my $model_ids = '';
my $model_group_id = '';
my $target_file_name = '';
my $join_column_name = '';
my $data_column_name = '';
my $annotation_column_names = '';
my $outfile = '';
my $verbose = 0;

GetOptions ('build_ids=s'=>\$build_ids, 'model_ids=s'=>\$model_ids, 'model_group_id=s'=>\$model_group_id, 
            'target_file_name=s'=>\$target_file_name, 'join_column_name=s'=>\$join_column_name, 'data_column_name=s'=>\$data_column_name, 'annotation_column_names=s'=>\$annotation_column_names,
            'outfile=s'=>\$outfile, 'verbose=i'=>\$verbose);

my $usage=<<INFO;
  Example usage: 
  
  convergeCufflinksExpression.pl  --model_group_id='25134'  --target_file_name='isoforms.merged.fpkm.expsort.tsv'  --join_column_name='tracking_id'  --data_column_name='FPKM'  --annotation_column_names='mapped_gene_name,CancerGeneCensus'  --outfile=Cufflinks_GeneLevel_Malat1Mutants.tsv  --verbose=1

  Specify *one* of the following as input (each model/build should be a ClinSeq model)
  --build_ids            Comma separated list of specific build IDs
  --model_ids            Comma separated list of specific model IDs
  --model_group_id       A singe genome model group ID

  Combines Cufflinks expression results from a group of Clinseq models into a single report:
  --target_file_name         The files to be joined across multiple ClinSeq models
  --join_column_name         The primary ID to be used for joining values (IDs must be unique and occur in all files to be joined)
  --data_column_name         The data column to be used to create an expression matrix across the samples of the ClinSeq models
  --annotation_column_names  Optional list of annotation columns to append to the end of each line in the matrix (value will be taken from the first file parsed)
  --outfile                  Path of the output file to be written
  --verbose                  More descriptive stdout messages

INFO

unless (($build_ids || $model_ids || $model_group_id) && $target_file_name && $data_column_name && $annotation_column_names && $outfile){
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
  exit(1);
}







exit();




