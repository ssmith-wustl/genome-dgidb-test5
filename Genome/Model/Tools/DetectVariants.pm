package Genome::Model::Tools::DetectVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants {
    is => 'Command',
    has_constant => [
        detect_snps => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect SNPs',
        },
        detect_indels => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect small indels',
        },
        detect_svs => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect structural variations',
        },
    ],
    has => [
        aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the aligned reads input file',
            shell_args_position => '1',
            is_input => 1,
        },
        reference_sequence_input => {
            is => 'Text',
            doc => 'Location of the reference sequence file',
            is_input => 1,
        },
    ],
    has_optional => [
        capture_set_input => {
            is => 'Text',
            doc => 'Location of the file containing the regions of interest (if present, only variants in the set will be reported)',
            is_input => 1,
        },
        snp_params => {
            is => 'Text',
            doc => 'Parameters to pass through to SNP detection',
            is_input => 1,
        },
        indel_params => {
            is => 'Text',
            doc => 'Parameters to pass through to small indel detection',
            is_input => 1,
        },
        sv_params => {
            is => 'Text',
            doc => 'Parameters to pass through to structural variation detection',
            is_input => 1,
        },
        version => {
            is => 'Version',
            doc => 'The version of the variant detector to use.',
        },
        working_directory => {
            is => 'Text',
            doc => 'Location to save to the detector-specific files generated in the course of running',
            is_input => 1,
            is_output => 1,
        }
    ],
};

sub help_brief {
    "A selection of variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants ...
EOS
}

sub help_detail {
    return <<EOS 
Tools to run variant detectors with a common API and output their results in a standard format.
EOS
}

1;
