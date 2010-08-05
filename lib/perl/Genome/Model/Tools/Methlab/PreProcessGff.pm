package Genome::Model::Tools::Methlab::PreProcessGff;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Methlab::PreProcessGff
{
  is => 'Command',
  has => [
  gff_directory => {
    is  => 'String',
    is_input  => 1,
    is_optional => 0,
    doc => 'Directory containing GFF files with log ratios from methylation arrays',
  },
  min_difference => {
    is  => 'Integer',
    is_input  => 1,
    is_optional => 1,
    default => 1,
    doc => 'The minimum difference between means of mutated logRs and WT logRs for a probe',
  },
  min_logratio => {
    is  => 'Integer',
    is_input  => 1,
    is_optional => 1,
    default => 1,
    doc => 'A probe must have logRs of at least this much for all its muts or all its WTs',
  },
  flanking_probes => {
    is  => 'Integer',
    is_input  => 1,
    is_optional => 1,
    default => 1,
    doc => 'Num of flanking probes to t-test together (A flank of 1 means 3 probes are tested)',
  },
]
};

sub help_brief
{
  return 'Load log ratios from gff files and find the differentially methylated probes';
}

sub help_synopsis
{
  return 'gmt methlab pre-process ...';
}

sub help_detail
{
  return <<"EOS"
This script assumes that you're giving it GFF files generated from Nimblegen's methylation array.
The first three lines of these tab delimited files usually looks something like:

  ##gff-version\t3
  # biweight_mean=-1.4964337109202206
  chr10\tNimbleScan\tdata_532:BLOCK1\t15724\t15773\t0.10\t.\t.\t.

where 0.10 is the log ratio of the first probe listed in this file. This script extracts the
ratios from all the GFF files in the given gff_directory and stores them together at ./logratios/
indexed by their genomic loci. Then they are filtered using the min_difference and min_logratio
cutoffs, and then a sliding window t-test that tests consecutive probes for differential
methylation. The p-value of a probe is determined by testing its log ratios from various samples,
and also the log ratios from probes on either side of it. This is based on the observation that
hypermethylation events of interest to us usually occur as hill shaped peaks.
EOS
}

sub execute
{
  my $self = shift; #This is a reference to the current object
  $DB::single = 1; #This makes the debugger skip all the boring stuff and break here

  return 1;
}

1;
