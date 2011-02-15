package Genome::Model::Tools::Music::PathScan;

use warnings;
use strict;
use Genome::Model::Tools::Music::PathScan::PopulationPathScan;
use IO::File;
use IO::Dir;

our $VERSION = '1.01';

class Genome::Model::Tools::Music::PathScan {
  is => 'Command',
  has => [
    maf_file => { is => 'Text', doc => "List of mutations in Mutation Annotation Format (MAF) format" },
    gene_covg_dir => { is => 'Text', doc => "Directory containing per-gene coverage files for each sample" },
    sample_list => { is => 'Text', doc => "List of all samples that were analyzed for mutations" },
    pathway_file => { is => 'Text', doc => "Tab-delimited file of pathways, their member genes, and any additional info" },
    output_file => { is => 'Text', doc => "Output file that will list the significant pathways and their p-values" },
    genes_to_ignore => { is => 'Text', doc => "Comma-delimited list of genes in the MAF to be ignored", is_optional => 1 },
    bmr => { is => 'Number', doc => "Background mutation rate in the targeted regions", is_optional => 1, default => 1.7E-6,  },
  ],
};

sub help_brief {
  "Find the various pathways significant to the cancer given a list of somatic mutations";
}

sub help_detail {
  return <<HELP
Only the following four columns in the MAF are used. All other columns may as well be empty.
Col 1: Hugo_Symbol (Need not be HUGO, but must match gene names used in the PathWay file)
Col 2: Entrez_Gene_Id (Matching Entrez ID trump gene name mathches between PathWay file and MAF)
Col 9: Variant_Classification (PathScan ignores Silent|RNA|3'Flank|3'UTR|5'Flank|5'UTR|Intron)
Col 16: Tumor_Sample_Barcode (Must match the name in sample-list, or contain it as a substring)

--sample-list
The first column in this file is expected to match (exactly or as a substring of) the tumor sample
names in the MAF file (16th column, Tumor_Sample_Barcode). Any additional columns like BAM file
locations or clinical data are ignored.

--genes-to-ignore
Any genes in this comma-delimited list will be ignored from the MAF file. This is useful when you
have recurrently mutated genes like TP53 that mask the significance of other genes.
HELP
}

