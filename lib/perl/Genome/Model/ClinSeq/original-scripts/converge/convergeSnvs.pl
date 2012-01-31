#!/usr/bin/perl
#Written by Malachi Griffith
#For a group of ClinSeq models, get SNVs and create a master table that merges all cases together
#Merge at the level of SNV positions and then separately at the level of genes

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;
use Genome;

#Required
my $model_group = '';
my $positions_outfile = '';
my $genes_outfile = '';

GetOptions ('model_group=s'=>\$model_group, 'positions_outfile=s'=>\$positions_outfile, 'genes_outfile=s'=>\$genes_outfile);

my $usage=<<INFO;
  Example usage: 
  
  convergeSnvs.pl  --model_group='25307'  --positions_outfile=BRAF_SNVs_Merged_PositionLevel.tsv  --genes_outfile=BRAF_SNVs_Merged_GeneLevel.tsv

  Combines SNV results from a group of Clinseq models into a single report:
  --model_group          Specifies a genome model group ID
  --positions_outfile    Results merged to the level of unique SNV positions will be written here
  --genes_outfile        Results merged to the level of unique Genes will be written here

INFO

unless ($model_group && $positions_outfile && $genes_outfile){
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
  exit(1);
}


#genome/lib/perl/Genome/ModelGroup.pm

#Get model group object
my $mg = Genome::ModelGroup->get("id"=>$model_group);

#Get display name of the model group
my $display_name = $mg->__display_name__;

#Get subjects (e.g. samples) associated with each model of the model-group
my @subjects = $mg->subjects;

#Get the members of the model-group, i.e. the models
my @models = $mg->models;

my %snvs;
my %genes;

#Cycle through the models and get their builds
my $header_line;
foreach my $m (@models){
  my $model_name = $m->name;
  my $model_id = $m->genome_model_id;
  my $b = $m->last_succeeded_build || "NONE_FINISHED";
  unless ($b){
    print RED, "\n\nCould not find a succeeded build to use... for $model_name\n\n", RESET;
    next();
  }
  my $data_directory = $b->data_directory;
  my $patient = $m->subject;
  my $wgs_build = $b->wgs_build;
  my $exome_build = $b->exome_build;

  my ($wgs_common_name, $wgs_name, $exome_common_name, $exome_name);
  if ($wgs_build){
    $wgs_common_name = $wgs_build->subject->patient->common_name;
    $wgs_name = $wgs_build->subject->patient->name;
  }
  if ($exome_build){
    $exome_common_name = $exome_build->subject->patient->common_name;
    $exome_name = $exome_build->subject->patient->name;
  }

  #Get the patient common name from one of the builds, if none can be found, use the individual name instead, if that can't be found either set the name to 'UnknownName'
  my @names = ($wgs_common_name, $exome_common_name, $wgs_name, $exome_name);
  my $final_name = "UnknownName";
  foreach my $name (@names){
    if ($name){
      $final_name = $name;
      last();
    }
  }

  #Find the appropriate SNV file
  my $clinseq_snv_dir = $data_directory . "/" . $final_name . "/snv/";
  if ($wgs_build && $exome_build){
    $clinseq_snv_dir .= "wgs_exome/";
  }elsif($wgs_build){
    $clinseq_snv_dir .= "wgs/";
  }elsif($exome_build){
    $clinseq_snv_dir .= "exome/";
  }
  print BLUE, "\n$final_name\t$model_id\t$model_name\t$clinseq_snv_dir", RESET;

  my $snv_file = $clinseq_snv_dir . "snvs.hq.tier1.v1.annotated.compact.tsv";
  unless (-e $snv_file){
    print RED, "\n\nCould not find SNV file: $snv_file\n\n", RESET;
    exit(1);
  }

  #Parse the SNV file
  my $header = 1;
  my %columns;
  open (SNV, "$snv_file") || die "\n\nCould not open SNV file: $snv_file\n\n";
  while(<SNV>){
    chomp($_);
    my $line = $_;
    my @line = split("\t", $line);
    if ($header == 1){
      $header_line = $line;
      $header = 0;
      my $p = 0;
      foreach my $head (@line){
        $columns{$head}{pos} = $p;
        $p++;
      }
      next();
    }

    my $coord = $line[$columns{'coord'}{pos}];
    my $gene_name = $line[$columns{'gene_name'}{pos}];
    my $mapped_gene_name = $line[$columns{'mapped_gene_name'}{pos}];
    my $aa_changes = $line[$columns{'aa_changes'}{pos}];
    my $ref_base = $line[$columns{'ref_base'}{pos}];
    my $var_base = $line[$columns{'var_base'}{pos}];

    #Merge to the level of distinct positions...
    if ($snvs{$coord}){
      $snvs{$coord}{recurrence}++;
      my $cases_ref = $snvs{$coord}{cases};
      $cases_ref->{$final_name}=1;
    }else{
      $snvs{$coord}{gene_name} = $gene_name;
      $snvs{$coord}{mapped_gene_name} = $mapped_gene_name;
      $snvs{$coord}{recurrence} = 1;
      $snvs{$coord}{line} = $line;
      my %cases;
      $cases{$final_name}=1;
      $snvs{$coord}{cases} = \%cases;
    }

    #Merge to the level of distinct gene names
    if ($genes{$gene_name}){
      $genes{$gene_name}{total_mutation_count}++;
      my $positions_ref = $genes{$gene_name}{positions};
      $positions_ref->{$coord}=1;
      my $cases_ref = $genes{$gene_name}{cases};
      $cases_ref->{$final_name}=1;
    }else{
      $genes{$gene_name}{mapped_gene_name} = $mapped_gene_name;
      $genes{$gene_name}{total_mutation_count} = 1;
      my %positions;
      $positions{$coord} = 1;
      $genes{$gene_name}{positions} = \%positions;
      my %cases;
      $cases{$final_name} = 1;
      $genes{$gene_name}{cases} = \%cases;
    }
  }
  close(SNV);
}

