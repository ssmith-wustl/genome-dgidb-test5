package Genome::Model::Tools::Music::PathScan;

use warnings;
use strict;
use Genome::Model::Tools::Music::PathScan::PopulationPathScan;
use IO::File;

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::PathScan {
  is => 'Command',
  has_input => [
    gene_covg_dir => { is => 'Text', doc => "Directory containing per-gene coverage files (Created using music bmr calc-covg)" },
    bam_list => { is => 'Text', doc => "Tab delimited list of BAM files [sample_name normal_bam tumor_bam] (See Description)" },
    pathway_file => { is => 'Text', doc => "Tab-delimited file of pathway information (See Description)" },
    maf_file => { is => 'Text', doc => "List of mutations using TCGA MAF specifications v2.2" },
    output_file => { is => 'Text', doc => "Output file that will list the significant pathways and their p-values" },
    bmr => { is => 'Number', doc => "Background mutation rate in the targeted regions", is_optional => 1, default => 1.7E-6 },
    genes_to_ignore => { is => 'Text', doc => "Comma-delimited list of genes whose mutations should be ignored", is_optional => 1 },
  ],
};

sub help_brief {
  "Find the various pathways significant to the cancer given a list of somatic mutations";
}

sub help_detail {
  return <<HELP
Only the following four columns in the MAF are used. All other columns may as well be blank.
Col 1: Hugo_Symbol (Need not be HUGO, but must match gene names used in the pathway file)
Col 2: Entrez_Gene_Id (Matching Entrez ID trump gene name matches between pathway file and MAF)
Col 9: Variant_Classification (PathScan ignores Silent|RNA|3'Flank|3'UTR|5'Flank|5'UTR|Intron)
Col 16: Tumor_Sample_Barcode (Must match the name in sample-list, or contain it as a substring)

The Entrez_Gene_Id can also be left blank, but it is highly recommended in case genes are named
differently in the pathway file and the MAF file.

ARGUMENTS:
--pathway-file
  ::TODO::

--gene-covg-dir
  This is usually the gene_covgs subdirectory created when you run "music bmr calc-covg". It
  should contain files for each sample that report per-gene covered base counts.

--bam-list
  Provide a file containing sample names and normal/tumor BAM locations for each. Use the tab-
  delimited format [sample_name normal_bam tumor_bam] per line. Additional columns like clinical
  data are allowed, but ignored. The sample_name must be the same as the tumor sample names used
  in the MAF file (16th column, with the header Tumor_Sample_Barcode).

--bmr
  The overall background mutation rate that can be calculated using "music bmr calc-bmr".

--genes-to-ignore
  A comma-delimited list of genes to ignore from the MAF file. This is useful when there are
  recurrently mutated genes like TP53 which might mask the significance of other genes.
HELP
}

