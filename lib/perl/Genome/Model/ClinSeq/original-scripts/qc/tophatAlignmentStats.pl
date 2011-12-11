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

#Input parameters
my $tophat_alignment_dir = '/gscmnt/gc8001/info/model_data/2881616601/build117345038/alignments/';
my $reference_transcript_dir = '';



my $top_junctions_file = $tophat_alignment_dir . "";


exit();



