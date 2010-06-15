
package Genome::ProcessingProfile::Somatic;

#:eclark 11/16/2009 Code review.

# Short Term: This processing profile implements a wrapper around a workflow.  ProcessingProfiles should have a more direct interface to them.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Somatic{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        only_tier_1 => {
            doc => "If set to true, the pipeline will skip ucsc annotation and produce only tier 1 snps",
        },
        min_mapping_quality => {
            doc => "minimum average mapping quality threshold for high confidence call",
        },
        min_somatic_quality => {
            doc => "minimum somatic quality threshold for high confidence call",
        },
        skip_sv => {
            doc => "If set to true, the pipeline will skip structural variation detection",
        },
        sv_detector_version => {
            doc => "Version of the SV detector to use.  If blank, use the default specified in the Genome::Model::Tools::BreakDancer module",
            is_optional => 1,
        },
        sv_detector_params => {
            doc => "Parameters to pass to the SV detector.  For breakdancer, separate params for bam2cfg & BreakDancerMax with a colon",
            is_optional => 1,
        },
        bam_window_version => {
            doc => "Version to use for bam-window in the copy number variation step.",
        },
        bam_window_params => {
            doc => "Parameters to pass to bam-window in the copy number variation step.",
        },
        sniper_version => {
            doc => "Version to use for bam-somaticsniper for detecting snps and indels.",
        },
        sniper_params => {
            doc => "Parameters to pass to bam-somaticsniper for detecting snps and indels",
        },
        bam_readcount_version => {
            doc => "Version to use for bam-readcount in the high confidence step.",
        },
        bam_readcount_params=> {
            doc => "Parameters to pass to bam-readcount in the high confidence step",
        },
        require_dbsnp_allele_match => {
            doc => "If set to true, the pipeline will require the allele to match during Lookup Variants"  
        },
    ],
};

sub stages {
    return (qw/
            somatic
            /);
}

sub somatic_job_classes {
    return (qw/
            Genome::Model::Event::Build::Somatic::RunWorkflow
        /);
}

sub somatic_objects {
    return 1;
}


1;

