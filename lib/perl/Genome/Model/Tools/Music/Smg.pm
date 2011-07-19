package Genome::Model::Tools::Music::Smg;

use warnings;
use strict;
use Genome;
use IO::File;
use Carp;
use POSIX qw( WIFEXITED );

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::Smg {
  is => 'Command::V2',
  has_input => [
    gene_mr_file => { is => 'Text', doc => "File with per-gene mutation rates (Created using \"music bmr calc-bmr\")" },
    output_file => { is => 'Text', doc => "Output file that will list significantly mutated genes and their p-values" },
    max_fdr => { is => 'Number', doc => "The maximum allowed false discovery rate for a gene to be considered an SMG", is_optional => 1, default => 0.20 },
  ],
  doc => "Identify significantly mutated genes."
};

sub help_synopsis {
  return <<HELP
 ... music smg \\
        --gene-mr-file output_dir/gene_mrs \\
        --output-file output_dir/smgs

("gene_mrs" can be generated using the tool "music bmr calc-bmr".)
HELP
}

sub help_detail {
  return <<HELP
This script runs R-based statistical tools to identify Significantly Mutated Genes (SMGs), when
given per-gene mutation rates categorized by mutation type, and the overall background mutation
rates for each of those categories (gene_mr_file, created using "music bmr calc-bmr").

P-values and false discovery rates (FDRs) for each gene in gene_mr_file is calculated using three
tests: Fisher's Combined P-value test (FCPT), Likelihood Ratio test (LRT), and the Convolution
test (CT). For a gene, if its FDR for at least 2 of these tests is <= max_fdr, it will be output
as an SMG. Another output file with prefix "_detailed" will have p-values and FDRs for all genes.
HELP
}

sub _doc_authors {
    return <<EOS
 Qunyuan Zhang, Ph.D.
 Cyriac Kandoth, Ph.D.
 Nathan D. Dees, Ph.D.
EOS
}

sub execute {
  my $self = shift;
  $DB::single = 1;
  my $gene_mr_file = $self->gene_mr_file;
  my $output_file = $self->output_file;
  my $output_file_detailed = $output_file . "_detailed";
  my $pval_file = $output_file . "_pvals";
  my $max_fdr = $self->max_fdr;

  # Check on all the input data before starting work
  print STDERR "Gene mutation rate file not found or is empty: $gene_mr_file\n" unless( -s $gene_mr_file );
  return undef unless( -s $gene_mr_file );

  # Call R for Fisher combined test, Likelihood ratio test, and convolution test on each gene
  my $smg_cmd = "R --slave --args < " . __FILE__ . ".R $gene_mr_file $pval_file smg_test";
  WIFEXITED( system $smg_cmd ) or croak "Couldn't run: $smg_cmd ($?)";

  # Call R for calculating FDR on the p-values calculated in the SMG test
  my $fdr_cmd = "R --slave --args < " . __FILE__ . ".R $pval_file $output_file_detailed calc_fdr";
  WIFEXITED( system $fdr_cmd ) or croak "Couldn't run: $fdr_cmd ($?)";

  # Remove the temporary intermediate file containing only pvalues
  unlink( $pval_file );

  # Parse the gene_mrs file to gather SNV and Indel counts for each gene
  my $mrFh = IO::File->new( $gene_mr_file ) or die "Couldn't open $gene_mr_file. $!\n";
  my %mut_cnts = ();
  while( my $line = $mrFh->getline )
  {
    next if( $line =~ m/^#/ );
    my ( $gene, $type, undef, $cnt ) = split( /\t/, $line );
    $mut_cnts{$gene}{indels} += $cnt if( $type =~ m/Indels/ );
    $mut_cnts{$gene}{snvs} += $cnt if( $type =~ m/(Transitions|Transversions)$/ );
  }
  $mrFh->close;

  # Parse the R output to identify the SMGs
  my $smgFh = IO::File->new( $output_file_detailed ) or die "Couldn't open $output_file_detailed. $!\n";
  my @newLines = ();
  my @smgLines = ();
  while( my $line = $smgFh->getline )
  {
    chomp( $line );
    if( $line =~ m/^Gene\tp.fisher\tp.lr\tp.convol\tfdr.fisher\tfdr.lr\tfdr.convol$/ )
    {
      push( @newLines, "#Gene\tSNVs\tIndels\tP-value FCPT\tP-value LRT\tP-value CT\tFDR FCPT\tFDR LRT\tFDR CT\n" );
      push( @smgLines, "#Gene\tSNVs\tIndels\tP-value FCPT\tP-value LRT\tP-value CT\tFDR FCPT\tFDR LRT\tFDR CT\n" );
    }
    else
    {
      my @cols = split( /\t/, $line );
      if( defined $mut_cnts{$cols[0]}{snvs} and defined $mut_cnts{$cols[0]}{indels} )
      {
        push( @newLines, join( "\t", $cols[0], $mut_cnts{$cols[0]}{snvs}, $mut_cnts{$cols[0]}{indels}, @cols[1..6] ) . "\n" );

        # If the FDR of at least two of these tests is less than the maximum allowed, we consider it an SMG
        if(( $cols[4] <= $max_fdr && $cols[5] <= $max_fdr ) || ( $cols[4] <= $max_fdr && $cols[6] <= $max_fdr ) ||
           ( $cols[5] <= $max_fdr && $cols[6] <= $max_fdr ))
        {
          push( @smgLines, join( "\t", $cols[0], $mut_cnts{$cols[0]}{snvs}, $mut_cnts{$cols[0]}{indels}, @cols[1..6] ) . "\n" );
        }
      }
    }
  }
  $smgFh->close;

  # Add per-gene SNV and Indel counts to the detailed R output, and make the header friendlier
  my $outDetFh = IO::File->new( $output_file_detailed, ">" ) or die "Couldn't open $output_file_detailed. $!\n";
  $outDetFh->print( @newLines );
  $outDetFh->close;

  # Do the same for only the genes that we consider SMGs
  my $outFh = IO::File->new( $output_file, ">" ) or die "Couldn't open $output_file. $!\n";
  $outFh->print( @smgLines );
  $outFh->close;

  return 1;
}

1;
