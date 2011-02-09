package Genome::Model::Tools::Music::Bmr::CalcBmr;

use warnings;
use strict;
use IO::File;
use Bit::Vector;

our $VERSION = '1.01';

class Genome::Model::Tools::Music::Bmr::CalcBmr {
  is => 'Command',
  has => [
    roi_file => { is => 'Text', doc => "Tab delimited list of ROIs [chr start stop gene_name]" },
    sample_list => { is => 'Text', doc => "List of all samples that were analyzed for mutations" },
    ref_seq => { is => 'Text', doc => "Path to reference sequence in FASTA format" },
    maf_file => { is => 'Text', doc => "List of mutations in TCGA MAF format v2.2" },
    output_dir => { is => 'Text', doc => "Directory where output files from calc-covg were written" },
    genes_to_ignore => { is => 'Text', doc => "Comma-delimited list of genes to ignore for overall BMR", is_optional => 1 },
  ],
};

sub help_brief {
  "Uses output files of calc-covg, and a mutation list to calculate Background Mutation Rates";
}

sub help_detail {
  return <<HELP;
::YOU complete me::
This script calculates overall BMR and BMRs in the mutation categories of AT_Transitions,
AT_Transversions, CG_Transitions, CG_Transversions, CpG_Transitions, CpG_Transversions and Indels.
It also generates a file with per-gene mutation rates for use by "music smg"

--roi_file
  The regions of interest (ROIs) of each gene are typically the regions targeted for sequencing
  or are merged exons from multiple transcripts of the gene with 2-bp flanks (splice junctions).

--sample-list
  The first column in this file is expected to be the names of the files in output-dir/gene_covgs.
  Any additional columns in this file like BAM file locations or clinical data are ignored.

--ref-seq
  If a reference sequence index is not found (fa.fai file), it will be created.

--output-dir
  This should be the same output directory used when running "music bmr calc-covg". The outputs of
  this script will also be written to this directory.

--genes-to-ignore
  Any genes in this comma-delimited list will be ignored toward BMR calculations. List genes that
  are known factors in this disease and whose mutations are not just background mutations.
HELP
}

