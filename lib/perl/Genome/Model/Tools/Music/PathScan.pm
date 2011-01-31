package Genome::Model::Tools::Music::PathScan;

use warnings;
use strict;
use Genome::Model::Tools::Music::PathScan::PopulationPathScan;
use IO::File;

=head1 NAME

Genome::Music::PathScan - identification of significantly mutated genes

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

class Genome::Model::Tools::Music::PathScan {
  is => 'Command',
  has => [ # specify the command's single-value properties (parameters) <---
    maf_file => { is => 'Text', doc => "List of mutations in Mutation Annotation Format (MAF) format" },  
    coverage_file => { is => 'Text', doc => "Tab-delimited matrix of gene coverages per sample" },
    pathway_file => { is => 'Text', doc => "Tab-delimited file of pathways, their member genes, and any additional info" },
    bmr => { is => 'Number', doc => "Background Mutation rate in the targeted regions", is_optional => 1, default => 3.0E-6,  },
  ],
};

sub sub_command_sort_position { 12 }

sub help_brief { # keep this to just a few words <---
  "Perform pathway analysis on a list of mutations"
}

sub help_synopsis {
  return <<EOS
gmt music pathscan --maf-file=? --coverage_file=? --pathway_file=? [--bmr=?]
Default BMR is 3.0E-6
EOS
}

sub help_detail { #this is what the user will see with the longer version of help. <---
  return <<EOS
EOS
}

=head1 SYNOPSIS

Identifies significantly mutated genes


=head1 USAGE

      music.pl pathway OPTIONS

      OPTIONS:

      --maf-file    List of mutations in MAF format
      --reference    Path to reference FASTA file
      --output-file    Output file to contain results


=head1 FUNCTIONS

=cut

################################################################################

=head2  execute

Initializes a new analysis

=cut

################################################################################

