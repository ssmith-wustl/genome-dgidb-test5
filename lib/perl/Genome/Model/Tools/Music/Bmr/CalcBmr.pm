package Genome::Model::Tools::Music::Bmr::CalcBmr;

use warnings;
use strict;
use IO::File;
use Bit::Vector;

our $VERSION = $Genome::Model::Tools::Music::VERSION;

class Genome::Model::Tools::Music::Bmr::CalcBmr {
  is => 'Genome::Model::Tools::Music::Bmr::Base',
  has_input => [
    roi_file => { is => 'Text', doc => "Tab delimited list of ROIs [chr start stop gene_name] (See DESCRIPTION)" },
    reference_sequence => { is => 'Text', doc => "Path to reference sequence in FASTA format" },
    bam_list => { is => 'Text', doc => "Tab delimited list of BAM files [sample_name normal_bam tumor_bam] (See DESCRIPTION)" },
    output_dir => { is => 'Text', doc => "Directory where output files will be written (Use the same one used with calc-covg)" },
    maf_file => { is => 'Text', doc => "List of mutations using TCGA MAF specifications v2.2" },
    show_skipped => { is => 'Boolean', doc => "Report each skipped mutation, not just how many", is_optional => 1, default => 0 },
    genes_to_ignore => { is => 'Text', doc => "Comma-delimited list of genes to ignore for background mutation rates", is_optional => 1 },
    skip_non_coding => { is => 'Boolean', doc => "Skip non-coding mutations from the provided MAF file", is_optional => 1, default => 1 },
    skip_silent => { is => 'Boolean', doc => "Skip silent mutations from the provided MAF file", is_optional => 1, default => 1 },
  ],
  doc => "Calculates background mutation rates using output files of calc-covg and a mutation list.",
};

sub help_synopsis {
  return <<HELP
 ... music bmr calc-bmr \\
    --bam-list input_dir/bam_list \\
    --maf-file input_dir/myMAF.tsv \\
    --output-dir output_dir/ \\
    --reference-sequence input_dir/all_sequences.fa \\
    --roi-file input_dir/all_coding_exons.tsv

 ... music bmr calc-bmr \\
    --bam-list input_dir/bam_list \\
    --maf-file input_dir/myMAF.tsv \\
    --output-dir output_dir/ \\
    --reference-sequence input_dir/all_sequences.fa \\
    --roi-file input_dir/all_coding_exons.tsv \\
    --genes-to-ignore GENE1,GENE2
HELP
}

sub help_detail {
  return <<HELP;
This script calculates overall Background Mutation Rate (BMR) and BMRs in the categories of
AT/CG/CpG Transitions, AT/CG/CpG Transversions, and Indels. It also generates a file with per-gene mutation rates that can be used for significantly mutated gene tests (music smg).

ARGUMENTS:

 --roi-file
  The regions of interest (ROIs) of each gene are typically regions targeted for sequencing or are
  merged exon loci (from multiple transcripts) of genes with 2-bp flanks (splice junctions). ROIs
  from the same chromosome must be listed adjacent to each other in this file. This allows the
  underlying C-based code to run much more efficiently and avoid re-counting bases seen in
  overlapping ROIs (for overall covered base counts). For per-gene base counts, an overlapping
  base will be counted each time it appears in an ROI of the same gene. To avoid this, be sure to
  merge together overlapping ROIs of the same gene. BEDtools' mergeBed can help if used per gene.

 --reference-sequence
  The reference sequence in FASTA format. If a reference sequence index is not found next to this
  file (a .fai file), it will be created.

 --bam-list
  Provide a file containing sample names and normal/tumor BAM locations for each. Use the tab-
  delimited format [sample_name normal_bam tumor_bam] per line. Additional columns like clinical
  data are allowed, but ignored. The sample_name must be the same as the tumor sample names used
  in the MAF file (16th column, with the header Tumor_Sample_Barcode).

 --output-dir
  This should be the same output directory used when running "music bmr calc-covg". The following
  outputs of this script will also be created/written:
  overall_bmrs: File containing categorized overall background mutation rates.
  gene_mrs: File containing categorized per-gene mutation rates.

 --genes-to-ignore
  A comma-delimited list of genes to ignore for overall BMR calculations. List genes that are
  known factors in this disease and whose mutations should not be classified as background.
HELP
}

sub _doc_authors {
  return " Cyriac Kandoth, Ph.D.";
}