sub execute {
  my $self = shift;
  $DB::single = 1;
  my $roi_file = $self->roi_file;
  my $sample_list = $self->sample_list;
  my $ref_seq = $self->ref_seq;
  my $maf_file = $self->maf_file;
  my $output_dir = $self->output_dir;
  my $genes_to_ignore = $self->genes_to_ignore;
  my %ignored_genes = ();
  if( defined $genes_to_ignore )
  {
    %ignored_genes = map { $_ => 1 } split( /,/, $genes_to_ignore );
  }

  # Check on all the input data before starting work
  print STDERR "ROI file not found or is empty: $roi_file\n" unless( -s $roi_file );
  print STDERR "List of samples not found or is empty: $sample_list\n" unless( -s $sample_list );
  print STDERR "Reference sequence file not found: $ref_seq\n" unless( -e $ref_seq );
  print STDERR "MAF file not found or is empty: $maf_file\n" unless( -s $maf_file );
  print STDERR "Output directory not found: $output_dir\n" unless( -e $output_dir );
  return 1 unless( -s $roi_file && -s $sample_list && -e $ref_seq && -s $maf_file && -e $output_dir );

  # Check on the files we expect to find within the provided output directory
  $output_dir =~ s/(\/)+$//; # Remove trailing forward slashes if any
  my $gene_covg_dir = "$output_dir/gene_covgs"; # Should contain per-gene coverage files per sample
  my $total_covgs_file = "$output_dir/total_covgs"; # Should contain overall coverages per sample
  print STDERR "Directory with per-gene coverages not found: $gene_covg_dir\n" unless( -e $gene_covg_dir );
  print STDERR "Total coverages file not found or is empty: $total_covgs_file\n" unless( -s $total_covgs_file );
  return 1 unless( -e $gene_covg_dir && -s $total_covgs_file );

  # Outputs of this script will be written to these files in the output directory
  my $overall_bmr_file = "$output_dir/overall_bmrs";
  my $smg_input_file = "$output_dir/smg_input";

  # If the reference sequence FASTA file hasn't been indexed, do it
  my $ref_seq_idx = "$ref_seq.fai";
  system( "samtools faidx $ref_seq" ) unless( -e $ref_seq_idx );

  # Create a CpG bitmask from the reference sequence, or load it if it was created earlier
  my $cpg_bitmask;
  my $cpg_bitmask_file = "$output_dir/cpg_bitmask"; # Stores a bitmask of all CpGs in the refseq
  if( -e $cpg_bitmask_file )
  {
    print "Loading existing CpG bitmask stored at $output_dir/cpg_bitmask\n";
    $cpg_bitmask = $self->read_genome_bitmask( $cpg_bitmask_file );
  }
  else
  {
    print "Generating a CpG bitmask from the RefSeq and storing it at $output_dir/cpg_bitmask\n";
    my $faiFh = IO::File->new( $ref_seq_idx ) or die "Couldn't open $ref_seq_idx. $!\n";
    while( my $line = $faiFh->getline )
    {
      my ( $chr, undef ) = split( /\t/, $line );
      open( FAIDX_PIPE, "samtools faidx $ref_seq $chr |" );
      my $header = <FAIDX_PIPE>;
      die "Unrecognized header in refseq FASTA file. $!\n" unless( $header =~ m/^>/ );

      # Load the whole sequence of this chrom and turn it into a bitmask
      my @lines = <FAIDX_PIPE>;
      my $seq = join( "", @lines );
      @lines = ();
      $seq =~ s/\n//g;
      $seq =~ s/CG/11/g;
      $seq =~ s/[^1]/0/g;
      $seq = "0" . $seq; # Add a zero at the beginning for 1-based indexing

      # Bit::Vector->new_Bin reverses the sequence for significance reasons
      my $revmask = reverse( $seq );
      $cpg_bitmask->{$chr} = Bit::Vector->new_Bin( length( $seq ), $revmask );
    }
    $faiFh->close;

    # Write the bitmask to the output folder so we don't have to recreate it for later runs
    $self->write_genome_bitmask( $cpg_bitmask_file, $cpg_bitmask );
  }

  # Parse out the names of the samples which should match the names of the coverage files
  my $inFh = IO::File->new( $sample_list ) or die "Couldn't open $sample_list. $!\n";
  my @samples = map { chomp; s/\t.*$//; $_ } $inFh->getlines;
  $inFh->close;

  # Create a bitmask of the ROIs. Mutations outside these regions will be skipped
  my %genes;
  my $roi_bitmask = $self->create_empty_genome_bitmask( $ref_seq_idx );
  my $bedFh = IO::File->new( $roi_file ) or die "Couldn't open $roi_file. $!\n";
  while( my $line = $bedFh->getline )
  {
    next if( $line =~ m/^#/ );
    chomp $line;
    my ( $chr, $start, $stop, $gene ) = split( /\t/, $line );
    $roi_bitmask->{$chr}->Interval_Fill( $start, $stop );
    $genes{$gene} = 1;
  }
  $bedFh->close;

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

  unless( $sample_cnt_in_file == scalar( @samples ))
  {
    print STDERR "Mismatching number of samples in $total_covgs_file and $sample_list\n";
    return 1;
  }

  my %gene_mr; # Stores information regarding per-gene mutation rates
  foreach my $gene ( keys %genes )
  {
    $gene_mr{$gene}{$_}{mutations} = 0 foreach( @mut_classes );
  }

  # Sum up the per-gene covered base-counts across samples from the output of "music bmr calc-covg"
  print "Loading per-gene coverage files stored under $output_dir/gene_covgs/\n";
  foreach my $sample ( @samples )
  {
    my $sample_covg_file = "$output_dir/gene_covgs/$sample.covg";
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
    next if ( $line =~ m/^Hugo\_Symbol/ or $line =~ m/^#/ );
    chomp $line;
    my @segs = split( /\t/, $line );
    my ( $gene, $chr, $start, $stop, $mutation_class, $mutation_type, $ref, $var1, $var2 ) =
      ( $segs[0], $segs[4], $segs[5], $segs[6], $segs[8], $segs[9], $segs[10], $segs[11], $segs[12] );
    $chr =~ s/chr//; # Remove chr prefixes from chrom names

    # Skip Silent mutations and those in Introns, RNA, UTRs, Flanks, or IGRs
    if( $mutation_class =~ m/^(Silent|Intron|RNA|3'Flank|3'UTR|5'Flank|5'UTR|IGR)$/ )
    {
      $skip_cnts{"are classified as $mutation_class"}++;
      print "Skipping $mutation_class mutation: $gene, chr$chr:$start-$stop\n";
      next;
    }

    # If the mutation classification is odd, quit with error
    if( $mutation_class !~ m/^(Missense_Mutation|Nonsense_Mutation|Nonstop_Mutation|Splice_Site|Translation_Start_Site|Targeted_Region|Frame_Shift_Del|Frame_Shift_Ins|In_Frame_Del|In_Frame_Ins)$/ )
    {
      print STDERR "Unrecognized Variant_Classification $mutation_class in MAF file: $gene, chr$chr:$start-$stop\n";
      print STDERR "Please use TCGA MAF Specification v2.2.\n";
      return 1;
    }

    # Skip mutations that were consolidated into others (E.g. SNP consolidated into a TNP)
    if( $mutation_type =~ m/^Consolidated$/ )
    {
      $skip_cnts{"are consolidated into another"}++;
      print "Skipping consolidated mutation: $gene, chr$chr:$start-$stop\n";
      next;
    }

    # If the mutation type is odd, quit with error
    if( $mutation_type !~ m/^(SNP|DNP|TNP|ONP|INS|DEL)$/ )
    {
      print STDERR "Unrecognized Variant_Type $mutation_type in MAF file: $gene, chr$chr:$start-$stop\n";
      print STDERR "Please use TCGA MAF Specification v2.2.\n";
      return 1;
    }

    # Skip mutations that fall completely outside any of the provided regions of interest
    if( $self->count_bits( $roi_bitmask->{$chr}, $start, $stop ) == 0 )
    {
      $skip_cnts{"are outside any ROIs"}++;
      print "Skipping mutation that falls outside ROIs: $gene, chr$chr:$start-$stop\n";
      next;
    }

    # Skip mutations whose gene names don't match any of those in the ROI list
    unless( defined $genes{$gene} )
    {
      $skip_cnts{"have unrecognized gene names"}++;
      print "Skipping unrecognized gene name (not in ROI file): $gene, chr$chr:$start-$stop\n";
      next;
    }

    # Handle SNVs
    if( $mutation_type =~ m/^(SNP|DNP|ONP|TNP)$/ )
    {
      next unless( $mutation_class =~ m/Missense_Mutation|Nonsense_Mutation|Nonstop_Mutation|Splice_Site/ );

      # ::TBD:: For DNPs and TNPs, we use only the first base for mutation classification
      $ref = substr( $ref, 0, 1 ); #In case of DNPs or TNPs
      $var1 = substr( $var1, 0, 1 ); #In case of DNPs or TNPs
      $var2 = substr( $var2, 0, 1 ); #In case of DNPs or TNPs

      # If the alleles are anything but A, C, G, or T then quit with error
      if( $ref !~ m/^[ACGT]$/ || $var1 !~ m/^[ACGT]$/ || $var2 !~ m/^[ACGT]$/ )
      {
        print STDERR "Unrecognized allele in column Reference_Allele, Tumor_Seq_Allele1, or Tumor_Seq_Allele2: $gene, chr$chr:$start-$stop\n";
        print STDERR "Please use TCGA MAF Specification v2.2.\n";
        return 1;
      }

      # Classify the mutation as AT/CG/CpG Transition or Transversion
      my $class = '';
      $class = $classify{ "$ref$var1" } if( defined $classify{ "$ref$var1" } );
      $class = $classify{ "$ref$var2" } if( defined $classify{ "$ref$var2" } );
      $class =~ s/CG/CpG/ if( $ref =~ m/[CG]/ && $self->count_bits( $cpg_bitmask->{$chr}, $start, $stop ));

      # The gene exclusion list should only affect the overall BMR calculations
      $overall_bmr{$class}{mutations}++ unless( defined $ignored_genes{$gene} );
      $gene_mr{$gene}{$class}{mutations}++;
    }
    # Handle Indels
    elsif( $mutation_type =~ m/^(INS|DEL)$/ )
    {
      $overall_bmr{Indels}{mutations}++;
    }
  }
  $mafFh->close;

  # Print statistics related to parsing the MAF
  print "Finished Parsing the MAF file to classify mutations\n";
  foreach my $skip_type ( sort keys %skip_cnts )
  {
    next unless( defined $skip_cnts{$skip_type} );
    print "Skipped ", $skip_cnts{$skip_type}, " mutation(s) that $skip_type\n";
  }

  my $totBmrFh = IO::File->new( $overall_bmr_file, ">" ) or die "Couldn't open $overall_bmr_file. $!\n";
  $totBmrFh->print( "#Genes ignored in this calculation: $genes_to_ignore\n" ) if( defined $genes_to_ignore );
  $totBmrFh->print( "#Mutation_Class\tOverall_Covered_Bases\tNon_Syn_Mutations\tBMR\n" );
  my $tot_muts = 0;
  foreach my $class ( @mut_classes )
  {
    # Subtract the covered bases in this class that belong to the genes to be ignored
    # ::TBD:: Some of these bases may belong to another gene, and then it must not be subtracted
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
  my $geneBmrFh = IO::File->new( $smg_input_file, ">" ) or die "Couldn't open $smg_input_file. $!\n";
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

# Writes a whole genome bitmask to a file that can be later loaded using read_genome_bitmask
sub write_genome_bitmask
{
  my ( $self, $bitmask_file, $bitmask_ref ) = @_;

  # Do some stuff to help read this from a file without making it suck
  my $outFh = IO::File->new( $bitmask_file, ">:raw" ) or die "Couldn't write to $bitmask_file. $!\n";
  my $header_string = join( "\t", map {$_ => $bitmask_ref->{$_}->Size()} sort keys %$bitmask_ref );
  my $write_string = pack( 'N/a*', $header_string );
  my $write_result = $outFh->syswrite( $write_string );
  die "Error writing bitmask header. $!\n" unless( defined $write_result && $write_result == length( $write_string ));
  foreach my $chr ( sort keys %$bitmask_ref )
  {
    my $chr_write_string = $bitmask_ref->{$chr}->Block_Read();
    # First write the length of this chrom in bytes
    $write_result = $outFh->syswrite( pack( "N", length( $chr_write_string )));
    die "Error writing the length of chromosome $chr. $!\n" unless( defined $write_result && $write_result == 4 );
    # Then write the actual masked bits for this chrom
    $write_result = $outFh->syswrite( $chr_write_string );
    die "Error writing bitmask. $!\n" unless( defined $write_result && $write_result == length( $chr_write_string ));
  }
  $outFh->close;
  return 1;
}

# Reads and whole genome bitmask file that was written to file using write_genome_bitmask
sub read_genome_bitmask
{
  my ( $self, $bitmask_file ) = @_;

  # Do some stuff to help read this from a file without making it suck
  my $inFh = IO::File->new( $bitmask_file, "<:raw" ) or die "Couldn't read from $bitmask_file. $!\n";
  my $read_string;
  $inFh->sysread( $read_string, 4 );
  my $header_length = unpack( "N", $read_string );
  $inFh->sysread( $read_string, $header_length );
  my $header_string = unpack( "a*", $read_string );
  my %genome = split( /\t/, $header_string ); # Keys are chrom names, values are sizes

  foreach my $chr ( sort keys %genome )
  {
    $genome{$chr} = Bit::Vector->new( $genome{$chr} ) or die "Failed to create a bitmask. $!\n";
    # Read the length of this chrom in bytes
    $inFh->sysread( $read_string, 4 );
    my $chr_byte_length = unpack( "N", $read_string );
    my $chr_read_string;
    # Read the actual masked bits of this chrom
    $inFh->sysread( $chr_read_string, $chr_byte_length );
    $genome{$chr}->Block_Store( $chr_read_string );
  }
  $inFh->close;
  return \%genome;
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
