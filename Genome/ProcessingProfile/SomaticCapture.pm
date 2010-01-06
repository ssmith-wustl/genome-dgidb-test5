
package Genome::ProcessingProfile::SomaticCapture;

#:eclark 11/16/2009 Code review.

# Short Term: This processing profile implements a wrapper around a workflow.  ProcessingProfiles should have a more direct interface to them.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticCapture{
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
        }
    ],
};

sub stages {
    return (qw/
            somaticcapture
            /);
}

sub somaticcapture_job_classes {
    return (qw/
            Genome::Model::Event::Build::SomaticCapture::RunWorkflow
        /);
}

sub somaticcapture_objects {
    return 1;
}


1;

