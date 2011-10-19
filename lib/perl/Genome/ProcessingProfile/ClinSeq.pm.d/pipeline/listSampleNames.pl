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
my $common_names = '';

GetOptions ('common_names=s'=>\$common_names);

my $usage=<<INFO;
  Example usage: 
  
  listExomeDatasets.pl  --common_names='BRC18,BRC36,BRC38'

INFO

if ($common_names){
  print GREEN, "\n\nAttempting to find exome (and other capture) datasets for: $common_names\n\n", RESET;
}else{
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
}


#my @common_names = qw/BRC18 BRC36 BRC38/;
my @common_names = split(",", $common_names);

for my $common_name (@common_names) {

  #Get an 'individual object using the patient common name
  print BLUE, "\n\n$common_name", RESET;
  my $individual = Genome::Individual->get(
    common_name => $common_name,
  );
  #Get sample objects associated with the individual object
  my @samples = $individual->samples;
  my $scount = scalar(@samples);
  print BLUE, "\n\tFound $scount samples", RESET;
  
  #Get additional info for each sample 
  for my $sample (@samples) {
    #Display basic sample info
    my $sample_name = $sample->name;
    my $extraction_type = $sample->extraction_type;
    my $sample_common_name = $sample->common_name || "UNDEF";
    my $tissue_desc = $sample->tissue_desc;
    my $cell_type = $sample->cell_type;
    #print BLUE, "\n\t\tSAMPLE\t". $common_name ."\t". $sample->name ."\t". $sample->extraction_type ."\t". $sample->common_name ."\t". $sample->tissue_desc ."\t". $sample->cell_type, RESET;
    print MAGENTA, "\n\t\tSAMPLE\tCN: $common_name\tSN: $sample_name\tET: $extraction_type\tSCN: $sample_common_name\tTD: $tissue_desc\tCT: $cell_type", RESET;

  }
}

print "\n\n";

exit();
