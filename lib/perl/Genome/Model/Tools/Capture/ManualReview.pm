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
    exclude_pindel => { is => 'Boolean', doc => "Separate calls unique to Pindel, since many cannot be reviewed on a BWA aligned BAM", is_optional => 1, default => 1 },
    hypermutation_minimum => { is => 'Number', doc => "If number of SNVs+Indels exceeds this, write output to a subdirectory named hypermutated", is_optional => 1, default => 500 },
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
  my $hypermutation_minimum = $self->hypermutation_minimum;
  $output_dir =~ s/(\/)+$//; # Remove trailing forward-slashes if any

  # Check on all the input data before starting work
  my $somvar_group = Genome::ModelGroup->get( $som_var_model_group_id );
  print STDERR "ERROR: Could not find a model-group with ID: $som_var_model_group_id\n" unless( defined $somvar_group );
  print STDERR "ERROR: Output directory not found: $output_dir\n" unless( -e $output_dir );
  return undef unless( defined $somvar_group && -e $output_dir );

  my @somvar_models = $somvar_group->models;
  my %bams; # Hash to store the tumor-normal BAM pairs
  print "Finding latest succeeded builds in model-group ", $somvar_group->name, "...\n";
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
    @{$bams{$tcga_patient_id}{snvs}} = `cat $snv_anno`;
    @{$bams{$tcga_patient_id}{indels}} = `cat $indel_anno`;
    if( $exclude_pindel )
    {
      ${$bams{$tcga_patient_id}{gatk}} = $gatk_calls;
      ${$bams{$tcga_patient_id}{pindel}} = $pindel_calls;
    }
  }

  # Unless it already exists, create a subdirectory to keep aside hypermutated cases
  mkdir "$output_dir/hypermutated" unless( -e "$output_dir/hypermutated" );

  foreach my $case ( keys %bams )
  {
    print "Preparing review files for $case... ";

    # Check if any review files exist. We don't want to overwrite reviewed variants
    if( -e "$output_dir/$case.snv.review.csv" or -e "$output_dir/$case.indel.review.csv" )
    {
      print "files exist. Will not overwrite.\n";
      next;
    }

    # Find the indels unique to Pindel, if the user wants to keep them aside
    my %uniq_to_pindel = ();
    if( $exclude_pindel )
    {
      my ( $gatk_calls, $pindel_calls ) = ( ${$bams{$case}{gatk}}, ${$bams{$case}{pindel}} );
      my @gatk_lines = `cut -f 1-4 $gatk_calls`;
      my @pindel_lines = `cut -f 1-4 $pindel_calls`;
      chomp( @gatk_lines, @pindel_lines );
      %uniq_to_pindel = map { $_ => 1 } @pindel_lines;
      foreach my $gatk_call ( @gatk_lines )
      {
        delete $uniq_to_pindel{$gatk_call} if( defined $uniq_to_pindel{$gatk_call} );
      }
    }

    # Store the variants into a hash to help sort variants by loci, and to remove duplicates
    my %review_lines = ();
    my %var_cnt = ( snvs => 0, indels => 0 );
    for my $line ( @{$bams{$case}{snvs}} )
    {
      my ( $chr, $start, $stop, $ref, $var ) = split( /\t/, $line );
      ++$var_cnt{snvs} unless( defined $review_lines{snvs}{$chr}{$start}{$stop} );
      $review_lines{snvs}{$chr}{$start}{$stop} = join( "\t", $chr, $start, $stop, $ref, $var );
    }
    for my $line ( @{$bams{$case}{indels}} )
    {
      my ( $chr, $start, $stop, $ref, $var ) = split( /\t/, $line );
      my ( $base0_start, $base0_stop ) = ( $start - 1, $stop - 1 );
      my $refvar = ( $ref eq '-' ? "0/$var" : "$ref/0" );
      if( $exclude_pindel && ( defined $uniq_to_pindel{"$chr\t$base0_start\t$stop\t$refvar"} ||
                               defined $uniq_to_pindel{"$chr\t$start\t$base0_stop\t$refvar"} ))
      {
        $review_lines{pindels}{$chr}{$start}{$stop} = join( "\t", $chr, $start, $stop, $ref, $var );
      }
      else
      {
        ++$var_cnt{indels} unless( defined $review_lines{indels}{$chr}{$start}{$stop} );
        $review_lines{indels}{$chr}{$start}{$stop} = join( "\t", $chr, $start, $stop, $ref, $var );
      }
    }

    # If there are more variants than our hypermutation threshold, store them separately
    my $tot_var_cnt = $var_cnt{snvs} + $var_cnt{indels};
    my $output_dir_new = $output_dir;
    if( $tot_var_cnt >= $hypermutation_minimum )
    {
      $output_dir_new = "$output_dir/hypermutated";
    }

    # Create a review file for manual reviewers to record comments, and a bed file for use with IGV
    my $snv_review_file = "$output_dir_new/$case.snv.review.csv";
    my $indel_review_file = "$output_dir_new/$case.indel.review.csv";
    my $snv_bed_file = "$output_dir_new/$case.snv.bed";
    my $indel_bed_file = "$output_dir_new/$case.indel.bed";
    # If user wants to exclude calls unique to pindel, create a separate file (no need for a .bed)
    my $pindel_review_file = "$output_dir_new/$case.pindel.review.csv";

    # Write indel review files
    my $indel_review_fh = IO::File->new( $indel_review_file, ">" ) or die "Cannot open $indel_review_file. $!";
    my $indel_bed_fh = IO::File->new( $indel_bed_file, ">" ) or die "Cannot open $indel_bed_file. $!";
    $indel_review_fh->print( "Chr\tStart\tStop\tRef\tVar\tCall\tNotes\n" );
    for my $chr ( nsort keys %{$review_lines{indels}} )
    {
      for my $start ( sort {$a <=> $b} keys %{$review_lines{indels}{$chr}} )
      {
        for my $stop ( sort {$a <=> $b} keys %{$review_lines{indels}{$chr}{$start}} )
        {
          my ( undef, undef, undef, $ref, $var ) = split( /\t/, $review_lines{indels}{$chr}{$start}{$stop} );
          $indel_review_fh->print( $review_lines{indels}{$chr}{$start}{$stop}, "\n" );
          $indel_bed_fh->printf( "%s\t%d\t%d\t%s\t%s\n", $chr, $start-1, $stop, $ref, $var );
        }
      }
    }
    $indel_bed_fh->close;
    $indel_review_fh->close;

    # If the user doesn't want to review Pindel calls, store them in a separate file
    if( $exclude_pindel )
    {
      my $pindel_review_fh = IO::File->new( $pindel_review_file, ">" ) or die "Cannot open $pindel_review_file. $!";
      $pindel_review_fh->print( "Chr\tStart\tStop\tRef\tVar\tCall\tNotes\n" );
      for my $chr ( nsort keys %{$review_lines{pindels}} )
      {
        for my $start ( sort {$a <=> $b} keys %{$review_lines{pindels}{$chr}} )
        {
          for my $stop ( sort {$a <=> $b} keys %{$review_lines{pindels}{$chr}{$start}} )
          {
            $pindel_review_fh->print( $review_lines{pindels}{$chr}{$start}{$stop}, "\n" );
          }
        }
      }
      $pindel_review_fh->close if( $exclude_pindel );
    }

    # Write SNV review files
    my $snv_review_fh = IO::File->new( $snv_review_file, ">" ) or die "Cannot open $snv_review_file. $!";
    my $snv_bed_fh = IO::File->new( $snv_bed_file, ">" ) or die "Cannot open $snv_bed_file. $!";
    $snv_review_fh->print( "Chr\tStart\tStop\tRef\tVar\tCall\tNotes\n" );
    for my $chr ( nsort keys %{$review_lines{snvs}} )
    {
      for my $start ( sort {$a <=> $b} keys %{$review_lines{snvs}{$chr}} )
      {
        for my $stop ( sort {$a <=> $b} keys %{$review_lines{snvs}{$chr}{$start}} )
        {
          my ( undef, undef, undef, $ref, $var ) = split( /\t/, $review_lines{snvs}{$chr}{$start}{$stop} );
          $snv_review_fh->print( $review_lines{snvs}{$chr}{$start}{$stop}, "\n" );
          $snv_bed_fh->printf( "%s\t%d\t%d\t%s\t%s\n", $chr, $start-1, $stop, $ref, $var );
        }
      }
    }
    $snv_bed_fh->close;
    $snv_review_fh->close;

    # Dump IGV XML files to make it easy on the manual reviewers
    unless( Genome::Model::Tools::Analysis::DumpIgvXml->execute( tumor_bam => $bams{$case}{tumor}, normal_bam => $bams{$case}{normal},
            review_bed_file => $indel_bed_file, review_description => "High-confidence Tier1 Indels", genome_name => "$case.indel", output_dir => $output_dir_new ) and
            Genome::Model::Tools::Analysis::DumpIgvXml->execute( tumor_bam => $bams{$case}{tumor}, normal_bam => $bams{$case}{normal},
            review_bed_file => $snv_bed_file, review_description => "High-confidence Tier1 SNVs", genome_name => "$case.snv", output_dir => $output_dir_new ))
    {
      print STDERR "WARNING: Unable to generate IGV XMLs for $case\n";
    }
    print "done.\n";
  }

  return 1;
}

1;
