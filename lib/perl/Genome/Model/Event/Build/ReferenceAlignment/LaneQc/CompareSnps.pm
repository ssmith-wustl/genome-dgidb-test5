package Genome::Model::Event::Build::ReferenceAlignment::LaneQc::CompareSnps;

use strict;
use warnings;

use Genome;
require File::Path;

class Genome::Model::Event::Build::ReferenceAlignment::LaneQc::CompareSnps {
    is => [ 'Genome::Model::Event' ],
};

sub execute {
    my $self  = shift;
    my $model = $self->model;
    my $build = $self->build;

    my @idas = $build->instrument_data_assignments;
    if (@idas > 1) {
        die $self->error_message("Build has many instrument data, __PACKAGE__ is designed to run on a per-lane basis.");
    }

    if ( !$self->validate_gold_snp_path ) {
        $self->status_message("No valid gold_snp_path for the build, aborting compare SNPs!");
    }

    my $output_dir = $build->qc_directory;
    File::Path::mkpath($output_dir) unless (-d $output_dir);
    unless (-d $output_dir) {
        die $self->error_message("Failed to create output_dir ($output_dir).");
    }

    my $genotype_file = $self->get_or_create_genotype_file;
    unless ( -s $genotype_file ) {
        die $self->error_message("Genotype file missing/empty: $genotype_file");
    }

    my @variant_files = glob($build->variants_directory . '/snv/samtools-*/snvs.hq');
    unless(scalar @variant_files eq 1) {
        die $self->error_message("Could not find samtools output for run.");
    }
    my $variant_file = $variant_files[0];
    unless ( -s $variant_file ) {
        die $self->error_message("Variant file missing/empty: $variant_file");
    }

    my $cmd = Genome::Model::Tools::Analysis::LaneQc::CompareSnps->create(
        genotype_file => $genotype_file, 
        output_file => $build->compare_snps_file,
        variant_file => $variant_file,
    );
    unless ($cmd) {
        die $self->error_message("Failed to create Genome::Model::Tools::Analysis::LaneQc::CompareSnps command.");
    }

    my $cmd_executed = eval { $cmd->execute };
    unless ($cmd_executed) {
        if ($@) {
            die $self->error_message("Failed to execute CompareSnps QC analysis! Received error: $@");
        }
        else {
            die $self->error_message("Failed to execute CompareSnps QC analysis!");
        }
    }

    my $metrics_rv = Genome::Model::ReferenceAlignment::Command::CreateMetrics::CompareSnps->execute(
        build_id => $self->build_id,
    );
    Carp::confess "Could not create compare_snps metrics for build " . $self->build_id unless $metrics_rv;

    return 1;
}

sub validate_gold_snp_path {
    my $self = shift;

    my $gold_snp_path = $self->build->gold_snp_path;
    unless ($gold_snp_path and -s $gold_snp_path) {
        $self->status_message('No gold_snp_path provided for the build or it is empty');
        return;
    }

    my $head    = `head -1 $gold_snp_path`;
    my @columns = split /\s+/, $head;
    
    unless (@columns and @columns == 9) {
        $self->status_message("Gold snp file: $gold_snp_path is not 9-column format");
        return;
    }
    return 1;
}

# FIXME This file should be created by genotype microarray builds if it's necessary for lane qc. Making the file here
# introduces concurrency problems (since multiple lane qc models are typically started in a batch) and also makes the 
# genotype microarray build's disk allocation inaccurate. 
sub get_or_create_genotype_file {
    my $self = shift;
    my $build = $self->build;
    my $gold_snp_file = $build->gold_snp_path;
    my $genotype_file = "$gold_snp_file.gold2geno";

    my $gold_snp_reader = Genome::Sys->open_file_for_reading($gold_snp_file);

    if ( -s $genotype_file ) {
        $self->status_message("Genotype file ($genotype_file) already exists, skipping generation.");
        return $genotype_file;
    }

    my $genotype_writer = Genome::Sys->open_file_for_writing($genotype_file);
    while (my $line = $gold_snp_reader->getline) {
        my @field = split("\t", $line);
        if ($field[1] ne $field[2]) {
            die $self->error_message("Sample ID differs in Gold SNP file: " . $field[1] . " vs. " . $field[2]);
        }
        print $genotype_writer $field[0] . "\t" . $field[1] . "\t" . $field[3] . $field[4] . "\n";
    }
    unless ( -s $genotype_file ) {
        die $self->error_message("Genotype file is empty after gold2geno conversion.");
    }
    return $genotype_file;
}

1;
