package Genome::Model::Tools::Analysis::LaneQc::CompareSnpsResult;

#####################################################################################################################################
# SearchRuns - Search the database for runs
#
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	04/01/2009 by D.K.
#	MODIFIED:	04/01/2009 by D.K.
#
#	NOTES:
#
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::Analysis::LaneQc::CompareSnpsResult {
	is => 'Genome::SoftwareResult::Stageable',

    #TODO: Use class pre-processor to sync the result class and the command class
    has => [
        verbose       => { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1},
        min_depth_het => { is => 'Text', doc => "Minimum depth to compare a het call", is_optional => 1, default => 8},
        min_depth_hom => { is => 'Text', doc => "Minimum depth to compare a hom call", is_optional => 1, default => 4},
        flip_alleles  => { is => 'Text', doc => "If set to 1, try to avoid strand issues by flipping alleles to match", is_optional => 1},
        fast          => { is => 'Text', doc => "If set to 1, run a quick check on just chromosome 1", is_optional => 1},
    ],

    has_input => [
        genotype_file   => { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0 },
        variant_file    => { is => 'Text', doc => "Variant calls in SAMtools mpileup-consensus format", is_optional => 1 },
        bam_file        => { is => 'Text', doc => "Alternatively, provide a BAM file", is_optional => 1 },
        sample_name     => { is => 'Text', doc => "Sample Name Used in QC", is_optional => 1 },
        reference_build => { is => 'Text', doc => "36 or 37", is_optional => 1, default => 36},
        output_file     => { is => 'Text' },
    ],
};

sub help_brief {                            # keep this to just a few words <---
    "Compares SAMtools variant calls to array genotypes"
}

sub help_synopsis {
    return <<EOS
This command compares SAMtools variant calls to array genotypes
EXAMPLE:	gmt analysis lane-qc compare-snps --genotype-file affy.genotypes --variant-file lane1.var
EOS
}

sub help_detail { }

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $rv = eval {
        $self->_prepare_staging_directory;
        $self->_generate_data;
        $self->_prepare_output_directory;
        $self->_promote_data;
        $self->_reallocate_disk_allocation;
        return 1;
    };
    my $error = $@;

    if ($error) {
        die $self->error_message($error);
    }
    elsif ($rv ne 1) {
        die $self->error_message("Unexpected return value: $rv");
    }

    $self->status_message('All processes completed.');

    return $self;
}

sub _generate_data {
    my $self = shift;
    die 'Command failed' unless Genome::Model::Tools::Analysis::LaneQc::CompareSnps->execute(
        output_file => $self->temp_staging_directory . '/output',
        verbose => $self->verbose,
        min_depth_het => $self->min_depth_het,
        min_depth_hom => $self->min_depth_hom,
        flip_alleles => $self->flip_alleles,
        fast => $self->fast,
        genotype_file => $self->genotype_file,
        variant_file => $self->variant_file,
        bam_file => $self->bam_file,
        sample_name => $self->sample_name,
        reference_build => $self->reference_build,
    );
}

1;
