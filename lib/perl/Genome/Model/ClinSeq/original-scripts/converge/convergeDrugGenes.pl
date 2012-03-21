#!/usr/bin/perl
#Written by Malachi Griffith
#For a group of ClinSeq models, converge various types of Druggable genes results
#Consider the following event types (individually, and then together)

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
my $expression_subdir = '';
my $join_column_name = '';
my $data_column_name = '';
my $annotation_column_names = '';
my $outfile = '';
my $verbose = 0;

GetOptions ('build_ids=s'=>\$build_ids, 'model_ids=s'=>\$model_ids, 'model_group_id=s'=>\$model_group_id,
            'target_file_name=s'=>\$target_file_name, 'expression_subdir=s'=>\$expression_subdir,
            'join_column_name=s'=>\$join_column_name, 'data_column_name=s'=>\$data_column_name, 'annotation_column_names=s'=>\$annotation_column_names,
            'outfile=s'=>\$outfile, 'verbose=i'=>\$verbose);

my $usage=<<INFO;
  Example usage: 

  Gene-level using isoforms merged to each gene
  convergeCufflinksExpression.pl  --model_group_id='25134'  --target_file_name='isoforms.merged.fpkm.expsort.tsv'  --expression_subdir='isoforms_merged'  --join_column_name='tracking_id'  --data_column_name='FPKM'  --annotation_column_names='ensg_name,mapped_gene_name,locus'  --outfile=Cufflinks_GeneLevel_Malat1Mutants.tsv  --verbose=1

  Transcript-level using isoforms individually
  convergeCufflinksExpression.pl  --model_group_id='25134'  --target_file_name='isoforms.fpkm.expsort.tsv'  --expression_subdir='isoforms'  --join_column_name='tracking_id'  --data_column_name='FPKM'  --annotation_column_names='gene_id,mapped_gene_name,locus'  --outfile=Cufflinks_IsoformLevel_Malat1Mutants.tsv  --verbose=1

  Specify *one* of the following as input (each model/build should be a ClinSeq model)
  --build_ids                Comma separated list of specific build IDs
  --model_ids                Comma separated list of specific model IDs
  --model_group_id           A singe genome model group ID

  Combines Cufflinks expression results from a group of Clinseq models into a single report:
  --target_file_name         The files to be joined across multiple ClinSeq models
  --expression_subdir        The expression subdir of Clinseq to use: ('genes', 'isoforms', 'isoforms_merged')
                             The values in these columns are assumed to be constant across the files being merged!
  --outfile                  Path of the output file to be written
  --verbose                  More descriptive stdout messages

  Test Clinseq model groups:
  25307                      BRAF inhibitor resistant cell lines
  25134                      MALAT1 mutant vs. wild type BRCs
  30176                      LUC RNA-seq vs. RNA-cap

INFO

unless (($build_ids || $model_ids || $model_group_id) && $target_file_name && $expression_subdir && $join_column_name && $data_column_name && $outfile){
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
  exit(1);
}

#Get the models/builds
if ($verbose){print BLUE, "\n\nGet genome models/builds for supplied list", RESET;}
my $models_builds;
if ($build_ids){
  my @build_ids = split(",", $build_ids);
  $models_builds = &getModelsBuilds('-builds'=>\@build_ids, '-verbose'=>$verbose);
}elsif($model_ids){
  my @model_ids = split(",", $model_ids);
  $models_builds = &getModelsBuilds('-models'=>\@model_ids, '-verbose'=>$verbose);
}elsif($model_group_id){
  $models_builds = &getModelsBuilds('-model_group_id'=>$model_group_id, '-verbose'=>$verbose);
}else{
  print RED, "\n\nCould not obtains models/builds - check input to convergeCufflinksExpression.pl\n\n", RESET;
  exit();
}






exit();





