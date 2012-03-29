#!/usr/bin/perl
#Written by Malachi Griffith
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

#The following three input should retrieve the same list of models/builds
my @build_ids = qw (120828540 120828557 120828600 120828640 120828672 120876429);
my @model_ids = qw (2881869913 2881869886 2881869890 2881871047 2881869908 2881869910);
my $model_group_id = "25134";


#Test each input approach
my $models_builds;
print BLUE, "\n\nSearch by build ID list", RESET;
$models_builds = &getModelsBuilds('-builds'=>\@build_ids, '-partial'=>1);
print BLUE, "\n\nSearch by model ID list - get last complete build of each", RESET;
$models_builds = &getModelsBuilds('-models'=>\@model_ids, '-partial'=>1);
print BLUE, "\n\nSearch by model-group ID - get last complete build of each", RESET;
$models_builds = &getModelsBuilds('-model_group_id'=>$model_group_id, '-partial'=>1);

print "\n\n";

print Dumper $models_builds;

print "\n\n";

exit();