sub execute
{
  my $self = shift;
  my @cov_files = reverse( split( /,/, $self->coverage_file ));
  my $maf_file = $self->maf_file;
  my $pathway_file = $self->pathway_file;
  my $backgrd_mut = $self->bmr;

  #sample => array of genes (based on maf)
  my %sample_gene_hash;

  #gene => array of pathways (based on path_file)
  my %gene_path_hash;

  #$path{$pathway} => all the information about the pathways in the database
  my %path_hash;

  #sample => pathways (based on %sample_gene_hash and %gene_path_hash)
  my %sample_path_hash;

  #path => sample => hits
  #               => mutated_genes
  my %path_sample_hits_hash;

  #all samples, no matter if it's mutated or not
  my %total_sample_hash;

  # gene => sample => coverage (based on 3 center's coverage files)
  my %gene_sample_cov_hash;

  #::TODO:: Generate the coverage data straight from the coverage bitmasks
  read_CoverageFile( $_, \%total_sample_hash, \%gene_sample_cov_hash ) foreach( @cov_files );

  #build gene => average_coverage hash for population test
  my %gene_cov_hash;
  foreach my $gene ( sort keys %gene_sample_cov_hash )
  {
    my $total_cov = 0;
    my @samples = sort keys %{$gene_sample_cov_hash{$gene}};
    my $sample_num = scalar( @samples );
    $total_cov += $gene_sample_cov_hash{$gene}{$_} foreach( @samples );
    $gene_cov_hash{$gene} = int( $total_cov / $sample_num );
  }

  #build %sample_gene_hash based on maf
  my $maf_fh = IO::File->new( $maf_file );
  while( my $line = $maf_fh->getline )
  {
    chomp( $line );
    next if( $line =~ /^(#|Hugo)/ ); #Skip headers

    my @cols = split( /\t/, $line );
    #my ( $gene, $entrez_id, $var_class, $var_type, $sample_t ) = ( $cols[0], $cols[1], $cols[8], $cols[9], $cols[15] );
    my ( $gene, $entrez_id, $var_class, $var_type, $sample_t ) = ( $cols[0], $cols[1], $cols[5], $cols[6], $cols[12] ); #TSP Maf is apparently different
    next if( $var_class =~ /silent/i );
    #next if( $var_class =~ /Silent|RNA|3'Flank|3'UTR|5'Flank|5'UTR|Intron/i );
    #next if( $line =~ /^TP53\t/ ); #Skip TP53 if necessary because it tends to mask the significance of other genes
    $sample_t =~ s/\-\d\d\w\-\d\dW$//; #Modify this depending on the sample format being used
    push( @{$sample_gene_hash{$sample_t}}, $gene ) unless( grep /^$gene$/, @{$sample_gene_hash{$sample_t}} );
  }
  $maf_fh->close;

  my $path_fh = IO::File->new( $pathway_file );
  while( my $line = $path_fh->getline )
  {
    chomp( $line );
    next if( $line =~ /^(#|ID)/ ); #Skip headers

    my ( $path_id, $name, $class, $gene_line, $diseases, $drugs, $description ) = split( /\t/, $line );
    my @genes = split( /\|/, $gene_line ); #Each gene is in the format "EntrezID:GeneSymbol"
    $diseases =~ s/\|/, /g; #Change the separators to commas
    $drugs =~ s/\|/, /g; #Change the separators to commas
    $path_hash{$path_id}{name} = $name unless( $name eq '' );
    $path_hash{$path_id}{class} = $class unless( $class eq '' );
    $path_hash{$path_id}{diseases} = $diseases unless( $diseases eq '' );
    $path_hash{$path_id}{drugs} = $drugs unless( $drugs eq '' );
    $path_hash{$path_id}{description} = $description unless( $description eq '' );
    @{$path_hash{$path_id}{gene}} = ();
    @{$path_hash{$path_id}{entrez}} = ();

    foreach my $gene ( @genes )
    {
      my ( $entrez_id, $gene_symbol ) = split( /:/, $gene );
      push( @{$gene_path_hash{$gene_symbol}}, $path_id ) unless( grep /^$path_id$/, @{$gene_path_hash{$gene_symbol}} );
      unless( grep /^$gene_symbol$/, @{$path_hash{$path_id}{gene}} )
      {
        push( @{$path_hash{$path_id}{gene}}, $gene_symbol );
        push( @{$path_hash{$path_id}{entrez}}, $entrez_id );
      }
    }
  }
  $path_fh->close;

  #::TODO:: Check if some MAF genes mismatched by name to those in the DB

  #build a sample => pathway hash
  foreach my $sample ( sort keys %sample_gene_hash )
  {
    foreach my $gene ( @{$sample_gene_hash{$sample}} )
    {
      if( defined $gene_path_hash{$gene} )
      {
        foreach my $pathway ( @{$gene_path_hash{$gene}} )
        {
          push( @{$sample_path_hash{$sample}}, $pathway ) unless( grep /^$pathway$/, @{$sample_path_hash{$sample}} );
        }
      }
    }
  }

  #build path_sample_hits_hash, for population test
  foreach my $sample ( sort keys %sample_path_hash )
  {
    foreach my $path ( @{$sample_path_hash{$sample}} )
    {
      my $hits = 0;
      my @mutated_genes = (); #Mutated genes in this sample belonging to this pathway
      my @mutated_genes_in_sample = @{$sample_gene_hash{$sample}};
      foreach my $gene ( @{$path_hash{$path}{gene}} )
      {
        if( grep /^$gene$/, @mutated_genes_in_sample ) #if this gene is mutated in this sample (in maf)
        {
          $hits++;
          push( @mutated_genes, $gene );
        }
      }
      if( $hits > 0 )
      {
        $path_sample_hits_hash{$path}{$sample}{hits} = $hits;
        $path_sample_hits_hash{$path}{$sample}{mutated_genes} = \@mutated_genes;
      }
    }
  }

  my $out_fh = IO::File->new( "tsp_significant_pathways.txt", ">" );
  #Calculation of p value
  my %data; #For printing
  foreach my $path ( sort keys %path_hash )
  {
    my @pathway_genes = @{$path_hash{$path}{gene}};
    my @gene_sizes = ();
    foreach my $gene ( @pathway_genes )
    {
      if( defined $gene_cov_hash{$gene} )
      {
        my $avg_cov = int( $gene_cov_hash{$gene} );
        push( @gene_sizes, $avg_cov ) if( $avg_cov > 3 );
      }
    }

    #If this pathway doesn't have any gene coverage, skip it
    next unless( scalar( @gene_sizes ) > 0 );

    my @num_hits_per_sample; #store hits info for each patient
    my @mutated_samples = sort keys %{$path_sample_hits_hash{$path}};

    foreach my $sample ( sort keys %total_sample_hash )
    {
      my $hits = 0;
      #if this sample has mutation
      if( grep /^$sample$/, @mutated_samples )
      {
        $hits = $path_sample_hits_hash{$path}{$sample}{hits};
      }
      push( @num_hits_per_sample, $hits );
    }

    #If this pathway doesn't have any mutated genes in any samples, skip it
    next unless( scalar( @num_hits_per_sample ) > 0 );

    my $hits_ref = \@num_hits_per_sample;

    ########### MCW ADDED
    # FIND MAX NUMBER OF HITS IN A SAMPLE
    my $max_hits = 0;
    foreach my $hits_in_sample ( @num_hits_per_sample )
    {
      $max_hits = $hits_in_sample if( $hits_in_sample > $max_hits );
    }
    ########### MCW ADDED

    my $pop_obj = Genome::Model::Tools::Music::PathScan::PopulationPathScan->new( \@gene_sizes );
    if( scalar( @gene_sizes ) >= 3 )
    {
      ########### MCW ADDED
      if( $max_hits > 15 )
      {
        $pop_obj->assign( 5 );
      }
      else
      {
        $pop_obj->assign( 3 );
      }
      ########### MCW ADDED
      #$pop_obj->assign(3);
    }
    elsif( @gene_sizes == 2 )
    {
      $pop_obj->assign( 2 );
    }
    else
    {
      $pop_obj->assign( 1 );
    }

    $pop_obj->preprocess( $backgrd_mut, $hits_ref );  #mwendl's new fix

    my $pval = $pop_obj->population_pval_approx($hits_ref);
    $data{$pval}{$path}{samples} = \@mutated_samples;
    $data{$pval}{$path}{hits} = $hits_ref;
  }

  #printing
  foreach my $pval ( sort { $a <=> $b } keys %data )
  {
    foreach my $path ( sort keys %{$data{$pval}} )
    {
      $out_fh->print( "Pathway: $path\n" );
      $out_fh->print( "Name: ", $path_hash{$path}{name}, "\n" ) if( defined $path_hash{$path}{name} );
      $out_fh->print( "Class: ", $path_hash{$path}{class}, "\n" ) if( defined $path_hash{$path}{class} );
      $out_fh->print( "Diseases: ", $path_hash{$path}{diseases}, "\n" ) if( defined $path_hash{$path}{diseases} );
      $out_fh->print( "Drugs: ", $path_hash{$path}{drugs}, "\n" ) if( defined $path_hash{$path}{drugs} );
      $out_fh->print( "P-value: $pval\nDescription: ", $path_hash{$path}{description}, "\n" );

      my @samples = @{$data{$pval}{$path}{samples}};
      my @hits = @{$data{$pval}{$path}{hits}};
      foreach my $sample ( @samples )
      {
        my @mutated_genes = @{$path_sample_hits_hash{$path}{$sample}{mutated_genes}};
        $out_fh->print( "$sample:" );
        $out_fh->print( join ",", @mutated_genes );
        $out_fh->print( "\n" );
      }
      $out_fh->print( "Samples with mutations (#hits): " );
      my @all_samples = sort keys %total_sample_hash;
      for( my $i = 0; $i < scalar( @all_samples ); ++$i )
      {
        $out_fh->print( "$all_samples[$i]($hits[$i]) " ) if( $hits[$i] > 0 );
      }
      $out_fh->print( "\n\n" );
    }
  }
  $out_fh->close;
  return(0);
}

################################################################################

=head2  read_CoverageFile

Reads a coverage file formatted as a tab-separated matrix of gene-coverages
perl sample. A row represent a gene, and a column represents a sample

=cut

################################################################################
sub read_CoverageFile
{
  my $fh = IO::File->new( $_[0] );
  my ( $total_sample_hash_ref, $gene_sample_cov_hash_ref ) = ( $_[1], $_[2] );
  my @samples;
  my $num_samples;

  while( my $line = $fh->getline )
  {
    chomp( $line );
    my @cols = split( /\t/, $line );
    if( $cols[0] =~ m/^Gene$/ ) #Header contains all sample IDs
    {
      @samples = splice( @cols, 2 );
      $total_sample_hash_ref->{$_} = 1 foreach( @samples );
      $num_samples = scalar( @samples );
    }
    else
    {
      my $gene = shift( @cols );
      my $expected_cov = shift( @cols );
      my @coverages = @cols;
      my $num_cov = @coverages;
      if( $num_cov != $num_samples )
      {
        print STDERR "Warning: A line in a coverage file has an incorrect number of columns\n";
        next;
      }
      for( my $i = 0; $i <= $num_cov - 1; $i++ )
      {
        $gene_sample_cov_hash_ref->{$gene}{$samples[$i]} = $expected_cov * $coverages[$i] / 100;
      }
    }
  }
  $fh->close;
}

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Genome::Music::PathScan

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license.

=cut

1; # End of Genome::Music::PathScan