#Print the position level recurrence summary
open (OUT, ">$positions_outfile") || die "\n\nCould not open output file for writing: $positions_outfile\n\n";
print OUT "coord\trecurrence_count\tmutated_samples\t$header_line\n";
foreach my $coord (sort keys %snvs){
  my $cases_ref = $snvs{$coord}{cases};
  my @cases = keys %{$cases_ref};
  my @sort_cases = sort @cases;
  my $sort_cases_string = join(",", @sort_cases);
  print OUT "$coord\t$snvs{$coord}{recurrence}\t$sort_cases_string\t$snvs{$coord}{line}\n";
}
close(OUT);

#Print the gene level recurrence summary
open (OUT, ">$genes_outfile") || die "\n\nCould not open output file for writing: $genes_outfile\n\n";
print OUT "gene_name\tmapped_gene_name\ttotal_mutation_count\tmutated_sample_count\tmutated_position_count\tmutated_samples\tmutated_positions\n";
foreach my $gene_name (sort keys %genes){
  my $positions_ref = $genes{$gene_name}{positions};
  my @positions = keys %{$positions_ref};
  my $positions_count = scalar(@positions);
  my @sort_positions = sort @positions;
  my $sort_positions_string = join (",", @sort_positions);
  my $cases_ref = $genes{$gene_name}{cases};
  my @cases = keys %{$cases_ref};
  my @sort_cases = sort @cases;
  my $sort_cases_string = join(",", @sort_cases);
  my $cases_count = scalar(@cases);
  print OUT "$gene_name\t$genes{$gene_name}{mapped_gene_name}\t$genes{$gene_name}{total_mutation_count}\t$cases_count\t$positions_count\t$sort_cases_string\t$sort_positions_string\n";
}
close(OUT);

print BLUE, "\n\nWrote results to: $positions_outfile AND $genes_outfile\n\n", RESET;

exit();



