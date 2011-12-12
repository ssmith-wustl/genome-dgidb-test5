#!/usr/bin/perl
#Written by Jason Walker, modified by Malachi Griffith
#Get a list of patient common names from the user.  
#Use the Genome API to list information about each of these patients relating to exome or other capture data sets
  

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;
use Genome;

#Required
my $model_group = '';

GetOptions ('model_group=s'=>\$model_group);

my $usage=<<INFO;
  Example usage: 
  
  listRNAseqBuildByModelGroup.pl  --model_group='21942'

INFO

if ($model_group){
  print GREEN, "\n\nAttempting to find RNAseq builds for a single model group: $model_group\n\n", RESET;
}else{
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
}


#genome/lib/perl/Genome/ModelGroup.pm

#Get model group object
my $mg = Genome::ModelGroup->get("id"=>$model_group);
print Dumper $mg;

#Get display name of the model group
my $display_name = $mg->__display_name__;
#print Dumper $display_name;

#Get subjects (e.g. samples) associated with each model of the model-group
my @subjects = $mg->subjects;
#print Dumper @subjects;

#Get the members of the model-group, i.e. the models
my @models = $mg->models;
print Dumper @models;

#Cycle through the models and get their builds


print "\n\n";

exit();