sub _doc_see_also {
  return <<EOS
B<genome-music-bmr>(1),
B<genome-music>(1),
B<genome>(1)
EOS
}

sub execute {
  my $self = shift;
  my $roi_file = $self->roi_file;
  my $ref_seq = $self->reference_sequence;
  my $bam_list = $self->bam_list;
  my $output_dir = $self->output_dir;
  my $maf_file = $self->maf_file;
  my $show_skipped = $self->show_skipped;
  my $genes_to_ignore = $self->genes_to_ignore;
  my $skip_non_coding = $self->skip_non_coding;
  my $skip_silent = $self->skip_silent;

  # Check on all the input data before starting work
  print STDERR "ROI file not found or is empty: $roi_file\n" unless( -s $roi_file );
  print STDERR "Reference sequence file not found: $ref_seq\n" unless( -e $ref_seq );
  print STDERR "List of BAMs not found or is empty: $bam_list\n" unless( -s $bam_list );
  print STDERR "Output directory not found: $output_dir\n" unless( -e $output_dir );
  print STDERR "MAF file not found or is empty: $maf_file\n" unless( -s $maf_file );
  return undef unless( -s $roi_file && -e $ref_seq && -s $bam_list && -e $output_dir && -s $maf_file );

  # Check on the files we expect to find within the provided output directory
  $output_dir =~ s/(\/)+$//; # Remove trailing forward slashes if any
  my $gene_covg_dir = "$output_dir/gene_covgs"; # Should contain per-gene coverage files per sample
  my $total_covgs_file = "$output_dir/total_covgs"; # Should contain overall coverages per sample
  print STDERR "Directory with per-gene coverages not found: $gene_covg_dir\n" unless( -e $gene_covg_dir );
  print STDERR "Total coverages file not found or is empty: $total_covgs_file\n" unless( -s $total_covgs_file );
  return undef unless( -e $gene_covg_dir && -s $total_covgs_file );

  # Outputs of this script will be written to these locations in the output directory
  my $overall_bmr_file = "$output_dir/overall_bmrs";
  my $gene_mr_file = "$output_dir/gene_mrs";

  # Build a hash to quickly lookup the genes to be ignored for overall BMRs
  my %ignored_genes = ();
  if( defined $genes_to_ignore )
  {
    %ignored_genes = map { $_ => 1 } split( /,/, $genes_to_ignore );
  }

  # Parse out the names of the samples which should match the names of the coverage files needed
  my @all_sample_names;
  my $sampleFh = IO::File->new( $bam_list ) or die "Couldn't open $bam_list. $!\n";
  while( my $line = $sampleFh->getline )
  {
    next if ( $line =~ m/^#/ );
    chomp( $line );
    my ( $sample ) = split( /\t/, $line );
    push( @all_sample_names, $sample );
  }
  $sampleFh->close;

  # If the reference sequence FASTA file hasn't been indexed, do it
  my $ref_seq_idx = "$ref_seq.fai";
  system( "samtools faidx $ref_seq" ) unless( -e $ref_seq_idx );

  # Create a bitmask of the ROIs. Mutations outside these regions will be skipped
  my %genes;
  my $roi_bitmask = $self->create_empty_genome_bitmask( $ref_seq_idx );
  my $roiFh = IO::File->new( $roi_file ) or die "Couldn't open $roi_file. $!\n";
  while( my $line = $roiFh->getline )
  {
    next if( $line =~ m/^#/ );
    chomp $line;
    my ( $chr, $start, $stop, $gene ) = split( /\t/, $line );
    $roi_bitmask->{$chr}->Interval_Fill( $start, $stop );
    $genes{$gene} = 1;
  }
  $roiFh->close;

  # These are the various categories that each mutation will be classified into
  my @mut_classes = qw( AT_Transitions AT_Transversions CG_Transitions CG_Transversions CpG_Transitions CpG_Transversions Indels );

  my %overall_bmr; # Stores information needed to calculate overall BMRs
  $overall_bmr{$_}{mutations} = 0 foreach( @mut_classes );

  # Sum up the overall covered base-counts across samples from the output of "music bmr calc-covg"
  print "Loading overall coverages stored in $total_covgs_file\n";
  my $sample_cnt_in_file = 0;
  my $totCovgFh = IO::File->new( $total_covgs_file ) or die "Couldn't open $total_covgs_file. $!\n";
  while( my $line = $totCovgFh->getline )
  {
    next if( $line =~ m/^#/ );
    chomp( $line );
    ++$sample_cnt_in_file;
    my ( $sample, $covd_bases, $covd_at_bases, $covd_cg_bases, $covd_cpg_bases ) = split( /\t/, $line );
    $overall_bmr{Indels}{covd_bases} += $covd_bases;
    $overall_bmr{AT_Transitions}{covd_bases} += $covd_at_bases;
    $overall_bmr{AT_Transversions}{covd_bases} += $covd_at_bases;
    $overall_bmr{CG_Transitions}{covd_bases} += $covd_cg_bases;
    $overall_bmr{CG_Transversions}{covd_bases} += $covd_cg_bases;
    $overall_bmr{CpG_Transitions}{covd_bases} += $covd_cpg_bases;
    $overall_bmr{CpG_Transversions}{covd_bases} += $covd_cpg_bases;
  }
  $totCovgFh->close;

  unless( $sample_cnt_in_file == scalar( @all_sample_names ))
  {
    print STDERR "Mismatching number of samples in $total_covgs_file and $bam_list\n";
    return undef;
  }

  my %gene_mr; # Stores information regarding per-gene mutation rates
  foreach my $gene ( keys %genes )
  {
    $gene_mr{$gene}{$_}{mutations} = 0 foreach( @mut_classes );
  }

  # Sum up the per-gene covered base-counts across samples from the output of "music bmr calc-covg"
  print "Loading per-gene coverage files stored under $gene_covg_dir/\n";
  foreach my $sample ( @all_sample_names )
  {
    my $sample_covg_file = "$gene_covg_dir/$sample.covg";
    my $sampleCovgFh = IO::File->new( $sample_covg_file ) or die "Couldn't open $sample_covg_file. $!\n";
    while( my $line = $sampleCovgFh->getline )
    {
      next if( $line =~ m/^#/ );
      chomp( $line );
      my ( $gene, undef, $covd_bases, $covd_at_bases, $covd_cg_bases, $covd_cpg_bases ) = split( /\t/, $line );
      $gene_mr{$gene}{Indels}{covd_bases} += $covd_bases;
      $gene_mr{$gene}{AT_Transitions}{covd_bases} += $covd_at_bases;
      $gene_mr{$gene}{AT_Transversions}{covd_bases} += $covd_at_bases;
      $gene_mr{$gene}{CG_Transitions}{covd_bases} += $covd_cg_bases;
      $gene_mr{$gene}{CG_Transversions}{covd_bases} += $covd_cg_bases;
      $gene_mr{$gene}{CpG_Transitions}{covd_bases} += $covd_cpg_bases;
      $gene_mr{$gene}{CpG_Transversions}{covd_bases} += $covd_cpg_bases;
    }
    $sampleCovgFh->close;
  }

  # Create a hash to help classify SNVs
  my %classify;
  $classify{$_} = 'AT_Transitions' foreach( qw( AG TC ));
  $classify{$_} = 'AT_Transversions' foreach( qw( AC AT TA TG ));
  $classify{$_} = 'CG_Transitions' foreach( qw( CT GA ));
  $classify{$_} = 'CG_Transversions' foreach( qw( CA CG GC GT ));

  # Parse through the MAF file and categorize each somatic mutation
  print "Parsing MAF file to classify mutations\n";
  my %skip_cnts;
  my $mafFh = IO::File->new( $maf_file ) or die "Couldn't open $maf_file. $!\n";
  while( my $line = $mafFh->getline )
  {
    next if( $line =~ m/^(#|Hugo_Symbol)/ );
    chomp $line;
    my @cols = split( /\t/, $line );
    my ( $gene, $chr, $start, $stop, $mutation_class, $mutation_type, $ref, $var1, $var2 ) =
    ( $cols[0], $cols[4], $cols[5], $cols[6], $cols[8], $cols[9], $cols[10], $cols[11], $cols[12] );
    $chr =~ s/^chr//; # Remove chr prefixes from chrom names if any

    # If the mutation classification is odd, quit with error
    if( $mutation_class !~ m/^(Missense_Mutation|Nonsense_Mutation|Nonstop_Mutation|Splice_Site|Translation_Start_Site|Frame_Shift_Del|Frame_Shift_Ins|In_Frame_Del|In_Frame_Ins|Silent|Intron|RNA|3'Flank|3'UTR|5'Flank|5'UTR|IGR|Targeted_Region)$/ )
    {
      print STDERR "Unrecognized Variant_Classification \"$mutation_class\" in MAF file: $gene, chr$chr:$start-$stop\n";
      print STDERR "Please use TCGA MAF Specification v2.2.\n";
      return undef;
    }

    # If user wants, skip Silent mutations, or those in Introns, RNA, UTRs, Flanks, IGRs, or the ubiquitous Targeted_Region
    if(( $skip_non_coding && $mutation_class =~ m/^(Intron|RNA|3'Flank|3'UTR|5'Flank|5'UTR|IGR|Targeted_Region)$/ ) ||
       ( $skip_silent && $mutation_class =~ m/^Silent$/ ))
    {
      $skip_cnts{"are classified as $mutation_class"}++;
      print "Skipping $mutation_class mutation: $gene, chr$chr:$start-$stop\n" if( $show_skipped );
      next;
    }

    # If the mutation type is odd, quit with error
    if( $mutation_type !~ m/^(SNP|DNP|TNP|ONP|INS|DEL|Consolidated)$/ )
    {
      print STDERR "Unrecognized Variant_Type \"$mutation_type\" in MAF file: $gene, chr$chr:$start-$stop\n";
      print STDERR "Please use TCGA MAF Specification v2.2.\n";
      return undef;
    }

    # Skip mutations that were consolidated into others (E.g. SNP consolidated into a TNP)
    if( $mutation_type =~ m/^Consolidated$/ )
    {
      $skip_cnts{"are consolidated into another"}++;
      print "Skipping consolidated mutation: $gene, chr$chr:$start-$stop\n" if( $show_skipped );
      next;
    }

    # Skip mutations that fall completely outside any of the provided regions of interest
    if( $self->count_bits( $roi_bitmask->{$chr}, $start, $stop ) == 0 )
    {
      $skip_cnts{"are outside any ROIs"}++;
      print "Skipping mutation that falls outside ROIs: $gene, chr$chr:$start-$stop\n" if( $show_skipped );
      next;
    }

    # Skip mutations whose gene names don't match any of those in the ROI list
    unless( defined $genes{$gene} )
    {
      $skip_cnts{"have unrecognized gene names"}++;
      print "Skipping unrecognized gene name (not in ROI file): $gene, chr$chr:$start-$stop\n" if( $show_skipped );
      next;
    }

    # Classify the mutation as AT/CG/CpG Transition, AT/CG/CpG Transversion, or Indel
    my $class = '';
    if( $mutation_type =~ m/^(SNP|DNP|ONP|TNP)$/ )
    {
      # ::TBD:: For DNPs and TNPs, we use only the first base for mutation classification
      $ref = substr( $ref, 0, 1 );
      $var1 = substr( $var1, 0, 1 );
      $var2 = substr( $var2, 0, 1 );

      # If the alleles are anything but A, C, G, or T then quit with error
      if( $ref !~ m/[ACGT]/ || $var1 !~ m/[ACGT]/ || $var2 !~ m/[ACGT]/ )
      {
        print STDERR "Unrecognized allele in column Reference_Allele, Tumor_Seq_Allele1, or Tumor_Seq_Allele2: $gene, chr$chr:$start-$stop\n";
        print STDERR "Please use TCGA MAF Specification v2.2.\n";
        return undef;
      }

      # Use the classify hash to find whether this SNV is an AT/CG Transition/Transversion
      $class = $classify{ "$ref$var1" } if( defined $classify{ "$ref$var1" } );
      $class = $classify{ "$ref$var2" } if( defined $classify{ "$ref$var2" } );

      # Fetch the current ref base and it's two neighboring bases from the refseq
      my ( $fetched_ref, $ref_and_flanks );
      my $region = "$chr:" . ( $start - 1 ) . "-" . ( $start + 1 );
      open( FAIDX_PIPE, "samtools faidx $ref_seq $region |" );
      my $header = <FAIDX_PIPE>;
      die "Failed to run \"samtools faidx\". $!\n" unless( $header =~ m/^>/ );
      $ref_and_flanks = <FAIDX_PIPE>;
      chomp( $ref_and_flanks );
      $fetched_ref = substr( $ref_and_flanks, 1, 1 ) if( defined $ref_and_flanks && length( $ref_and_flanks ) == 3 );
      close( FAIDX_PIPE );

      # Check if the ref base in the MAF matched what we fetched from the ref-seq
      if( defined $fetched_ref && $fetched_ref ne $ref )
      {
        print STDERR "Reference allele $ref for mutation in $gene at chr$chr:$start-$stop is $fetched_ref in the reference sequence. Using it anyway.\n";
      }

      # Check if a C or G reference allele belongs to a CpG pair
      if(( $ref eq 'C' || $ref eq 'G' ) && defined $ref_and_flanks )
      {
        $class =~ s/CG/CpG/ if( $ref_and_flanks =~ m/CG/ );
      }
    }
    # Handle Indels
    elsif( $mutation_type =~ m/^(INS|DEL)$/ )
    {
      $class = 'Indels';
    }

    # The user's gene exclusion list only affects the overall BMR calculations
    $overall_bmr{$class}{mutations}++ unless( defined $ignored_genes{$gene} );
    $gene_mr{$gene}{$class}{mutations}++;
  }
  $mafFh->close;

  # Diplay statistics related to parsing the MAF
  print "Finished Parsing the MAF file to classify mutations\n";
  foreach my $skip_type ( sort keys %skip_cnts )
  {
    next unless( defined $skip_cnts{$skip_type} );
    print "Skipped ", $skip_cnts{$skip_type}, " mutation(s) that $skip_type\n";
  }

  my $totBmrFh = IO::File->new( $overall_bmr_file, ">" ) or die "Couldn't open $overall_bmr_file. $!\n";
  $totBmrFh->print( "#User-specified genes skipped in this calculation: $genes_to_ignore\n" ) if( defined $genes_to_ignore );
  $totBmrFh->print( "#Mutation_Class\tOverall_Covered_Bases\tNon_Syn_Mutations\tBMR\n" );
  my $tot_muts = 0;
  foreach my $class ( @mut_classes )
  {
    # Subtract the covered bases in this class that belong to the genes to be ignored
    # ::TBD:: Some of these bases may belong to another gene, and those should not be subtracted
    foreach my $ignored_gene ( keys %ignored_genes )
    {
      $overall_bmr{$class}{covd_bases} -= $gene_mr{$ignored_gene}{$class}{covd_bases} if( defined $gene_mr{$ignored_gene} );
    }

    #Calculate overall BMR for this mutation class and print it to file
    $overall_bmr{$class}{bmr} = 0;
    if( defined $overall_bmr{$class}{covd_bases} && $overall_bmr{$class}{covd_bases} != 0 )
    {
      $overall_bmr{$class}{bmr} = $overall_bmr{$class}{mutations} / $overall_bmr{$class}{covd_bases};
    }
    $totBmrFh->print( join( "\t", $class, $overall_bmr{$class}{covd_bases}, $overall_bmr{$class}{mutations}, $overall_bmr{$class}{bmr} ), "\n" );
    $tot_muts += $overall_bmr{$class}{mutations};
  }
  $totBmrFh->print( join( "\t", "Overall_BMR", $overall_bmr{Indels}{covd_bases}, $tot_muts, $tot_muts / $overall_bmr{Indels}{covd_bases} ), "\n" );
  $totBmrFh->close;

  # Print out a file containing per-gene mutation counts and covered bases for use by "music smg"
  my $geneBmrFh = IO::File->new( $gene_mr_file, ">" ) or die "Couldn't open $gene_mr_file. $!\n";
  $geneBmrFh->print( "#Gene\tMutation_Class\tCovered_Bases\tNon_Syn_Mutations\tOverall_BMR\n" );
  foreach my $gene ( sort keys %genes )
  {
    foreach my $class ( @mut_classes )
    {
      $geneBmrFh->print( join( "\t", $gene, $class, $gene_mr{$gene}{$class}{covd_bases}, $gene_mr{$gene}{$class}{mutations}, $overall_bmr{$class}{bmr} ), "\n" );
    }
  }
  $geneBmrFh->close;

  return 1;
}

# Creates an empty whole genome bitmask based on the given reference sequence index
sub create_empty_genome_bitmask
{
  my ( $self, $ref_seq_idx_file ) = @_;
  my %genome;
  my $refFh = IO::File->new( $ref_seq_idx_file ) or die "Couldn't open $ref_seq_idx_file. $!\n";
  while( my $line = $refFh->getline )
  {
    my ( $chr, $length ) = split( /\t/, $line );
    $genome{$chr} = Bit::Vector->new( $length + 1 ); # Adding a base for 1-based coordinates
  }
  $refFh->close;
  return \%genome;
}

# Counts the number of bits that are set in the given region of a Bit:Vector
sub count_bits
{
  my ( $self, $vector, $start, $stop ) = @_;
  my $count = 0;
  for my $pos ( $start..$stop )
  {
    ++$count if( $vector->bit_test( $pos ));
  }
  return $count;
}

1;
