package Genome::Model::Tools::Capture::ManualReview;

use warnings;
use strict;
use IO::File;
use Genome;
use Sort::Naturally qw(nsort);

class Genome::Model::Tools::Capture::ManualReview {
  is => 'Command',
  has_input => [
    som_var_model_group_id => { is => 'Text', doc => "ID of model-group containing SomaticVariation models with variants to manually review" },
    output_dir => { is => 'Text', doc => "Analysis where files for manual review will be organized" },
    exclude_pindel => { is => 'Boolean', doc => "Set aside calls unique to Pindel, since many cannot be reviewed on a BWA aligned BAM", is_optional => 1, default => 1 },
  ],
  doc => "Prepares variants for manual review in IGV, given a model-group of SomaticVariation models",
};

sub help_detail {
  return <<HELP;
Given a model-group containing SomaticVariation models, this tool will collect the resulting tier1
variants and prepare them for manual review.

NOTE: If exclude-pindel is used, then calls unique to Pindel are stored in a separate review file.
Pindel calls that are also found by GATK are stored in the main review file.
HELP
}

sub _doc_authors {
  return <<AUTHS;
 David Larson, Ph.D.
 Cyriac Kandoth, Ph.D.
AUTHS
}

sub execute {
  my $self = shift;
  my $som_var_model_group_id = $self->som_var_model_group_id;
  my $output_dir = $self->output_dir;
  my $exclude_pindel = $self->exclude_pindel;
  $output_dir =~ s/(\/)+$//; # Remove trailing forward-slashes if any

  # Check on all the input data before starting work
  my $somvar_group = Genome::ModelGroup->get( $som_var_model_group_id );
  print STDERR "ERROR: Could not find a model-group with ID: $som_var_model_group_id\n" unless( defined $somvar_group );
  print STDERR "ERROR: Output directory not found: $output_dir\n" unless( -e $output_dir );
  return undef unless( defined $somvar_group && -e $output_dir );

  my @somvar_models = $somvar_group->models;
  my %bams; # Hash to store the tumor-normal BAM pairs
  foreach my $model ( @somvar_models )
  {
    my $build = $model->last_succeeded_build;
    unless( defined $build )
    {
      print STDERR "WARNING: Skipping model ", $model->id, " that has no succeeded builds\n";
      next;
    }
    my $tcga_patient_id = $build->tumor_build->model->subject->extraction_label;
    $tcga_patient_id = $build->tumor_build->model->subject_name unless( $tcga_patient_id =~ /^TCGA/ );
    my $tumor_bam = $build->tumor_build->whole_rmdup_bam_file;
    my $normal_bam = $build->normal_build->whole_rmdup_bam_file;

    if( exists( $bams{$tcga_patient_id} ))
    {
      print STDERR "ERROR: Multiple models in model-group $som_var_model_group_id for sample $tcga_patient_id";
      return undef;
    }
    else
    {
      $bams{$tcga_patient_id}{tumor} = $tumor_bam;
      $bams{$tcga_patient_id}{normal} = $normal_bam;
    }
    my $build_dir = $build->data_directory;

    # Check if the necessary SNV and Indel files were created by this build
    my $snv_anno = "$build_dir/effects/snvs.hq.tier1.v1.annotated.top";
    print STDERR "ERROR: Tier1 SNV annotations for $tcga_patient_id not found at $snv_anno\n" unless( -e $snv_anno );
    my $indel_anno = "$build_dir/effects/indels.hq.tier1.v1.annotated.top";
    print STDERR "ERROR: Tier1 Indel annotations for $tcga_patient_id not found at $indel_anno\n" unless( -e $indel_anno );
    my $gatk_calls = "$build_dir/variants/indel/gatk-somatic-indel-5336-/indels.hq.bed";
    print STDERR "ERROR: GATK calls for $tcga_patient_id not found at $gatk_calls\n" unless( -e $gatk_calls );
    my $pindel_calls = "$build_dir/variants/indel/pindel-0.5-/pindel-somatic-calls-v1-/pindel-read-support-v1-/indels.hq.bed";
    print STDERR "ERROR: Pindel calls for $tcga_patient_id not found at $pindel_calls\n" unless( -e $pindel_calls );
    return undef unless( -e $snv_anno && -e $indel_anno && -e $gatk_calls && -e $pindel_calls );

    # I know I shouldn't use backticks like this, but think of all the lines of code we save
    @{$bams{$tcga_patient_id}{lines}} = `cat $snv_anno $indel_anno`;
    chomp( @{$bams{$tcga_patient_id}{lines}} );
    if( $exclude_pindel )
    {
      @{$bams{$tcga_patient_id}{gatk}} = `cut -f 1-4 $gatk_calls`;
      @{$bams{$tcga_patient_id}{pindel}} = `cut -f 1-4 $pindel_calls`;
      chomp( @{$bams{$tcga_patient_id}{gatk}}, @{$bams{$tcga_patient_id}{pindel}} );
    }
  }

  foreach my $case ( keys %bams )
  {
    # Create a review file for manual reviewers to record comments, and a bed file for use with IGV
    print "Preparing review files for $case... ";
    my $review_file = "$output_dir/$case.review.csv";
    my $bed_file = "$output_dir/$case.bed";
    # If user wants to exclude calls unique to pindel create a separate file
    my $pindel_file = "$output_dir/$case.review_pindel.csv";

    # Check if the review file exists. We don't want to overwrite reviewed variants
    if( -e $review_file )
    {
      print "files exist. Will not overwrite.\n";
      next;
    }

    # Find the indels unique to Pindel, if the user wants to keep them aside
    my %uniq_to_pindel = ();
    if( $exclude_pindel )
    {
      %uniq_to_pindel = map { $_ => 1 } @{$bams{$case}{pindel}};
      foreach my $gatk_call ( @{$bams{$case}{gatk}} )
      {
        delete $uniq_to_pindel{$gatk_call} if( defined $uniq_to_pindel{$gatk_call} );
      }
    }

    # Store the variants into a hash to help sort variants by loci, and to remove duplicates
    my @annotated_lines = @{$bams{$case}{lines}};
    my %review_lines;
    for my $line ( @annotated_lines )
    {
      my ( $chr, $start, $stop, $ref, $var ) = split( /\t/, $line );
      $review_lines{$chr}{$start}{$stop} = join( "\t", $chr, $start, $stop, $ref, $var );
    }

    my $review_fh = IO::File->new( $review_file, ">" ) or die "Cannot open $review_file. $!";
    my $bed_fh = IO::File->new( $bed_file, ">" ) or die "Cannot open $bed_file. $!";
    $review_fh->print( "Chr\tStart\tStop\tRef\tVar\tCall\tNotes\n" );
    my $pindel_fh = IO::File->new( $pindel_file, ">" ) or die "Cannot open $pindel_file. $!" if( $exclude_pindel );
    $pindel_fh->print( "Chr\tStart\tStop\tRef\tVar\tCall\tNotes\n" ) if( $exclude_pindel );
    for my $chr ( nsort keys %review_lines )
    {
      for my $start ( sort {$a <=> $b} keys %{$review_lines{$chr}} )
      {
        for my $stop ( sort {$a <=> $b} keys %{$review_lines{$chr}{$start}} )
        {
          my ( undef, undef, undef, $ref, $var ) = split( /\t/, $review_lines{$chr}{$start}{$stop} );
          my ( $base0_start, $base0_stop ) = ( $start - 1, $stop - 1 );
          my $refvar = ( $ref eq '-' ? "0/$var" : "$ref/0" );
          if( $exclude_pindel && ( defined $uniq_to_pindel{"$chr\t$base0_start\t$stop\t$refvar"} ||
                                   defined $uniq_to_pindel{"$chr\t$start\t$base0_stop\t$refvar"} ))
          {
            $pindel_fh->print( $review_lines{$chr}{$start}{$stop}, "\n" );
          }
          else
          {
            $review_fh->print( $review_lines{$chr}{$start}{$stop}, "\n" );
            $bed_fh->printf( "%s\t%d\t%d\t%s\t%s\n", $chr, $base0_start, $stop, $ref, $var );
          }
        }
      }
    }
    $pindel_fh->close if( $exclude_pindel );
    $bed_fh->close;
    $review_fh->close;

    # Dump an IGV XML file to make it easy on the manual reviewers
    unless( Genome::Model::Tools::Analysis::DumpIgvXml->execute( tumor_bam => $bams{$case}{tumor}, normal_bam => $bams{$case}{normal}, review_bed_file => $bed_file, review_description => "High-confidence Tier1 SNVs and Indels", genome_name => $case, output_dir => $output_dir ))
    {
      print STDERR "WARNING: Unable to generate IGV XML for $case\n";
    }
    print "done.\n";
  }

  # Unless they already exist, create subdirectories to keep aside cases that won't be reviewed
  mkdir "$output_dir/dnu_qc_fail" unless( -e "$output_dir/dnu_qc_fail" );
  mkdir "$output_dir/dnu_hypermutated" unless( -e "$output_dir/dnu_hypermutated" );

  return 1;
}

1;
