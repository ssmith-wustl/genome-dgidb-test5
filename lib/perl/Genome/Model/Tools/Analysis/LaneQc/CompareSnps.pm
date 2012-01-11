package Genome::Model::Tools::Analysis::LaneQc::CompareSnps;     # rename this when you give the module file a different name <--

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

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::LaneQc::CompareSnps {
	is => 'Command',

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

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS

EOS
}

sub execute {
    my $self = shift;
    return Genome::Model::Tools::Analysis::LaneQc::CompareSnpsResult::_generate_data($self);
}

1;
