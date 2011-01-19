package Genome::ProcessingProfile::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticVariation{
    is => 'Genome::ProcessingProfile',
    has_param => [
        snv_detection_strategy => {
            doc => "Snv detector strategy string",
        },
        indel_detection_strategy => {
            doc => "Indel detector strategy string",
        },
        sv_detection_strategy => {
            doc => "SV detector strategy string",
        },
    ],
};

sub _initialize_build {
    my($self,$build) = @_;
    die "This is not yet implemented.";
}

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;
    die "This is not yet implemented.";
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;
    die "This is not yet implemented.";
}

1;
