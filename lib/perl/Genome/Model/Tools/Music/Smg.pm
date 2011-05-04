package Genome::Model::Tools::Music::Smg;

use warnings;
use strict;
use Genome;
use Carp;
use POSIX qw( WIFEXITED );

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::Smg {
  is => 'Command::V2',
  has_input => [
    gene_mr_file => { is => 'Text', doc => "File with per-gene mutation rates (Created using B<music bmr calc-bmr>)" },
    output_file => { is => 'Text', doc => "Output file that will list significantly mutated genes and their p-values" },
  ],
  doc => "Identify significantly mutated genes."
};

sub help_synopsis {
  return <<HELP
... music smg --gene-mr-file output_dir/gene_mrs --output-file output_dir/smgs

(Please note that "gene_mrs" is an output of B<music bmr calc-bmr>.)
HELP
}

sub help_detail {
  return <<HELP
This script runs R-based statistical tools to calculate the significance of mutated genes, given
their individual mutation rates categorized by mutation type and the overall background mutation
rates for each of those categories.
HELP
}

sub _doc_authors {
    return ('',
        'Qunyuan Zhang, Ph.D.',
        'Cyriac Kandoth, Ph.D.',
        'Nathan D. Dees, Ph.D.',
    );
}

sub execute {
  my $self = shift;
  $DB::single = 1;
  my $gene_mr_file = $self->gene_mr_file;
  my $output_file = $self->output_file;
  my $pval_file = $output_file . "_pvals";

  # Check on all the input data before starting work
  print STDERR "Gene mutation rate file not found or is empty: $gene_mr_file\n" unless( -s $gene_mr_file );
  return undef unless( -s $gene_mr_file );

  # Call R for Fisher combined test, Likelihood ratio test, and convolution test on each gene
  my $smg_cmd = "R --slave --args < " . __FILE__ . ".R $gene_mr_file $pval_file smg_test";
  WIFEXITED( system $smg_cmd ) or croak "Couldn't run: $smg_cmd ($?)";

  # Call R for calculating FDR on the p-values calculated in the SMG test
  my $fdr_cmd = "R --slave --args < " . __FILE__ . ".R $pval_file $output_file calc_fdr";
  WIFEXITED( system $fdr_cmd ) or croak "Couldn't run: $fdr_cmd ($?)";

  return 1;
}

1;
