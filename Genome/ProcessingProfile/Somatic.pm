
package Genome::ProcessingProfile::Somatic;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Somatic{
    is => 'Genome::ProcessingProfile',
    has => [
        only_tier_1 => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'only_tier_1'],
            is_mutable  => 1,
            doc => "If set to true, the pipeline will skip ucsc annotation and produce only tier 1 snps",
        },
        min_mapping_quality => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'min_mapping_quality'],
            is_mutable  => 1,
            doc => "minimum average mapping quality threshold for high confidence call",
        },
        min_somatic_quality => {
            via         => 'params',
            to          => 'value',
            where       => [name => 'min_mapping_quality'],
            is_mutable  => 1,
            doc => "minimum somatic quality threshold for high confidence call",
        },
    ],
};

sub params_for_class{
    my $self = shift;
    return qw//;
}

sub stages {
    return (qw/
            somatic
            verify_successful_completion
            /);
}

sub somatic_job_classes {
    return (qw/
            Genome::Model::Command::Build::Somatic::RunWorkflow
        /);
}

sub somatic_objects {
    return 1;
}


1;