sub execute
{
  my $self = shift;
  $DB::single = 1;
  my $maf_file = $self->maf_file;
  my $covg_dir = $self->gene_covg_dir;
  my $sample_list = $self->sample_list;
  my $pathway_file = $self->pathway_file;
  my $output_file = $self->output_file;
  my $genes_to_ignore = $self->genes_to_ignore;
  my $bgd_mut = $self->bmr;

  # Check on all the input data before starting work
  print STDERR "MAF file not found or is empty: $maf_file\n" unless( -s $maf_file );
  print STDERR "Directory with gene coverages not found: $covg_dir\n" unless( -e $covg_dir );
  print STDERR "List of samples not found or is empty: $sample_list\n" unless( -s $sample_list );
  print STDERR "Pathway info file not found or is empty: $pathway_file\n" unless( -s $pathway_file );
  exit 1 unless( -s $maf_file && -e $covg_dir && -s $sample_list && -s $pathway_file );

  my %sample_gene_hash; # sample => array of genes (based on maf)
  my %gene_path_hash; # gene => array of pathways (based on path_file)
  my %path_hash; # pathway => all the information about the pathways in the database
  my %sample_path_hash; # sample => pathways (based on %sample_gene_hash and %gene_path_hash)
  my %path_sample_hits_hash; # path => sample => hits,mutated_genes
  my %gene_sample_cov_hash; # gene => sample => coverage
  my @all_sample_names; # names of all the samples, no matter if it's mutated or not
  my %id_gene_hash; # entrez id => gene (based on first two columns in MAF)
  my %ignored_genes = ();
  if( defined $genes_to_ignore )
  {
    %ignored_genes = map { $_ => 1 } split( /,/, $genes_to_ignore );
  }

  # Read coverage data calculated by the Music::Bmr::CalcCovg
  $covg_dir =~ s/(\/)+$//; # Remove trailing forward slashes if any
  read_CoverageFiles( $sample_list, $covg_dir, \@all_sample_names, \%gene_sample_cov_hash );

  #build gene => average_coverage hash for population test
  my %gene_cov_hash;
  foreach my $gene ( keys %gene_sample_cov_hash )
  {
    my $total_cov = 0;
    my $sample_num = scalar( @all_sample_names );
    $total_cov += $gene_sample_cov_hash{$gene}{$_} foreach( @all_sample_names );
    $gene_cov_hash{$gene} = int( $total_cov / $sample_num );
  }

  #build %sample_gene_hash based on maf
  my $maf_fh = IO::File->new( $maf_file );
  while( my $line = $maf_fh->getline )
  {
    chomp( $line );
    next if( $line =~ /^(#|Hugo)/ ); #Skip headers

    my @cols = split( /\t/, $line );
    my ( $gene, $entrez_id, $var_class, $tumor_sample ) = ( $cols[0], $cols[1], $cols[8], $cols[15] );
    next if( $var_class =~ /Silent|Intron|RNA|3'Flank|3'UTR|5'Flank|5'UTR|IGR/i ); # Ignore non-somatic variants
    next if( defined $ignored_genes{$gene} ); # Ignore variants in genes that need to be ignored

    #Find the sample name as listed in the sample_list file and push it into the hash
    my $sample = "";
    foreach( @all_sample_names )
    {
      if( $tumor_sample =~ m/$_/ )
      {
        $sample = $_;
        last;
      }
    }
    if( $sample eq "" )
    {
      print STDERR "Sample $tumor_sample in MAF file does not match any provided in sample-list\n";
      exit 1;
    }
    $id_gene_hash{$entrez_id} = $gene unless( $entrez_id eq '' or $entrez_id == 0 );
    push( @{$sample_gene_hash{$sample}}, $gene ) unless( grep /^$gene$/, @{$sample_gene_hash{$sample}} );
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

    foreach my $gene ( @genes )
    {
      my ( $entrez_id, $gene_symbol ) = split( /:/, $gene );
      unless( $entrez_id eq '' or $entrez_id == 0 )
      {
        # Use the gene name from the MAF file if the entrez ID matches
        $gene_symbol = $id_gene_hash{$entrez_id} if( defined $id_gene_hash{$entrez_id} );
      }
      push( @{$gene_path_hash{$gene_symbol}}, $path_id ) unless( grep /^$path_id$/, @{$gene_path_hash{$gene_symbol}} );
      unless( grep /^$gene_symbol$/, @{$path_hash{$path_id}{gene}} )
      {
        push( @{$path_hash{$path_id}{gene}}, $gene_symbol );
      }
    }
  }
  $path_fh->close;

  #build a sample => pathway hash
  foreach my $sample ( keys %sample_gene_hash )
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
  foreach my $sample ( keys %sample_path_hash )
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

  my $out_fh = IO::File->new( $output_file, ">" );
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

    foreach my $sample ( @all_sample_names )
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

    $pop_obj->preprocess( $bgd_mut, $hits_ref );  #mwendl's new fix

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
      for( my $i = 0; $i < scalar( @all_sample_names ); ++$i )
      {
        $out_fh->print( "$all_sample_names[$i]($hits[$i]) " ) if( $hits[$i] > 0 );
      }
      $out_fh->print( "\n\n" );
    }
  }
  $out_fh->close;
  return 1;
}

# Reads files for each sample which are formatted as tab-separated lines each showing the number of
# bases with sufficient coverage in a gene.
sub read_CoverageFiles
{
  my ( $sample_list, $covg_dir ) = ( $_[0], $_[1] );
  my ( $all_samples_ref, $gene_sample_cov_hash_ref ) = ( $_[2], $_[3] );

  # Parse out the names of the samples which should match the names of the coverage files
  my $inFh = IO::File->new( $sample_list );
  @{$all_samples_ref} = map { chomp; s/\t.*$//; $_ } $inFh->getlines;
  $inFh->close;

  # Read per-gene covered base counts for each sample
  foreach my $sample ( @{$all_samples_ref} )
  {
    # If the file doesn't exist, quit with error. The Music::Bmr::CalcCovg step is incomplete
    unless( -s "$covg_dir/$sample.covg" )
    {
      print STDERR "Couldn't find $sample.covg in $covg_dir. Use \"bmr calc-covg\"\n";
      exit 1;
    }

    my $covgFh = IO::File->new( "$covg_dir/$sample.covg" );
    while( my $line = $covgFh->getline )
    {
      next if( $line =~ m/^#/ );
      my ( $gene, undef, $covd_bases ) = split( /\t/, $line );
      $gene_sample_cov_hash_ref->{$gene}{$sample} = $covd_bases;
    }
    $covgFh->close;
  }
}

1;