sub execute
{
  my $self = shift;
  $DB::single = 1;
  my $covg_dir = $self->gene_covg_dir;
  my $bam_list = $self->bam_list;
  my $pathway_file = $self->pathway_file;
  my $maf_file = $self->maf_file;
  my $output_file = $self->output_file;
  my $bgd_mut_rate = $self->bmr;
  my $genes_to_ignore = $self->genes_to_ignore;

  # Check on all the input data before starting work
  print STDERR "MAF file not found or is empty: $maf_file\n" unless( -s $maf_file );
  print STDERR "Directory with gene coverages not found: $covg_dir\n" unless( -e $covg_dir );
  print STDERR "List of samples not found or is empty: $bam_list\n" unless( -s $bam_list );
  print STDERR "Pathway info file not found or is empty: $pathway_file\n" unless( -s $pathway_file );
  return 1 unless( -s $maf_file && -e $covg_dir && -s $bam_list && -s $pathway_file );

  # Build a hash to quickly lookup the genes whose mutations should be ignored
  my %ignored_genes = ();
  if( defined $genes_to_ignore )
  {
    %ignored_genes = map { $_ => 1 } split( /,/, $genes_to_ignore );
  }

  # PathScan uses a helluva lot of hashes - all your RAM are belong to it
  my %sample_gene_hash; # sample => array of genes (based on maf)
  my %gene_path_hash; # gene => array of pathways (based on path_file)
  my %path_hash; # pathway => all the information about the pathways in the database
  my %sample_path_hash; # sample => pathways (based on %sample_gene_hash and %gene_path_hash)
  my %path_sample_hits_hash; # path => sample => hits,mutated_genes
  my %gene_sample_cov_hash; # gene => sample => coverage
  my @all_sample_names; # names of all the samples, no matter if it's mutated or not
  my %id_gene_hash; # entrez id => gene (based on first two columns in MAF)

  # Parse out the names of the samples which should match the names of the coverage files needed
  my $sampleFh = IO::File->new( $bam_list ) or die "Couldn't open $bam_list. $!\n";
  while( my $line = $sampleFh->getline )
  {
    next if ( $line =~ m/^#/ );
    chomp( $line );
    my ( $sample ) = split( /\t/, $line );
    push( @all_sample_names, $sample );
  }
  $sampleFh->close;

  # Read coverage data calculated by the Music::Bmr::CalcCovg
  $covg_dir =~ s/(\/)+$//; # Remove trailing forward slashes if any
  read_CoverageFiles( $covg_dir, \@all_sample_names, \%gene_sample_cov_hash );

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
    next if( $line =~ m/^(#|Hugo_Symbol)/ );
    chomp( $line );
    my @cols = split( /\t/, $line );
    my ( $gene, $entrez_id, $mutation_class, $tumor_sample ) = ( $cols[0], $cols[1], $cols[8], $cols[15] );

    # Skip Silent mutations and those in Introns, RNA, UTRs, Flanks, IGRs, or the ubiquitous Targeted_Region
    next if( $mutation_class =~ m/^(Silent|Intron|RNA|3'Flank|3'UTR|5'Flank|5'UTR|IGR|Targeted_Region)$/ );

    # If the mutation classification is odd, quit with error
    if( $mutation_class !~ m/^(Missense_Mutation|Nonsense_Mutation|Nonstop_Mutation|Splice_Site|Translation_Start_Site|Frame_Shift_Del|Frame_Shift_Ins|In_Frame_Del|In_Frame_Ins)$/ )
    {
      print STDERR "Unrecognized Variant_Classification $mutation_class in MAF file.\n";
      print STDERR "Please use TCGA MAF Specification v2.2.\n";
      return 1;
    }

    # Check that the user followed instructions and named each sample correctly
    unless( grep( /^$tumor_sample$/, @all_sample_names ))
    {
      print STDERR "Sample $tumor_sample in MAF file does not match any in $bam_list\n";
      return 1;
    }

    next if( defined $ignored_genes{$gene} ); # Ignore variants in genes that user wants ignored
    $id_gene_hash{$entrez_id} = $gene unless( $entrez_id eq '' or $entrez_id == 0 or $entrez_id !~ m/^\d+$/ );
    push( @{$sample_gene_hash{$tumor_sample}}, $gene ) unless( grep /^$gene$/, @{$sample_gene_hash{$tumor_sample}} );
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
      unless( $entrez_id eq '' or $entrez_id == 0 or $entrez_id !~ m/^\d+$/ )
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

    $pop_obj->preprocess( $bgd_mut_rate, $hits_ref );  #mwendl's new fix

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
  my ( $covg_dir, $all_samples_ref, $gene_sample_cov_hash_ref ) = ( $_[0], $_[1], $_[2] );

  # Read per-gene covered base counts for each sample
  foreach my $sample ( @{$all_samples_ref} )
  {
    # If the file doesn't exist, quit with error. The Music::Bmr::CalcCovg step is incomplete
    unless( -s "$covg_dir/$sample.covg" )
    {
      print STDERR "Couldn't find $sample.covg in $covg_dir. (music bmr calc-covg possibly incomplete)\n";
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
